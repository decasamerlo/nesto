# Nesto — Meta-Repo

This repo is the orchestration hub for three independent repos. It tracks shared docs, conventions, and config — not the sub-repos' code.

## Repos

| Repo | Role |
|---|---|
| `backend/` | Java + Spring Boot API (Hexagonal Architecture, Node domain model) |
| `web/` | React + TypeScript SPA (Vite) |
| `mobile/` | React Native (Expo) — not yet started |

Working inside a sub-repo, or deciding which repo owns a change? Read [docs/repo-briefs.md](docs/repo-briefs.md) first.

## Agent conventions

- **Launch from this directory** (the meta-repo root).
- Sub-repo context files (`backend/AGENTS.md`, etc.) stay scoped to that repo — build commands, module map, stack-specific notes.

## Orchestration

`mani sync` clones/updates the three repos. `mani run` executes tasks across them. Manifest: [`mani.yaml`](mani.yaml).
