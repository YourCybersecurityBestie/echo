# Echo — Cost & Ops

What this thing costs to run, and how to drive that to zero when you're not using it.

---

## Monthly cost — demo workload (~30 episodes/month, ~10 catalog questions/month)

### Azure (always on)

| Layer | Resource | SKU | Monthly |
|---|---|---|---|
| Speech | `spch-echo-prod` | S0, ~30 episodes × 12K chars × $30/1M | ~$11 |
| Foundry | `aif-echo-prod` GPT-4o calls | ~30 episodes × 8K tokens | ~$2 |
| Compute | `func-echo-publisher` | Flex Consumption (mostly idle) | ~$2 |
| Web | `swa-echo-listener` | Standard | $9 |
| Storage | `stechoprod*` | LRS, < 5 GB | < $1 |
| Monitoring | `appi-echo-prod` → shared `law-uksouth` | ingestion-based | ~$3 |
| Secrets | `kv-echo-prod-*` | RBAC, low ops | < $1 |
| **Azure subtotal** | | | **~$28/mo** |

### AWS (start/stop — `cdk destroy` to zero)

| Resource | Monthly when ON | Monthly when OFF |
|---|---|---|
| Lambda + API Gateway (10 invocations) | < $0.01 | $0 |
| Bedrock Claude Haiku (10 × ~5K in / 500 out) | ~$0.10 | $0 |
| S3 catalog snapshot | < $0.01 | retained, < $0.01 |
| CloudWatch Logs (7-day retention) | < $0.10 | $0 |
| Secrets Manager (1 secret) | $0.40 | retained, $0.40 |
| **AWS subtotal** | **~$0.60/mo** | **~$0.40/mo** |

### Variable cost drivers (worth modeling)

Speech is by far the largest variable. At 100 episodes/month it's ~$36; at 500 it's ~$180.

| Episodes / month | Azure total | AWS (on) total |
|---|---|---|
| 30 | ~$28 | ~$0.60 |
| 100 | ~$50 | ~$1 |
| 500 | ~$200 | ~$2 |

### Budget alerts to set

- **Azure:** Cost Management budget on `rg-echo-prod`, alert at $75/mo (200% of expected)
- **AWS:** AWS Budgets alert at $10/mo on the entire account
- **Foundry:** Daily token budget alert at $10 (Azure portal → Foundry project → Quotas)

---

## Start/stop runbooks

### Bring AWS arm online (~3 min)

```pwsh
cd ~/code/echo-bedrock-catalog
gh auth status                       # confirm correct GitHub identity
npm ci
npx cdk deploy --require-approval never
# Output prints the API Gateway URL — note it
```

Then in Copilot Studio:
1. Open the Echo agent → Variables → `Global.bedrockCatalogEnabled` → set to `true`
2. Save and re-publish to the channels (Teams, M365 Copilot, DirectLine)

### Tear down AWS arm (back to ~$0.40/mo)

```pwsh
cd ~/code/echo-bedrock-catalog
npx cdk destroy --force
```

Then in Copilot Studio:
1. `Global.bedrockCatalogEnabled` → `false`
2. Re-publish

The S3 catalog bucket and Secrets Manager secret are intentionally retained — they're cheap and they let `cdk deploy` come back faster next time.

### Stop everything Microsoft-side (rare — full pause)

You generally don't want to do this — the always-on cost is small and stopping breaks the demo. But if you must:

```pwsh
# Stop the Function App (still pays for SWA + storage but ~$10 cheaper)
az functionapp stop --resource-group rg-echo-prod --name func-echo-publisher

# Stop SWA — only affects custom domains; default hostname stays
# (no clean stop; delete the resource if truly pausing for months)
```

To resume:
```pwsh
az functionapp start --resource-group rg-echo-prod --name func-echo-publisher
```

### Nuclear option — delete everything

