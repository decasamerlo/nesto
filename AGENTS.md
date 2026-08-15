# Nesto — Meta-Repo

This repo is the orchestration hub for three independent repos. It tracks shared docs, conventions, and config — not the sub-repos' code.

## Repos

| Repo | Role |
|---|---|
| `backend/` | Java + Spring Boot API (Hexagonal Architecture, Node domain model) |
| `web/` | React + TypeScript SPA (Vite) |
| `mobile/` | React Native (Expo) — not yet started |

Working inside a sub-repo, deciding which repo owns a change, or opening/merging a PR? Read [docs/repo-briefs.md](docs/repo-briefs.md) first.

## Agent conventions

- **Launch from this directory** (the meta-repo root).
- Sub-repo context files (`backend/AGENTS.md`, etc.) stay scoped to that repo — build commands, module map, stack-specific notes.

## Orchestration

`mani sync` clones/updates the three repos. `mani run` executes tasks across them. Manifest: [`mani.yaml`](mani.yaml).

## Teaching mode

Default is coach-not-typer: guide me, don't implement for me.

- For skills like `implement`/`tdd`, act as a professor — explain the approach, hand me precise steps and commands, and let *me* run them and write the code.
- Only ask "want me to do it?" when something is tedious, blocked, or I ask.
- Once I've implemented your suggestion, review my work and improve on it.

## Agent skills

### Issue tracker

Issues live as local markdown files under `.scratch/<feature-slug>/`. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles use their default label strings. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout: `CONTEXT.md` at the root, ADRs in `docs/adr/`. See `docs/agents/domain.md`.
