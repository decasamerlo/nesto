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

The body carries more weight here than in most repos. Both repos squash-merge with `squash_merge_commit_message: COMMIT_MESSAGES`, so **the commit body is what lands on `main`** and the PR description reaches no commit at all. Reasoning that history should keep goes in the body; reasoning aimed at the reviewer goes in the PR. Near-verbatim, not verbatim — the squash trap below has the one exception.

## The `Refs:` trailer

**A commit carries `Refs:` exactly when its branch matches `^(build|chore|docs|feat|fix)/[0-9]+-[a-z0-9-]+$`**, taking the issue number from that match. Any other branch carries none — which is how `dependabot/*` is exempt, with no bot or author special-casing anywhere.

**It sits in the message's final paragraph, on its own line, and stops being a trailer the moment the PR is squashed.** In the commit as written, `git interpret-trailers --parse` and `%(trailers:key=Refs)` both resolve it; on `main` neither does, for the reason the trap below gives. One issue per line, key repeated:

```text
Refs: #52
Refs: #49
```

**Trap — squash merge demotes the trailer, and the writing side cannot prevent it.** GitHub's squash strips `Co-Authored-By` from wherever it sits, normalises it to `Co-authored-by`, and re-appends it after a blank line. That blank line opens a new final paragraph; git parses trailers only from the last one, so `Refs:` is stranded in the second-to-last and stops being a trailer:

```text
Refs: #64          <- stranded: second-to-last paragraph, no longer a trailer

Co-authored-by: Claude Opus 5 (1M context) <noreply@anthropic.com>
```

**The writing side has two levers, and both are spent.** Authoring the co-author line *above* `Refs:` was tried deliberately on PR #66; writing that order automatically is what the hook already does, since `interpret-trailers --if-exists replace` appends below a co-author line that is already there. PR #71 reached GitHub with `Refs: #64` last and resolving, and came out of the squash with the co-author line below it. Attribution requires that line, so no third ordering exists. The tally is 8 of 8 as of `0b59328`, and every commit carrying a trailer also carries a co-author line, so in practice the failure is total.

Head branches are deleted on merge, so the pre-squash message is not in the object store; read it back from the PR instead, which is what makes the paragraph above checkable:

```bash
gh api repos/decasamerlo/nesto/pulls/71/commits --jq '.[].commit.message'
```

