# Nesto — Initial Commit Plan

This document tracks the phased bootstrap of the `nesto` meta-repo. It is consumed by future sessions until both `nesto-planning-notes.md` and `nesto-repo-structure-discussion-notes.md` are fully removed — at which point this file is rewritten to describe the repo as it actually is.

## The Two Source Files

- `nesto-planning-notes.md` — product, architecture, and domain decisions (Java over Rails, Hexagonal Architecture, React, REST, node model, slices).
- `nesto-repo-structure-discussion-notes.md` — repo organization and AI tooling (three-repo split, `mani`, skill placement, ecosystem hub pattern, context-file conventions).

Both are committed as-is in the first commit. They get progressively stripped — line by line, commit by commit — as their content is committed into the artifacts that replace them. When nothing remains, both are deleted.

## Commit Sequence

### 1. Seed planning files

Commit the two planning files plus this `README.md`.

```
docs: seed planning notes and repo structure discussion
```

### 2. Install agent skills

Commit the `.agents/skills/` and `.claude/skills/` directories (plus `skills-lock.json`). Where the two skill folders carry identical content, prefer symlinks to avoid duplication.

### 3. Scaffold meta-repo

The meta-repo is created first (with all three sub-repos scaffolded from the start). Commit:
- `mani.yaml`
- `AGENTS.md` and `CLAUDE.md` (symlinked where content is identical)
- `docs/repo-briefs.md`
- The matt-pocock skills setup (`docs/agents/`, etc.)
- Any other root-level meta-repo files

Strip every line from the two planning files that describes multi-repo orchestration, `mani`, repo topology, or AI-agent tooling — those now live in the committed artifacts.

### 4. Incremental extraction

One commit per artifact created. Each commit:
- Adds the artifact (e.g., `docs/adr/001-java-over-rails.md`, `docs/conventions/hexagonal-architecture.md`).
- Removes the corresponding lines from whichever planning file held them.
- Uses Conventional Commits: `type(scope): summary`.

When both planning files are empty, delete them in a final commit.

## Agent Tooling Conventions

- **Always launch AI-agent sessions from the `nesto` meta-repo root**, not from inside a sub-repo. Skill discovery is scoped to the repo root of wherever the session starts — launching from `backend/` would miss `nesto/.agents/skills/`.
- **Context files (`CLAUDE.md` / `AGENTS.md`) use ancestor loading** — tools walk up the filesystem tree, crossing git-repo boundaries. Sub-repo context files should point back to the meta-repo hub rather than duplicating it.
- **Skills are repo-root-scoped** — discovery climbs from the working directory up to the session's repo root. Sub-repo-specific skills are discovered lazily when the agent works in that subdirectory.
- **Symlinks keep identical content in sync** — `.claude/skills/` ↔ `.agents/skills/` share one skill set; `AGENTS.md` ↔ `CLAUDE.md` will do the same for context.

(These notes will move into `AGENTS.md` when it's created in commit 3.)

## Commit Style

Conventional Commits, per the `commit-work` skill:

```
<type>(<scope>): <summary>

<What changed.>
<Why it changed.>
```

Prefer small, single-concept commits over batching — each commit should do one thing and explain why.
