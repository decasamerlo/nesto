---
title: Nesto — Repo Structure & AI Tooling Discussion Notes
date: 2026-08-07
purpose: Context for an AI assistant (OpenCode, Claude Code, or similar) to scaffold the actual meta-repo files
---

# Nesto — Repo Structure & AI Tooling Discussion Notes

This document summarizes a planning discussion about how to structure Nesto's repositories and how to set up AI-agent context (AGENTS.md, CLAUDE.md, and .agents/ / .claude/ skill folders) across them. It is meant to be handed to another AI assistant as context to actually generate the described files/structure.

For product/domain/architecture decisions (Java backend, Hexagonal Architecture, React frontend, node/tree model, slices, etc.), see the separate `nesto-planning-notes.md` file. This document is scoped only to **repo organization and AI-agent tooling**.





## 6. Concrete Plan for Nesto

The `nesto` meta-repo is created first (per Section 2), with all three sub-repos scaffolded from the start:

- **Split the existing `nesto-planning-notes.md` file** into this new structure:
  - Ecosystem-level architecture decisions → `docs/adr/` as individual ADR entries. Created so far: ADR 001 (self-referential Node type), ADR 002 (REST over GraphQL), ADR 003 (polyrepo over monorepo). Decisions deemed not worth an ADR (self-evident from the codebase or personal context) were skipped — Java over Rails, React over Vue.
  - Cross-cutting conventions → `docs/conventions/`. Created so far: domain-layer isolation.
  - The slice-by-slice implementation roadmap → likely stays closer to `nesto-backend`'s own docs, or a `docs/` folder within the meta-repo scoped to planning/roadmap, since it's primarily backend-sequenced (not yet finalized where this should live).
- Each of `backend/`, `web/`, `mobile/` (once each repo exists) should have its own `CLAUDE.md` / `AGENTS.md` scoped to that repo's build commands, module map, and stack-specific notes, with a one-line pointer back to the ecosystem hub.

## Open Items Still Undecided

- Exact home for the slice-by-slice implementation roadmap (meta-repo `docs/` vs. inside `nesto-backend` itself) once the split from `nesto-planning-notes.md` happens.