**Only the machine-readable claim breaks.** The reference survives as text, so the historical record is intact and no commit needs rewriting. What fails is tooling that reads the trailer as a trailer — which is the stated reason the convention exists. Read it as text instead: [Reading the reference](#reading-the-reference).

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

## The hook

`.githooks/prepare-commit-msg` derives the trailer from the branch name, so it is generated rather than remembered — including the reference form, which it reads off `remote.origin.url`: bare in the meta-repo, qualified in every other repo. Git does not distribute hooks and two of the four repos are still scaffolds, so a `mani` task installs it everywhere:

```bash
mani run install-hooks --all --ignore-non-existing
```

It symlinks the meta-repo's copy into each project's `.git/hooks/`, so editing the one script reaches every repo at once. Run it again after `mani sync` clones a repo for the first time.

**A branch that doesn't match is a no-op**, which is the whole of the dependabot exemption. `--no-verify` does not skip the hook either — that flag bypasses `pre-commit` and `commit-msg` only. One side effect to know: saving the editor without typing anything commits with the trailer as the subject, where git would otherwise abort on an empty message.

**Trap — an extra `Refs:` line goes above the generated one.** The hook runs `git interpret-trailers --if-exists replace`, which rewrites the *last* `Refs:` line in the block. A second issue added below the generated line is overwritten on the next amend; added above it, both survive.

**Trap — an interactive-rebase squash leaves one `Refs:` per squashed commit.** A rebase runs with a detached HEAD, so the hook finds no branch name and exits without touching the message; git concatenates the originals, trailers and all. Prune to one in the editor git opens, or squash with `git reset --soft HEAD~<n> && git commit`, which builds a fresh message and picks up exactly one trailer.

**Trap — a custom `commit.template` moves the trailer into the comment block.** The hook keeps the trailer off the subject line by checking that line 1 is empty, which is what the default template gives it. A template whose first line is a comment is read as the subject instead, so the trailer is written among the template's comments and the separation never runs — saving without typing then commits `Refs: <reference>` as the subject. Nothing in these repos sets `commit.template`; this is for whoever does.

**The behaviour above is tested, not asserted.** `tests/prepare-commit-msg.test.sh` builds a throwaway repo per case, symlinks the hook in exactly as the `mani` task does, commits for real, and reads back the message git stored — both reference forms, the branch-name exemptions, one trailer surviving repeated amends, `--no-verify`, the editor path, and the detached-HEAD no-op. It points `GIT_CONFIG_GLOBAL` and `GIT_CONFIG_SYSTEM` at `/dev/null`, so nobody's personal `commit.template` can change the result:

```bash
tests/prepare-commit-msg.test.sh
```

**What the suite cannot see, by construction.** It commits into a throwaway repo and reads back what git stored, and the squash demotion happens server-side at merge. The hook's output is correct in every case covered here — trailer in the final paragraph, resolving — and stays correct right up until GitHub rewrites it. The suite's own assertions read `%(trailers:key=Refs,valueonly)` — right pre-merge, and exactly the call that fails on `main`.

**Decided: the demotion itself stays unasserted.** Reproducing it needs a live merge, and a fixture of a post-squash message would only assert GitHub's behaviour back at itself — it would keep passing if GitHub changed. The testable half is the remedy: the recipes under [Reading the reference](#reading-the-reference) are ordinary local commands, and a fixture commit shaped like a squashed one would catch an edit that quietly breaks them. That test is the open half of this decision, not an oversight.

## Reading the reference

Keeping the reference out of the subject costs nothing but its visibility in a default `git log --oneline`. **Put it back by reading the body as text, not by asking git for a trailer** — `%(trailers:key=Refs)` and `git interpret-trailers --parse` both come back empty on `main`, for the reason the squash trap above gives. Both still work against a commit that has not been merged yet, which is how the gap went unnoticed: every recipe is correct on the branch and wrong on the trunk.

One commit:

```bash
git log -1 --format=%B <sha> | sed -n 's/^Refs: //p'
```

A log listing, restoring the reference to the one-line format:

```bash
git log --format='@@%h %s%n%b' |
  awk '/^@@/  { if (h != "") { if (r != "") h = h "  " r; print h }
                h = substr($0, 3); r = ""; next }
       /^Refs: / { if (r != "") r = r ", "
                   r = r substr($0, 7) }
       END     { if (h != "") { if (r != "") h = h "  " r; print h } }'
```

Three rows of its output on `main` — one reference, two, and none:

```text
0b59328 docs: decide the Node persistence seam and the v1 write path (#71)  #64
9afa14d docs(context): make the status matrix total and name completion time (#66)  #22, #17
44f5f62 docs: reference issues across repos as owner/repo#N (#55)
```

`%b` is the body alone, so the `@@` marker is what separates one commit's header from the body lines beneath it: awk holds the header until it has seen every `Refs:` line under it, then prints them joined. A commit with no reference prints a bare subject, and two join with a comma and a space, as the old `separator` argument arranged. Both reference forms match the same pattern, so a sub-repo's `decasamerlo/nesto#N` is picked up unchanged.

**Nothing here sets `RS` or leans on a GNU extension**, so mawk, one-true-awk and busybox awk all print byte-identical output. That is worth two extra lines, because the failure it avoids is silent. The obvious `RS = "\0"` version reads that as the empty string under one-true-awk, switches to paragraph mode, and prints body prose where commit rows should be; under busybox awk it prints nothing at all. Both exit 0 and write no stderr, so neither looks like a failure.

**The cost of reading text is that nothing distinguishes a real trailer from a body line that merely begins `Refs:`.** Git's own parser drew that distinction; squash is what took it away. No commit in these repos writes such a line, and a body that needs to quote the trailer should indent it — which keeps git's parser off it too, for as long as git is still doing the parsing. The listing's `@@` marker is exposed the same way by a body line starting `@@`, a quoted diff hunk header being the realistic case; indenting settles both.
