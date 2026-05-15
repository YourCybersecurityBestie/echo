# Contributing to Echo

Thanks for taking a look. Echo is a personal lab + customer-demo project, so contributions land via PR after a quick conversation in an issue.

## Before you open a PR

1. Open an issue describing the change. For anything beyond a typo or a doc clarification, get a thumbs-up first — Echo has a deliberately small surface area and not every feature fits.
2. For new features: cite the demo or use case it unblocks.
3. For infra changes: include the `az deployment sub what-if` output in the PR description.

## Local setup

Each subsystem lives in its own repo:

- **`echo`** (this repo) — docs, Bicep infra, top-level architecture
- **`echo-publisher`** — Function App
- **`echo-listener`** — PWA
- **`echo-bedrock-catalog`** — AWS CDK Bedrock Q&A

Clone the ones you need. Each has its own README with setup steps.

## Style

- TypeScript strict mode everywhere. No `any` without a comment explaining why.
- Bicep: one resource per module, MI auth wherever possible, no shared-key auth on storage.
- Docs: no emojis. Lead with action, not explanation. Use markdown tables for anything tabular.
- Commit messages: imperative mood — "Add catalog endpoint", not "Added" or "Adds".

## Branch and PR conventions

- Branch from `main`. Name branches `kind/short-description` — e.g. `feat/whatsapp-trigger`, `fix/duration-zero`, `docs/cost-table`.
- Squash-merge to `main`. PR title becomes the commit message.
- One logical change per PR. Refactors and feature work go in separate PRs.

## Testing

- Function App: unit tests for `src/lib/*`, integration tests run against a real Speech account (set `SPEECH_REGION` + `SPEECH_KEY` in your local env).
- PWA: Playwright for the critical user flows (login → feed → play).
- Bicep: `az deployment sub what-if` is the test. Don't merge without it green.
- Bedrock arm: `cdk synth` + a manual `curl /v1/health` after deploy.

## Code of conduct

Be kind. Disagree with the work, not the person. Maintainers reserve the right to close PRs that ignore prior issue conversation.

## What we won't merge

- Code that hardcodes secrets, even in tests
- Bicep that lowers the security baseline (anonymous blob access, shared-key auth, public Key Vault, etc.)
- Features that add always-on AWS cost (the start/stop model is intentional)
- Anything that mixes user data across `userSlug` boundaries
