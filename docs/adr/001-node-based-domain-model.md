# ADR 001: Self-Referential Node Type

Status: accepted

## Context

A list-of-lists app needs to represent nested structures: todos, shopping lists, exercise logs, recipes, ideas. The obvious approach is two distinct types — `List` (a container) and `Item` (a leaf) — or a `type` column distinguishing them.

## Decision

A single self-referential `Node` type replaces both. "List-ness" is derived: a node with children renders as a list; a node without children renders as an item. Conversion is automatic — adding a child makes a node a list, removing the last child makes it an item again.

The domain `Node` holds only a `NodeId parentId` value, not object references. "Get children" is an explicit repository call, not a traversable property.

## Consequences

- No polymorphic dispatch or type-checking in the domain layer.
- The domain never solves a graph-loading problem — hierarchy queries stay in the repository.
- All fields persist regardless of list/item state; the UI hides or shows fields based on derived state.
- Reordering and reparenting are unified into a single `MoveNodeUseCase` — "reorder" is just the case where `newParentId == currentParentId`.
