# ADR 001: Self-Referential Node Type

Status: accepted

## Context

A list-of-lists app needs to represent nested structures: todos, shopping lists, exercise logs, recipes, ideas. The obvious approach is two distinct types — `List` and `Item` — or a `type` column.

## Decision

A single self-referential `Node` type replaces both. "List-ness" is derived: a node with children renders as a list; a node without children renders as an item. Conversion is automatic — adding a child makes a node a list, removing the last child makes it an item again.

The domain `Node` holds only a `NodeId parentId` value, not object references. "Get children" is an explicit repository call, not a traversable property.

## Consequences

- No polymorphic dispatch or type-checking.
- The domain never solves a graph-loading problem — hierarchy queries stay in the repository.
- All fields persist regardless of list/item state; the UI hides or shows fields based on derived state.
- Hierarchy is stored as an adjacency list (`parent_id`) — lowest complexity at solo/small-friends scale. A closure table and recursive CTEs (`WITH RECURSIVE`) were rejected: the former adds complexity without need, the latter has no Spring Data JPA support.
- "Has children" is a derived, query-backed check via a repository method, not a stored counter — more correct-by-construction than a manually maintained cache.
- Cycle prevention lives in a domain service, not on `Node` itself — the service receives the ancestor/descendant chain to check.
- Ordering is a domain concern: `Node` carries its own `position` field, domain rules enforce no duplicate positions among siblings. Reindexing (shifting siblings on insert/delete/reorder) is hand-rolled — no `acts_as_list` equivalent in Java.
- Move is a single use case, not two: `MoveNodeUseCase(nodeId, newParentId, newPosition)`. "Reorder" is the special case where `newParentId == currentParentId`.
