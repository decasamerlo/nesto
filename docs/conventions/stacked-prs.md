# Stacked PRs Workflow

How the four repos use GitHub native stacked PRs (`gh stack`), reference issues across repo boundaries, and handle fork-based contribution. Decisions behind this: [ADR 005](../adr/005-native-stacked-prs.md), [ADR 006](../adr/006-contribution-and-review-model.md).

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

`<type>/<issue-number>-<slug>`, e.g. `feat/42-node-domain-entity`, `fix/7-recurrence-rollover`, `docs/3-stacked-prs`. Types: `feat`, `fix`, `docs`, `chore`, `build`. Issue number before the slug — always a meta-repo (`decasamerlo/nesto`) issue number, including on a branch in a sub-repo.

## Referencing issues

GitHub's `#N` shorthand is repo-local — it resolves against the repo the text lives in — and with the work split between the meta-repo and its sub-repos, most references cross a boundary.

**A reference that crosses a repo boundary is written `owner/repo#N`.** A meta-repo issue cited from a sub-repo is `decasamerlo/nesto#42`; a sub-repo PR cited from the meta-repo is `decasamerlo/nesto-backend#7`.

**A reference within the same repo stays bare `#N`.** A layer pointing at the layer below it is same-repo, so `Stacked on #8.` in a `nesto-backend` PR is correct as written — as is `Closes #N.` on a PR sitting in the same repo as its issue.

**Trap — a wrong bare reference is silent.** A bare `#N` with no matching item renders as plain text — no link, no error — and it starts resolving to a real but unrelated item as soon as that repo's numbering reaches `N`.

**A sub-repo PR body opens with its closing line**, `Closes decasamerlo/nesto#N.`

- **`Closes` is the only closing verb this project uses.** `Implements` is retired: GitHub does not treat it as a closing keyword, so the verb itself never closed anything — those issues closed through hand-made Development-panel links, which this rule replaces.
- **`Refs` is the inert form** — for a layer that contributes to an issue without finishing it: `Refs decasamerlo/nesto#N.`
- **One issue, one `Closes`, on the layer that completes it.** Lower layers carrying part of it use `Refs`.
- **The keyword only fires from a PR based on `main`.** GitHub ignores closing keywords on a PR targeting any other branch — no link is created, and merging has no effect on the issue. A layer still based on the layer below is therefore inert; the merge procedure below retargets each layer to `main` before it merges — step 5 is where you confirm it — which is what makes the issue close exactly when the work lands.
- **An outside contributor's closing line is intent, not automation.** Closing an issue across a repo boundary needs write access to the repo holding it, which a fork contributor does not have. They still open with `Closes decasamerlo/nesto#N.`; the owner closes the issue when the PR merges.
- **The PR body is the single source of truth for the issue → PR link.** GitHub derives the Development-panel entry from it — never create that entry by hand.
- **A pasted full issue URL is equivalent, not preferred.** GitHub renders it as the same `owner/repo#N` anchor, and both forms follow repo renames — the short form is the convention.

**A commit carries the same reference as an inert `Refs:` trailer**, never a closing keyword — the commit body is what lands on `main`, so closing from there would credit the commit and cost the issue → PR link. See [commits.md](commits.md).

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

**Work inside the meta-repo layout, never a standalone sub-repo clone.** Clone `nesto`, run `mani sync`, and work in the directory of the repo you are changing — a sub-repo beneath the root, or the root itself for the meta-repo. That layout is what brings `docs/conventions/` and the meta-repo's domain and agent docs within reach, and what the hook install in [commits.md](commits.md) runs from. Fork and open the pull request against that same repo — a pull request to a sub-repo cannot originate from a meta-repo fork.

**Trap — a standalone clone fails silently.** Both first symptoms are indirect, and neither one points back at the layout:

- The `../AGENTS.md` pointer in a sub-repo's own context file resolves outside the repository.
- Commits land with no `Refs:` trailer, because the hook was never installed.

