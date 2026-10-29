#!/bin/sh
# Lints this repo's own markdown at a pinned tool version, and exits nonzero
# when any file fails. First it checks that every "ADR NNN" names a written
# ADR or a reserved number, which markdownlint cannot.
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
# Run: scripts/lint-docs.sh       from the meta-repo root
#      ../scripts/lint-docs.sh    from a sub-repo directory
set -eu

VERSION=0.23.2

# The globs are relative to the meta-repo root, so resolve it from this
# script's own location rather than trusting the caller's directory.
cd "$(dirname "$0")/.."

# An "ADR NNN" with no file and no reservation is how ADR 010 and ADR 011
# came to cite an ADR 008 that a later edit then declared a gap never to be
# filled. docs/conventions/adr.md, Numbering, says how a number is reserved.
dangling=0
for n in $(grep -rohE 'ADR[ -][0-9]{3}\b' docs AGENTS.md README.md CONTEXT.md | grep -oE '[0-9]{3}' | sort -u); do
	ls docs/adr/"$n"-*.md >/dev/null 2>&1 && continue
	grep -qE "^- \*\*$n\*\* — reserved by " docs/conventions/adr.md && continue
	grep -rnE "ADR[ -]$n\b" docs AGENTS.md README.md CONTEXT.md >&2
	dangling=1
done
if [ "$dangling" -ne 0 ]; then
	echo "lint-docs: each ADR above has no file in docs/adr/ and no reservation in docs/conventions/adr.md" >&2
	exit 1
fi

exec npx --yes "markdownlint-cli2@$VERSION" \
	"docs/**/*.md" "AGENTS.md" "README.md" "CONTEXT.md"
