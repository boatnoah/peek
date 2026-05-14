---
name: secret-hygiene
description: Use in this repo before editing API keys, tokens, credentials, environment variables, Xcode schemes, CI, tests with credential fixtures, or any Git history cleanup involving leaked secrets.
---

# Secret Hygiene

## Rules

1. Never write a real credential into a tracked file. This includes Swift source, tests, docs, CI, `.env` files, and shared Xcode schemes.
2. Shared Xcode schemes may declare environment variable names, but secret-like variables must have `value = ""`.
3. Test fixtures must use obvious fake values that do not match provider token formats, such as `test-api-key-12345`.
4. Before committing or opening a PR, run `./scripts/scan-secrets`.
5. If a credential was exposed, assume compromise: revoke or rotate it before relying on history cleanup.

## Workflow

Run the scanner before every commit:

```bash
./scripts/scan-secrets
```

For a staged-only check:

```bash
./scripts/scan-secrets --staged
```

This repo has a versioned pre-commit hook at `.githooks/pre-commit`. Enable it in a clone with:

```bash
git config core.hooksPath .githooks
```

If the scanner fails, remove the credential without printing it in chat, logs, commits, or review comments. Re-run the scanner after the fix.

## History Cleanup

When asked to remove a leaked secret from Git history:

1. Locate the affected refs without printing the secret value.
2. Rewrite every reachable branch/tag that contains the secret.
3. Delete rewrite backup refs, expire reflogs, and run garbage collection locally.
4. Force-push rewritten remote branches with lease protection.
5. Check GitHub PR refs with `git ls-remote origin`; hidden `refs/pull/*` refs may require GitHub Support to purge.
