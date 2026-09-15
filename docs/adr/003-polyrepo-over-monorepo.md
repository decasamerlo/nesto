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
- Issue-to-commit traceability has to be built deliberately — GitHub's `#N` is repo-local, so a reference crossing a repo boundary resolves only in the qualified `owner/repo#N` form ([docs/conventions/stacked-prs.md](../conventions/stacked-prs.md#referencing-issues)).
- Getting that reference into permanent history takes a `Refs:` commit trailer and a hook to generate it ([docs/conventions/commits.md](../conventions/commits.md#the-refs-trailer)), and both conventions are out of reach of a contributor who clones a sub-repo on its own ([docs/conventions/stacked-prs.md](../conventions/stacked-prs.md#fork-contribution--outside-contributors)).
- Web + mobile could merge into one repo later if shared-code pain justifies it.