```pwsh
# AWS
cd ~/code/echo-bedrock-catalog && npx cdk destroy --force
aws s3 rb s3://echo-catalog-{suffix} --force
aws secretsmanager delete-secret --secret-id echo/entra-agent-secret --force-delete-without-recovery

# Azure
az group delete --name rg-echo-prod --yes --no-wait
# (shared law-uksouth and ACR are NOT touched)

# Entra
# Disable then delete the Agent Identity, BlueprintPrincipal, Blueprint via Graph
# (see 09-entra-agent-id-setup.md → Revocation)
```

---

## Quotas & limits to know

| Service | Limit | Where you'll hit it |
|---|---|---|
| Azure Speech S0 | 200 concurrent requests | Demo with > 200 simultaneous viewers — won't happen |
| Foundry GPT-4o | TPM/RPM per region | At ~10 concurrent episode generations; raise via support if needed |
| Bedrock Claude Haiku | per-account TPM, eu-central-1 | Trivial for demo workloads |
| Azure Storage account | 5 PiB | Trivial |
| Function App Flex Consumption | 1000 concurrent | Way past demo scale |

---

## Operational checklists

### Pre-demo (1 hour before)

- [ ] Generate one episode end-to-end via phone share-sheet — verify it lands in the feed
- [ ] Generate one episode via Teams chat — verify the agent's status messages render
- [ ] Open the PWA, play 10 seconds of an existing episode, confirm audio
- [ ] If Bedrock arm is in scope: `cdk deploy` the AWS stack, ask one catalog question, confirm the answer
- [ ] If M365 Copilot is in scope: open Copilot Chat → Echo agent → drop a URL → confirm episode publishes
- [ ] Phone charged to 100%, screen mirroring tested
- [ ] App Insights tab open as a backup diagnostic surface

### Weekly maintenance (5 min)

- [ ] Cost Management → check `rg-echo-prod` actual vs budget
- [ ] App Insights → Failures dashboard → triage anything red
- [ ] Foundry → Agents → check token consumption trend
- [ ] If AWS arm is currently deployed: AWS Budgets actual vs $10 alert

### Monthly maintenance (15 min)

- [ ] Rotate the Function App key (Azure portal → Function App → App keys → regenerate `default`) — re-paste into the Power Platform connector
- [ ] If Entra Agent ID secret is < 30 days from expiry: renew via `09-entra-agent-id-setup.md` Step 4
- [ ] Review `catalog.json` per user — prune episodes older than 6 months if listening drops to zero
- [ ] Update Foundry agents if a new model became GA in your region

### When something breaks during a demo

1. **Don't apologize for latency.** 90 seconds of generation is fine if you're talking through it.
2. **If episode generation fails on stage:** "Let me play one I made earlier" — pull up an existing episode in the PWA. The architecture story still lands.
3. **If the agent doesn't respond at all in Teams:** switch to the PWA and play a queued episode. Move on. Diagnose offline.
4. **Never open App Insights or Function logs live** — too much noise on screen.

---

## Security & data handling

- **Audio files** are per-user containers in Blob Storage. Each user's `feed.xml` is reachable via SAS — anyone with the URL can subscribe but not enumerate other users.
- **No PII in catalog.json** beyond the SHA-256 hash of the requester's email (`userSlug`).
- **Speech transcripts** are not retained — the Function streams MP3 bytes from Speech directly into Blob.
- **Foundry diagnostic logs** ingest into shared `law-uksouth` — applies the standard galaxysec retention policy (90 days hot).
- **AWS catalog snapshots** in S3 contain episode titles, descriptions, and source URLs — no audio. Bucket has block-public-access enforced.
- **Entra Agent ID tokens** to the AWS Lambda live in Power Platform's connector cache, not in any code repo.

## When to revisit this doc

- WhatsApp / Communication Services lands in v2 — add to the cost table
- Episode volume crosses 200/month — re-evaluate Bedrock Knowledge Base for the catalog agent
- New tenants onboarded — add per-tenant cost rows
- A new HD voice ships — check whether it changes the per-character pricing
