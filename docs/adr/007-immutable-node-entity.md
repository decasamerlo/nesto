# ADR 007: Immutable Node Domain Entity

Status: accepted

## Context

`Node` was a mutable entity: `rename()` and `changeDescription()` mutated fields in place.

The repository contract tests pin defensive list copies on read — a naive in-memory impl would hand out the live list, and Java's `List` cannot express immutability. But the snapshot is shallow: a caller holding a read result could call `rename()` on it and corrupt stored state without a save. Deep-copying the lists' `Node` elements only makes sense if `Node` itself is immutable.

The mutator surface is about to grow (status transitions, dates, recurrence roll-over, move). Java convention leans mutable (buckpal's `Account`, dddsample-core), and immutable aggregates are a minority pattern (CodelyTV, functional DDD per Wlaschin). The choice needs recording.

## Decision

`Node` is fully immutable. All fields are `final`; the constructor stays private; `create()` is the only factory for new nodes, and a new `reconstitute()` factory rebuilds persisted nodes from explicit timestamps. `rename()` and `changeDescription()` return new `Node` instances, stamping a fresh `updatedAt`; when the change is a no-op they return `this` and leave `updatedAt` untouched. All future mutators (move, status transitions, recurrence roll-over) follow the same pure-function shape.

The repository read methods may return the stored instances directly — no node-level defensive copies are needed. The existing list-level copy contract remains, and the shallow-snapshot caveat disappears by construction. `Node` gets `equals()`/`hashCode()` on `id` only (entity semantics). The write path stays replace-by-id `save()`, with last-write-wins accepted for now — optimistic locking is deferred until a real adapter with concurrent access exists.

## Consequences

- `NodeTest` reshapes: mutation tests assert on the returned instance instead of the receiver; the no-op tests keep their shape (`this` returned, `updatedAt` unchanged).
- The snapshot contract test stays list-only; a node-level snapshot test is no longer expressible (that is the point).
- Persistence, when it arrives, keeps the immutable domain model separate from a mutable persistence model, mapped to/from `Node` via mappers — `reconstitute()` is the mapping target.
- `updatedAt` can never go stale or be forgotten: every state change stamps it inside the pure function.
- Concurrent writes resolve by last-write-wins until a `@Version`-style guard is added with the first real adapter.
