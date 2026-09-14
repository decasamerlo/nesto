# Commit Conventions

Every commit follows Conventional Commits, and a commit made on an issue-numbered branch ends with a `Refs:` trailer naming the meta-repo issue it belongs to. Branch names, and how a reference is written across a repo boundary, live in [stacked-prs.md](stacked-prs.md).

## Subject

`<type>(<scope>): <summary>` — imperative mood, lower case after the colon, no trailing period. A `!` before the colon marks a breaking change. Keep it under ~70 characters. The ceiling is soft and unenforced: squash merge appends the PR number, and the longest subject on `main` already reaches 78 with that `(#27)` counted.

**Types** are the same set the branch-name types come from, so a `docs/52-…` branch carries `docs:` commits:

| Type | For |
| --- | --- |
| `feat` | new behaviour |
| `fix` | repaired behaviour |
| `docs` | documentation only — ADRs, conventions, context, READMEs |
| `build` | build files and dependency bumps; `build(deps)` is dependabot's |
| `chore` | changes neither behaviour nor docs — tooling, config, scaffolding |

`fix` has not been used yet, because nothing has shipped that could break.

**Scopes** name where the change lands, and are optional — just over half the history omits one, 21 commits of 39 across both repos:

- Meta-repo: the `docs/` subdirectory or root file being edited — `adr`, `agents`, `conventions`, `context`, `readme`.
- Backend: the Gradle module — `core` today.
- `deps` for a dependency bump, whoever raises it.

Omit the scope when a change has no single home; don't invent one.

## Body

Prose explaining *why*, not a restatement of the diff — the diff is already in the commit. **Wrap it at 72 columns.** `git log` indents a body by four spaces and never reflows it, so 72 still fits an 80-column terminal while an unwrapped paragraph comes out as one 200-character line. Twenty of the thirty commits on the meta-repo's `main` already wrap, between 63 and 70; the nine that don't are recent drift, not the standard.

The body carries more weight here than in most repos. Both repos squash-merge with `squash_merge_commit_message: COMMIT_MESSAGES`, so **the commit body is what lands on `main` verbatim** and the PR description reaches no commit at all. Reasoning that history should keep goes in the body; reasoning aimed at the reviewer goes in the PR.

## The `Refs:` trailer

**A commit carries `Refs:` exactly when its branch matches `^(build|chore|docs|feat|fix)/[0-9]+-[a-z0-9-]+$`**, taking the issue number from that match. Any other branch carries none — which is how `dependabot/*` is exempt, with no bot or author special-casing anywhere.

**It sits in the message's final paragraph, on its own line**, so both `git interpret-trailers --parse` and `%(trailers:key=Refs)` resolve it. One issue per line, key repeated:

```text
Refs: #52
Refs: #49
```

**The reference form is the one [stacked-prs.md](stacked-prs.md#referencing-issues) sets** — bare `#N` inside the meta-repo, `decasamerlo/nesto#N` from a sub-repo.

**Trap — a bare reference from a sub-repo rots into a wrong link.** GitHub's bare-`#N` autolinking is existence-sensitive: `#28` in a `nesto-backend` commit is inert only until that repo has 28 items, then it silently becomes a link to an unrelated PR. A commit body on `main` cannot be corrected, so the qualified form is not optional there.

**Why the trailer is inert.** `Refs` is none of GitHub's closing keywords, and that is the point — closing an issue stays the PR body's job (`Closes decasamerlo/nesto#N`):

- A closing keyword in a commit body closes the issue when the commit reaches the default branch and credits the *commit*, so the Development panel loses the issue → PR link that [stacked-prs.md](stacked-prs.md#referencing-issues) makes the single source of truth.
- Layers merge bottom-up, one squash commit each. A closing keyword in the body would fire from whichever layer landed first, not from the layer that finished the work.

**The word does double duty, and the two senses don't mix.** In a PR body, `Refs` is a verb picked against `Closes` — the layer that finishes the issue writes `Closes`, the layers under it write `Refs`. In a commit, `Refs:` is a trailer key and the only form there is: no commit carries `Closes:`, whichever layer it sits on.

**`(#N)` in the subject is not the trailer.** GitHub appends `(#N)` to a squash-merge subject: that is the *PR* number, in the repo the PR was opened in. The trailer is the *issue* number, always in the meta-repo. On a backend commit the two sit inches apart and mean different things:

```text
feat(core): make Node immutable (#10)     <- nesto-backend PR 10

Refs: decasamerlo/nesto#29                <- nesto issue 29
```

**Trap — the requirement follows the branch name, not the issue link.** A branch named off-convention (`fix-thing`, `52-commits`) exempts itself silently, and a conforming branch records the number its *name* claims rather than the issue its PR actually closes. Nothing reconciles the two.

**What a trip-wire can and cannot see.** `git log --grep='^Refs:'` lists the commits that carry a trailer, and nothing more. It cannot show which commits *should* have carried one: branches are deleted on merge and a squash commit records only `(#N)`, a PR number, so reading a branch name back off `main` takes `gh pr view <N> --json headRefName`. Nor can it separate a right issue number from a wrong one — the number comes from the branch name by the rule above, so any check rooted there agrees with itself. Reconciling the number means comparing the trailer against the `Closes` line in the PR body, the one place the two are stated independently.
