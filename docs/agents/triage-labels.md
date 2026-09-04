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
| `wontfix`                  | `wontfix`            | Will not be actioned                     |
| —                          | `pending-merge`      | Implemented; PR open, waiting to land    |

When a skill mentions a role (e.g. "apply the AFK-ready triage label"), use the corresponding label string from this table.

Edit the right-hand column to match whatever vocabulary you actually use.

### Why `pending-merge` exists

The canonical five are all states with work outstanding. Each names whose turn it is: the maintainer for `needs-triage`, the reporter for `needs-info`, an agent for `ready-for-agent`, a human implementer for `ready-for-human`, nobody ever for `wontfix`. None of them covers an issue whose work is finished and whose only remaining obstacle is a review gate. `pending-merge` is that state, applied when the PR opens, replacing `ready-for-agent`.

**Why not `ready-for-human`.** On an issue, that label says an agent cannot build this, which routes the issue into the human work queue. `pending-merge` takes the issue out of both queues: nothing is outstanding and the artifact already exists. The triage skill does give `ready-for-human` a second sense — read against a PR's attached code, it means the code is ready for a human to merge — but that sense has no surface here. PRs are not a triage surface in this repo (see [issue-tracker.md](issue-tracker.md)), and implementation PRs live in the sub-repos, which carry no triage labels at all. The issue is the only place the state can be recorded, and on an issue `ready-for-human` makes the opposite claim.

**Why the gap matters here.** [ADR 005](../adr/005-native-stacked-prs.md) and [ADR 006](../adr/006-contribution-and-review-model.md) put a human at the merge gate and have the owner land one layer at a time, bottom-up. The window between "agent finished" and "landed on `main`" is therefore long, and it holds several issues at once while agents keep stacking new work on top of the open PRs. An issue left in `ready-for-agent` through that window sits in the agent queue with its work already done, inviting a second implementation. The upstream skills have the same gap; it does not surface there because an agent-ready issue is typically merged within minutes.

This footing survives automation. Cross-repo closing keywords would close these issues on merge, but a closing keyword fires at the far end of the window, and nothing else marks where it starts.
