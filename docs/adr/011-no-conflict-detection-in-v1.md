# ADR 011: No Conflict Detection in v1

Status: accepted

## Context

ADR 007 deferred optimistic locking "until a real adapter with concurrent access exists". ADR 010 is that adapter, so the deferral expired — but the question it posed turned out to be the wrong one twice over.

First, it was framed in adapter terms. Whether two saves can clobber each other is a **product** question — your phone and your browser both have a node open, both save; should the second win silently, or say "this changed under you"? Nesto has a web app and a mobile app planned, so the scenario is real. The locking mechanism follows from that answer; it cannot substitute for it.

Second, the obvious mechanism does not work. Four options were sketched as code on [`prototype/64-write-path`](https://github.com/decasamerlo/nesto-backend/tree/prototype/64-write-path) in `nesto-backend`:

- **A** — native upsert, no version column, last write wins.
- **B** — `@Version` on the JPA entity only, never on `Node`.
- **C** — a version on `Node`, the shape other repos use.
- **D** — `updatedAt` used as the concurrency token.

**B detects nothing.** `save()` re-reads the version, so its guard spans the microseconds between that read and the flush rather than the caller's read-modify-write window:

```text
t0  phone  reads node (version 7)
t1  laptop reads node (version 7)
t2  phone  save(): SELECT v7 -> UPDATE WHERE version = 7 -> v8. OK.
t3  laptop save(): SELECT v8 -> UPDATE WHERE version = 8 -> OK. NO CONFLICT.
```

It costs a column, a `SELECT` on every write, and a hand-written `version = version + 1` in every bulk `UPDATE` (`@Modifying` bypasses Hibernate's version bump), and guards only two threads racing inside one adapter — which a single-user app does not have. It is also incompatible with ADR 010's mapper: a mapper-built entity always has a null version, so `isNew()` is always true and every save would `persist()`.

It then emerged that the exposure is far smaller than it first appeared. ADR 001 and the application layer commit Nesto to a use case per operation, so a command carries **intent**, not state: `SetStatusUseCase(nodeId, DONE)` loads the node fresh server-side, mutates, and saves. The client's stale copy never reaches the database. The dangerous window is not "a browser left open since this morning" — it is the overlap between two in-flight requests, and the damage is one field of one node reverting.

## Decision

**Option A.** The write path is a single native upsert — `INSERT … ON CONFLICT (id) DO UPDATE` — with no version column anywhere and no conflict reported. `created_at` is excluded from the `DO UPDATE` set, and the statement carries `WHERE nodes.deleted_at IS NULL` so a save can never mutate a soft-deleted row. Both guards live in the one write path; there is no second write path that could forget them. A zero row count can only mean the row exists and is deleted, so it is thrown on rather than discarded.

**ADR 009's other write-side rule — no node under a deleted parent — is deliberately not in this statement.** It spans two rows, so guards that protect the row being written cannot express it, and folding a parent check into the upsert would cost the zero row count its only meaning. It lives in the application service, which needs no new port to ask it: `findById` returns active nodes only (ADR 009), so a parent that does not resolve is absent or deleted, and either answer rejects the write. The same check covers move, which reaches the identical state by a different path. The newest equivalent across other repos places its guard the same way — the parent's state modelled in the child's own vocabulary, the check in the application service rather than in the repository or the SQL. This is policy at one choke point, not an invariant the database enforces; the concurrent case stays open as [#70](https://github.com/decasamerlo/nesto/issues/70).

`Node` gains nothing. ADR 007 stands unamended, and its deferral now expires on a condition that can actually be observed.

**This decision holds on two conditions, and they are the point of recording it.**

**1. Writes stay intent-shaped.** A coarse "update the whole node" use case, or a `PUT /nodes/{id}` accepting full node state from the client, puts the client's stale copy back on the write path and widens the window from milliseconds to minutes. Either change reopens this ADR and should pull option D in with it. The REST surface is not yet decided, so this is a live constraint on that decision, not a hypothetical.

**2. A node created under a subtree being concurrently deleted can survive as a live orphan.** Knowingly accepted — see [#70](https://github.com/decasamerlo/nesto/issues/70). No write-path option closes it: conflict detection guards one row against another edit of the same row, and this anomaly spans two rows. The trigger to revisit is a second concurrent user, not a bigger tree.

## Considered Options

**D — `updatedAt` as the concurrency token** is the option to reach for if condition 1 breaks. `Node` already carries `updatedAt`, and ADR 007 already guarantees it is stamped on every effective change and left untouched on a no-op — precisely a version counter's contract. The guard becomes `WHERE id = :id AND updated_at = :expected AND deleted_at IS NULL` in the same single write path, with the expected value taken from the use case's own load, so it covers the whole read-modify-write window that B misses. Immutability supplies the before-image for free: the loaded instance survives the mutation.

Its cost is the port splitting `save` into `create` + `update`, a zero row count that cannot distinguish "changed" from "deleted" from "never existed", and indistinguishable changes within the same microsecond — the trade ADR 009 already accepted for the shared deletion instant.

**C — a version on `Node`** is what other repos do, and it was rejected on the grounds that put this question here in the first place. It adds a field that exists for no domain reason; every mutator, the four that exist and the several ADR 007 says are coming, must remember `version + 1` — the same class of forgettable rule as a remembered `WHERE`, relocated into the domain; it brings the precedent's documented mapper off-by-one; and it obliges every bulk `UPDATE` to hand-bump the column. It buys the same detection D buys for none of that.

## Consequences

- The port keeps `void save(Node)`. No `NodeChangedUnderYou`, no 409, and commands in the application layer — ADR 008, reserved by [#19](https://github.com/decasamerlo/nesto/issues/19) and not yet written — carry no expected-token parameter.
- The parent guard is not in `NodeRepositoryContractTest`. It is an application-layer rule, exercised against the in-memory fake port with no Spring context, which keeps the repository a dumb store and the contract suite about storage.
- **Moving to D later needs no data migration.** `updated_at` is written from day one either way; A simply does not read it. The change is splitting a port method, adding a parameter, and checking a row count.
- One invariant keeps that door open: `updated_at` must always reflect the last effective change to a node's content, stamped by the domain. ADR 007 guarantees it and nothing here threatens it. Note `softDeleteSubtree` does not touch `updatedAt` — deletion is guarded by `deleted_at` instead — so `updatedAt` is a domain timestamp, not a row-audit timestamp. That is what makes it usable as a domain-level token.
- The change is cheapest now and never cheaper again: adding D later means touching every use case that writes, and today there are almost none. By the time it is wanted, the move, status, date and restore use cases all exist.
