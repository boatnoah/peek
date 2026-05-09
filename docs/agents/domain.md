# Domain Docs

How engineering skills should consume this repo's domain documentation when exploring the codebase.

## Layout

Single-context repo. One `CONTEXT.md` + `docs/adr/` at the repo root.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root — domain glossary and key concepts
- **`docs/adr/`** — architectural decision records for past decisions in this area

If either doesn't exist yet, proceed silently. They are created lazily as terms and decisions get resolved.

## Use the glossary's vocabulary

When naming a concept in an issue title, refactor proposal, hypothesis, or test name — use the term as defined in `CONTEXT.md`. Don't drift to synonyms the glossary explicitly avoids.

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly:

> _Contradicts ADR-0001 (reason) — but worth reopening because…_
