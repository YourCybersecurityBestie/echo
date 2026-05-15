# Echo — Microsoft Entra Agent ID Setup

How the AWS-hosted Bedrock catalog Q&A agent gets registered in your Microsoft tenant so it can be invoked from Copilot Studio under the same governance as your Microsoft-hosted agents.

This is the **cross-cloud governance moment** in the customer demo. One identity surface (Entra), two clouds (Azure + AWS). When you want to revoke the AWS agent, you do it in Entra — same place you'd revoke a Microsoft-native one.

---

## Concepts

| Object | Created where | What it represents |
|---|---|---|
| **Agent Identity Blueprint** | Microsoft Graph `/applications/microsoft.graph.agentIdentityBlueprint` | The "type" of agent. Like an app registration for agents. |
| **BlueprintPrincipal** | Microsoft Graph `/servicePrincipals/microsoft.graph.agentIdentityBlueprintPrincipal` | The service principal in your tenant for the blueprint. |
| **Agent Identity** | Microsoft Graph `/servicePrincipals/microsoft.graph.agentIdentity` | A specific running agent instance. One per environment (dev/prod). |

For Echo's catalog agent we create one Blueprint, one BlueprintPrincipal, and one Agent Identity (the prod instance running in `eu-central-1`).

## Prereqs

- Tenant: `2d40759a-de76-4b8a-9497-7b4d3e672b3b` (Microsoft EMU — galaxysec scope)
- Azure subscription: `d7505cac-f0a2-4896-8c19-818421939a96`
- Permissions to create app registrations + service principals in the tenant
- Microsoft Graph PowerShell installed (`Install-Module Microsoft.Graph`)
- The AWS Lambda already deployed (see `07-bedrock-catalog-agent.md`)

## Step 1 — Create the Blueprint

```pwsh
Connect-MgGraph -Scopes "Application.ReadWrite.All","AgentIdentity.ReadWrite.All"

$blueprint = @{
  displayName = "Echo Catalog Q&A Agent"
  description = "Cross-cloud agent that answers questions about a user's Echo podcast catalog. Runs in AWS (eu-central-1) on Bedrock Claude Haiku. Governed under Microsoft Entra Agent ID."
  publisherDomain = "yourcybersecuritybestie.dev"
  signInAudience = "AzureADMyOrg"
  identifierUris = @("api://echo-catalog")
  agentBlueprintProperties = @{
    runtime = "external"           # not Azure-hosted
    region  = "aws-eu-central-1"
    tags    = @("project:echo","tier:specialist","cloud:aws")
  }
}

$bp = Invoke-MgGraphRequest -Method POST `
  -Uri "https://graph.microsoft.com/v1.0/applications/microsoft.graph.agentIdentityBlueprint" `
  -Body ($blueprint | ConvertTo-Json -Depth 10)

$bp.id        # save this — it's the Blueprint object ID
$bp.appId     # save this — it's the appId clients present in tokens
```

## Step 2 — Create the BlueprintPrincipal (service principal)

```pwsh
$bpPrincipal = @{
  appId = $bp.appId
  agentIdentityProperties = @{
    blueprintId = $bp.id
  }
}

$bps = Invoke-MgGraphRequest -Method POST `
  -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/microsoft.graph.agentIdentityBlueprintPrincipal" `
  -Body ($bpPrincipal | ConvertTo-Json -Depth 10)

$bps.id   # save this — BlueprintPrincipal object ID
```

## Step 3 — Create the Agent Identity (prod instance)

```pwsh
$agent = @{
  displayName = "echo-catalog-prod"
  blueprintPrincipalId = $bps.id
  agentInstanceProperties = @{
    deploymentLocation = "aws-eu-central-1"
    deploymentRef = "echo-bedrock-catalog/main"
    environment = "prod"
  }
}

$ai = Invoke-MgGraphRequest -Method POST `
  -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/microsoft.graph.agentIdentity" `
  -Body ($agent | ConvertTo-Json -Depth 10)

$ai.id      # Agent Identity object ID
$ai.appId   # this is what the Lambda validates against incoming tokens
```

## Step 4 — Generate a client secret for the Blueprint

WIF / sidecar pattern is the *preferred* runtime credential. AWS Lambda can't host a sidecar, so we use a client secret stored in AWS Secrets Manager.

```pwsh
$secret = Invoke-MgGraphRequest -Method POST `
  -Uri "https://graph.microsoft.com/v1.0/applications/$($bp.id)/addPassword" `
  -Body (@{ passwordCredential = @{ displayName = "echo-catalog-aws-prod"; endDateTime = (Get-Date).AddYears(1) } } | ConvertTo-Json -Depth 5)