[`scripts/verify-layout.sh`](#verifying-the-layout) is the loud version of both — one command, run before you start work.

1. Fork the repo you are changing, then branch off `main` (`<type>/<issue-number>-<slug>`) in its directory under the layout.
2. Add your fork as a second remote and push the branch there — `origin` stays the canonical repo, which outside contributors only have Read on: `git remote add fork git@github.com:<you>/<repo>.git`, then `git push -u fork <branch>`.
3. Check the setup before committing anything — `../scripts/verify-layout.sh` from a sub-repo directory, `scripts/verify-layout.sh` from the meta-repo root.
4. Open the PR to `main`, from your fork's branch.
5. The owner reviews (code-owner gate) and merges with squash. The reviewer user's review is advisory — it never blocks or unblocks the merge.
6. First-time contributors: the owner approves running CI on the fork PR before it executes.

## Verifying the layout

`scripts/verify-layout.sh` checks the three states the layout has to be in, and names which one is wrong when it is not. Run it after `mani sync`, after the hook install, and before starting work. The walk it opens with starts at the current directory, so it runs from anywhere inside the layout — but the path you type is relative to where you are:

```bash
scripts/verify-layout.sh       # from the meta-repo root
../scripts/verify-layout.sh    # from a sub-repo directory
```

| State | What has to be true |
| --- | --- |
| `layout` | `mani.yaml` is somewhere above this directory, and every project it declares that exists on disk is a clone of its own |
| `origin` | `origin` is the canonical repo `mani.yaml` declares for that directory |
| `hook` | the project's `prepare-commit-msg` is a symlink resolving to an executable `.githooks/prepare-commit-msg` |

One run reports the whole workspace: a row per project per state, `skip` for a repo that is declared but not cloned, and a nonzero exit if any row failed. It opens with the same parent walk `install-hooks` does — duplicated rather than shared, because that walk is what finds the script in the first place, so the two are marked to change together.

**It reports the workspace it is standing in.** Run from a linked worktree of the meta-repo, the sub-repos are not beneath it and every one of them is a `skip`: truthful about that checkout, and no statement at all about the main one. Run it there too.

**It checks `origin`, and never looks for the fork.** Step 2 above has outside contributors add their fork as a *second* remote precisely so `origin` keeps pointing at the canonical repo — which is what makes this check meaningful for them rather than hostile. It is also what the hook reads to decide between a bare and a qualified reference, so an install step that repointed `origin` would change the trailers too.

**Trap — a dangling hook symlink is the state that most resembles a working one.** `[ -e ]` is false for a symlink whose target is gone, and git skips such a hook without a word, so the one state that looks most like "installed" is the one that silently does nothing. The check tests `[ -L ]` as well — the same care `mani.yaml`'s install guard takes on the write side. Deleting the checkout a link points into is how it happens.

**A linked worktree shares one hooks directory with the checkout that owns the repository**, so the live hook there is legitimately that checkout's file and not the one beside the `mani.yaml` the walk found. The check accepts the hook of *any* checkout of the meta-repo and names the file it resolved to — while still refusing an unrelated project's `.githooks/prepare-commit-msg`, which it tells apart by the common git directory the two checkouts would share.

**Decided: a script, not a `mani` task.** `mani run` executes a task once per project, so one layout problem would be reported once per repo — and the check has to work for someone who has cloned the meta-repo but not yet installed `mani`. **`install-hooks` does not run it either.** The install writes and the check reads; keeping them apart is what lets the check be run on its own, repeatedly, by someone who has changed nothing.

**CI is out of scope**, and not only because there is none yet: the layout is a property of a contributor's machine rather than of a pushed branch, so a green pipeline could never stand in for this.

**The behaviour above is tested.** `tests/verify-layout.test.sh` builds a throwaway layout per case — the negative ones especially: no `mani.yaml` above, a fork as `origin`, no hook, a dangling hook symlink, a hook copied instead of linked, a hook belonging to another repository, a directory that is not a clone of its own — and asserts on the row rather than the exit status, so a failure has to keep naming *which* state is wrong:

```bash
tests/verify-layout.test.sh
```

**What it cannot see.** It reads `mani.yaml`, not GitHub: a repo renamed there but not in the manifest passes, and so does a hook whose contents were edited locally. It answers for the machine it runs on, and nothing reconciles that with what another contributor's machine says.

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
