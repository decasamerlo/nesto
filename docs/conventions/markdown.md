# Markdown

How this repo's own documentation is checked.

## The command

```bash
scripts/lint-docs.sh
```

It runs [markdownlint-cli2](https://github.com/DavidAnson/markdownlint-cli2) over this repo's markdown and exits nonzero when any file fails. Run it before committing documentation. It is a command a person runs, and stays one until there is CI — [#73](https://github.com/decasamerlo/nesto/issues/73) owns that.

The script resolves the repo root from its own location, so it behaves the same from anywhere in the layout: `scripts/lint-docs.sh` from the meta-repo root, `../scripts/lint-docs.sh` from a sub-repo directory.

Rules come from `.markdownlint-cli2.jsonc` at the root: the defaults, with `MD013` disabled. Prose here wraps at the paragraph rather than at a column. The 72-column rule in [commits.md](commits.md) governs commit bodies, which `git log` indents and never reflows, and says nothing about files.

## The version is pinned

`VERSION` in the script fixes the tool at one release, and that matters more than it looks. Run through an unpinned `npx`, markdownlint-cli2 resolves to whatever is current, so the ruleset moves under the repo and a file that passed when it was written starts failing without anyone editing it. The failure then arrives inside somebody's unrelated change, which is the worst place to meet it.

That is not hypothetical. It is how nine errors accumulated before [#83](https://github.com/decasamerlo/nesto/issues/83) cleared them — four of the nine from a single rule that did not exist when the table it flagged was written.

**Bumping is deliberate**: edit `VERSION`, run the script, and fix what the new rules find in the same commit. The bump and its consequences land together, attributable to the person who chose them.

The trade is that new rules never arrive on their own. A pinned tool goes stale silently, and nothing here notices — reviewing the pin is an occasional deliberate act, not something the repo will remind anyone about.

## What is not linted

- **The three sub-repos.** Each carries its own files, and nothing here reaches into them.
- **`.agents/skills/`** — vendored third-party material. Not ours to reformat, and reformatting it would be overwritten on the next sync.
- **`CLAUDE.md`** — a symlink to `AGENTS.md`. Linting both reports every finding twice, against two paths that are one file.
