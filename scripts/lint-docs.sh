#!/bin/sh
# Lints this repo's own markdown at a pinned tool version, and exits nonzero
# when any file fails. First it runs the checks markdownlint cannot, each
# commented where it runs.
#
# The version is pinned on purpose. Run through an unpinned npx,
# markdownlint-cli2 resolves to whatever is current, so its ruleset moves
# under the repo and a file that passed when it was written starts failing
# with nobody having touched it. That is how the nine errors cleared in #83
# accumulated — four of them from one rule that did not exist when the table
# it flagged was written.
#
# Bumping is a deliberate edit to VERSION below, with whatever the new rules
# find fixed in the same commit.
#
# What is left out, and why: the three sub-repos carry their own files and
# nothing here reaches into them; .agents/skills/ is vendored third-party
# material; and CLAUDE.md is a symlink to AGENTS.md, so linting it would
# report every finding twice.
#
# Given files, it lints those instead, with the same checks and the
# markdownlint config nearest each file: a PR or issue body, or a draft in
# .scratch/, before it is published.
#
# Run: scripts/lint-docs.sh              this repo's docs, from the meta-repo root
#      scripts/lint-docs.sh <file>...    those files, relative to where you are
#      ../scripts/lint-docs.sh           this repo's docs, from a sub-repo directory
set -eu

VERSION=0.23.2

# A file given is relative to the caller's directory, so it is made absolute
# before the move to the meta-repo root below.
for path; do
	case $path in
	/*) ;;
	*) path=$PWD/$path ;;
	esac
	set -- "$@" "$path"
	shift
done

# The globs are relative to the meta-repo root, so resolve it from this
# script's own location rather than trusting the caller's directory.
cd "$(dirname "$0")/.."

# What the checks below read: the files given, or this repo's docs.
if [ "$#" -eq 0 ]; then
	given=no
	set -- docs AGENTS.md README.md GLOSSARY.md
else
	given=yes
fi

# An "ADR NNN" with no file and no reservation is how ADR 010 and ADR 011
# came to cite an ADR 008 that a later edit then declared a gap never to be
# filled. docs/conventions/adr.md, Numbering, says how a number is reserved.
dangling=0
for n in $(grep -rohE 'ADR[ -][0-9]{3}\b' "$@" | grep -oE '[0-9]{3}' | sort -u); do
	ls docs/adr/"$n"-*.md >/dev/null 2>&1 && continue
	grep -qE "^- \*\*$n\*\* — reserved by " docs/conventions/adr.md && continue
	grep -rHnE "ADR[ -]$n\b" "$@" >&2
	dangling=1
done
if [ "$dangling" -ne 0 ]; then
	echo "lint-docs: each ADR above has no file in docs/adr/ and no reservation in docs/conventions/adr.md" >&2
	exit 1
fi

# A reference that crosses a repo boundary is written owner/repo#N
# (docs/conventions/stacked-prs.md, Referencing issues). ADR 014 reached
# review with four bare nesto-backend#N, which only the reviewer caught.
if grep -rHnE '(^|[^/A-Za-z0-9_-])nesto-(backend|web|mobile)#[0-9]' "$@" >&2; then
	echo "lint-docs: write each reference above as decasamerlo/nesto-<repo>#N" >&2
	exit 1
fi

# An amendment entry's PR number is written once the PR is open, and the
# entry reads pull/NNN until then (docs/conventions/adr.md, The amendment
# entry). This fails until the amend that writes the number. It reads ADRs
# alone: adr.md itself names the placeholder in prose.
placeholders=0
if [ "$given" = no ]; then
	grep -rn 'pull/NNN' docs/adr >&2 && placeholders=1
else
	for file; do
		case $file in
		*/docs/adr/*) grep -Hn 'pull/NNN' "$file" >&2 && placeholders=1 ;;
		esac
	done
fi
if [ "$placeholders" -ne 0 ]; then
	echo "lint-docs: amend each placeholder above to the PR's number" >&2
	exit 1
fi

if [ "$given" = yes ]; then
	exec npx --yes "markdownlint-cli2@$VERSION" "$@"
fi
exec npx --yes "markdownlint-cli2@$VERSION" \
	"docs/**/*.md" "AGENTS.md" "README.md" "GLOSSARY.md"
