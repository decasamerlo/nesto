# Domain-Layer Isolation

Domain logic must be unit-testable with zero Spring context and zero DB. If a test needs Spring to run, the code under test belongs in an adapter, not the domain.

## What this means in practice

- Domain `Node`, value objects, and domain services carry no `@Entity`, `@Service`, or `@Repository` annotations.
- `MoveNodeUseCase`, cycle prevention, position reindexing, status transitions, and recurrence roll-over all run as plain unit tests — no `@SpringBootTest`, no `TestEntityManager`, no H2.

## Why

A domain rule that needs a database to verify is a rule you can't trust in a unit test suite. Zero coupling to infrastructure makes the hardest logic the fastest to test: tree reindexing, cycle detection, status transitions.
