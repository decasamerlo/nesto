# ADR 010: The Node Persistence Seam

Status: accepted

## Context

`Node` is immutable (ADR 007): all fields final, constructor private, no no-arg constructor, and `reconstitute()` is the only door back in from storage. `backend/core` is a plain `java-library` with no Spring and no database on its compile classpath. ADR 009 then grew the port three subtree operations. Nothing had yet decided what the adapter on the other side of that port looks like.

Three pressures made it urgent. `reconstitute()` takes seven positional arguments today and reaches eleven once `status`, `dueDate`, `completedAt` and `deletedAt` land — **five of them `Instant`**, two more `String`, so seven of eleven positions are silently swappable and a mistake compiles. ADR 009's cascade needs a subtree walk in SQL that no existing read path resembles. And ADR 001 and ADR 009 contradict each other on recursion: ADR 001 rejected recursive CTEs partly because they have "no Spring Data JPA support", while ADR 009's Consequences assume "a recursive query in the JPA adapter".

A survey of sibling implementations in other repos informed every choice below; where this ADR departs from that precedent it says so.

## Decision

**Two models.** A separate `NodeEntity` — a mutable JPA bean — in package `dev.nesto.adapter.out.postgresql`, mapped to and from the immutable `Node`. Annotating `Node` directly would mean dropping `final` from every field and pulling `jakarta.persistence` into `core`, trading ADR 007's central guarantee for one saved class. A separate entity class is likewise the norm in other repos.
— *Reversed by [ADR 014](014-backend-module-layout.md), the package only: it is `dev.nesto.adapter.out.persistence.postgresql`.*

**Modules are named by hexagonal direction, not by technology.** A new `:persistence` module now; `:api` later, depending only on `:core` and never on `:persistence`. The technology lives in the package name, where hexagonal wants it; a second database would be `adapter/out/mongodb` inside `:persistence`.
— *Reversed by [ADR 014](014-backend-module-layout.md): the backend has two modules, `:core` and `:app`, and every production adapter sits in `:app`. A package names the adapter's category and its implementation, so a second database would be `adapter.out.persistence.mongodb`.*

The alternative — a Gradle module per adapter technology — is a minority pattern in other repos and was not repeated; the newest code there went the package route. More to the point, a technology-named module cannot express the in/out boundary, which is the boundary that matters here: it is what stops the REST layer importing `NodeEntity`. Splitting by direction makes that a compile error. The alternative way to buy that guarantee is an ArchUnit rule — a string pattern over package names, asserted in CI — and precedent elsewhere shows such patterns drifting out of step with the classes they describe. Compile errors do not drift.
— *Reversed by [ADR 014](014-backend-module-layout.md), the case for the compiler: an ArchUnit rule in `:app` stops the REST layer importing `NodeEntity`, and ADR 014 says how its rules are kept from drifting in either direction.*

