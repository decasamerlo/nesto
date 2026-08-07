---
title: Nesto — Repo Structure & AI Tooling Discussion Notes
date: 2026-08-07
purpose: Context for an AI assistant (OpenCode, Claude Code, or similar) to scaffold the actual meta-repo files
---

# Nesto — Repo Structure & AI Tooling Discussion Notes

This document summarizes a planning discussion about how to structure Nesto's repositories and how to set up AI-agent context (AGENTS.md, CLAUDE.md, and .agents/ / .claude/ skill folders) across them. It is meant to be handed to another AI assistant as context to actually generate the described files/structure.

For product/domain/architecture decisions (Java backend, Hexagonal Architecture, React frontend, node/tree model, slices, etc.), see the separate `nesto-planning-notes.md` file. This document is scoped only to **repo organization and AI-agent tooling**.

## 1. Repo Separation Decision

**Decided: three separate repositories**, not a monorepo:
- `nesto-backend` — Java + Spring Boot, Hexagonal Architecture.
- `nesto-web` — React + TypeScript frontend.
- `nesto-mobile` — React Native (via Expo), to be started later.

### Reasoning
- Each repo should be independently readable/evaluable as a portfolio piece — a monorepo makes it harder for someone (e.g. a reviewer) to assess one piece without the others.
- The three pieces have genuinely different lifecycles, tooling, and release cadences (Maven/Gradle vs npm/Vite vs Expo/EAS).
- No mobile app exists yet — building monorepo tooling (Nx/Turborepo) for a mostly-empty third piece would be premature structure.
- Matches the same "explicit boundaries, no leaking concerns" instinct already applied to the backend's Hexagonal Architecture — the backend shouldn't need to know or care what's consuming its API.
- A middle ground was discussed (merge web + mobile into one repo later, since React and React Native can share real code beyond just types) — **not adopted yet**; revisit only once the mobile app exists and there's evidence of real shared-code pain, not speculatively.

## 2. Sequencing

**Decided: create the meta-repo (`nesto`) first**, with all three sub-repos (`nesto-backend`, `nesto-web`, `nesto-mobile`) scaffolded from the start. The meta-repo is the single source of truth for the ecosystem; starting with it avoids retrofitting orchestration later. Each sub-repo is still an independent git repository with its own history and CI — the meta-repo only tracks its own manifest, docs, and configuration. Begin implementation with `nesto-backend` (the first slice of work), but the structure for all three is in place from day one.

## 3. Meta-Repo / Multi-Repo Orchestration Tooling

**Decided: use `mani`** (already known from prior job experience) as the orchestration tool for a "meta-repo" that ties the three independent repos together for local development convenience.

### What this is (and isn't)
- This is **not** git submodules and **not** a true monorepo. Each of the three repos remains a fully independent git repository — separate history, separate CI, separate remote.
- The `nesto` meta-repo itself is just a thin wrapper: a `mani.yaml` manifest listing the repo URLs, plus shared docs. Running `mani sync` clones/updates all three repos into place; `mani run` executes commands across a filtered subset.
- This solves the "juggling three separate clones/terminals" annoyance without creating git-level coupling between the repos.

Since the meta-repo is created first (per Section 2), `mani.yaml` is committed as part of the initial scaffolding — it doesn't need auto-discovery from pre-existing repos.

### Alternatives considered and rejected
- **`meta` (mateodelnorte/meta)** — similar concept, npm/JS-flavored, optionally backed by real git submodules. Rejected in favor of `mani`'s language-agnostic approach (better fit for a polyglot Java + TS/RN project) and because `mani` is already known from prior experience.
- **`vcstool`** — same manifest idea, originally from the ROS/robotics ecosystem. Less actively used outside that community; not chosen.
- **Plain git submodules (no orchestrator)** — would give a pinned-commit-per-repo guarantee (useful for reproducible "snapshot" tagging across all three repos at once) but comes with real, well-known friction (detached HEAD state, easy to forget to push a submodule's commits before updating the parent's pointer). Not adopted; could be revisited only if reproducible cross-repo snapshots become a specific need.
- **Google's `repo` tool** — powerful but real learning-curve overhead; overkill for a 3-repo personal project.

### Folder layout inside the meta-repo

Following `mani`'s own conventions — role-named folders flat at the root:

