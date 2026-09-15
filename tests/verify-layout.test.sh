#!/bin/sh
# Smoke test for scripts/verify-layout.sh.
#
# One throwaway meta-repo layout per case — a root holding mani.yaml and
# .githooks/, a clone or two beneath it, the hook symlinked in exactly as
# `mani run install-hooks` does it — then the checker is run from inside that
# layout and its report is read back row by row.
#
# The cases are mostly the negative ones. Each has to fail *and* name which of
# the three states is wrong, because "your layout is broken" is the unhelpful
# version of this tool, so every assertion reads one row's result out of the
# report rather than only the exit status.
#
# Run: tests/verify-layout.test.sh

set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
script=$root/scripts/verify-layout.sh
[ -x "$script" ] || { echo "missing $script" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Global and system config are read out of the picture, as in the hook's own
# suite: a developer's core.hooksPath would otherwise move the hooks directory
# the checker inspects, and a personal url.*.insteadOf could rewrite an origin.
GIT_CONFIG_GLOBAL=/dev/null
GIT_CONFIG_SYSTEM=/dev/null
export GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM

meta=git@github.com:decasamerlo/nesto.git
backend=git@github.com:decasamerlo/nesto-backend.git
fork=git@github.com:contributor/nesto-backend.git

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

clone() { # clone <layout-root> <dir> <origin-url> — a clone with the hook in
	mkdir -p "$2"
	(
		cd "$2"
		git init --quiet --initial-branch=main
		git config user.name "Layout Test"
		git config user.email "layout-test@example.invalid"
		git config commit.gpgsign false
		git config remote.origin.url "$3"
		ln -sfn "$1/.githooks/prepare-commit-msg" \
			"$(git rev-parse --git-path hooks)/prepare-commit-msg"
	)
}

layout() { # layout <name> — a meta-repo layout: nesto + backend, web declared
	d=$tmp/$1
	mkdir -p "$d/.githooks"
	printf '#!/bin/sh\nexit 0\n' >"$d/.githooks/prepare-commit-msg"
	chmod +x "$d/.githooks/prepare-commit-msg"
	cat >"$d/mani.yaml" <<EOF
projects:
  nesto:
    path: .
    url: $meta

  backend:
    url: $backend

  web:
    url: git@github.com:decasamerlo/nesto-web.git

tasks:
  hello:
    desc: Print Hello World
    cmd: echo "Hello World"
EOF
	clone "$d" "$d" "$meta"
	clone "$d" "$d/backend" "$backend"
}

out=''
status=0

run() { # run <dir> — run the checker from <dir>, capturing report and status
	out=$(cd "$1" && "$script" 2>&1) && status=0 || status=$?
}

verdict() { # verdict <project> <state> — that row's result word, or empty
	printf '%s\n' "$out" |
		awk -v p="$1" -v s="$2" \
			'($1 == "ok" || $1 == "FAIL" || $1 == "skip") &&
			 $2 == p && $3 == s { print $1; exit }'
}

said() { # said <substring> — yes/no, whether the report mentions it
	case $out in
	*"$1"*) echo yes ;;
	*) echo no ;;
	esac
}

# --- a layout that is wired correctly passes, from anywhere inside it ------

layout clean
run "$tmp/clean"
check "clean layout -> exit 0" "0" "$status"
check "clean layout -> layout ok" "ok" "$(verdict - layout)"
check "clean layout -> root origin ok" "ok" "$(verdict nesto origin)"
check "clean layout -> root hook ok" "ok" "$(verdict nesto hook)"
check "clean layout -> sub-repo origin ok" "ok" "$(verdict backend origin)"
check "clean layout -> sub-repo hook ok" "ok" "$(verdict backend hook)"

run "$tmp/clean/backend"
check "run from a sub-repo -> exit 0" "0" "$status"
check "run from a sub-repo -> layout ok" "ok" "$(verdict - layout)"

# --- a repo declared but never cloned is a skip, not a failure ------------

check "project not cloned -> skipped" "skip" "$(verdict web -)"
check "project not cloned -> still exit 0" "0" "$status"

