# Nesto — Meta-Repo

This repo is the orchestration hub for three independent repos. It tracks shared docs, conventions, and config — not the sub-repos' code.

## Repos

`backend/` (Java + Spring Boot API), `web/` (React + TypeScript SPA — not yet started), `mobile/` (React Native/Expo — not yet started). Detailed roles in the [README repo table](README.md).

Working inside a sub-repo, deciding which repo owns a change, or opening/merging a PR? Read [docs/repo-briefs.md](docs/repo-briefs.md) first.

## Agent conventions

- **Launch from this directory** (the meta-repo root).
- Sub-repo context files (`backend/AGENTS.md`, etc.) stay scoped to that repo — build commands, module map, stack-specific notes.

## Orchestration

`mani sync` clones/updates the three repos. `mani run` executes tasks across them. Manifest: [`mani.yaml`](mani.yaml).

## Coach mode

Default is coach-not-typer on product work: guide me, don't implement for me. The line follows what I'm trying to learn — I'm learning to build this app, not learning to write ADRs — and the branch's Conventional Commit type ([commits.md](docs/conventions/commits.md)) is how you tell which side you're on.

| Branch type | Behaviour |
| --- | --- |
| `feat`, `fix` | **Coach.** Explain the approach, then hand me a draft — a skeleton with the part that carries the concept left to me and marked, or the complete code when it's mechanical (a Gradle stanza, a test fixture, an `equals`/`hashCode` pair). Say which one you're giving me. I write the real file. |
| `docs` | **Type it.** Edit directly, then tell me what you changed and why. No coaching first. |
| `chore`, `build` | **Ask once**, naming what you'd change. On a go-ahead, type the whole task. |

- **No usable branch** — `main`, detached, or a branch whose number belongs to other work? Infer the type from the task and say so in one line before acting: "treating this as `docs`, so I'll edit directly."
- **Work that straddles tiers takes the stricter one** — coach is stricter than ask once, which is stricter than type it — and you say so rather than riding the original grant.
- **Reviewing my work is advisory.** Report findings; I apply them. Type the fix only if I ask.
- **The lever goes both ways, and is never volunteered.** Offer to type on `feat`/`fix` only when something is tedious, blocked, or I ask. Coach me on `docs` only when I ask.
- Drafts too long to read inline go in `.scratch/` (gitignored), never into the real file on a `feat`/`fix` branch.

## Agent skills

### Issue tracker

Issues live as GitHub issues in this meta-repo (`decasamerlo/nesto`). See `docs/agents/issue-tracker.md`.

### Triage labels

Two category roles and seven state roles, two of them (`deferred` and `pending-merge`) local to this repo. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout: `CONTEXT.md` at the root, ADRs in `docs/adr/`. See `docs/agents/domain.md`.

### Commit conventions

Conventional Commits, plus a `Refs:` trailer naming the meta-repo issue on any issue-numbered branch. See `docs/conventions/commits.md`.
