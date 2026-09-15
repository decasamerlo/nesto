#!/bin/sh
# Checks that this working copy is a meta-repo layout wired the way the fork
# flow in docs/conventions/stacked-prs.md requires, and reports which part is
# wrong when it is not.
#
# Three states, and each one fails in a way that surfaces long after the
# mistake that caused it — as a dead ../AGENTS.md pointer, or as commits
# landing with no Refs: trailer:
#
#   layout   mani.yaml is above this directory, and every declared project
#            that exists on disk is a clone of its own
#   origin   origin is the canonical repo mani.yaml declares for it
#   hook     prepare-commit-msg is installed and would actually run
#
# One run reports every project mani.yaml declares, from wherever inside the
# layout it is started. It is a command a person runs — after `mani sync`,
# before starting work — and stays one even once there is CI, because the
# layout is a property of a machine rather than of a pushed branch.
#
# Run: scripts/verify-layout.sh       from the meta-repo root
#      ../scripts/verify-layout.sh    from a sub-repo directory

set -eu

# --- the report -----------------------------------------------------------
#
# Every row is <result> <project> <state> <detail>, so the state that is wrong
# is named on the row that fails. Workspace-wide rows take `-` as the project.
# Rows the checker could not reach are absent rather than passing quietly.

passed=0
failed=0
skipped=0

ok() { # ok <project> <state> <detail>
	passed=$((passed + 1))
	printf 'ok    %-9s %-7s %s\n' "$1" "$2" "$3"
}

skip() { # skip <project> <state> <detail>
	skipped=$((skipped + 1))
	printf 'skip  %-9s %-7s %s\n' "$1" "$2" "$3"
}

fail() { # fail <project> <state> <detail> [more...]
	failed=$((failed + 1))
	printf 'FAIL  %-9s %-7s %s\n' "$1" "$2" "$3"
	shift 3
	for line in "$@"; do
		printf '          %s\n' "$line"
	done
}

summary() {
	printf '\n%s ok, %s failed, %s skipped\n' "$passed" "$failed" "$skipped"
}

# The repository a directory belongs to, as the absolute path of its common
# git directory — one per repository, shared by its linked worktrees, so two
# checkouts of the same repo answer the same here and a second clone does not.
# Empty when the directory is not in a repository at all.
common_dir() { # common_dir <dir>
	(
		cd "$1" 2>/dev/null &&
			git_dir=$(git rev-parse --git-common-dir 2>/dev/null) &&
			cd "$git_dir" 2>/dev/null &&
			pwd -P
	) || true
}

fork_flow=docs/conventions/stacked-prs.md
install='mani run install-hooks --all --ignore-non-existing'

# --- the layout itself ----------------------------------------------------
#
# The same parent walk `install-hooks` does, and for the same reason: the walk
# is what makes a directory part of the layout.
#
# Duplicated from mani.yaml rather than shared with it, because the walk is
# what finds this script in the first place — a task that called out to it
# would have to walk up to locate it. The two change together.

root=$PWD
while [ ! -f "$root/mani.yaml" ]; do
	if [ "$root" = / ]; then
		fail - layout "no mani.yaml above $PWD" \
			"this looks like a standalone clone" \
			"clone decasamerlo/nesto, run mani sync, and work in" \
			"the directory of the repo you are changing under it" \
			"see $fork_flow (Fork contribution)"
		summary
		exit 1
	fi
	root=$(dirname "$root")
done
ok - layout "$root"

# Which repository the meta-repo checkout is, and where it physically sits —
# both read once, to tell an installed hook belonging to this repository from
# one belonging to some other project that happens to keep a .githooks too.
root_repo=$(common_dir "$root")
root_physical=$(cd "$root" && pwd -P)

# The meta-repo's single copy of the hook. Every install is a symlink to this
# one file, so if it is gone or lost its executable bit, every clone is dead
# at once — and git skips a hook it cannot run without a word.
hook=$root/.githooks/prepare-commit-msg
if [ ! -f "$hook" ]; then
	fail - hook "missing $hook"
elif [ ! -x "$hook" ]; then
	fail - hook "not executable: $hook" "chmod +x $hook"
else
	ok - hook "$hook"
fi

# --- what mani.yaml declares ----------------------------------------------
#
# Reading our own manifest rather than asking mani for it: `mani list` has no
# machine-readable output, and the check has to keep working for someone who
# has cloned the meta-repo but not yet installed mani. The parser assumes the
# shape mani.yaml is written in — two-space indentation, one project per
# block, `path:` and `url:` beneath it — and mani's own default that a project
# with no `path:` sits in a directory named after it.

projects() { # projects <mani.yaml> — one "<name> <path> <url>" line each
	awk '
		function emit() {
			if (name != "") print name, (path == "" ? name : path), url
		}
		/^[^ \t#]/ {
			emit()
			name = ""
			in_projects = ($0 ~ /^projects:[ \t]*$/)
			next
		}
		!in_projects { next }
		/^  [^ \t#]/ {
			emit()
			name = $0
			sub(/^ */, "", name)
			sub(/:.*$/, "", name)
			path = ""
			url = ""
			next
		}
		/^    [a-z]+:/ {
			key = $0
			sub(/^ */, "", key)
			sub(/:.*$/, "", key)
			value = $0
			sub(/^[^:]*:[ \t]*/, "", value)
			sub(/[ \t]*$/, "", value)
			if (key == "path") path = value
			else if (key == "url") url = value
		}
		END { emit() }
	' "$1"
}