```
nesto/
├── mani.yaml
├── README.md
├── CLAUDE.md
├── AGENTS.md
├── docs/
│   ├── repo-briefs.md
│   ├── conventions/
│   └── adr/
├── backend/   (nesto-backend repo, cloned here by mani)
├── web/       (nesto-web repo, cloned here by mani)
└── mobile/    (nesto-mobile repo, cloned here by mani)
```

Example `mani.yaml` shape:

```yaml
projects:
  backend:
    path: backend
    url: git@github.com:you/nesto-backend.git
  web:
    path: web
    url: git@github.com:you/nesto-web.git
  mobile:
    path: mobile
    url: git@github.com:you/nesto-mobile.git
```

`mani init`, run inside a folder already containing cloned repos, can auto-generate this file. `mani` also generates a `.gitignore` excluding the cloned subfolders from the meta-repo's own git tracking (the meta-repo tracks only its own manifest/docs, not the sub-repos' contents).

## 4. AI Agent Tooling Across Repos

### The core question
Whether AI-agent skills/context installed once "in `nesto`" (the meta-repo) can be referenced/used automatically by the sub-repos nested inside it (`backend/`, `web/`, `mobile/`), without reinstalling per repo, and without using global user-level installs (which don't travel with a repo across machines — a real constraint since machines get switched).

### Tool-specific context files
Different AI-agent tools use different file conventions for project context. The main ones in use here:

| Tool | Context file | Skill folder |
|------|-------------|--------------|
| OpenCode | `AGENTS.md` | `.agents/skills/` |
| Claude Code | `CLAUDE.md` | `.claude/skills/` |

Both file types should exist at the meta-repo root (and inside each sub-repo where repo-specific content applies). A symlink can keep `AGENTS.md` and `CLAUDE.md` in sync where their content overlaps; where they diverge (e.g., a tool-specific invocation hint), each file carries its own version.

The same applies to skill folders: `.agents/skills/` and `.claude/skills/` can either be symlinks of each other (if the skill set is identical) or diverge per tool if needed.

### Confirmed behavior (verified against tool documentation)
There is an important asymmetry between how the two file types are loaded by their respective tools:

- **Context files (`CLAUDE.md` / `AGENTS.md`) use ancestor loading** — these tools walk *up* the full filesystem directory tree looking for their respective context file, and this crosses nested git-repo boundaries (it is filesystem-based, not git-boundary-based). A real-world example of this in production: a company's multi-repo setup (structurally similar to what's being built here) has each sub-repo's own context file explicitly state that "ecosystem context is inherited via parent-chain" and instructs not to duplicate it — this only works because the parent directory's context file is picked up automatically regardless of the sub-repo's own `.git` boundary.
- **Skills are scoped more narrowly** — skill discovery goes from the starting directory, through every parent, **up to the repository root** of wherever the session was started. If a session is launched from inside `backend/` (its own independent git repo), skill discovery stops at `backend`'s own root and will *not* climb further up into `nesto/.claude/skills/` (or `nesto/.agents/skills/`).

### Resulting practice (decided)
**Always start/launch AI-agent sessions from the `nesto` meta-repo root**, not by `cd`-ing directly into an individual sub-repo (`backend/`, `web/`, `mobile/`) and launching from there. When started at the `nesto` root:
- Root-level skills (`nesto/.agents/skills/`, `nesto/.claude/skills/`) are in scope from the start of the session.
- Skills nested inside sub-repos (`nesto/backend/.agents/skills/`, etc.) are discovered lazily the moment the agent works with files in that subdirectory during the session — this works regardless of the sub-repos being separate git repositories.
- Context-file ancestor-loading works automatically in either case, since it isn't git-boundary-limited.

This means: **no separate "shared skills" repo, no submodules are needed** to share skills across the three repos — placement plus consistent session-launch habit is sufficient. Symlinks are used only to keep identical content (e.g., `AGENTS.md` ↔ `CLAUDE.md`, or `.agents/skills/` ↔ `.claude/skills/`) in sync, avoiding duplication.

**One caveat to keep in mind**: if a sub-repo is ever cloned and opened completely standalone (outside of the `nesto` folder structure — e.g., someone else clones just `nesto-backend` on its own), it will only have access to whatever tool-specific content is committed inside that repo itself. Anything repo-specific that needs to survive a standalone clone (e.g., Hexagonal Architecture conventions specific to the backend) should live inside that repo's own `.claude/` and `.agents/` folders, not only at the `nesto` root.

