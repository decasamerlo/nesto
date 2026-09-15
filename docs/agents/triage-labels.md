# Triage Labels

The skills speak in terms of canonical triage roles. This file maps those roles to the actual label strings used in this repo's issue tracker, and records where this repo's vocabulary diverges from them.

## Category roles

`bug` (something is broken) and `enhancement` (new feature or improvement). Every triaged issue carries exactly one.

There is no third category for documentation. This repo's content is almost entirely docs, so a `documentation` category would apply to nearly every issue and separate nothing. It would also make the one-category rule ambiguous in the common case, since a doc defect has an equal claim on `bug`. Docs work is `enhancement`; a doc that states something false is a `bug`.

## State roles

Every triaged issue carries exactly one state role, and applying one removes the previous one.

A state role is a durable stamp: it stays on the issue after the issue closes. A queue is therefore the label plus `--state open`, never the label alone — `gh issue list --state open --label ready-for-agent`, rather than expecting the label to be cleared.

| Label in mattpocock/skills | Label in our tracker | Meaning                                  |
| -------------------------- | -------------------- | ---------------------------------------- |
| `needs-triage`             | `needs-triage`       | Maintainer needs to evaluate this issue  |
| `needs-info`               | `needs-info`         | Waiting on reporter for more information |
| `ready-for-agent`          | `ready-for-agent`    | Fully specified, ready for an AFK agent  |
| `ready-for-human`          | `ready-for-human`    | Requires human implementation            |
| none                       | `deferred`           | Ruled out of scope; revisit on trigger   |
| `wontfix`                  | `wontfix`            | Will not be actioned                     |
| none                       | `pending-merge`      | Implemented; PR open, waiting to land    |

When a skill mentions a role (e.g. "apply the AFK-ready triage label"), use the corresponding label string from this table.

Edit the right-hand column to match whatever vocabulary you actually use.

### Why `pending-merge` exists

The canonical five are all states with work outstanding. Each names whose turn it is: the maintainer for `needs-triage`, the reporter for `needs-info`, an agent for `ready-for-agent`, a human implementer for `ready-for-human`, nobody ever for `wontfix`. None of them covers an issue whose work is finished and whose only remaining obstacle is a review gate. `pending-merge` is that state, applied when the PR opens, replacing `ready-for-agent`.

**Why not `ready-for-human`.** On an issue, that label says an agent cannot build this, which routes the issue into the human work queue. `pending-merge` takes the issue out of both queues: nothing is outstanding and the artifact already exists. The triage skill does give `ready-for-human` a second sense — read against a PR's attached code, it means the code is ready for a human to merge — but that sense has no surface here. PRs are not a triage surface in this repo (see [issue-tracker.md](issue-tracker.md)), and implementation PRs live in the sub-repos, which carry no triage labels at all. The issue is the only place the state can be recorded, and on an issue `ready-for-human` makes the opposite claim.

**Why the gap matters here.** [ADR 005](../adr/005-native-stacked-prs.md) and [ADR 006](../adr/006-contribution-and-review-model.md) put a human at the merge gate and have the owner land one layer at a time, bottom-up. The window between "agent finished" and "landed on `main`" is therefore long, and it holds several issues at once while agents keep stacking new work on top of the open PRs. An issue left in `ready-for-agent` through that window sits in the agent queue with its work already done, inviting a second implementation. The upstream skills have the same gap; it does not surface there because an agent-ready issue is typically merged within minutes.

This footing survives automation. Cross-repo closing keywords would close these issues on merge, but a closing keyword fires at the far end of the window, and nothing else marks where it starts — so the near end stays manual: whoever opens the PR applies the label.

### Why `deferred` exists

`pending-merge` closes one gap in the canonical five; this is the other. Run the same test — each state names whose turn it is — and `wontfix` is the only one that answers "nobody". It answers permanently: *will not be actioned*. Nothing covers work that has been read, understood, and ruled out of the current scope while staying genuinely wanted.

`deferred` is that state: **nobody's turn until a named trigger fires.** It pairs with `wontfix` as *not now* against *never*, and the pairing only holds while the trigger is written down — so a deferred issue names its revisit condition in the body. The two that arrived already decided both do: [#70](https://github.com/decasamerlo/nesto/issues/70) names a second concurrent user, [#67](https://github.com/decasamerlo/nesto/issues/67) names the trash screen.

**Why not `v2`.** A version names a release, not a turn, and it decays — when v1 ships, every issue carrying it is relabelled or starts lying. It also misfiles the case that motivated the label: #70 waits on a second concurrent user, a property of how the app is used rather than a point in the release order. [#26](https://github.com/decasamerlo/nesto/issues/26)'s *Out of scope* section already carries the release-shaped reading in prose, where it can say which scope and why. The label carries the state; the map carries the scope.

**Why not a third category role.** The same argument this file makes against a `documentation` category. Deferral is orthogonal to whether a thing is broken or wanted: #70 is a `bug` that is deferred, #67 an `enhancement` that is deferred. As a category it would collide with the one-category rule; as a state it collides with nothing, because a deferred issue is in no other state.

**It does not mean "untriaged".** A deferred issue has been read and decided about, which is why it carries a category role too. Six of the first eight (#65, #48, #47, #46, #45, #44) sat in `needs-triage` with no category at all, and were triaged as `enhancement` at the same time the label was applied — the deferral is not a way to clear a queue without reading it.
