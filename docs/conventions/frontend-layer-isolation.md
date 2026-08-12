# Frontend-Layer Isolation

Frontend components follow the same "explicit layers" discipline as the backend: API clients and hooks stay separate from presentational components.

## What this means in practice

- Data access lives in dedicated modules (API client, hooks) — components receive data via props or hooks, never fetch directly.
- Routing, state, and forms are composed from chosen libraries, not provided by the framework.

## Why

The backend's hexagonal discipline exists for testability and clarity; the frontend keeps the same instinct so logic survives the mobile port (React Native shares hooks and API client patterns, UI is rebuilt).