## 5. The "Ecosystem Hub" Pattern (source: real-world example reviewed)

A real multi-repo company codebase was reviewed for structural inspiration (structure/organization only — proprietary business content was not carried into this document). The pattern observed, generalized:

```
<meta-repo>/
├── CLAUDE.md              ← short "hub" doc: table of repos + roles, links out only
├── AGENTS.md                ← same content, for tool-agnostic agents (Cursor, etc.)
├── README.md                 ← human-facing overview
├── docs/
│   ├── repo-briefs.md       ← one entry per repo: role, stack, key modules,
│   │                            plus "Full context → <repo>/CLAUDE.md"
│   ├── conventions/          ← cross-cutting rules that apply to all repos
│   └── adr/                  ← ecosystem-level architecture decisions (span repos)
├── <repo-a>/                  (own git repo, own CLAUDE.md — repo-local details only)
├── <repo-b>/                  (own git repo, own CLAUDE.md)
└── <repo-c>/                  (own git repo, own CLAUDE.md)
```

### Key design principles observed and worth replicating
1. **The root `CLAUDE.md` stays deliberately short** — a routing table (which repo owns what) plus pointers, explicitly framed as "only what agents can't infer from the code" — not a full explanation of anything.
2. **`docs/repo-briefs.md` is the real index** — one short paragraph per repo (role, stack, key modules) plus an explicit relative link to that repo's own full `CLAUDE.md` / `AGENTS.md`. Keeps the hub cheap to load while still giving a fast map of the whole ecosystem — consistent with how AI-agent tooling guidance recommends managing context in larger codebases (small always-loaded summaries, deeper content loaded on demand).
3. **`docs/conventions/` and `docs/adr/` live once, at the top**, for anything true across repos (shared architectural principles, git conventions, testing philosophy) rather than being duplicated into each sub-repo's own docs folder. Each sub-repo's `CLAUDE.md` gets a one-line pointer back up ("ecosystem context inherited from parent — see `<meta-repo>/CLAUDE.md` / `docs/conventions/`") instead of restating shared content — avoids drift when a shared convention changes.
4. **Each sub-repo's own `CLAUDE.md` stays scoped to that repo only** — build commands, module map, stack-specific notes, nothing ecosystem-level duplicated in there.

## 6. Concrete Plan for Nesto

The `nesto` meta-repo is created first (per Section 2), with all three sub-repos scaffolded from the start:

- Scaffold the structure shown in Section 3's folder layout.
- Populate `nesto/CLAUDE.md` as a short hub doc: table of the three repos (backend/web/mobile) and their roles, pointers to `docs/conventions/` and `docs/adr/`.
- Create `nesto/AGENTS.md` as a symlink to `CLAUDE.md` (or vice versa) so they stay in sync — both files carry the same ecosystem hub content, avoiding duplication.
- Create `docs/repo-briefs.md` with one entry per repo (role, stack, key modules, link to that repo's own `CLAUDE.md`).
- **Split the existing `nesto-planning-notes.md` file** into this new structure:
  - Ecosystem-level architecture decisions (Java over Rails, Hexagonal Architecture, React over Vue, REST over GraphQL, polyrepo over monorepo, node-based domain model, etc.) → `docs/adr/` as individual ADR entries.
  - Cross-cutting conventions (e.g., Hexagonal Architecture rules, domain modeling principles, testing philosophy) → `docs/conventions/`.
  - The slice-by-slice implementation roadmap → likely stays closer to `nesto-backend`'s own docs, or a `docs/` folder within the meta-repo scoped to planning/roadmap, since it's primarily backend-sequenced (not yet finalized where this should live).
- Each of `backend/`, `web/`, `mobile/` (once each repo exists) should have its own `CLAUDE.md` / `AGENTS.md` scoped to that repo's build commands, module map, and stack-specific notes, with a one-line pointer back to the ecosystem hub.

## Open Items Still Undecided

- Exact home for the slice-by-slice implementation roadmap (meta-repo `docs/` vs. inside `nesto-backend` itself) once the split from `nesto-planning-notes.md` happens.
- Whether skills should be split into "shared" (`nesto/.claude/skills/`, `nesto/.agents/skills/`) vs. "repo-specific" (`backend/.claude/skills/`, `backend/.agents/skills/`, etc.) categories explicitly now, or organized organically as they're created — the mechanics support either, per Section 4.
