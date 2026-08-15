# Stacked PRs Workflow

How the four repos use GitHub native stacked PRs (`gh stack`) and fork-based contribution. Decisions behind this: [ADR 005](../adr/005-native-stacked-prs.md), [ADR 006](../adr/006-contribution-and-review-model.md).

## Vocabulary

**Stack**: A chain of open PRs, each one depending on the one below it. Bottom layer targets `main`; every layer above targets the layer below.

**Layer**: One PR in a stack is one minimal, reviewable unit and one commit; squash merge makes the merged commit *be* the layer. Layers must be CI-green before they merge.

**Cascade rebase**: When a layer merges, GitHub automatically rebases the layers above it so the next layer targets `main`. The stack moves without re-applying old commits by hand.

**Trunk**: `main`. Single, protected, squash-only.

**Code-owner gate**: Only `decasamerlo` — the owner — can approve a PR into `main`, because only that account is a code owner. The owner's own PRs merge via the bypass list, never by self-approval (GitHub forbids it anyway).

**Co-developer**: Has Write on all four repos, so they build native stacked PRs (same-repo only). Their approvals never satisfy the code-owner gate; the owner's bypass overrides their request-changes.

**Fork contribution**: An outside PR from a fork to `main`. Never part of a stack — native stacks are same-repo only.

## Branch naming

`<type>/<slug>`, e.g. `feat/node-domain-entity`, `fix/recurrence-rollover`, `docs/stacked-prs`. Types: `feat`, `fix`, `docs`, `chore`. No issue numbers.

## Building a stack — owner or co-developer (Write)

Requires the extension once: `gh extension install github/gh-stack`.

```bash
gh stack init                 # in the repo, on a branch off main
gh stack add feat/a           # grow the stack (or branch + gh stack add later)
gh stack add feat/b
gh stack submit               # one PR per layer, each targeting the layer below
```

Work in the top layer; `gh stack rebase` / `gh stack sync` keep layers aligned. Metadata lives in `.git/gh-stack` — nothing committed.

## Merging a stack — owner only (bypass)

1. Bottom-up, one layer at a time. After your approval (or directly, via your bypass) merge the bottom layer — it lands as one squashed commit.
2. The server-side cascade rebase moves the layers above onto `main` automatically — confirm it completed (upper layers now target `main`) before merging the next layer.
3. Repeat until no layers remain above `main`. When the whole stack is green and you're confident, `gh stack merge` lands everything at once.

Never force-push someone else's branch. Only push your own layers.

## Fork contribution — outside contributors

1. Fork the repo, branch off `main` (`<type>/<slug>`).
2. Open the PR to `main`.
3. The owner reviews (code-owner gate) and merges with squash. The reviewer user's review is advisory — it never blocks or unblocks the merge.
4. First-time contributors: the owner approves running CI on the fork PR before it executes.

## Configuration summary (applied to all four repos)

| Setting | Value |
|---|---|
| Visibility | public |
| Merge method | squash only, auto-delete head branches |
| Ruleset (branch `main`) | require pull request; 1 approval; require code-owner review; non-fast-forward |
| Bypass list | `decasamerlo`, "for pull requests only" |
| CODEOWNERS | `* @decasamerlo` |
| Roles | outside contributors → Read via forks; co-developer → Write (stacks) |
| Backend extra | CI workflow (Gradle build + tests) as required check |
| Off | merge queue, "require branches up to date", stale-review dismissal |
