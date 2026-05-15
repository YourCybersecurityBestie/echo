# Copilot instructions for the Echo repo

This repo is the docs + infra hub for **Echo** — an AI agent system that turns articles into two-host podcast episodes on the Microsoft AI stack (Copilot Studio, Azure AI Foundry, Azure AI Speech), with an optional cross-cloud Q&A agent on AWS Bedrock governed by Microsoft Entra Agent ID.

## Repo conventions

- Project name is **Echo**. Always capitalized. Never "echo" in user-facing copy.
- Hosts are **Ava** and **Andrew** (Azure Speech HD voices `en-US-Ava3:DragonHDLatestNeural` and `en-US-Andrew3:DragonHDLatestNeural`).
- Resource group: `rg-echo-prod` in **Sweden Central** for compute, **West Europe** for Speech + Static Web App (regional limitations — see `infra/README.md`).
- Reuse, **do not recreate**: shared `law-uksouth` Log Analytics workspace in RG `sentinel-goodies`.
- All Azure resources tagged `{ project: 'echo', environment: 'prod', owner: 'vesolomons', costCenter: 'demo' }`.
- Use **British or American English consistently** within a doc — don't mix.
- Prefer **Azure SDKs over raw REST** when there's a choice.
- Prefer **managed identity over keys** unless the service genuinely doesn't support MI yet.

## Code style

- TypeScript strict mode. No `any` without an inline `// reason: …` comment.
- Bicep: one resource per module under `infra/modules/`. Use `existing` for cross-RG references.
- Functions: keep handlers thin. Business logic in `src/lib/`. One endpoint per file under `src/functions/`.
- Avoid emojis in code, docs, and commit messages.

## Out of scope (don't suggest these without checking)

- WhatsApp / Azure Communication Services — deferred from v1
- Container Apps / ACR for the Publisher — Flex Consumption is the choice
- Bedrock Knowledge Base / OpenSearch Serverless — too expensive for the catalog size
- Custom domains — defaults are fine for v1
- Adding always-on AWS resources — the AWS arm must remain start/stop with `cdk destroy` returning to ~$0

## When generating Bicep

- Always use `subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '<id>')` for RBAC role refs
- Always set `principalType` on role assignments (avoid eventual-consistency races)
- Always use `existing` for cross-RG resources rather than passing IDs around as strings
- Storage: `allowSharedKeyAccess: false`, `defaultToOAuthAuthentication: true`
- Key Vault: `enableRbacAuthorization: true`, `enablePurgeProtection: true`

## When generating TypeScript for the Function App

- Use `@azure/functions` v4 programming model
- Use `DefaultAzureCredential` from `@azure/identity` — never connection strings in production
- Validate every request body with `zod`
- For MP3 duration: use `@ffprobe-installer/ffprobe`, not `music-metadata` (returns 0 for some HD voice outputs)
- Log to App Insights with custom dimensions `episodeId`, `userSlug`, `durationMs` on every successful publish

## When generating Copilot Studio / Foundry agent text

- Match the system prompts in `01-orchestrator-agent.md` and `02-foundry-agents.md` verbatim — they're the spec
- Don't drift the M365 Copilot declarative agent's `instructions.md` from the orchestrator's instructions; they're the same agent surfaced twice

## Glossary

- **MDASH** — Microsoft's multi-model agentic security harness (the demo article subject, not part of Echo)
- **userSlug** — sha256(userId).slice(0, 16). The blob container prefix and AWS S3 prefix for a user's data.
- **Brief** — JSON object output by the Researcher and consumed by the Scriptwriter. Schema in `02-foundry-agents.md`.
- **Catalog** — append-only JSON of episode metadata, one file per user. Consumed by the Bedrock Q&A agent.
