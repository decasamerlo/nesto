#!/bin/sh
# Smoke test for .githooks/prepare-commit-msg.
#
# One throwaway repo per case, the hook symlinked in exactly as
# `mani run install-hooks` does it, then a real commit and an assertion on the
# message git actually stored. Locks in the behaviour table in
# docs/conventions/commits.md (The hook).
#
# Run: tests/prepare-commit-msg.test.sh

set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
hook=$root/.githooks/prepare-commit-msg
[ -f "$hook" ] || { echo "missing $hook" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Global and system config are read out of the picture: a developer's own
# commit.template or core.hooksPath would otherwise change the result, and
# commit.template in particular is a case the hook documents as unhandled.
GIT_CONFIG_GLOBAL=/dev/null
GIT_CONFIG_SYSTEM=/dev/null
export GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM

meta=git@github.com:decasamerlo/nesto.git
backend=git@github.com:decasamerlo/nesto-backend.git

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

new_repo() { # new_repo <name> <origin-url>
	mkdir -p "$tmp/$1"
	(
		cd "$tmp/$1"
		git init --quiet --initial-branch=main
		git config user.name "Hook Test"
		git config user.email "hook-test@example.invalid"
		git config commit.gpgsign false
		git config remote.origin.url "$2"
		ln -sfn "$hook" "$(git rev-parse --git-path hooks)/prepare-commit-msg"
	)
}

refs_of() { # refs_of <name> — every Refs: value, | separated
	( cd "$tmp/$1" && git log -1 --format='%(trailers:key=Refs,valueonly,separator=|)' )
}

subject_of() { # subject_of <name>
	( cd "$tmp/$1" && git log -1 --format='%s' )
}

refs_lines() { # refs_lines <name> — how many Refs: lines the message carries
	( cd "$tmp/$1" && git log -1 --format='%B' | grep -c '^Refs:' || true )
}

# An editor that types a subject onto the blank first line, the way a person
# would. Anything else would overwrite the trailer the hook just wrote.
cat >"$tmp/fake-editor" <<'EOF'
#!/bin/sh
sed '1s/^$/feat: typed in the editor/' "$1" >"$1.typed"
mv "$1.typed" "$1"
EOF
chmod +x "$tmp/fake-editor"

# --- the reference form comes from origin ---------------------------------

new_repo bare "$meta"
( cd "$tmp/bare" && git checkout -q -b docs/52-commit-conventions &&
	git commit -q --allow-empty -m "docs: a change" )
check "meta-repo origin -> bare reference" "#52" "$(refs_of bare)"

new_repo qualified "$backend"
( cd "$tmp/qualified" && git checkout -q -b feat/29-node-immutable &&
	git commit -q --allow-empty -m "feat(core): a change" )
check "sub-repo origin -> qualified reference" \
	"decasamerlo/nesto#29" "$(refs_of qualified)"

# --- the branch name is the whole of the exemption ------------------------

new_repo bot "$meta"
( cd "$tmp/bot" && git checkout -q -b dependabot/gradle/org.example-1.2 &&
	git commit -q --allow-empty -m "build(deps): bump org.example" )
check "dependabot branch -> no trailer" "" "$(refs_of bot)"

new_repo trunk "$meta"
( cd "$tmp/trunk" && git commit -q --allow-empty -m "docs: straight to main" )
check "main -> no trailer" "" "$(refs_of trunk)"

new_repo offgrammar "$meta"
( cd "$tmp/offgrammar" && git checkout -q -b refactor/12-extract-node &&
	git commit -q --allow-empty -m "refactor: extract Node" )
check "type outside the branch grammar -> no trailer" "" "$(refs_of offgrammar)"

# --- amending must not stack a second trailer -----------------------------

new_repo amended "$meta"
( cd "$tmp/amended" && git checkout -q -b fix/33-null-node &&
	git commit -q --allow-empty -m "fix(core): a change" &&
	git commit -q --amend --no-edit --allow-empty &&
	git commit -q --amend --no-edit --allow-empty )
check "amended twice -> one Refs line" "1" "$(refs_lines amended)"
check "amended twice -> right reference" "#33" "$(refs_of amended)"

# --- --no-verify bypasses pre-commit and commit-msg, not this hook --------

new_repo noverify "$meta"
( cd "$tmp/noverify" && git checkout -q -b chore/37-tidy-config &&
	git commit -q --allow-empty --no-verify -m "chore: tidy config" )
check "--no-verify -> trailer still written" "#37" "$(refs_of noverify)"

# --- the editor path: subject and trailer must not collapse together ------

new_repo editor "$meta"
( cd "$tmp/editor" && git checkout -q -b feat/41-editor-path &&
	GIT_EDITOR="$tmp/fake-editor" git commit -q --allow-empty )
check "editor path -> subject survives" \
	"feat: typed in the editor" "$(subject_of editor)"
check "editor path -> trailer separated from subject" "#41" "$(refs_of editor)"

# --- a detached HEAD has no branch to read, which is why rebase no-ops ----

new_repo detached "$meta"
( cd "$tmp/detached" && git checkout -q -b docs/45-detached &&
	git commit -q --allow-empty -m "docs: on a branch" )
check "on a branch -> trailer" "#45" "$(refs_of detached)"
( cd "$tmp/detached" && git checkout -q --detach &&
	git commit -q --allow-empty -m "docs: detached" )
check "detached HEAD -> no trailer" "" "$(refs_of detached)"

printf '\n%s passed, %s failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
