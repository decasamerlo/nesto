# Stacked PRs Workflow

How the four repos use GitHub native stacked PRs (`gh stack`) and fork-based contribution. Decisions behind this: [ADR 005](../adr/005-native-stacked-prs.md), [ADR 006](../adr/006-contribution-and-review-model.md).

## Vocabulary

**Stack**: A chain of open PRs, each one depending on the one below it. Bottom layer targets `main`; every layer above targets the layer below.

**Layer**: One PR in a stack is one minimal, reviewable unit and one commit; squash merge makes the merged commit *be* the layer. Layers must be CI-green before they merge.

**Cascade rebase**: When a layer merges, GitHub automatically rebases the layers above it so the next layer targets `main`. The stack moves without re-applying old commits by hand.

**Trunk**: `main`. Single, protected, squash-only.

**Code-owner gate**: Only `decasamerlo` — the owner — can approve a PR into `main`, because only that account is a code owner. The owner cannot self-approve (GitHub forbids it), and stacked merges never honor the bypass list — so an own stacked layer can only land by leaving the stack first.

**Unstacking**: Removing a branch from the stack with `gh stack modify` (Drop). The local branch and PR are preserved — only the stack membership is severed, which makes the PR a normal PR that the bypass can merge.

**Bypass**: The owner's ruleset bypass ("for pull requests only") merges *non-stacked* PRs. Stacked PRs cannot use it at all: GitHub's async stack merge evaluates every rule for every layer and honors no bypass, admin or otherwise. On non-stacked PRs the CLI only applies it with `gh pr merge --admin` — plain merges still fail the 1-approval and code-owner rules.

**Co-developer**: Has Write on all four repos, so they build native stacked PRs (same-repo only). Their approvals never satisfy the code-owner gate; the owner's bypass overrides their request-changes on non-stacked PRs.

**Fork contribution**: An outside PR from a fork to `main`. Never part of a stack — native stacks are same-repo only.

## Branch naming

`<type>/<issue-number>-<slug>`, e.g. `feat/42-node-domain-entity`, `fix/7-recurrence-rollover`, `docs/3-stacked-prs`. Types: `feat`, `fix`, `docs`, `chore`. Issue number before the slug.

## Building a stack — owner or co-developer (Write)

Requires the extension once: `gh extension install github/gh-stack`.

```bash
gh stack init                 # in the repo, on a branch off main
gh stack add feat/a           # grow the stack (or branch + gh stack add later)
gh stack add feat/b
gh stack submit               # one PR per layer, each targeting the layer below
```

Work in the top layer; `gh stack rebase` / `gh stack sync` keep layers aligned. Metadata lives in `.git/gh-stack` — nothing committed.

**Trap — drafts by default.** In a non-interactive terminal, `gh stack submit` skips the editor (acts as `--auto`) and creates new PRs as drafts. Run it interactively, or pass `--open` to submit ready-for-review. If a PR came out as draft, fix with `gh pr ready <n>`.

## Adding a layer to an existing stack

The stack is already open on GitHub — someone else's, or an earlier session's. You want to build on top of it:

```bash
gh stack checkout <stack>        # by stack number, PR number, PR URL, or branch name
gh stack add <new-branch>        # from the top layer: creates the branch and checks it out
gh stack submit                  # creates the PR — verify its base is the layer below
```

`gh stack add` must run from a stack branch (e.g. the top layer), not the new branch — on the new branch it errors with "current branch is not part of a stack".

**Trap — one layer, one commit.** A layer is one minimal, reviewable unit and one commit (see **Layer** in Vocabulary). A branch that carries two commits lands as a PR with two commits — not a valid layer. Keep each logical change on its own branch and stack them, or squash the branch down to one commit before submitting.

**Trap — `gh stack init` adopts local branches only.** It treats `origin/*`-only branches as missing and creates them from trunk. A later `gh stack submit` force-pushes them back to trunk, empties the diffs, and GitHub closes the PRs. This section checks out first to avoid that.

**Recovery.** If it happens anyway, the old heads usually still exist in the object store: restore each branch with `git branch -f <branch> <old-head>`, push with `git push --force origin <branch>`, and reopen with `gh pr reopen <n>`. Then `gh stack sync`; verify every PR open and every diff non-empty.

## Merging a stack — owner only, unstack → submit → bypass-merge → rebase

Stacked PRs never honor the bypass list, and the owner cannot self-approve — so an own stacked layer cannot merge while it is in the stack. The owner merges bottom-up, one layer at a time:

1. **Unstack the layer**: `gh stack modify` → select the layer → `x` (Drop) → `Ctrl+S`. The branch and PR are preserved; the remaining branches are rebased locally onto their new parents (the layer above ends up based on `main`).
2. **Submit first, then merge**: `gh stack submit` pushes the rebased branches and recreates the stack on GitHub without the layer — answer **Yes** to "Overwrite the existing stack on GitHub?" This must happen *before* the merge: while the PR is still linked in a GitHub stack, even `--admin` merges are refused (async stack merge API only).
3. **Merge via bypass, with `--admin`**: `gh pr merge <n> --squash --admin`. The plain `--squash` form fails against the 1-approval and code-owner rules — the CLI does not apply the bypass list automatically; `--admin` is required even on non-stacked PRs.
4. **Rebase the rest**: `gh stack rebase` fetches the new `main` and re-plays the layers above onto it — each retains its original commits; the squash-merge already put that content on `main`, so the rebase drops the now-empty duplicates. `gh stack sync` works here too.
5. **Push**: `gh stack push` publishes the rebased branches. Confirm the upper layers now target `main` before merging the next.

Repeat bottom-up until no layers remain above `main`.

Push only your own layers; never force-push someone else's branch.

## Fork contribution — outside contributors

1. Fork the repo, branch off `main` (`<type>/<issue-number>-<slug>`).
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
