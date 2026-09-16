# ADR 009: Soft Delete with Cascading Timestamp and Subtree Restore

Status: accepted

## Context

`Node` is an adjacency-list tree (ADR 001), so deleting one node takes an arbitrarily large subtree with it. That is what earns soft delete its keep here — not adapter-level data safety, but undo: the subtree delete is the mistake a user most needs to take back.

Three places in the tracker disagreed about where `deletedAt` lives, because `CONTEXT.md` had no deletion entry to arbitrate between them. Precedent in other repos leans against the adapter-only reading: the dominant shape puts the field on the domain entity and grows the repository port explicit delete and restore methods. Such a method names the end state it wants and reports how many rows moved, so two callers issuing the same delete finish in agreement, where a read-then-write cycle would leave them racing each other's version check. That precedent still stops short of Nesto: it does not cascade, and deleting a parent leaves its children in place. The subtree recursion this ADR needs is therefore designed here rather than adopted, which is where the design risk sits.

Two semantic models were considered, and they turn out to express the same thing. **Deletion by unreachability** stamps only the node deleted and treats a node as deleted when any ancestor carries a stamp — which is how a scoped read path elsewhere makes the children of a deleted parent invisible without a single write to them. **Cascade** writes the stamp down the subtree. The first is the definition; the second materializes it.

## Decision

`Node` carries a nullable `deletedAt` instant and no boolean — deletion is the timestamp's presence, so there is no second source of truth to keep in sync.

Deleting a node stamps its whole subtree with one shared instant, **skipping any node that already carries one**. Restoring clears the stamp on the node and on every node in its subtree carrying that same instant. A node deleted on its own therefore keeps its original stamp, survives an ancestor's deletion and restoration untouched, and stays deleted — restore returns a subtree to exactly the state it was deleted in rather than resurrecting everything beneath it.

The port grows three methods, following that state-flip grain rather than load-mutate-save:

```java
int softDeleteSubtree(NodeId rootId, Instant deletedAt);
int restoreSubtree(NodeId rootId, Instant deletedAt);
Optional<Node> findDeletedById(NodeId id);
```

`restoreSubtree` takes the instant as its **selector**, which puts the same-deletion rule in the signature instead of in application code. `Node` gains no `delete()` mutator, so ADR 007's pure-function mutator shape is untouched and its list of future mutators stands unchanged.

Every other read path filters `deletedAt is null` — one clause, no ancestor walk. `findById` returns active nodes only; `findDeletedById` is restore's private read path and the only one that sees deleted nodes. Creating a child under a deleted parent is rejected: without that guard a live, unreachable node could be created beneath a deleted one, invisible to both the tree and the trash. Restore carries the symmetric rule: it runs on trash members only, so a node whose ancestor is deleted is not restored on its own and cannot surface as a live node beneath a deleted one. Neither rule is enforced by the port signature — `restoreSubtree` clears a child's matching stamp if asked — so both constrain the caller. The rule is recorded here rather than left to the trash screen, which is deferred while the restore operation itself ships.

**Trash** is the deleted nodes with no deleted ancestor — each the restorable unit for its subtree. Membership is derived, not stored, and a node hidden behind a deleted ancestor joins the trash when that ancestor is restored. The listing query and its surface are deferred.

Cascade was chosen over unreachability because of `findById`. A node whose ancestor is deleted must not resolve, so under unreachability the most-used read path needs a recursive ancestor walk on every call. The recursion gets written either way; cascade pays it once per delete and keeps every read at a single clause.

## Consequences

- One transaction modifies many `Node` instances, breaking the one-aggregate-per-transaction guideline deliberately. The precedent's non-cascade obeys it; Nesto's destination requires undoable subtree deletion, so the break is the point rather than an oversight.
- A second write shape joins replace-by-id `save()`: the idempotent state flip, returning a count. Both stay.
- The recursion has two implementations — a recursive query in the JPA adapter, a walk in the in-memory fake — held in agreement by `NodeRepositoryContractTest`. That is what the contract suite is for.
- Restore fidelity rests on the shared instant. Two deletions colliding on one instant would merge into a single restorable unit; at microsecond precision on a single-user app that is accepted rather than guarded with a batch-id column.
- The trash listing is the only **read path** needing an ancestor walk, and it is deferred along with the screen that shows it. Cycle prevention on move needs one too (ADR 001), but that is a per-move check rather than a read, so it does not weaken the argument above: unreachability would have put an ancestor walk on every `findById`.
- Nothing purges, so deleted rows accumulate forever. That is the settled norm in those repos, and it is accepted here.
- `deletedAt` is never overwritten and is only ever cleared by a restore that matches it. Those two invariants are what let a later trash reconstruct every undoable operation from rows written by the first version, with no column and no backfill.
- `Status summary` is unaffected: it counts direct children only, and that read is already filtered.
- The precedent above is cited as direction only — no counts, no names, no quotation — so a reader of this repo cannot check any of it. That is [ADR 012](012-precedent-without-evidence.md)'s decision rather than an omission, and it leaves the agreement-with-precedent argument weaker than it was when this was decided.