slug() { # slug <url> — the owner/repo a clone URL names, without .git
	trimmed=${1%/}
	trimmed=${trimmed%.git}
	repo=${trimmed##*/}
	owner=${trimmed%/*}
	owner=${owner##*[/:]}
	printf '%s/%s' "$owner" "$repo"
}

declared=$(projects "$root/mani.yaml")
if [ -z "$declared" ]; then
	fail - layout "mani.yaml declares no projects"
fi

# A here-document rather than a pipe: a `while` loop on the right of a pipe
# runs in a subshell, and the counters above would not survive it.
while read -r name path url; do
	[ -n "$name" ] || continue

	case $path in
	.) dir=$root ;;
	/*) dir=$path ;;
	*) dir=$root/$path ;;
	esac

	if [ ! -d "$dir" ]; then
		skip "$name" - "not cloned — mani sync clones it into $dir"
		continue
	fi

	# git answers for the first repository at or above a directory, so a plain
	# directory sitting in the layout — a half-finished sync, a repo that was
	# never cloned — would otherwise be checked against the meta-repo's own
	# origin and hook, and pass. Insisting the directory is its own top level
	# is what keeps that from being read as a verdict about the project.
	physical=$(cd "$dir" && pwd -P)
	toplevel=$(cd "$dir" && git rev-parse --show-toplevel 2>/dev/null || true)
	if [ "$toplevel" != "$physical" ]; then
		if [ -n "$toplevel" ]; then
			fail "$name" layout "$dir is not a clone of its own" \
				"git resolves it to $toplevel" \
				"mani sync clones $name here"
		else
			fail "$name" layout "$dir is not a git repository" \
				"mani sync clones $name here"
		fi
		continue
	fi

	# origin stays the canonical repo, for everyone. An outside contributor
	# pushes to a fork added as a *second* remote, which is what keeps this
	# check meaningful for them — so nothing here looks at any other remote.
	origin=$(cd "$dir" && git config --get remote.origin.url || true)
	canonical=$(slug "$url")
	if [ -z "$url" ]; then
		fail "$name" origin "mani.yaml declares no url for $name"
	elif [ -z "$origin" ]; then
		fail "$name" origin "no origin remote in $dir" \
			"expected: $canonical"
	else
		# The hook's own test, so both agree about which URL spellings name
		# the same repo: ssh, https, with or without .git. Anything else
		# falls through and is reported rather than guessed at.
		case $origin in
		*[/:]"$canonical" | *[/:]"$canonical".git)
			ok "$name" origin "$canonical"
			;;
		*)
			fail "$name" origin "origin is not the canonical repo" \
				"declared: $canonical" \
				"origin:   $origin" \
				"origin stays canonical; add your fork as a second remote" \
				"see $fork_flow (Fork contribution)"
			;;
		esac
	fi

	# The hook. `--git-path hooks` because that is what the install task uses:
	# it follows core.hooksPath and a worktree's shared hooks directory, so
	# both look in the same place.
	hooks_dir=$(cd "$dir" && git rev-parse --git-path hooks 2>/dev/null || true)
	if [ -z "$hooks_dir" ]; then
		fail "$name" hook "git will not say where $dir keeps its hooks"
		continue
	fi
	case $hooks_dir in
	/*) ;;
	*) hooks_dir=$dir/$hooks_dir ;;
	esac
	dest=$hooks_dir/prepare-commit-msg

	if [ -L "$dest" ]; then
		# A relative link resolves against the directory holding it.
		target=$(readlink "$dest" || true)
		case $target in
		/*) resolved=$target ;;
		*) resolved=$hooks_dir/$target ;;
		esac
		# The checkout the link reaches into, if the path is shaped like one.
		checkout=${resolved%/.githooks/prepare-commit-msg}

		if [ ! -e "$dest" ]; then
			# The one state that most resembles "installed": [ -e ] is false
			# for a dangling symlink and git skips it silently, so this is
			# the failure that otherwise looks exactly like success.
			fail "$name" hook "dangling symlink: $dest" \
				"points at $target, which does not exist" \
				"run: $install"
		elif [ "$checkout" = "$resolved" ] || [ ! -d "$checkout" ] ||
			[ "$(common_dir "$checkout")" != "$root_repo" ]; then
			# Not this root's copy but any checkout of this same repository,
			# because a linked worktree shares one hooks directory with the
			# checkout that owns the repository: work in a worktree and the
			# live hook is legitimately the main checkout's file. Comparing
			# the common git directory is what keeps that from also
			# admitting an unrelated project's .githooks.
			fail "$name" hook "hook points outside the meta-repo" \
				"links to: $target" \
				"expected: $hook" \
				"run: $install"
		elif [ ! -x "$resolved" ]; then
			fail "$name" hook "hook is not executable: $resolved" \
				"chmod +x $resolved"
		elif [ "$(cd "$checkout" && pwd -P)" = "$root_physical" ]; then
			ok "$name" hook "$dest"
		else
			ok "$name" hook "$dest -> $resolved (another checkout)"
		fi
	elif [ -e "$dest" ]; then
		fail "$name" hook "$dest is a file, not a link to $hook" \
			"a copy stops tracking the meta-repo's hook" \
			"move it aside, then run: $install"
	else
		fail "$name" hook "not installed: $dest" "run: $install"
	fi
done <<EOF
$declared
EOF

summary
[ "$failed" -eq 0 ]
