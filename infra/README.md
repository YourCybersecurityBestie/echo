# Echo — Infrastructure

Subscription-scope Bicep that provisions everything Echo needs in Azure. Reuses the shared `law-uksouth` Log Analytics workspace (RG `sentinel-goodies`) — the deployment **does not create** a new LAW.

## What it deploys

Into a new resource group **`rg-echo-prod`** in **Sweden Central**:

| Resource | SKU | Purpose |
|---|---|---|
| Storage account `stechoprod<suffix>` | Standard_LRS, MI-only | Audio + RSS + catalog |
| Key Vault `kv-echo-prod-<suffix>` | Standard, RBAC, purge protection | Secrets |
| Speech `spch-echo-prod` | S0 (deployed in West Europe — see note) | TTS |
| App Insights `appi-echo-prod` | Workspace-based → shared `law-uksouth` | Telemetry |
| Function App `func-echo-publisher` | Flex Consumption Linux Node 20, MI | Publisher API |
| Static Web App `swa-echo-listener` | Standard (West Europe) | PWA |
| Foundry hub + project `aih-echo-prod` / `aif-echo-prod` | AI Services S0 | Agents |
| GPT-4o deployment | GlobalStandard, 50K TPM | Researcher + Scriptwriter |
| RBAC | various | MIs across SA / Speech / KV / Foundry |

## Region notes

- **Compute / Storage / Foundry:** Sweden Central (matches global default)
- **Speech:** West Europe — `Andrew3` / `Ava3` Dragon HD voices are GA there as of May 2026; Sweden Central availability is unverified. Cross-region call adds ~50ms.
- **Static Web App:** West Europe — SWA is not yet GA in Sweden Central.
- **Log Analytics:** UK South — reuses the existing shared workspace.

## Prereqs

```pwsh
az login --use-device-code      # CAE token expiry — device code is more reliable
az account set --subscription d7505cac-f0a2-4896-8c19-818421939a96
az bicep upgrade
```

## Deploy

1. Get your AAD object ID:
   ```pwsh
   az ad signed-in-user show --query id -o tsv
   ```
2. Edit `main.parameters.json` — paste your object ID into `ownerObjectId.value`.
3. Optional: change `nameSuffix` (must be 4–8 lowercase alphanumeric).
4. What-if first:
   ```pwsh
   az deployment sub what-if `
     --location swedencentral `
     --template-file main.bicep `
     --parameters main.parameters.json
   ```
5. Deploy:
   ```pwsh
   az deployment sub create `
     --location swedencentral `
     --template-file main.bicep `
     --parameters main.parameters.json
   ```

## Outputs

After deploy, useful values are surfaced as deployment outputs:

```pwsh
az deployment sub show --name main --query properties.outputs
```

Includes: `functionAppHost`, `staticWebAppHost`, `foundryProjectEndpoint`, `keyVaultName`, `appInsightsConnectionString`.

## Tear down

```pwsh
az group delete --name rg-echo-prod --yes --no-wait
```

The shared `law-uksouth` and any Galaxysec resources are **not touched**.

## What's NOT in here

- No Container Apps, no ACR usage — Flex Consumption uses zip deploy
- No private endpoints — public network with MI auth (v1 simplicity; v1.1 may add)
- No Azure Communication Services (WhatsApp deferred)
- No Bicep for the AWS Bedrock arm — that's CDK in the `echo-bedrock-catalog` repo
- No Microsoft Graph calls (Entra Agent ID setup is a manual one-time step in `09-entra-agent-id-setup.md`)
