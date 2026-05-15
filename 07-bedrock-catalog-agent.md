# Echo — Bedrock Catalog Q&A Agent (AWS, optional)

A small AWS workload that lets you ask questions about your Echo podcast catalog using Anthropic Claude on Bedrock. Designed to be **start/stop**: when you're not actively demoing, run `cdk destroy` and AWS cost goes to **$0**. `cdk deploy` brings it back in ~3 minutes.

It's deliberately not a critical-path dependency. Echo's core flow (URL → episode) works whether this is online or not.

---

## Why it exists

Three demo purposes:
1. **Cross-cloud agent story.** The Echo orchestrator (Microsoft) reaches into AWS as if it were a local tool.
2. **Entra Agent ID governance demo.** AWS workload, Microsoft-tenant identity. See `09-entra-agent-id-setup.md`.
3. **Bedrock comparison.** Same brief reviewed by a non-Microsoft model is a useful contrast in customer conversations.

---

## Architecture

```
                        Microsoft Entra
                        Agent Identity
                              │ (token)
                              ▼
   Copilot Studio ──► API Gateway ──► Lambda ──► Bedrock (Claude Haiku 4.5)
                          │              │
                          │              └─► S3 (catalog.json snapshot)
                          │
                       (eu-central-1)
```

**Components**

| Resource | Why this choice |
|---|---|
| **API Gateway HTTP API** | Cheaper + simpler than REST API; no always-on cost |
| **Lambda** (Node.js 20, 1024 MB, 30s timeout) | Pay-per-call; no idle cost |
| **S3 bucket `echo-catalog-<suffix>`** | Stores the catalog JSON synced from Azure |
| **Bedrock model `anthropic.claude-haiku-4-5`** | Cheapest decent model in eu-central-1; fast |
| **Secrets Manager** | Holds the Entra Agent ID client secret |
| **CloudWatch Logs** | Lambda logs only, 7-day retention |

**Deliberately omitted**

- **Bedrock Knowledge Base / OpenSearch Serverless** — ~$175/mo always-on. Not justified for under 200 episodes. Lambda fetches `catalog.json` from S3 on each call and fits it into Claude's context window.
- **VPC** — Lambda runs without a VPC. Bedrock and S3 are reached via AWS service endpoints. Adds no security; saves cold-start time.
- **CloudFront / WAF** — API Gateway + Entra Agent ID auth is sufficient gate.

---

## Repo: `echo-bedrock-catalog`

```
echo-bedrock-catalog/
├── README.md
├── cdk.json
├── package.json
├── bin/
│   └── echo-bedrock-catalog.ts        # CDK app entry
├── lib/
│   └── echo-bedrock-stack.ts          # one stack, all resources
├── lambda/
│   ├── ask.ts                         # POST /ask handler
│   ├── health.ts                      # GET /health handler
│   ├── lib/
│   │   ├── entraAgentAuth.ts          # validate inbound Entra token
│   │   ├── catalogClient.ts           # fetch catalog.json from S3
│   │   └── bedrockClient.ts           # invoke Claude Haiku
│   └── package.json
├── scripts/
│   ├── sync-catalog.ts                # pulls /api/catalog from Azure → S3
│   └── deploy.ps1
├── .github/
│   └── workflows/
│       ├── deploy.yml                 # OIDC → AWS → cdk deploy
│       └── sync.yml                   # nightly catalog sync
└── .gitignore
```

## Identity & secrets

**Outbound (CI → AWS):** GitHub OIDC trust to AWS account `839000215331`, scoped to the `YourCybersecurityBestie/echo-bedrock-catalog` repo. No long-lived AWS access keys anywhere.

**Inbound (Microsoft tenant → AWS):** every request to `/ask` must carry a JWT issued by Microsoft Entra against the Agent Identity Blueprint. The Lambda validates:

- `iss` is `https://login.microsoftonline.com/{TENANT_ID}/v2.0`
- `appid` matches the registered Agent Identity service principal
- `aud` is `api://echo-catalog`
- Token signature against the Entra JWKS

Validation logic in `lambda/lib/entraAgentAuth.ts` — uses `jose` for JWKS caching.

## Bedrock model choice

| Model | eu-central-1 available | Input $/1M | Output $/1M | Notes |
|---|---|---|---|---|
| `anthropic.claude-haiku-4-5` | yes | $1.00 | $5.00 | **Default.** Fast, cheap, plenty smart for catalog Q&A. |
| `anthropic.claude-sonnet-4-5` | yes | $3.00 | $15.00 | Use for the side-by-side "second opinion" demo only. |
| `amazon.nova-lite` | yes | $0.06 | $0.24 | Cheapest fallback. Quality drops on multi-episode reasoning. |

Switch by changing the `BEDROCK_MODEL_ID` env var on the Lambda.

## Sync strategy

Echo's Publisher exposes `GET /api/catalog?userId=…&limit=200` (see `04-github-copilot-prompts.md`). The `scripts/sync-catalog.ts` script fetches it, writes to `s3://echo-catalog-<suffix>/users/{userSlug}/catalog.json`. Runs:

- **On every publish** (nice-to-have, future): Publisher webhook → Lambda → S3
- **Nightly via GitHub Actions** (`.github/workflows/sync.yml`): cron `0 2 * * *`

## Start / stop runbook

**Bring online (~3 min):**
```pwsh
gh repo clone YourCybersecurityBestie/echo-bedrock-catalog
cd echo-bedrock-catalog
npm install
npx cdk deploy --require-approval never
# Then in the Echo orchestrator, set Global.bedrockCatalogEnabled = true
```

**Tear down (back to $0):**
```pwsh
npx cdk destroy --force
# Then in the Echo orchestrator, set Global.bedrockCatalogEnabled = false
```

The S3 bucket is **retained on destroy** (the catalog snapshot is small and worth keeping). Everything else — Lambda, API Gateway, IAM roles, log groups — is deleted.

## Cost when on

For the demo workload (~10 questions/month):

| Line item | Monthly |
|---|---|
| Lambda (10 invocations × 2s × 1 GB) | < $0.01 |
| API Gateway (10 requests) | < $0.01 |
| Bedrock Claude Haiku (10 × ~5K input + ~500 output) | ~$0.10 |
| S3 (catalog snapshots, < 100 KB) | < $0.01 |
| CloudWatch Logs (7-day retention) | < $0.10 |
| Secrets Manager (1 secret) | $0.40 |
| **Total when on** | **~$0.60/mo** |
| **Total when off** | **$0.00** |

## Verification

1. `cdk deploy` completes without errors
2. `curl https://{API_HOST}/v1/health` returns 200
3. `curl -X POST https://{API_HOST}/v1/ask -H "Authorization: Bearer {ENTRA_TOKEN}" -d '{"question":"what episodes mention Defender","userId":"you@example.com"}'` returns a real answer with cited episode IDs
4. CloudWatch Logs show the inbound token validation succeeded
5. `cdk destroy` removes everything except the S3 bucket
