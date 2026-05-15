# Security policy

## Reporting a vulnerability

If you find a security issue in Echo, **do not open a public GitHub issue.** Email the maintainer at the address listed on the GitHub profile, or open a private security advisory under the repo's **Security** tab. You'll get a response within 5 business days.

Please include:
- A description of the issue
- Steps to reproduce
- Affected component (Publisher / PWA / Foundry agents / Bedrock arm / Bicep)
- Any suggested mitigation

## Supported versions

Only the `main` branch is supported. Pinned releases are best-effort.

## Scope

In scope:
- Code in this repo and the companion repos (`echo-publisher`, `echo-listener`, `echo-bedrock-catalog`)
- Bicep templates under `infra/`
- Secrets handling, auth flows, RBAC role assignments

Out of scope:
- Issues in upstream Microsoft / AWS services themselves — report those to the vendor
- Issues caused by deviating from the documented deployment (`infra/README.md`)

## What we consider a vulnerability

- Anything that exposes one user's audio, feed, or catalog data to another user
- Auth bypass on any endpoint
- Hardcoded secrets in the repo (please flag these even though they shouldn't exist)
- Privilege escalation in the Bicep RBAC assignments
- Token validation flaws in the Bedrock Lambda or the Function App
