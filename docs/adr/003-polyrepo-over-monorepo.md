# ADR 003: Polyrepo over Monorepo

Status: accepted

## Context

Three pieces — Java backend, React web app, React Native mobile — with different lifecycles, tooling, and release cadences. Monorepos (Nx, Turborepo) are the trend for multi-package projects, and web + mobile could eventually share code.

## Decision

Use three separate repositories, not a monorepo. Each repo is an independent git repository with its own history and CI. A meta-repo (`nesto`) ties them together for local development via `mani`.

## Consequences

- Each repo is independently readable — a monorepo forces a reviewer to sift through unrelated code.
- No monorepo tooling (Nx/Turborepo) to configure and maintain, including for a mostly-empty mobile repo.
- The same "explicit boundaries, no leaking concerns" principle applied to the backend's Hexagonal Architecture — the backend shouldn't need to know what's consuming its API.
- Web + mobile could merge into one repo later if shared-code pain justifies it.
