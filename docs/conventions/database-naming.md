# Database Naming

How Nesto names its relational tables. It governs the schema only. API paths and prose are not affected.

## Tables are singular

**A table is named for one of its rows**, in snake_case with no prefix: `node`. Names that embed the table follow it: `node_pkey`, `fk_node_parent_id`, `idx_node_parent_id`.

**Name every table explicitly.** The Liquibase `createTable` and the entity's `@Table` both state the name. Left implicit, Spring Boot derives the table from the entity class, so `NodeEntity` would map to `node_entity`.

## Why singular

The industry is split, so this is a choice rather than a standard. Rails and Laravel pluralize by default; Hibernate, Django and Prisma name the table after the model. Singular wins here because:

- JPA, this stack's default, names a table after its entity.
- PostgreSQL names its own catalog tables in the singular: `pg_class`, `pg_namespace`, `pg_attribute`.
- It is the dominant approach in the other repos this project draws precedent from.

## Trap — some singulars are reserved words

In PostgreSQL, `user`, `order` and `group` are reserved ([Appendix C](https://www.postgresql.org/docs/current/sql-keywords-appendix.html)), and those are among the most natural singular table names. A reserved name works only double-quoted, and then it has to be quoted everywhere it appears: the changelog, `@Table`, and every native statement.

**When the natural noun is reserved, pick another one**, such as `account` rather than `user` or `purchase` rather than `order`. The identifier then stays unquoted everywhere.
