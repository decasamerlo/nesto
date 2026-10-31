# ADR 014: The Backend Module Layout

Status: accepted

## Context

[ADR 010](010-node-persistence-seam.md) gave the backend's adapters a Gradle module per hexagonal direction, `:persistence` now and `:api` later, and [ADR 008](008-application-layer.md) gave the application services an `:application` module. Both chose modules so that the compiler would guard a boundary. ADR 010 weighed the alternative, an ArchUnit rule, "a string pattern over package names", and concluded: "Compile errors do not drift." Neither module is on nesto-backend's `main` yet. `:persistence` is in [decasamerlo/nesto-backend#24](https://github.com/decasamerlo/nesto-backend/pull/24), and `:application` in [decasamerlo/nesto-backend#27](https://github.com/decasamerlo/nesto-backend/pull/27), stacked on it.

A module per layer costs two things, and the first has already shown up in the code.

**It repeats an adapter's category, or drops it.** ADR 010 names its modules for direction, but `:persistence` and `:api` are categories: each names what its adapters do. A package inside such a module either repeats the category, as in `persistence/…/adapter/out/persistence/postgresql/`, or leaves it out. Leaving it out has already split the two implementations of `NodeRepositoryPort`. The in-memory fake sits in `dev.nesto.adapter.out.persistence`, which names a category and no implementation, and decasamerlo/nesto-backend#24's adapter sits in `dev.nesto.adapter.out.postgresql`, which names an implementation and no category.

**It adds a module per category.** Each new kind of adapter brings its own build file and its own place in the module graph.

## Decision

**Two Gradle modules, `:core` and `:app`.**

- `:core` holds the domain, the ports and the application services, in `dev.nesto.domain`, `dev.nesto.port.in`, `dev.nesto.port.out` and `dev.nesto.application`. Its compile classpath carries Lombok and no framework or database, and it depends on no other module.
- `:app` holds every production adapter, the composition root and the Spring Boot application. It depends on `:core` alone, and nothing depends on it.

The in-memory fake is a test fixture, not a production adapter. It stays in `:core`'s test fixtures, where the contract suite and the application services' tests reach it without Spring.

**What stays with the compiler.**

- No framework reaches the domain, the ports or the application services. This is the guarantee ADR 008 and ADR 010 both protect, and all three layers sit in `:core`, whose classpath has no framework to import.
- `:core` depends on no other module, so nothing in it can reach an adapter or the composition root. The hexagon's inward dependency rule stays a compile error.

**What moves to ArchUnit: the boundaries inside each module.** Five rules, as tests in `:app`, on `com.tngtech.archunit:archunit-junit6` 1.5.1, the latest release when this was written: the artifact ArchUnit [1.5.0](https://github.com/TNG/ArchUnit/releases/tag/v1.5.0) added for JUnit 6, which the backend runs. Java 25 class files need [1.4.1](https://github.com/TNG/ArchUnit/releases/tag/v1.4.1) or later.

```java
// 1. The domain depends only on itself, the JDK and Lombok
classes().that().resideInAPackage("dev.nesto.domain..")
    .should().onlyDependOnClassesThat()
    .resideInAnyPackage("dev.nesto.domain..", "java..", "lombok..");

// 2. The ports depend on no application service
noClasses().that().resideInAPackage("dev.nesto.port..")
    .should().dependOnClassesThat().resideInAPackage("dev.nesto.application..");

// 3. An adapter depends on no application service
noClasses().that().resideInAPackage("dev.nesto.adapter..")
    .should().dependOnClassesThat().resideInAPackage("dev.nesto.application..");

// 4. An adapter depends on no adapter of another category
slices().matching("dev.nesto.adapter.(*).(*)..").should().notDependOnEachOther();

// 5. Every class sits in a package the rules name
classes().that().resideInAPackage("dev.nesto..")
    .should().resideInAnyPackage(
        "dev.nesto", "dev.nesto.domain..", "dev.nesto.port.in..", "dev.nesto.port.out..",
        "dev.nesto.application..", "dev.nesto.adapter.[in|out].*.*..");
```

- **Rule 1** allows what [buckpal's domain rule](https://github.com/thombergs/buckpal/blob/master/src/test/java/io/reflectoring/buckpal/DependencyRuleTests.java) allows: the domain's own package, the JDK and Lombok. With rule 2, it takes over what ADR 008's `:application` → `:core` edge enforced, so neither the domain nor a port can reach an application service. It also guards ADR 008's "Only application services call ports", which nothing guarded before: a domain service importing a port fails it. On nesto-backend's `main` the domain imports only `java.time`, `java.util` and `lombok`, so the rule holds from its first run.
- **Rule 3**: an adapter reaches an application service through a driving port only. ADR 008 and ADR 010 had the adapter modules' classpath enforce this.
- **Rule 4**: a slice is a direction and a category, so the REST adapter imports no `NodeEntity`. That is the boundary ADR 010 split its modules by direction to protect. A new category is a new slice, covered without editing the rule. Written for `adapter.in` alone, the rule would match nothing until the REST adapter exists, and fail.
- **Rule 5**: `dev.nesto`, without `..`, is that package alone, which holds the composition root. `adapter.[in|out].*.*..` requires a direction, a category and an implementation, so an adapter package that leaves one out fails the rule.

**The rules are written by hand**, not with ArchUnit's `onionArchitecture()`, under which "Adapters can use both the items of the `domain` as well as the `application` packages" ([user guide](https://github.com/TNG/ArchUnit/blob/main/docs/userguide/008_The_Library_API.adoc)). Rule 3 forbids that.

**Drift, in both directions.** ADR 010 named the trigger for this record itself: ArchUnit "becomes worth adding if `:api` and `:persistence` ever merge into one module", and here they merge into `:app`. ADR 010's worry was a rule drifting out of step with the classes it describes. That can happen two ways, and the rules close both.

- **A rule that matches nothing.** A renamed package would leave a rule checking no class, and passing. By default ArchUnit "will forbid the should-part of rules to be evaluated against an empty set of classes" ([user guide](https://github.com/TNG/ArchUnit/blob/main/docs/userguide/010_Advanced_Configuration.adoc)), so the rule fails instead. No rule here calls `allowEmptyShould`, and the default stays on: precedent elsewhere turned it off, and then needed a separate guard against rules that examined nothing.
- **A class that no rule matches.** A class outside every pattern is invisible to the rules about its role. An adapter in `dev.nesto.web` that imports an application service and `NodeEntity` passes rules 3 and 4, and rule 5 fails it. Rule 5 also fails a composition root moved under `adapter`. Rule 3 fails that root too, because it builds the services it exists to build, but rule 5 is the one that names the actual fault, its package.

**Adapter packages: `adapter.{in,out}.{category}.{implementation}`.** The category says what the adapter does, and the implementation says which one it is. The implementation is written even when only one exists, so a second never moves the first.

| Adapter | Package, under `dev.nesto` |
| --- | --- |
| decasamerlo/nesto-backend#24's Postgres adapter | `adapter.out.persistence.postgresql` |
| The in-memory fake, in `:core`'s test fixtures | `adapter.out.persistence.inmemory` |
| The REST adapter, when it comes | `adapter.in.web.rest` |
| ADR 010's second database | `adapter.out.persistence.mongodb` |

The REST adapter's category is web, and its implementation is the protocol [ADR 002](002-rest-over-graphql.md) chose, so a GraphQL adapter would be `adapter.in.web.graphql`.

**The composition root is the package `dev.nesto`, in `:app`.** `NestoApplication` is the `@SpringBootApplication` class, and `ApplicationServiceConfiguration` holds the `@Bean` methods that build the application services, as ADR 008 asks. Configuration that belongs to one adapter stays in that adapter's package. `dev.nesto` sits above every adapter, where Spring Boot [recommends](https://docs.spring.io/spring-boot/reference/using/structuring-your-code.html) the main application class go, and a test slice such as `@DataJpaTest` [searches up](https://docs.spring.io/spring-boot/reference/testing/spring-boot-applications.html) from the test's package until it finds it.

**This reverses two decisions in ADR 010 and one in ADR 008.** In ADR 010, the modules per direction, and its adapter's package, `dev.nesto.adapter.out.postgresql`. Every other decision in it stands. In ADR 008, the `:application` module, with its rejected option "The service in `:core`". Its other decisions stand, the application service's freedom from frameworks among them: the service moves into `:core`, which carries no framework either.

**Neither ADR is superseded.** Each keeps `Status: accepted`, and takes an amendment entry and a marker on each passage this record reverses. That narrows [ADR 013](013-marking-post-acceptance-change.md), whose "a reversal produces a new ADR and leaves the old one superseded" now holds when the whole ADR is reversed. [adr.md](../conventions/adr.md#reversing-one-decision) has the rule for one decision among several.

## Considered Options

**ADR 010's adapter modules**: a module per direction. Every boundary between adapters would be a compile error. Rejected for the two costs in Context: each category of adapter becomes a module, and its packages either repeat the category or drop it, as they already do.

**ADR 008's `:application` module, beside `:core` and `:app`.** The compiler would keep guarding the `:application` → `:core` edge. ADR 008 rejected the service in `:core` because "ADR 010 already chose the compiler", and this record reverses that choice. Once the composition root and the adapters share `:app`, `:app` has to see the application services, so the compiler can no longer stop an adapter from reaching one. Rule 3 is needed whether or not the module exists. What the module still guards is the inward edge, which rules 1 and 2 hold, so it would cost a module and buy nothing the rules don't already guard.

**One module**, as [buckpal](https://github.com/thombergs/buckpal) has, and as other repos have per bounded context. It saves a build file and puts every boundary in ArchUnit. Rejected: it leaves the domain's freedom from frameworks to tests that must run, and that freedom is what ADR 008, ADR 010 and [domain-layer-isolation.md](../conventions/domain-layer-isolation.md) all rest on. A second module keeps it on the classpath.

**The composition root in a module of its own.** Precedent elsewhere keeps each deployable's composition root in a module apart from the code it wires, so that one deployable can host several bounded contexts. Nesto has one bounded context, as ADR 010 notes, and one deployable, so the split would buy nothing yet.

## Consequences

- decasamerlo/nesto-backend#24's adapter, its tests and its Liquibase changelog go into `:app`, the changelog at `app/src/main/resources/db/postgresql/changelog/`.
- `NodeApplicationService` goes into `:core`'s `dev.nesto.application`, and no `:application` module is created. Its tests run as ADR 008 has them, on the in-memory fake with no Spring context.
- That `:core` carries no framework is checkable: `./gradlew :core:dependencies --configuration compileClasspath` lists Lombok alone.
- The five rules land with decasamerlo/nesto-backend#27, the change that takes the application layer's boundary off the classpath, and each is run red against the break it forbids before it lands.
- A break in a boundary ArchUnit guards shows at test time, not at compile time: the code compiles, and the build fails on `:app`'s tests. The backend's CI runs `./gradlew build` as a required check, so the break still stops a merge.
- The precedent above is cited as direction only, so a reader cannot audit it. [ADR 012](012-precedent-without-evidence.md) records why.

## Amendments

- **2026-10-31** — corrected: the rules run on `archunit-junit6`, not `archunit-junit5` ([#122](https://github.com/decasamerlo/nesto/pull/122)).
