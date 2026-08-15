# Stacked PRs Workflow

How the four repos use GitHub native stacked PRs (`gh stack`) and fork-based contribution. Decisions behind this: [ADR 005](../adr/005-native-stacked-prs.md), [ADR 006](../adr/006-contribution-and-review-model.md).

## Vocabulary

**Stack**: A chain of open PRs, each one depending on the one below it. Bottom layer targets `main`; every layer above targets the layer below.

**Layer**: One PR in a stack is one minimal, reviewable unit and one commit; squash merge makes the merged commit *be* the layer. Layers must be CI-green before they merge.

**Cascade rebase**: When a layer merges, GitHub automatically rebases the layers above it so the next layer targets `main`. The stack moves without re-applying old commits by hand.

**Trunk**: `main`. Single, protected, squash-only.

**Code-owner gate**: A merge into `main` requires an approving review from a code owner. Only `decasamerlo` and `nesto-bot` are code owners, so no approval by anyone else can unlock a merge.

**Gatekeeper**: The machine-user account `nesto-bot` (Write on all four repos). Its PAT is held by the owner only. On owner-authored PRs — where the owner cannot self-approve — the gatekeeper's approval is the only way to satisfy the code-owner gate.

**Bypass**: The owner's ruleset bypass ("for pull requests only") merges *non-stacked* PRs. Stacked PRs cannot use it at all: GitHub's async stack merge evaluates every rule for every layer and honors no bypass.

**Co-developer**: Has Write on all four repos, so they build native stacked PRs (same-repo only). Their approvals can never satisfy the code-owner gate, so they can never merge anything into `main`.

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

## Merging a stack — owner only, via the gatekeeper

Stacked PRs never honor the bypass list. Every layer must satisfy the code-owner gate on its own, and on owner-authored layers only the gatekeeper can do that. The owner therefore merges with the one-command flow:

```bash
scripts/merge-layer.sh <pr-number> [repo]
```

It approves the PR as `nesto-bot` (`NESTO_BOT_TOKEN` exported from your keyring), then runs `gh stack merge <pr> --yes --squash`, then `gh stack sync` for the cascade rebase. Merge bottom-up, one layer at a time; confirm the upper layers now target `main` before merging the next.

Never force-push someone else's branch. Only push your own layers.

### Emergency escape hatch

If the gatekeeper flow is unavailable (PAT lost, account locked, GitHub outage): unstack the affected layer, merge it as a normal PR via your bypass (async stack merge rules no longer apply once it is not part of a stack), then restack the layers above it. This sacrifices the atomic-stack property for that one merge — use it only when the gatekeeper flow is genuinely blocked.

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
| Bypass list | `decasamerlo`, "for pull requests only" (non-stacked merges only; stacks ignore it) |
| CODEOWNERS | `* @decasamerlo @nesto-bot` (in `.github/CODEOWNERS`, all repos) |
| Gatekeeper | `nesto-bot` machine user, Write, PAT in owner's keyring (`NESTO_BOT_TOKEN`) |
| Roles | outside contributors → Read via forks; co-developer → Write (stacks); `nesto-bot` → Write (gatekeeper) |
| Backend extra | CI workflow (Gradle build + tests) as required check |
| Off | merge queue, "require branches up to date", stale-review dismissal |
| Unavailable | "restrict who can dismiss reviews" — GitHub silently drops it on personal-account repos; see ADR 006 |