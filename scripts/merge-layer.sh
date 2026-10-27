#!/bin/sh
# Merges one layer of the owner's stack and leaves the layers above it ready
# for the next run: the procedure in docs/conventions/stacked-prs.md (Merging
# a stack) as one command, because the manual path goes through
# gh stack modify's TUI and a prompt in gh stack submit.
#
# Before it changes anything, it stops, naming what failed, unless the PR is
# open, based on the default branch and not behind it, green on every check
# of its head (it waits while one is running), and free of review threads
# still waiting for a reply. A thread is answered when the viewer wrote its
# last comment or gave that comment a thumbs-up.
#
# Then, in order:
#
#   unstack   a layer still in a GitHub stack takes the whole stack off
#             GitHub, since even --admin merges are refused on a stacked PR.
#             Unstacking drops the local tracking too, so the open layers'
#             branches are adopted again with gh stack init, after checking
#             that each one equals its PR's head
#   link      each issue the body names on a "Closes" line has to be in the
#             PR's closingIssuesReferences. GitHub does not always refresh
#             the link when it retargets a layer onto main by itself, so a
#             missing one gets the body saved again, unchanged, and a wait
#   threads   the answered threads are resolved: they close at merge, not
#             when the reply is posted
#   merge     gh pr merge --squash --admin, the owner's bypass
#   after     it waits for each issue to close, rebases and pushes the
#             layers above, and retargets the next layer onto the default
#             branch if GitHub has not
#
# Run: ../scripts/merge-layer.sh [--dry-run] <pr>   from the sub-repo holding the stack
#      scripts/merge-layer.sh [--dry-run] <pr>      from the meta-repo root
#
# --dry-run runs every check and prints what it would change, changing nothing.

set -eu

dry_run=false
if [ "${1-}" = --dry-run ]; then
	dry_run=true
	shift
fi
if [ $# -ne 1 ]; then
	echo "usage: $0 [--dry-run] <pr>" >&2
	exit 2
fi
pr=$1

die() { # die <line>...
	for line; do printf 'merge-layer: %s\n' "$line" >&2; done
	exit 1
}

say() { printf '%s\n' "$*"; }

run() { # run <command>...: runs it, or prints it under --dry-run
	if $dry_run; then
		say "would run: $*"
	else
		"$@"
	fi
}

repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
trunk=$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name)
viewer=$(gh api user --jq .login)

pull() { # pull <fields> <jq>: reads fields of the PR through GraphQL
	gh api graphql -F pr="$pr" -f o="${repo%/*}" -f n="${repo#*/}" \
		-f query="query(\$o:String!,\$n:String!,\$pr:Int!){repository(owner:\$o,name:\$n){pullRequest(number:\$pr){$1}}}" \
		--jq ".data.repository.pullRequest | $2"
}

# --- checks: nothing changes until every one of them passes ----------------

state=$(pull state .state)
[ "$state" = OPEN ] || die "#$pr is $state"

base=$(pull baseRefName .baseRefName)
[ "$base" = "$trunk" ] || die "#$pr targets $base, not $trunk" \
	"merge the layer below it first"

head_branch=$(pull headRefName .headRefName)
behind=$(gh api "repos/$repo/compare/$trunk...$head_branch" --jq .behind_by)
[ "$behind" -eq 0 ] || die "#$pr is $behind commit(s) behind $trunk" \
	"run gh stack rebase && gh stack push, then this script again once CI has run"

# Open layers of the GitHub stack, bottom to top, one "<branch> <oid> <number>"
# per line. gh stack init adopts whatever commit a local branch holds, so a
# branch that differs from its PR's head stops the run here.
stack=$(pull 'stack{number}' '.stack.number // empty')
layers=
if [ -n "$stack" ]; then
	entries=$(pull 'stack{entries(first:50){nodes{position pullRequest{number state headRefName headRefOid}}}}' \
		'[.stack.entries.nodes[] | select(.pullRequest.state == "OPEN")] | sort_by(.position) | .[] | "\(.pullRequest.headRefName) \(.pullRequest.headRefOid) \(.pullRequest.number)"')
	while read -r branch oid number; do
		local_oid=$(git rev-parse --verify --quiet "refs/heads/$branch" || true)
		[ "$local_oid" = "$oid" ] || die "local $branch is at ${local_oid:-nothing}, #$number's head is $oid" \
			"check the branch out at its PR's head before unstacking"
		layers="$layers $branch"
	done <<EOF
$entries
EOF
fi

# Checks register a moment after a push, so a head with none yet while the
# repo has workflows is waited for rather than read as "no checks".
checks() {
	pull 'commits(last:1){nodes{commit{statusCheckRollup{contexts(first:100){nodes{__typename}}}}}}' \
		'[.commits.nodes[0].commit.statusCheckRollup.contexts.nodes[]?] | length'
}
workflows=$(gh api "repos/$repo/actions/workflows" --jq .total_count)
tries=0
while [ "$(checks)" -eq 0 ] && [ "$workflows" -gt 0 ]; do
	tries=$((tries + 1))
	[ "$tries" -le 12 ] || die "#$pr has no checks on its head after two minutes" \
		"rerun once CI has started"
	sleep 10
