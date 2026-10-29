#!/bin/sh
# Smoke test for the ADR-reference check in scripts/lint-docs.sh.
#
# One throwaway docs tree per case, with the script copied in beside it and
# npx stubbed out, so only the check runs: markdownlint is the pinned tool's
# business, not this suite's.
#
# Run: tests/lint-docs.test.sh

set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
script=$root/scripts/lint-docs.sh
[ -x "$script" ] || { echo "missing $script" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin"
printf '#!/bin/sh\nexit 0\n' >"$tmp/bin/npx"
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
	for f in AGENTS.md README.md CONTEXT.md; do printf '# %s\n' "$f" >"$tmp/$1/$f"; done
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

printf '\n%s passed, %s failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
