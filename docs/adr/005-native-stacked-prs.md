# ADR 005: Native Stacked PRs with Squash Merges

Status: accepted

## Context

Development needs multiple minimal PRs that depend on each other (a stack), with the stack moving onto `main` when the bottom layer merges — without rebasing or re-applying old commits by hand. Graphite offers this but adds a third-party dependency the owner dislikes; third-party stack-rebase GitHub Actions are all archived or unmaintained (verified August 2026).

## Decision

Use GitHub's native stacked PRs (public preview, July 2026) with the official `gh stack` CLI extension. `main` is the single trunk; each PR is one layer of a stack, chained to the branch below it — vocabulary and mechanics (stack, layer, cascade rebase): [docs/conventions/stacked-prs.md](../conventions/stacked-prs.md). The server-side cascade rebase moves the remaining layers onto `main` when a lower layer merges.

Merge method is **squash only**: every merged PR lands as one commit. Head branches are auto-deleted on merge; native stacks auto-retarget upper layers when a head branch disappears.

## Consequences

- No third-party tooling: stacking lives on GitHub's server + the `gh stack` extension. Preview caveats apply (API subject to change).
- Native stacks are same-repo only — fork PRs cannot be stacked. Outside contributions are always single PRs to `main`.
- One merged commit per PR keeps `main` history readable and makes `git rebase --onto` trivial when layers are touched manually.
- Layers merge bottom-up, one at a time; `gh stack merge` merges a whole stack as a shortcut.
