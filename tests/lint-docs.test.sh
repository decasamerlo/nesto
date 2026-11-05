#!/bin/sh
# Smoke test for scripts/lint-docs.sh's own checks, run over the repo's docs
# or over the files it is given.
#
# One throwaway docs tree per case, with the script copied in beside it and
# npx stubbed out, so only the checks run: markdownlint is the pinned tool's
# business, not this suite's. The stub records what it was handed, which is
# how a case sees the files reach markdownlint.
#
# Run: tests/lint-docs.test.sh

set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
script=$root/scripts/lint-docs.sh
[ -x "$script" ] || { echo "missing $script" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# The stub records what markdownlint would have been handed, one per line,
# after the --yes and the pinned package
mkdir -p "$tmp/bin"
printf '#!/bin/sh\nshift 2\nprintf "%%s\\n" "$@" >"%s/npx.args"\n' "$tmp" >"$tmp/bin/npx"
chmod +x "$tmp/bin/npx"

passed=0
failed=0

check() { # check <name> <expected> <actual>
	if [ "$2" = "$3" ]; then
		passed=$((passed + 1))
		printf 'ok    %s\n' "$1"
	else
		failed=$((failed + 1))
		printf 'FAIL  %s\n        expected: [%s]\n        actual:   [%s]\n' \
			"$1" "$2" "$3"
	fi
}

tree() { # tree <name> — a docs tree holding ADR 001 and nothing else
	mkdir -p "$tmp/$1/scripts" "$tmp/$1/docs/adr" "$tmp/$1/docs/conventions"
	cp "$script" "$tmp/$1/scripts/"
	printf '# One\n' >"$tmp/$1/docs/adr/001-one.md"
	printf '# ADRs\n' >"$tmp/$1/docs/conventions/adr.md"
	for f in AGENTS.md README.md GLOSSARY.md; do printf '# %s\n' "$f" >"$tmp/$1/$f"; done
	printf 'See ADR 001.\n' >"$tmp/$1/docs/notes.md"
}

lint() { # lint <name> — prints the exit status, then stderr
	status=0
	PATH="$tmp/bin:$PATH" "$tmp/$1/scripts/lint-docs.sh" 2>"$tmp/$1.err" >/dev/null || status=$?
	echo "$status"
}

tree written
check "a written ADR passes" 0 "$(lint written)"

tree dangling
printf 'See ADR 002.\n' >>"$tmp/dangling/docs/notes.md"
check "an unwritten, unreserved ADR fails" 1 "$(lint dangling)"
check "the failure names the citing line" "docs/notes.md:2:See ADR 002." \
	"$(head -n 1 "$tmp/dangling.err")"

tree reserved
printf 'See ADR 002.\n' >>"$tmp/reserved/docs/notes.md"
printf '\n- **002** — reserved by [#1](https://example.invalid/1)\n' \
	>>"$tmp/reserved/docs/conventions/adr.md"
check "a reserved number passes" 0 "$(lint reserved)"

tree legacy
printf 'Renamed from ADR 0005.\n' >>"$tmp/legacy/docs/notes.md"
check "a four-digit legacy name is not a reference" 0 "$(lint legacy)"
check "no files given -> markdownlint reads the docs globs" "docs/**/*.md" \
	"$(head -n 1 "$tmp/npx.args")"

# --- files given: a draft outside the docs, named from the caller's directory

given() { # given <name> <dir> <file>... — lint those files from <dir>, as lint does
	name=$1 dir=$2
	shift 2
	status=0
	(cd "$dir" && PATH="$tmp/bin:$PATH" "$tmp/$name/scripts/lint-docs.sh" "$@") \
		2>"$tmp/$name.err" >/dev/null || status=$?
	echo "$status"
}

tree drafts
mkdir -p "$tmp/drafts/.scratch"
printf 'Closes decasamerlo/nesto#1, after decasamerlo/nesto-backend#2.\n' \
	>"$tmp/drafts/.scratch/body.md"
check "a clean draft given -> passes" 0 "$(given drafts "$tmp/drafts/.scratch" body.md)"
check "a clean draft given -> markdownlint reads it, made absolute" \
	"$tmp/drafts/.scratch/body.md" "$(cat "$tmp/npx.args")"

printf 'After nesto-backend#2.\n' >>"$tmp/drafts/.scratch/body.md"
check "a bare cross-repo reference given -> fails" 1 \
	"$(given drafts "$tmp/drafts/.scratch" body.md)"
check "a bare cross-repo reference given -> names the line" "yes" \
	"$(grep -q 'body.md:2:After nesto-backend#2.' "$tmp/drafts.err" && echo yes || echo no)"

printf 'See ADR 002.\n' >"$tmp/drafts/.scratch/adr-cite.md"
check "an unwritten ADR in a draft given -> fails" 1 \
	"$(given drafts "$tmp/drafts" .scratch/adr-cite.md)"

tree conventions
printf 'An entry reads pull/NNN until the PR opens.\n' >>"$tmp/conventions/docs/conventions/adr.md"
check "the placeholder named in prose, given -> passes" 0 \
	"$(given conventions "$tmp/conventions" docs/conventions/adr.md)"

printf '%s\n' '- **2026-11-05** — corrected ([#1](https://example.invalid/pull/NNN))' \
	>>"$tmp/conventions/docs/adr/001-one.md"
check "a placeholder in an ADR given -> fails" 1 \
	"$(given conventions "$tmp/conventions" docs/adr/001-one.md)"

printf '\n%s passed, %s failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
