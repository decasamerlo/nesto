---
title: Nesto — Repo Structure & AI Tooling Discussion Notes
date: 2026-08-07
purpose: Context for an AI assistant (OpenCode, Claude Code, or similar) to scaffold the actual meta-repo files
---

# Nesto — Repo Structure & AI Tooling Discussion Notes

This document summarizes a planning discussion about how to structure Nesto's repositories and how to set up AI-agent context (AGENTS.md, CLAUDE.md, and .agents/ / .claude/ skill folders) across them. It is meant to be handed to another AI assistant as context to actually generate the described files/structure.

For product/domain/architecture decisions (Java backend, Hexagonal Architecture, React frontend, node/tree model, slices, etc.), see the separate `nesto-planning-notes.md` file. This document is scoped only to **repo organization and AI-agent tooling**.



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

- **Split the existing `nesto-planning-notes.md` file** into this new structure:
  - Ecosystem-level architecture decisions → `docs/adr/` as individual ADR entries. Created so far: ADR 001 (self-referential Node type), ADR 002 (REST over GraphQL), ADR 003 (polyrepo over monorepo). Decisions deemed not worth an ADR (self-evident from the codebase or personal context) were skipped — Java over Rails, React over Vue.
  - Cross-cutting conventions → `docs/conventions/`. Created so far: domain-layer isolation.
  - The slice-by-slice implementation roadmap → likely stays closer to `nesto-backend`'s own docs, or a `docs/` folder within the meta-repo scoped to planning/roadmap, since it's primarily backend-sequenced (not yet finalized where this should live).
- Each of `backend/`, `web/`, `mobile/` (once each repo exists) should have its own `CLAUDE.md` / `AGENTS.md` scoped to that repo's build commands, module map, and stack-specific notes, with a one-line pointer back to the ecosystem hub.

## Open Items Still Undecided

- Exact home for the slice-by-slice implementation roadmap (meta-repo `docs/` vs. inside `nesto-backend` itself) once the split from `nesto-planning-notes.md` happens.
