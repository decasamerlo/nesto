# ADR 010: The Node Persistence Seam

Status: accepted

## Context

`Node` is immutable (ADR 007): all fields final, constructor private, no no-arg constructor, and `reconstitute()` is the only door back in from storage. `backend/core` is a plain `java-library` with no Spring and no database on its compile classpath. ADR 009 then grew the port three subtree operations. Nothing had yet decided what the adapter on the other side of that port looks like.

Three pressures made it urgent. `reconstitute()` takes seven positional arguments today and reaches eleven once `status`, `dueDate`, `completedAt` and `deletedAt` land — **five of them `Instant`**, two more `String`, so seven of eleven positions are silently swappable and a mistake compiles. ADR 009's cascade needs a subtree walk in SQL that no existing read path resembles. And ADR 001 and ADR 009 contradict each other on recursion: ADR 001 rejected recursive CTEs partly because they have "no Spring Data JPA support", while ADR 009's Consequences assume "a recursive query in the JPA adapter".

A survey of sibling implementations in other repos informed every choice below; where this ADR departs from that precedent it says so.

## Decision

**Two models.** A separate `NodeEntity` — a mutable JPA bean — in package `dev.nesto.adapter.out.postgresql`, mapped to and from the immutable `Node`. Annotating `Node` directly would mean dropping `final` from every field and pulling `jakarta.persistence` into `core`, trading ADR 007's central guarantee for one saved class. A separate entity class is likewise the norm in other repos.

**Modules are named by hexagonal direction, not by technology.** A new `:persistence` module now; `:api` later, depending only on `:core` and never on `:persistence`. The technology lives in the package name, where hexagonal wants it; a second database would be `adapter/out/mongodb` inside `:persistence`.

The alternative — a Gradle module per adapter technology — is a minority pattern in other repos and was not repeated; the newest code there went the package route. More to the point, a technology-named module cannot express the in/out boundary, which is the boundary that matters here: it is what stops the REST layer importing `NodeEntity`. Splitting by direction makes that a compile error. The alternative way to buy that guarantee is an ArchUnit rule — a string pattern over package names, asserted in CI — and precedent elsewhere shows such patterns drifting out of step with the classes they describe. Compile errors do not drift.

**A snapshot record, and a hand-rolled mapper.** `Node.reconstitute(NodeSnapshot)`, where `NodeSnapshot` is a record in `core`'s domain package carrying the full persisted state. `NodePersistenceMapper` is a plain class, not MapStruct.

This takes the minority shape from other repos, where positional `reconstitute` dominates and a snapshot record is reserved for the longest argument lists. The precedent's threshold is argument *count*; the hazard here is type *collision*, which does not wait for a long list. Five adjacent `Instant`s are more dangerous than a longer list of distinct types — a swapped `dueDate`/`completedAt` compiles and ships. Notably, the hand-rolled mappers in those repos are the snapshot-based ones: for one entity, MapStruct's annotation processor is pure build overhead.

**`parent_id` is a plain `String` column.** No `@ManyToOne`, no `@OneToMany` — matching ADR 001 ("holds only a `NodeId parentId` value, not object references") and matching a precedent that models such links as plain id columns.

**Reads are filtered declaratively.** `@SQLRestriction("deleted_at IS NULL")` on `NodeEntity` implements ADR 009's "every read path excludes deleted nodes" once, structurally, including query methods written years from now by someone not thinking about deletion. The alternative — a `…AndDeletedAtIsNull` suffix on every derived query — is the dominant approach in other repos and makes the invariant a discipline instead of a property. One forgotten suffix leaks deleted nodes.

**The three operations that must see deleted rows are native**, because `@SQLRestriction` is not applied to native SQL: `softDeleteSubtree`, `restoreSubtree`, and `findDeletedById`. That is the whole inventory of hand-written SQL on the read side.

**The subtree operations are recursive CTEs** — `WITH RECURSIVE` plus a guarded `UPDATE`, one atomic statement each, returning the affected row count the port already asks for. The in-memory fake keeps an iterative walk, so ADR 009's two independent implementations held in agreement by `NodeRepositoryContractTest` survive.

This resolves the ADR 001 / ADR 009 contradiction in ADR 009's favour. ADR 001's reason is true of Spring Data *derived* queries and not of `@Query(nativeQuery = true)`; its decision to store hierarchy as an adjacency list stands unchanged, and `findChildren` remains a single `WHERE parent_id = ?`. The CTE is confined to the two subtree writes.

**No `@SQLDelete`.** It fires on `deleteById()` with no way to pass an `Instant`, so it would have to use the database clock — and ADR 009 makes the caller-supplied shared instant the restore selector. Precedent elsewhere additionally records that `@SQLDelete` collides with an optimistic-lock check. Deletion is a named port operation, not an override.

**Migrations are Liquibase YAML** at `persistence/src/main/resources/db/postgresql/changelog/`, a master plus `001-create-nodes.yaml`. Liquibase is the dominant choice in other repos. The technology segment is in the path because the changelog stops being portable the moment it reaches for a `jsonb` column or a GIN index; labelling it truthfully costs nothing. **No per-module Postgres schema** — that convention keeps bounded contexts from colliding, and Nesto has one.

**Adapter tests run against Testcontainers Postgres**, with Liquibase applying the real changelog and `ddl-auto=validate`, so the test asserts that the entity and the migration agree. H2 cannot make that assertion honestly: it would validate against a schema H2 accepted rather than the one Postgres will. Container reuse is not used; a JVM-wide singleton container with `TRUNCATE` between tests does the same job.

**`@Transactional` sits on the Spring Data repository interface** for the `@Modifying` writes, which are not auto-wrapped the way `save()` is, and on the inbound adapter for reads. The application service stays framework-free — a constraint on ADR 008, which [#19](https://github.com/decasamerlo/nesto/issues/19) reserves for the application layer and has not yet written. Bulk updates carry `clearAutomatically = true`; `flushAutomatically` is not used.

## Consequences

- `NodeSnapshot` lives in `core`, so the mapper in `:persistence` builds a `core` type and `core` gains no dependency. `Node`'s constructor stays private and `reconstitute` stays its only door.
- `reconstitute`'s signature stops growing. Adding a field changes the record and the mapper, and no call site's argument order.
- `:persistence` has no Spring Boot application class of its own, so `@DataJpaTest` needs a test-only `@SpringBootConfiguration`.
- ArchUnit is not needed yet: every boundary that matters is a classpath fact. It becomes worth adding if `:api` and `:persistence` ever merge into one module.
- `findById` must not resolve a deleted node, by whatever mechanism — ADR 009 decided that, and the contract test asserts it rather than discovering it. Whether `@SQLRestriction` applies to `find()` by primary key decides only whether this adapter gets it for free or needs its own clause, which the adapter test settles: the contract suite runs against the in-memory fake too, so it cannot see the annotation at all.
- The adapter owns exactly four hand-written statements: two subtree CTEs, `findDeletedById`, and the write path of ADR 011. Everything else is derived queries.
- The survey behind the choices above is cited as direction only, with no counts, names, or quotation. [ADR 012](012-precedent-without-evidence.md) records why; the practical effect is that every "dominant" and "minority" claim here rests on the author's word and cannot be audited from this repo.
