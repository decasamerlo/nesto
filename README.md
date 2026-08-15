# Nesto

A personal list-of-lists app for capturing any hierarchical structure (todos, shopping lists, recipes, ideas, exercise logs, diaries) organized as a tree of recursively composable nodes.

This is the **meta-repo**: it tracks shared docs, conventions, and config; it orchestrates the three application repos.

## Repo Structure

```text
nesto/
├── backend/        Java + Spring Boot API (Hexagonal Architecture)
├── web/            React + TypeScript SPA (Vite)
├── mobile/         React Native (Expo) — not yet started
└── docs/           Architecture decisions (ADRs), conventions, domain context
```

| Repo | Role |
| ------ | ------ |
| `backend/` | Java + Spring Boot API. Self-referential `Node` domain model stored in Postgres with Flyway migrations. Exposed via a REST API. |
| `web/` | React + TypeScript SPA (Vite). Consumes the backend REST API and mirrors its explicit layers. |
| `mobile/` | Planned port of the web app to iOS/Android via React Native (Expo). |

See [docs/repo-briefs.md](docs/repo-briefs.md) for how each repo is shaped inside, which one owns a given change, and how changes land as stacked, squash-merged PRs.

## Quick Start

This meta-repo is cloned/updated with [`mani`](https://github.com/mani-learn/mani), which also lets you run tasks across all repos at once.

```bash
# Clone all repos and set up this workspace
mani sync
```

## Development

Before working in a sub-repo, read its `AGENTS.md`:

- [backend/AGENTS.md](backend/AGENTS.md) — Java/Spring Boot, module map, build commands
- [web/AGENTS.md](web/AGENTS.md) — React/Vite, module map, build commands
- [mobile/AGENTS.md](mobile/AGENTS.md) — React Native (Expo), module map, build commands

Run commands across all repos:

```bash
mani run <task-name>
```

## Architecture & Design

Key decisions are recorded as ADRs in [docs/adr/](docs/adr/):

- [ADR 001 — Self-Referential Node Type](docs/adr/001-node-based-domain-model.md)
- [ADR 002 — REST over GraphQL](docs/adr/002-rest-over-graphql.md)
- [ADR 003 — Polyrepo over Monorepo](docs/adr/003-polyrepo-over-monorepo.md)
- [ADR 004 — React for Frontend](docs/adr/004-react-for-frontend.md)
- [ADR 005 — Native Stacked PRs](docs/adr/005-native-stacked-prs.md)
- [ADR 006 — Contribution and Review Model](docs/adr/006-contribution-and-review-model.md)

The domain model is documented in [CONTEXT.md](CONTEXT.md).
