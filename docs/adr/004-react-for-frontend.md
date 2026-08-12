# ADR 004: React for Frontend

Status: accepted

## Context

The web frontend needs to mirror the backend's "explicit layers, no magic" discipline while serving three concrete requirements: drag-and-drop (nested tree reordering/reparenting), a near-term mobile app that shares the same language and patterns, and a portfolio/skill-building goal.

Three frontend frameworks were considered: Angular (existing real hands-on experience), Vue 3 (AI-assisted experience from JTech Tasklist), and React (component model liked, real experience limited).

## Decision

Use **React + TypeScript** with **Vite** for the web app, plus the fixed frontend stack:

- **Build tool:** Vite — standard choice for a greenfield React + TS SPA.
- **Drag-and-drop:** `dnd-kit` — mature, accessible (keyboard support built-in), the right fit for nested/tree DnD, the hardest UI problem in this app.
- **Server state / API calls:** TanStack Query — pairs naturally with a REST backend.
- **Client-only state (if needed beyond server state):** Zustand — lightweight, hooks-based.
- **Forms:** `react-hook-form` + `zod` — type-safe validation without ceremony.
- **Component structure:** API clients/hooks separated from presentational components — "explicit layers" instinct, per `docs/conventions/frontend-layer-isolation.md`.
- **Mobile (later):** React Native via Expo, sharing types and API client logic where practical; UI rebuilt natively per platform conventions.

## Drivers

- **Mobile path.** React Native (via Expo) shares language, mental model, and business-logic patterns (hooks, state management, API client, types) with the React web app. Angular's mobile story (Ionic) has a smaller ecosystem and less momentum; Vue Native never gained traction. This is the single biggest factor — without it, the decision is a wash on every other axis.
- **Drag-and-drop.** dnd-kit (fixed in the stack) beat the Angular CDK's genuinely good drag-drop module: CDK is Angular-only, so it doesn't carry over to a React Native mobile app.
- **Learning value.** React is deliberately unopinionated — no built-in router, state management, or forms handling. These are composed from separate libraries, forcing explicit decisions. Same "explicit over magic" preference already reflected in choosing Java/Spring + strict hexagonal architecture over Rails. Not optimizing for implementation speed.
- **Portfolio value.** React is the most in-demand frontend skill in most markets; builds real depth rather than re-banking existing Angular experience.

## Consequences

- React provides no built-ins for routing, state, or forms — each is an explicit, composed choice (stack above); routing remains open until navigation needs are concrete.
- Adding mobile later reuses this React investment rather than requiring a new framework learning phase.
- Angular remains a defensible fallback if banking existing experience matters more than building real React depth, but was not chosen.