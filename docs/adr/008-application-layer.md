# ADR 008: The Application Layer

Status: accepted

## Context

`backend/core` holds the domain and one driven port, `NodeRepositoryPort`, and nothing sits above them. The first operation that needs a layer there, setting a node's status, is also the one every later operation copies: create and move ([#76](https://github.com/decasamerlo/nesto/issues/76)), dates ([#22](https://github.com/decasamerlo/nesto/issues/22)), delete and restore ([#104](https://github.com/decasamerlo/nesto/issues/104)). Whatever it does about where a use case lives, what it is called, what it takes and returns, where its clock comes from and how it fails, they will repeat.

Three records already constrain the layer without describing it. [ADR 001](001-node-based-domain-model.md) commits to a use case per operation (`MoveNodeUseCase`). [ADR 010](010-node-persistence-seam.md) keeps the application service framework-free and leaves transactions at the adapter. [ADR 011](011-no-conflict-detection-in-v1.md) holds only while writes stay intent-shaped, says this layer's commands carry no expected-token parameter, and puts [ADR 009](009-soft-delete-with-subtree-restore.md)'s parent guard in the application service. ADR 010 and ADR 011 cited this record by number before it existed: [#19](https://github.com/decasamerlo/nesto/issues/19) reserved 008 when ADR 009 was numbered, which is why it is written after 013.

The tracker once proposed `NodeService`, one service per entity, against ADR 001's use case per operation. The dominant shape in the newest code of other repos takes both.

## Decision

**One application service per aggregate, implementing one driving port per operation.** `NodeApplicationService`, in `dev.nesto.application`, implements every use case and query on `Node`. That keeps ADR 001's promise, since callers see a port per operation and depend on it rather than on the class, and it gives create and move a single choke point. Both write `parentId`, ADR 011's parent guard has to hold on each, and a rule copied into two services is a rule one of them can forget. Because callers depend on the ports, splitting the service later changes no caller; the trigger to split is a constructor dependency that only some of its operations use.

**Two framework-free modules.** The application service lives in a new `:application` Gradle module that depends on `:core` alone. Neither `:core` (domain and ports) nor `:application` declares a framework dependency, Lombok aside, so both layers are framework-free as a classpath fact: ADR 010 already prefers a compile error to an ArchUnit rule. This extends ADR 010's module list without changing it. The adapter modules, `:persistence` and `:api` later, depend on `:core` only, so the compiler stops an adapter from reaching the service except through a port. Only a composition root sees every module, and none exists yet ([#103](https://github.com/decasamerlo/nesto/issues/103)).
— *Reversed by [ADR 014](014-backend-module-layout.md): there is no `:application` module. The application service lives in `:core`, which stays framework-free, and the adapters sit in `:app` with the composition root, where ArchUnit rules stop an adapter reaching the service except through a port.*

**Driving ports live in `:core`'s `dev.nesto.port.in`**, beside `port.out`.

- A write is a `…UseCase`. Its one method takes a nested `Command` record and returns nothing, or a nested `Result` record when its caller needs data back.
- A read is a `…Query`, and takes its inputs as parameters.
- A nested type is named for its role and written with its port's name in front, `SetNodeStatusUseCase.Command`, because the one class that implements every port sees a `Command` for each.

ADR 001's `MoveNodeUseCase(nodeId, newParentId, newPosition)` reads, under this, as the port and its `Command`'s components. ADR 011's `SetStatusUseCase(nodeId, DONE)` was an illustration: a port carries the aggregate's name, as ADR 001's does, so the first one is `SetNodeStatusUseCase`.

**A port method's prefix says what absence means**, in driving and driven ports alike.

- `find…` returns an `Optional`: absence is an answer the caller handles.
- `get…` returns the value or throws: absence breaks an invariant.
- `list…` returns a `List`, empty when nothing matches.

`NodeRepositoryPort`'s `findRoots` and `findChildren` return lists, so they break the rule today; [#105](https://github.com/decasamerlo/nesto/issues/105) renames them `listRoots` and `listChildren`. The rule is about ports. A Spring Data repository inside an adapter keeps `find…By`, because `list…By` is not a query subject Spring Data accepts.

**The method is named after the operation**: `setNodeStatus`, never `execute`. One service implements every port of its aggregate, so an `execute` on each would leave methods that differ only by parameter type.

**A `Command` validates in its compact constructor** with `Objects.requireNonNull`, as `NodeId` does. Not Bean Validation, which would put `jakarta.validation` on `:core`'s classpath. A missing input is all a `Command` checks. Whether an operation is legal is the domain's question, and for status there is nothing to check, since the matrix is total.

**A `Command` carries intent, never node state, and no expected-token parameter.** ADR 011's first condition is that writes stay intent-shaped; a command carrying a node's fields would break it and reopen ADR 011.

**The application service carries no Spring annotation.** It is a plain class, built by a `@Bean` method in the composition root; `:application` has no Spring to annotate it with. Lombok's annotations are allowed: Lombok sits on the compile classpath only and none of its annotations is visible at runtime, so `@RequiredArgsConstructor` writes the constructor the `@Bean` method calls and leaves a container nothing to find. Where other repos allow Lombok in this layer, the dominant shape draws the same line. Adapters stay annotated and component-scanned. That answers the wiring question [decasamerlo/nesto-backend#24](https://github.com/decasamerlo/nesto-backend/pull/24) left for this layer.
— *Reversed by [ADR 014](014-backend-module-layout.md), the module only: the service sits in `:core`, which has no Spring to annotate it with either.*

**No transaction is opened here, for now.** Each port call is its own transaction, as ADR 010 has it, so `setNodeStatus` runs as two: the load and the save. That widens nothing ADR 011 has not already accepted. The window between them is the overlap of two in-flight requests, and the command carries intent rather than a client's copy of the node. #76's move, the first operation that saves several rows, revisits where the boundary lives.

**ADR 009's two caller rules are this layer's.** No node is created or moved under a deleted parent, checked through `findById`, which ADR 009 restricts to active nodes; ADR 011 places that guard here, and this record does not decide it again. Restore runs on trash members only. #76 enforces the first, #104 the second.

**Only application services call ports.** An application service reads through a port, calls the domain, and writes through a port. A domain service is a pure function handed its data, as ADR 001 already has cycle prevention receive the ancestor chain, and reindexing ([#15](https://github.com/decasamerlo/nesto/issues/15)) is written the same way. The rule also keeps the packages acyclic: `dev.nesto.port.out` imports `dev.nesto.domain`, so a domain service importing a port would make each depend on the other.

**Time comes from an injected `java.time.Clock`.** An application service takes a `Clock` in its constructor, reads `clock.instant()` once per operation, and passes that instant to the domain, so every timestamp one operation writes is the same instant. Tests use `Clock.fixed`. `Clock` rather than the narrower `InstantSource` follows precedent in other repos; the zone it carries goes unused. Which `Clock` production gets, the JDK's with its sub-microsecond digits or one truncated to the microsecond Postgres stores, is #103's to decide and to record here.

**Not found is a `NoSuchElementException` naming the id.** `findById` returns empty for a node that is absent or deleted (ADR 009), and the service throws on either. It catches nothing, so `save`'s `IllegalStateException` for a node deleted between the load and the save (ADR 011) reaches the caller unchanged. The two types differ, so a later mapper can tell "no such node" from "write refused"; a named exception type is [#97](https://github.com/decasamerlo/nesto/issues/97)'s to decide.

**The first use case is `SetNodeStatusUseCase`**, with `Command(NodeId nodeId, Optional<Node.Status> status)`, empty meaning untracked, mirroring `withStatus`. One use case, not one per status value: there is one mutator, and the matrix is total. Its write path is `findById`, then `withStatus(status, clock.instant())`, then `save`. The mutator stamps `updatedAt` and `completedAt` ([ADR 007](007-immutable-node-entity.md)), so the service stamps nothing.

## Considered Options

**A service per use case**, the shape of the public reference implementation [buckpal](https://github.com/thombergs/buckpal). Each class stays small and the split is already made. Rejected for the choke point: create and move would each carry their own copy of the parent guard.

**A write that returns the saved `Node`.** A REST response would need no second read. Rejected: it makes every write a query too, and until #103 settles the clock's precision it can hand back an `updatedAt` the database rounded on the way in. A write whose caller needs data declares a `Result`, which names what it returns.

**The service in `:core`, under its own package.** One module fewer. Rejected: review or an ArchUnit rule would guard the boundary instead of the compiler, and ADR 010 already chose the compiler.
— *Reversed by [ADR 014](014-backend-module-layout.md), which takes this option: ArchUnit rules guard the boundary, and the compiler still keeps every framework out of `:core`.*

## Consequences

- The backend's module graph gains one edge, `:application` → `:core`. That neither module carries a framework is checkable: `./gradlew :core:dependencies --configuration compileClasspath :application:dependencies --configuration compileClasspath`. Gradle binds `--configuration` to the task before it, so each task needs its own.
  — *Reversed by [ADR 014](014-backend-module-layout.md): the graph's one edge is `:app` → `:core`, and the check is `./gradlew :core:dependencies --configuration compileClasspath`.*
- A no-op still saves. `withStatus` returns `this`, and the upsert writes identical values. Nobody should add a skip: `Node.equals` compares `id` alone (ADR 007), so a skip written with `equals` would never save.
- Application-layer tests run against the in-memory fake with `Clock.fixed` and no Spring context, as ADR 011 already has the parent guard tested, and assert fields rather than `Node` equality, for the same `equals` reason.
- `setNodeStatus` runs as two transactions until #76 moves the boundary.
- `NodeRepositoryPort` breaks the prefix rule in two methods until #105 lands.
- The precedent above is cited as direction only, so a reader cannot audit it. [ADR 012](012-precedent-without-evidence.md) records why.

## Amendments

- **2026-10-30** — narrowed the application service's no-annotation rule to Spring annotations: Lombok's, such as `@RequiredArgsConstructor`, are allowed ([#113](https://github.com/decasamerlo/nesto/pull/113)).
- **2026-10-31** — reversed by ADR 014: the `:application` module, and the rejection of the service in `:core`. The application service lives in `:core`'s `dev.nesto.application`, and the other decisions stand ([#121](https://github.com/decasamerlo/nesto/pull/121)).