# --- no mani.yaml above: the standalone clone the fork flow warns about ---

mkdir -p "$tmp/standalone"
clone "$tmp/standalone" "$tmp/standalone" "$backend"
run "$tmp/standalone"
check "standalone clone -> exit 1" "1" "$status"
check "standalone clone -> layout FAILs" "FAIL" "$(verdict - layout)"
check "standalone clone -> says what is missing" "yes" "$(said 'no mani.yaml above')"

# --- origin must stay the canonical repo, and the fork is not checked -----

layout forked
( cd "$tmp/forked/backend" && git config remote.origin.url "$fork" )
run "$tmp/forked"
check "fork as origin -> exit 1" "1" "$status"
check "fork as origin -> origin FAILs" "FAIL" "$(verdict backend origin)"
check "fork as origin -> names the canonical repo" "yes" \
	"$(said 'declared: decasamerlo/nesto-backend')"
check "fork as origin -> hook still checked" "ok" "$(verdict backend hook)"

# The fork is a *second* remote by design (stacked-prs.md, Fork contribution),
# so a contributor's working setup has to pass untouched.
layout contributor
( cd "$tmp/contributor/backend" && git config remote.fork.url "$fork" )
run "$tmp/contributor"
check "fork as a second remote -> exit 0" "0" "$status"
check "fork as a second remote -> origin ok" "ok" "$(verdict backend origin)"

