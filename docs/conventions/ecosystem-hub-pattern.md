# Ecosystem Hub Pattern

The meta-repo root is a routing table: repos and their roles, plus pointers to detailed context.

## Layout

- **Root `AGENTS.md`** — short hub: repos table, agent conventions, orchestration pointer. Only what agents can't infer from the code.
- **`docs/repo-briefs.md`** — one short paragraph per repo (role, stack, key modules) plus a link to that repo's own `AGENTS.md`.
- **`docs/conventions/` and `docs/adr/`** — live once at the top for anything true across repos.
- **Each sub-repo's `AGENTS.md`** — scoped to that repo only: build commands, module map, stack-specific notes. Inherits shared context from the root to avoid drift.

## Standalone clone caveat

If a sub-repo is cloned outside the meta-repo structure, it only has access to content committed inside itself. Anything repo-specific that needs to survive a standalone clone (e.g., backend-specific conventions) lives inside that repo's own `AGENTS.md`.
