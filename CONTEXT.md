# Nesto

A personal list-of-lists app for capturing any hierarchical structure — todos, shopping lists, recipes, ideas, exercise logs, diaries — organized as a tree of recursively composable nodes.

## Language

**Node**:
The single domain entity in Nesto. A node has a name, optional description, optional status, optional dates, optional recurrence rule, a parent (nullable), and a position among its siblings.
_Avoid_: List, item, task, entry

**Root**:
A node with `parentId == null`. A user's home view shows all root nodes.
_Avoid_: Workspace, dashboard, home, inbox

**Position**:
An integer that orders siblings. Positions are auto-assigned on creation, gaps are allowed, and no two siblings may share a position. Reindexing shifts only the minimum necessary siblings.
_Avoid_: Order, sort index, rank

**Status**:
An optional lifecycle state on a node: `OPEN`, `IN_PROGRESS`, or `DONE`. Assigning a status is an explicit, opt-in action — the first status mutation transitions from no status to a tracking state. Valid transitions are any → Open, any non-null → Done, any non-null → In-Progress. Entering tracking from null is opt-in — the first mutation _is_ the choice of state; status jumps directly to the chosen tracking state, never through a null → OPEN intermediate.

Transition matrix:

```text
FROM    →  OPEN  IN_PROGRESS  DONE
null            ✓        ✓        ✓
OPEN           ✓        ✓        ✓
IN_PROGRESS    ✓        ✓        ✓
DONE           ✓        ✓        ✓
```

_Avoid_: State, workflow, phase

**Recurrence**:
An optional schedule attached to a node. It defines a recurring cycle that periodically resets the node's status to Open and recomputes its dates. The domain provides `rollOverForNextOccurrence(Clock)`; a scheduled job finds due nodes and invokes it.
_Avoid_: Repeating, schedule, template

**Status summary**:
A read-time-only aggregate computed from a node's children: counts of done, in-progress, open, and untracked (status-less) nodes. Not stored — derived on each read.
_Avoid_: Roll-up, aggregate status

**Child** / **Parent**:
Relationship terms. A node's children are those nodes whose `parentId` points to it. A node's parent is the node referenced by its `parentId` (always null for roots). "Has children" is a query-backed derived check, not a stored flag.
_Avoid_: Sub-node, descendant