# An https clone of the same repo is the same repo.
layout https
( cd "$tmp/https/backend" &&
	git config remote.origin.url https://github.com/decasamerlo/nesto-backend.git )
run "$tmp/https"
check "https origin -> origin ok" "ok" "$(verdict backend origin)"

# --- the hook: missing, dangling, or somebody else's ----------------------

layout nohook
rm "$tmp/nohook/backend/.git/hooks/prepare-commit-msg"
run "$tmp/nohook"
check "hook not installed -> exit 1" "1" "$status"
check "hook not installed -> hook FAILs" "FAIL" "$(verdict backend hook)"
check "hook not installed -> names the install task" "yes" "$(said 'install-hooks')"

# The state that most resembles "installed": git skips a dangling hook without
# a word, and [ -e ] is false for it, so only [ -L ] sees it at all. Deleting
# the checkout a link points into — a finished worktree, a moved clone — is
# how it happens. The fixture is not named for the word being asserted on:
# every row carries the layout's path, so it would match the directory name
# and the case would pass with the rule taken out.
layout brokenlink
ln -sfn "$tmp/brokenlink/.githooks/deleted-hook" \
	"$tmp/brokenlink/backend/.git/hooks/prepare-commit-msg"
run "$tmp/brokenlink"
check "hook symlink dangles -> exit 1" "1" "$status"
check "hook symlink dangles -> hook FAILs" "FAIL" "$(verdict backend hook)"
check "hook symlink dangles -> says so" "yes" "$(said 'dangling symlink')"
check "hook symlink dangles -> meta-repo hook still ok" "ok" "$(verdict - hook)"

# The same failure from the other side: the single file every install links to.
layout nosource
rm "$tmp/nosource/.githooks/prepare-commit-msg"
run "$tmp/nosource"
check "meta-repo hook missing -> exit 1" "1" "$status"
check "meta-repo hook missing -> hook FAILs" "FAIL" "$(verdict - hook)"

layout copied
rm "$tmp/copied/backend/.git/hooks/prepare-commit-msg"
cp "$tmp/copied/.githooks/prepare-commit-msg" \
	"$tmp/copied/backend/.git/hooks/prepare-commit-msg"
run "$tmp/copied"
check "hook copied instead of linked -> exit 1" "1" "$status"
check "hook copied instead of linked -> hook FAILs" "FAIL" "$(verdict backend hook)"

layout elsewhere
ln -sfn "$tmp/elsewhere/.githooks/somebody-elses-hook" \
	"$tmp/elsewhere/backend/.git/hooks/prepare-commit-msg"
printf '#!/bin/sh\nexit 0\n' >"$tmp/elsewhere/.githooks/somebody-elses-hook"
chmod +x "$tmp/elsewhere/.githooks/somebody-elses-hook"
run "$tmp/elsewhere"
check "hook links elsewhere -> hook FAILs" "FAIL" "$(verdict backend hook)"

# Inside the right checkout, but not the hook: the path has to be shaped like
# .githooks/prepare-commit-msg, or a link to any directory in the meta-repo
# would be read as one and pass on the strength of the repository alone.
layout notahook
mkdir -p "$tmp/notahook/docs"
ln -sfn "$tmp/notahook/docs" \
	"$tmp/notahook/backend/.git/hooks/prepare-commit-msg"
run "$tmp/notahook"
check "hook links at a directory -> hook FAILs" "FAIL" "$(verdict backend hook)"

# A linked worktree shares one hooks directory with the checkout that owns the
# repository, so the live hook there is legitimately that checkout's file and
# not this root's copy. Working in a worktree is ordinary, and the check has
# to pass for it — this is the case that stops the comparison from being
# tightened back to "this root's copy only".
layout wtsame
(
	cd "$tmp/wtsame"
	git commit -q --allow-empty -m "a commit to branch a worktree from"
	git worktree add -q "$tmp/wtsame-checkout" -b other
)
mkdir -p "$tmp/wtsame-checkout/.githooks"
printf '#!/bin/sh\nexit 0\n' >"$tmp/wtsame-checkout/.githooks/prepare-commit-msg"
chmod +x "$tmp/wtsame-checkout/.githooks/prepare-commit-msg"
ln -sfn "$tmp/wtsame-checkout/.githooks/prepare-commit-msg" \
	"$tmp/wtsame/backend/.git/hooks/prepare-commit-msg"
run "$tmp/wtsame"
check "hook from another checkout -> exit 0" "0" "$status"
check "hook from another checkout -> hook ok" "ok" "$(verdict backend hook)"
check "hook from another checkout -> names it" "yes" "$(said 'another checkout')"

# The other side of that latitude: same path shape, different repository. Only
# checkouts of *this* repository count, which is what keeps "any .githooks
# anywhere" from being what the rule actually says.
layout foreign
mkdir -p "$tmp/foreign-project/.githooks"
printf '#!/bin/sh\nexit 0\n' >"$tmp/foreign-project/.githooks/prepare-commit-msg"
chmod +x "$tmp/foreign-project/.githooks/prepare-commit-msg"
( cd "$tmp/foreign-project" && git init --quiet --initial-branch=main )
ln -sfn "$tmp/foreign-project/.githooks/prepare-commit-msg" \
	"$tmp/foreign/backend/.git/hooks/prepare-commit-msg"
run "$tmp/foreign"
check "hook from another repository -> exit 1" "1" "$status"
check "hook from another repository -> hook FAILs" "FAIL" "$(verdict backend hook)"

# A hook that lost its executable bit is skipped as silently as a missing one,
# and it is the meta-repo's single copy, so every clone is dead at once.
layout unexecutable
chmod -x "$tmp/unexecutable/.githooks/prepare-commit-msg"
run "$tmp/unexecutable"
check "meta-repo hook not executable -> exit 1" "1" "$status"
check "meta-repo hook not executable -> hook FAILs" "FAIL" "$(verdict - hook)"

# --- a directory that is not its own clone ------------------------------

# git walks up out of a plain directory and answers for the repo above it, so
# an uncloned backend/ inside the meta-repo would otherwise be checked against
# the meta-repo's own origin and hook — and pass, or fail for the wrong reason.
layout plaindir
rm -rf "$tmp/plaindir/backend"
mkdir -p "$tmp/plaindir/backend/src"
run "$tmp/plaindir"
check "plain directory -> exit 1" "1" "$status"
check "plain directory -> layout FAILs" "FAIL" "$(verdict backend layout)"
check "plain directory -> no origin verdict" "" "$(verdict backend origin)"
check "plain directory -> no hook verdict" "" "$(verdict backend hook)"

printf '\n%s passed, %s failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