done
if [ "$(checks)" -eq 0 ]; then
	say "#$pr has no checks"
else
	say "waiting for the checks on #$pr"
	gh pr checks "$pr" --watch --fail-fast --interval 15 >/dev/null ||
		die "a check on #$pr did not pass: gh pr checks $pr"
fi

# One "<thread id> <last author> <viewer thumbs-up count> <path:line>" per
# unresolved thread.
threads=$(pull 'reviewThreads(first:100){nodes{id isResolved path line comments(last:1){nodes{author{login} reactionGroups{content viewerHasReacted}}}}}' \
	'.reviewThreads.nodes[] | select(.isResolved | not) | .comments.nodes[0] as $c | "\(.id) \($c.author.login // "ghost") \([$c.reactionGroups[]? | select(.content == "THUMBS_UP" and .viewerHasReacted)] | length) \(.path):\(.line // "-")"')
answered=
waiting=
while read -r id author thumbs where; do
	[ -n "$id" ] || continue
	if [ "$author" = "$viewer" ] || [ "$thumbs" -gt 0 ]; then
		answered="$answered $id"
	else
		waiting="$waiting $where"
	fi
done <<EOF
$threads
EOF
[ -z "$waiting" ] || die "#$pr has threads waiting for a reply:$waiting"

# Upper layers are read now: the head branch is deleted on merge.
upper=$(gh pr list --base "$head_branch" --state open --json number --jq '.[].number')

# --- changes ----------------------------------------------------------------

if [ -n "$stack" ]; then
	say "#$pr is in GitHub stack $stack; unstacking it and adopting$layers"
	run gh stack unstack "$stack"
	# One word per branch, so the expansion is unquoted on purpose.
	# shellcheck disable=SC2086
	run gh stack init $layers
fi

# The issues the body closes, as owner/repo#N; a bare #N is this repo's.
expected=$(pull body .body |
	sed -n -E 's/^Closes ([A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+)?#([0-9]+).*/\1#\2/p' |
	sed "s|^#|$repo#|")
missing() {
	links=$(pull 'closingIssuesReferences(first:20){nodes{number repository{nameWithOwner}}}' \
		'.closingIssuesReferences.nodes[] | "\(.repository.nameWithOwner)#\(.number)"')
	for issue in $expected; do
		printf '%s\n' "$links" | grep -qxF "$issue" || printf '%s\n' "$issue"
	done
}
if [ -z "$expected" ]; then
	say "#$pr closes no issue"
else
	gone=$(missing)
	if [ -n "$gone" ]; then
		say "GitHub does not link $(echo $gone); saving #$pr's body again"
		if ! $dry_run; then
			body=$(mktemp)
			pull body .body >"$body"
			gh pr edit "$pr" --body-file "$body" >/dev/null
			rm -f "$body"
			tries=0
			while gone=$(missing) && [ -n "$gone" ]; do
				tries=$((tries + 1))
				[ "$tries" -le 12 ] || die "GitHub still does not link $(echo $gone)" \
					"check the Closes line in #$pr's body"
				sleep 5
			done
		fi
	fi
	say "#$pr closes $(echo $expected)"
fi

for id in $answered; do
	if $dry_run; then
		say "would resolve thread $id"
	else
		gh api graphql -f id="$id" \
			-f query='mutation($id:ID!){resolveReviewThread(input:{threadId:$id}){thread{isResolved}}}' >/dev/null
	fi
done

run gh pr merge "$pr" --squash --admin

# --- after the merge ----------------------------------------------------------

unclosed=
if ! $dry_run; then
	for issue in $expected; do
		tries=0
		until [ "$(gh issue view "${issue##*#}" --repo "${issue%#*}" --json state --jq .state)" = CLOSED ]; do
			tries=$((tries + 1))
			if [ "$tries" -gt 12 ]; then
				unclosed="$unclosed $issue"
				break
			fi
			sleep 5
		done
	done
fi

if gh stack view --short >/dev/null 2>&1; then
	run gh stack rebase
	run gh stack push
else
	say "no local stack on this branch; nothing to rebase"
fi

for next in $upper; do
	if [ "$(gh pr view "$next" --json baseRefName --jq .baseRefName)" != "$trunk" ]; then
		run gh pr edit "$next" --base "$trunk"
	fi
	say "#$next is the next layer: run this script on it once its CI has run"
done

if $dry_run; then
	say "dry run: #$pr would merge"
	exit 0
fi
[ -z "$unclosed" ] || die "merged #$pr, but still open:$unclosed"
say "merged #$pr"
