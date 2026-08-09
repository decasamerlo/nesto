# Nesto — Initial Commit Plan

This document tracks the phased bootstrap of the `nesto` meta-repo. It is consumed by future sessions until both `nesto-planning-notes.md` and `nesto-repo-structure-discussion-notes.md` are fully removed — at which point this file is rewritten to describe the repo as it actually is.

## The Two Source Files

- `nesto-planning-notes.md` — product, architecture, and domain decisions (Java over Rails, Hexagonal Architecture, React, REST, node model, slices).
- `nesto-repo-structure-discussion-notes.md` — repo organization and AI tooling (three-repo split, `mani`, skill placement, ecosystem hub pattern, context-file conventions).

Both are committed as-is in the first commit. They get progressively stripped — line by line, commit by commit — as their content is committed into the artifacts that replace them. When nothing remains, both are deleted.

## Commit Sequence

### 5. Stage: Incremental extraction

One commit per artifact created. Each commit:

- Adds the artifact (e.g., `docs/adr/001-java-over-rails.md`, `docs/conventions/hexagonal-architecture.md`).
- Removes the corresponding lines from whichever planning file held them.
- Uses Conventional Commits: `type(scope): summary`.

When both planning files are empty, delete them in a final commit.

## Commit Style

Conventional Commits, per the `commit-work` skill:

```text
<type>(<scope>): <summary>

<What changed.>
<Why it changed.>
```

Prefer small, single-concept commits over batching — each commit should do one thing and explain why.
