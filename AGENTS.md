# Agents

Configuration for AI coding agent skills used in this repo.

## Checks

Run the full local test suite before opening a PR:

```bash
./scripts/test
```

This wraps `xcodebuild test` for the `peek` scheme on macOS and writes DerivedData to `/private/tmp/peek-derived-data-local` by default.

## Agent skills

### Issue tracker

Issues live in GitHub Issues; use the `gh` CLI for all operations. See `docs/agents/issue-tracker.md`.

### Triage labels

Default label vocabulary — `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context repo — one `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.