**A snapshot record, and a hand-rolled mapper.** `Node.reconstitute(NodeSnapshot)`, where `NodeSnapshot` is a record in `core`'s domain package carrying the full persisted state. `NodePersistenceMapper` is a plain class, not MapStruct.
— *Reversed during [#14](https://github.com/decasamerlo/nesto/issues/14), the snapshot only: there is no `NodeSnapshot`, and the mapper calls the positional `reconstitute`. A record's canonical constructor takes the same arguments in the same order, so the snapshot would have moved the swap hazard to every place that builds one rather than removed it. The mapper is still a plain class.*

This takes the minority shape from other repos, where positional `reconstitute` dominates. Which shape a module uses there is local convention rather than a function of argument count — a factory with more arguments than any that switched stayed positional, the aggregate carrying the most state was written with a snapshot from its first commit rather than refactored into one, and the most recently added aggregate is positional. So no threshold is being followed here; a hazard is being answered, and that hazard is type *collision*. Five adjacent `Instant`s are more dangerous than a longer list of distinct types — a swapped `dueDate`/`completedAt` compiles and ships. Notably, the hand-rolled mappers in those repos are the snapshot-based ones: for one entity, MapStruct's annotation processor is pure build overhead.
— *Reversed during [#14](https://github.com/decasamerlo/nesto/issues/14), with the snapshot above: `reconstitute` stays positional. The case against MapStruct stands.*

**A third option answers the same hazard more directly, and is not taken here.** Giving each timestamp its own type — so that no two adjacent parameters share one — makes a mis-ordered rebuild fail to compile rather than fail a test, and it is what the dominant practice in comparable public projects does instead of reaching for a snapshot. It is set aside because it is a domain-wide change rather than a persistence-seam one, and because it composes with this decision instead of replacing it: typed fields answer swappability, the snapshot keeps `reconstitute`'s signature from growing. Tracked separately.
— *Reversed during [#14](https://github.com/decasamerlo/nesto/issues/14): typed timestamps are the remedy rather than a complement, and [#94](https://github.com/decasamerlo/nesto/issues/94) tracks them. The snapshot would have kept `reconstitute`'s own signature fixed and moved its growth to the record's constructor, which every caller writes positionally.*

**`parent_id` is a plain `String` column.** No `@ManyToOne`, no `@OneToMany` — matching ADR 001 ("holds only a `NodeId parentId` value, not object references") and matching a precedent that models such links as plain id columns.

**`parent_id` also carries a foreign key to `node(id)`**, `fk_node_parent_id`, with no `ON DELETE`. The paragraph above says how the column is mapped, not whether the database checks it, and [#14](https://github.com/decasamerlo/nesto/issues/14)'s acceptance criteria asked for the check. Without it, a node could name a parent that never existed and no read would notice: `listRoots` reads `parent_id IS NULL`, and `listChildren` of an unknown id is empty, so the node would be reachable from nowhere. Nesto deletes with an `UPDATE`, so the key never meets a delete, and a deleted parent is still a row it accepts. `save()` therefore rejects a node whose parent row does not exist, the in-memory fake refuses it too, and `NodeRepositoryContractTest` pins both. The rule [ADR 011](011-no-conflict-detection-in-v1.md) keeps out of the repository, no node under a *deleted* parent, is the application service's, and [#76](https://github.com/decasamerlo/nesto/issues/76) owns it: the suite's `should accept child under deleted parent` pins that the repository does not enforce it.

**Reads are filtered declaratively.** `@SQLRestriction("deleted_at IS NULL")` on `NodeEntity` implements ADR 009's "every read path excludes deleted nodes" once, structurally, including query methods written years from now by someone not thinking about deletion. The alternative — a `…AndDeletedAtIsNull` suffix on every derived query — is the dominant approach in other repos and makes the invariant a discipline instead of a property. One forgotten suffix leaks deleted nodes.

**The three operations that must see deleted rows are native**, because `@SQLRestriction` is not applied to native SQL: `softDeleteSubtree`, `restoreSubtree`, and `findDeletedById`. That is the whole inventory of hand-written SQL on the read side.

**The subtree operations are recursive CTEs** — `WITH RECURSIVE` plus a guarded `UPDATE`, one atomic statement each, returning the affected row count the port already asks for. The in-memory fake keeps an iterative walk, so ADR 009's two independent implementations held in agreement by `NodeRepositoryContractTest` survive.

This resolves the ADR 001 / ADR 009 contradiction in ADR 009's favour. ADR 001's reason is true of Spring Data *derived* queries and not of `@Query(nativeQuery = true)`; its decision to store hierarchy as an adjacency list stands unchanged, and `listChildren` remains a single `WHERE parent_id = ?`. The CTE is confined to the two subtree writes.

**No `@SQLDelete`.** It fires on `deleteById()` with no way to pass an `Instant`, so it would have to use the database clock — and ADR 009 makes the caller-supplied shared instant the restore selector. Precedent elsewhere additionally records that `@SQLDelete` collides with an optimistic-lock check. Deletion is a named port operation, not an override.

**Migrations are Liquibase YAML** at `persistence/src/main/resources/db/postgresql/changelog/`, a master plus `001-create-node.yaml`. Liquibase is the dominant choice in other repos. The technology segment is in the path because the changelog stops being portable the moment it reaches for a `jsonb` column or a GIN index; labelling it truthfully costs nothing. **No per-module Postgres schema** — that convention keeps bounded contexts from colliding, and Nesto has one.
— *Reversed by [ADR 014](014-backend-module-layout.md), the module only: the changelog is at `app/src/main/resources/db/postgresql/changelog/`.*

**Adapter tests run against Testcontainers Postgres**, with Liquibase applying the real changelog and `ddl-auto=validate`, so the test asserts that the entity and the migration agree. H2 cannot make that assertion honestly: it would validate against a schema H2 accepted rather than the one Postgres will. Container reuse is not used; a JVM-wide singleton container with `TRUNCATE` between tests does the same job.

**`@Transactional` sits on the Spring Data repository interface** for the `@Modifying` writes, which are not auto-wrapped the way `save()` is, and on the inbound adapter for reads. The application service stays framework-free — a constraint on [ADR 008](008-application-layer.md), the application layer. Bulk updates carry `clearAutomatically = true`; `flushAutomatically` is not used.

## Consequences

- `NodeSnapshot` lives in `core`, so the mapper in `:persistence` builds a `core` type and `core` gains no dependency. `Node`'s constructor stays private and `reconstitute` stays its only door.
  — *Reversed by [ADR 014](014-backend-module-layout.md), the module only: the mapper is in `:app`.*
  — *Reversed during [#14](https://github.com/decasamerlo/nesto/issues/14): there is no `NodeSnapshot`. The mapper builds `Node` through the positional `reconstitute`, the constructor stays private, and `reconstitute` stays its only door.*
- `reconstitute`'s signature stops growing. Adding a field changes the record and the mapper, and no call site's argument order.
  — *Reversed during [#14](https://github.com/decasamerlo/nesto/issues/14): with `reconstitute` positional, each new field adds a parameter, and every call site changes.*
- `:persistence` has no Spring Boot application class of its own, so `@DataJpaTest` needs a test-only `@SpringBootConfiguration`.
  — *Reversed by [ADR 014](014-backend-module-layout.md): the adapter's tests sit in `:app`, with the Spring Boot application class, `NestoApplication`, which [#103](https://github.com/decasamerlo/nesto/issues/103) adds. Until it does, `@DataJpaTest` still needs a test-only one.*
- ArchUnit is not needed yet: every boundary that matters is a classpath fact. It becomes worth adding if `:api` and `:persistence` ever merge into one module.
  — *Reversed by [ADR 014](014-backend-module-layout.md): the adapters merge into `:app`, the trigger named here, and seven ArchUnit rules and an allow-list per adapter category, in `:app`, guard the boundaries that stopped being classpath facts, and ADR 008's "Only application services call ports", which never was one.*
- `findById` must not resolve a deleted node, by whatever mechanism — ADR 009 decided that, and the contract test asserts it rather than discovering it. Whether `@SQLRestriction` applies to `find()` by primary key decides only whether this adapter gets it for free or needs its own clause, which the adapter test settles: the contract suite runs against the in-memory fake too, so it cannot see the annotation at all.
- The adapter owns exactly four hand-written statements: two subtree CTEs, `findDeletedById`, and the write path of ADR 011. Everything else is derived queries.
- The survey behind the choices above is cited as direction only, with no counts, names, or quotation. [ADR 012](012-precedent-without-evidence.md) records why; the practical effect is that every "dominant" and "minority" claim here rests on the author's word and cannot be audited from this repo.

## Amendments

- **2026-09-20** — corrected: the surveyed precedent does not reserve a snapshot record for the longest argument lists, and its threshold is not argument count; the typed-parameter option that answers the same hazard is now recorded as considered ([#96](https://github.com/decasamerlo/nesto/pull/96)).
- **2026-10-06** — corrected: the table is `node`, per [database-naming.md](../conventions/database-naming.md), so the changelog is `001-create-node.yaml` ([#98](https://github.com/decasamerlo/nesto/pull/98)).
- **2026-10-31** — reversed by ADR 014: the modules per direction, and the adapter's package. Every production adapter sits in `:app`, in `dev.nesto.adapter.{in,out}.{category}.{implementation}`, and ArchUnit guards the boundaries the modules did. The other decisions stand ([#121](https://github.com/decasamerlo/nesto/pull/121)).
- **2026-11-26** — reversed during [#14](https://github.com/decasamerlo/nesto/issues/14): `Node.reconstitute(NodeSnapshot)`; also recorded the foreign key that issue put on `parent_id`. `reconstitute` stays positional, [#94](https://github.com/decasamerlo/nesto/issues/94)'s typed timestamps are the remedy for the swap hazard, and the other decisions stand ([#148](https://github.com/decasamerlo/nesto/pull/148)).