$secret.secretText   # store this in AWS Secrets Manager IMMEDIATELY
```

Push to AWS:
```pwsh
aws secretsmanager create-secret `
  --name echo/entra-agent-secret `
  --region eu-central-1 `
  --secret-string $secret.secretText
```

The Lambda fetches this at cold start, exchanges it for an access token, and uses that to call Microsoft Graph if it needs to (e.g., to look up the requester's recent episodes). It also validates incoming tokens against `$ai.appId`.

## Step 5 — Wire the Power Platform custom connector

In `03-custom-connectors-openapi.md` the `BedrockCatalogQA` connector has its `securityDefinitions` already pointing at OAuth 2.0 against your tenant. In Power Platform:

1. **Custom connectors → Edit `BedrockCatalogQA` → Security**
2. Authentication type: **OAuth 2.0**
3. Identity provider: **Azure Active Directory**
4. Client id: `$bp.appId` from Step 1
5. Client secret: from Step 4
6. Tenant ID: `2d40759a-de76-4b8a-9497-7b4d3e672b3b`
7. Resource URL / Scope: `api://echo-catalog/.default`
8. Redirect URL: copy what Power Platform shows; add it back to the Blueprint's reply URLs:

```pwsh
Invoke-MgGraphRequest -Method PATCH `
  -Uri "https://graph.microsoft.com/v1.0/applications/$($bp.id)" `
  -Body (@{ web = @{ redirectUris = @("https://global.consent.azure-apim.net/redirect") } } | ConvertTo-Json -Depth 5)
```

Now Copilot Studio can call the connector — Power Platform handles the token exchange under the hood, presents the bearer token to API Gateway, and the Lambda validates it.

## Step 6 — Lambda-side validation

Pseudocode for `lambda/lib/entraAgentAuth.ts`:

```ts
import { jwtVerify, createRemoteJWKSet } from 'jose'

const TENANT = process.env.ENTRA_TENANT_ID!
const EXPECTED_APP_ID = process.env.ENTRA_AGENT_APP_ID!  // $ai.appId from Step 3
const EXPECTED_AUDIENCE = 'api://echo-catalog'
const JWKS = createRemoteJWKSet(new URL(`https://login.microsoftonline.com/${TENANT}/discovery/v2.0/keys`))

export async function validate(authHeader: string) {
  const token = authHeader.replace(/^Bearer /i, '')
  const { payload } = await jwtVerify(token, JWKS, {
    issuer: `https://login.microsoftonline.com/${TENANT}/v2.0`,
    audience: EXPECTED_AUDIENCE,
  })
  if (payload.appid !== EXPECTED_APP_ID && payload.azp !== EXPECTED_APP_ID) {
    throw new Error('appId mismatch — token was not issued to the registered Agent Identity')
  }
  return payload
}
```

## Step 7 — Verify end-to-end

```pwsh
# From a dev machine, mint a token using the client secret
$body = @{
  client_id = $bp.appId
  client_secret = $secret.secretText
  scope = "api://echo-catalog/.default"
  grant_type = "client_credentials"
}
$tok = Invoke-RestMethod -Method POST `
  -Uri "https://login.microsoftonline.com/$TENANT/oauth2/v2.0/token" `
  -Body $body

# Call the Lambda
Invoke-RestMethod -Method POST `
  -Uri "https://{API_HOST}/v1/ask" `
  -Headers @{ Authorization = "Bearer $($tok.access_token)" } `
  -ContentType "application/json" `
  -Body (@{ question = "what episodes mention Defender?"; userId = "you@example.com" } | ConvertTo-Json)
```

You should get a real Bedrock answer back.

## Revocation

To kill the AWS agent without touching AWS:

```pwsh
# Disable the Agent Identity — Power Platform tokens stop being issued
Invoke-MgGraphRequest -Method PATCH `
  -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($ai.id)" `
  -Body (@{ accountEnabled = $false } | ConvertTo-Json)
```

Pair with `cdk destroy` in `echo-bedrock-catalog` to also remove the AWS resources.

## Notes

- **fmi_path / WIF** is the documented preferred pattern for non-Azure agents that *can* run a sidecar. Lambda can't, so we use a client secret. If you later move the catalog agent to ECS Fargate, switch to the sidecar.
- **Token caching:** the Lambda doesn't issue outbound tokens for every request — the Power Platform connector does that and caches the bearer it presents. The Lambda only validates inbound tokens (cheap, JWKS cached).
- **Audit trail:** every token issuance shows up in **Entra ID → Sign-in logs → Service principal sign-ins**. Filter by app ID to see invocations of your AWS agent.
