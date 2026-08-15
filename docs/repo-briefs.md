# Repo Briefs

Stacks live in the root [AGENTS.md](../AGENTS.md) table. This file carries what the table can't: how each repo is shaped inside, and which one owns a change.

## backend (nesto-backend)

Self-referential `Node` domain model — a recursive tree where tasks and lists are the same type. Postgres + Flyway behind a REST API.

Strict domain-layer isolation: all business logic is unit-testable with zero Spring context and zero DB. If a change needs Spring to test it, it belongs in an adapter, not the domain.

Full context: [backend/AGENTS.md](../backend/AGENTS.md)

## web (nesto-web)

Consumes the backend REST API. Mirrors the backend's explicit layers — API client and hooks stay separate from presentational components.

Full context: [web/AGENTS.md](../web/AGENTS.md)

## mobile (nesto-mobile)

Port of the web app to iOS/Android.

Full context: [mobile/AGENTS.md](../mobile/AGENTS.md)

## Who owns a change

- API contract change → backend first; web and mobile follow.
- Anything both web and mobile need → decide in the meta-repo, don't fix it twice downstream.

## How changes land

Opening, merging, or reviewing a PR in any repo? Read [stacked-prs.md](conventions/stacked-prs.md) first: stacked squash-merged PRs, owner-approval gate, fork flow.
