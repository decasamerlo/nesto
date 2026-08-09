# ADR 002: REST over GraphQL

Status: accepted

## Context

A list-of-lists app with a nested tree structure. GraphQL is a natural fit for tree-shaped data — its graph traversal model matches the domain, and it solves the N+1 problem of recursive queries.

## Decision

Use REST, not GraphQL. GraphQL's benefits — flexible querying for many differing clients — don't apply here: a single frontend, predictable access patterns, and the adjacency-list storage already handles N+1.

## Consequences

- No GraphQL schema, resolvers, or query complexity analysis.
- The API surface maps directly to use cases (`CreateNode`, `MoveNode`, `ListChildren`).
- Adding a second client (mobile) won't require rethinking the API strategy.
