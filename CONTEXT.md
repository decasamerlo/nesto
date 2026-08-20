# Nesto

A personal list-of-lists app for capturing any hierarchical structure (todos, shopping lists, recipes, ideas, exercise logs, diaries) organized as a tree of recursively composable nodes.

## Language

**Node**:
The single domain entity in Nesto. A node has a name, plus an optional description, status, dates, and recurrence rule, a nullable parent, and a position among its siblings.
_Node mutations_: renaming a node or setting a value it already holds is a no-op; `updatedAt` is stamped only on effective change.
_Avoid_: List, item, task, entry

**NodeId**:
An opaque identifier for a node. Any value is accepted as long as it is present and not blank; the format is never validated, so migrated (non-ULID) ids keep working.
_Avoid_: ID, key

**Root**:
A node with `parentId == null`. A user's top-level view shows all root nodes.
_Avoid_: Workspace, dashboard, home, inbox

**Position**:
An integer that orders siblings. A node's position is supplied by its creator (the creation use case); the entity itself does not compute or assign it. Gaps are allowed, and no two siblings may share a position. Reindexing shifts only the minimum necessary siblings.
_Avoid_: Order, sort index, rank

**Status**:
An optional lifecycle state on a node: `OPEN`, `IN_PROGRESS`, or `DONE`. Every transition in the matrix below is valid. Giving a status-less node a status is opt-in: the first mutation jumps straight to the chosen state, never through a `null → OPEN` intermediate.

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
An optional schedule attached to a node. It defines a recurring cycle that periodically resets the node's status to OPEN and recomputes its dates. The domain provides `rollOverForNextOccurrence(Clock)`; a scheduled job finds due nodes and invokes it.
_Avoid_: Repeating, schedule, template

**Status summary**:
An aggregate computed from a node's children on each read: counts of DONE, IN_PROGRESS, OPEN, and untracked (status-less) nodes. Never stored.
_Avoid_: Roll-up, aggregate status

**Child** / **Parent**:
Relationship terms. A node's children are those nodes whose `parentId` points to it. A node's parent is the node referenced by its `parentId` (always null for roots). "Has children" is a query-backed derived check, not a stored flag.
_Avoid_: Sub-node, descendant
