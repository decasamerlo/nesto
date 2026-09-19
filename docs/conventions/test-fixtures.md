# Test Fixtures

A fixture decides what an assertion is able to prove. An assertion over a field the fixture never populated is **vacuous**: it passes whether or not the code is correct, and reads exactly like one that means something.

The bar: for every field a test asserts on, name the mutant the fixture would kill. If no mutant comes to mind, that field is unguarded.

Each rule below was found by a mutant that survived a green suite.

## A comparison guards only the fields the fixture populates

`usingRecursiveComparison()` looks like it covers everything. It covers what is there. If every node in a suite is built by a factory that leaves `status` null, then a comparison of two such nodes checks `null` against `null` on that field, in every test, forever.

The failing case: soft delete rebuilds a node to stamp `deletedAt`. Dropping `status` and `completedAt` from that rebuild kept the whole suite green, because the only test asserting "restored to exact prior state" compared nodes that had never carried either field.

**In practice:** a field is guarded when some fixture sets it to something other than its default. Adding a nullable field to an entity therefore means revisiting the fixtures, not only the tests.

## Fields that must stay distinct need distinct values

Two fields holding the same value are indistinguishable, so any code that swaps them compares equal. This matters most for same-typed neighbours — several `Instant`s in a row is the usual case.

The failing case: a fixture built its node with `withStatus(…, NOW)`, and `NOW` was already the creation instant. That left `createdAt`, `updatedAt` and `completedAt` all holding one value, and code feeding the wrong one into the rebuild passed. A different instant killed it.

**In practice:** give each timestamp in a fixture its own value. Some collisions are forced by the code — a mutator that stamps two fields from one argument makes those two equal whatever you pass.

## Name a constant for what it holds

Two kinds of constant, two naming schemes:

| Kind | Name | Example |
| --- | --- | --- |
| A clock reading handed to an operation | ordinal | `repository.softDeleteSubtree(id, LATER)` |
| A pre-existing field value injected into a factory | role | `Node.reconstitute(…, DELETED_AT, DONE, COMPLETED_AT)` |

An operation names the role itself, so a role-named constant says it twice — and starts lying the moment the same value serves a second operation. A positional factory argument names nothing, so there the constant is the only thing telling a reader which slot it fills.

A clock reading resists a role name, because it rarely maps to one field: an instant passed to a creation factory becomes both `createdAt` and `updatedAt`, and one passed to a status transition becomes both `updatedAt` and `completedAt`. Naming it after either is wrong half the time.

**In practice:** a file that builds its state only through operations needs no role-named constants at all. A file that injects state directly needs both kinds, and which is which follows the table.

## Why

A test suite is a claim about what the code may not do. A fixture too sparse to distinguish right from wrong makes that claim vacuous, and the suite still reports green — so nothing tells you. The mutant is what tells you.
