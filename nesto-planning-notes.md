---
title: Nesto — Planning Notes
date: 2026-08-05
---

# Nesto — Planning Notes

A personal list-of-lists app (todos, shopping lists, exercise/food/diary logs, recipes, ideas, discussions, bullet points), starting solo, later shared with friends.

## App Name

**Nesto** — short, invented word, easy to pronounce/type in both English and Portuguese, distinctive, no dictionary collisions.

## Tech Stack Decision

- **Backend: Java + Spring Boot**, not Ruby on Rails.
  - Reasoning: 8 years of existing Java experience vs zero Rails experience. Faster for *this developer specifically* despite Rails being faster in the abstract. Aligns with existing job-market trajectory. Reuses existing hexagonal architecture discipline.
- **Architecture: Hexagonal Architecture (HA)**, as clean and rigorous as possible — no shortcuts ("gambiarras"/"atalhos"), even where it adds effort.
- **Frontend: React + TypeScript** (decided). Backend is API-first (REST), so this was a deferred decision revisited after initial planning — see "Frontend Stack Decision" section below for full reasoning.


## Frontend Stack Decision

**Decided: React + TypeScript** for web, with **React Native (via Expo)** planned for the eventual mobile app.

### Context / prior experience
- Vue 3 experience exists (JTech Tasklist project) but was almost entirely AI-assisted — limited genuine personal depth built from it.
- Real hands-on experience with Angular.
- Older experience with JSF — considered too outdated, ruled out.
- Liked the idea of React's component model and its relatively direct path to React Native for mobile, though acknowledged a PWA could also cover mobile reasonably well.

### Decision criteria
Nesto needs: drag-and-drop (nested tree reordering/reparenting), an eventual mobile app, personal + close-friends usage, portfolio value, and a strong learning/skill-building goal — explicitly not optimizing for implementation speed, wants the most rigorous codebase without shortcuts.

### Reasoning
- **Drag and drop**: `dnd-kit` (React) is mature, accessible (keyboard support built in), and well-suited to nested/tree drag-and-drop specifically — the hardest UI problem in this app. Angular CDK's drag-drop module is also genuinely good, so this alone wasn't the deciding factor.
- **Mobile path**: React Native (via Expo) shares language, mental model, and business-logic patterns (hooks, state management, API client, types) with the React web app — more real transfer than Angular's mobile story (Ionic), which has a smaller ecosystem and less momentum today.
- **Portfolio value**: React is currently the most in-demand frontend skill in most markets and pairs naturally with a Spring Boot backend as a coherent full-stack story. Angular experience is already "banked" from prior work; building real React depth fills an actual gap rather than duplicating existing skills.
- **Learning value (weighted heaviest)**: React is deliberately unopinionated — no built-in router, state management, or forms handling; these are composed from separate libraries. This forces more explicit understanding and decision-making, mirroring the same "explicit over magic" preference already reflected in choosing Java/Spring + strict Hexagonal Architecture over Rails. Given the stated goal of learning and not caring about time-to-implement, this trade-off fits well.
- Angular remains a defensible alternative if banking existing experience mattered more than building new depth, but was not chosen given the above.

### Concrete stack (for later reference, not yet committed to revisit until needed)
- **Web**: React + TypeScript, Vite as build tool.
- **Drag and drop**: `dnd-kit`.
- **Server state / API calls**: TanStack Query.
- **Client-only state** (if needed beyond server state): Zustand.
- **Forms**: `react-hook-form` + `zod` for validation.
- **Component structure**: apply the same "explicit layers, no magic" instinct used in the Java backend — separate API client/hooks layer from presentational components (not a strict 1:1 mapping to hexagonal architecture, but same spirit).
- **Mobile (later)**: React Native via Expo, sharing types and API client logic where practical; UI rebuilt natively per platform conventions.

## Core Domain Model

### Hierarchy storage strategy
- **Adjacency list** (`parent_id` on the node), not a closure table, to start — chosen for lowest complexity given solo/small-friends scale.
- Closure-table equivalent (hand-rolled `node_hierarchy` join table) considered but deferred — only build if descendant/ancestor query performance actually becomes a problem.
- Alternative considered and rejected for now: recursive CTEs via native queries/jOOQ (Postgres `WITH RECURSIVE`), since Spring Data JPA has no native recursive query support.

### Checking "has children" (no counter cache)
- Explicitly **not** using a stored/manually-maintained counter (`childrenCount`) — decided against Rails-style `counter_cache` pattern.
- Reasoning: a derived, query-backed check (`NodeRepository.hasChildren(NodeId id)` via `COUNT` query) is more correct-by-construction than a manually maintained cache, which risks drifting out of sync if any code path forgets to update it. Revisit only if measured performance requires it.

### Cycle prevention
- Lives in a domain service (e.g., `NodeHierarchyService`), not on `Node` itself — handed the specific ancestor/descendant chain to check rather than the aggregate knowing its own ancestors.

### Ordering (position)
- Confirmed to be a **domain concern**, not a persistence-only detail.
- `Node` carries its own `position` field; reordering is enforced by domain rules (no duplicate positions among siblings, etc.), fully unit-testable without Spring/DB.
- No `acts_as_list`-equivalent gem in Java — reindexing logic (shifting siblings on insert/delete/reorder) is hand-rolled in the application layer.

### Move (reparent + reposition)
- **One use case, not two.** Since the UI dictates exact placement on every move (including drag within the same parent), "reorder" is just the special case of "move" where `newParentId == currentParentId`. Modeled as a single `MoveNodeUseCase(nodeId, newParentId, newPosition)`.
- Internally: validate no cycle → update node's parent/position → close the gap in the old parent's siblings → make room in the new parent's siblings. The reindexing logic is the most invariant-sensitive part of the whole app and deserves the most thorough tests.

## Statuses

- **Status is optional, not universal** — not every node needs one (a recipe, idea, or discussion has no status; a todo, shopping item, or exercise does).
- `Optional<NodeStatus> status` on `Node`, with `NodeStatus` kept deliberately small: `OPEN`, `IN_PROGRESS`, `DONE`.
- No raw setter — controlled domain methods (`markInProgress()`, `markDone()`, `reopen()`) enforce valid transitions. OPEN → DONE directly is allowed (no forced pass-through IN_PROGRESS).
- Assigning a status to a previously status-less node is an explicit action, not implicit — keeps the domain honest about which nodes are "trackable" vs. pure content.
- `completedAt` stored as a real field (not derived), set in `markDone()`, cleared in `reopen()` — useful for logs/diary-style accuracy independent of status itself.
- Logs (exercise/food/diary entries) generally should **not** use status at all — modeled as plain child nodes relying on `createdAt` (+ a content/value field), since they represent something that already happened rather than a workflow state.

### Status summary for parent nodes
- **Computed at read time only — nothing stored on the parent**, consistent with the list/item derivation pattern.
- A pure function/value object (e.g., `NodeStatusSummary`) computed from a node's children — total, done, in-progress, open, and a separate count for children with no status at all (so untracked children don't silently distort the summary).

## Dates

- Optional, not universal — same principle as status.
- Unified as `Optional<Instant> startDate` + `Optional<Instant> endDate` rather than separate "due date" vs. "start/end" pairs — a todo's due date is just `endDate` with no `startDate`; an event/workout block uses both.
- Store as UTC (`Instant`), let the frontend localize for display — decided early to avoid a painful timezone retrofit once friends in different timezones are using the app.

## Recurrence

- Modeled as a separate concern from status — a schedule that *resets* status/dates, not a status value itself.
- `RecurrenceRule` value object: frequency (DAILY/WEEKLY/MONTHLY), interval, optionally days-of-week. Deliberately simple to start — no full cron/RRULE parser unless daily/weekly/monthly + interval proves insufficient.
- `Node.rollOverForNextOccurrence()` — domain method, resets status to OPEN, clears `completedAt`, computes next `startDate`/`endDate`. Uses injected `Clock`/explicit "now" rather than calling `Instant.now()` directly, to keep it deterministic and testable.
- Delivered via a scheduled job (`ResetRecurringNodesUseCase`, Spring `@Scheduled`) rather than on-demand.

## Testing Philosophy

- Very rigorous testing, especially at the domain layer.
- Domain-layer logic (cycle prevention, list/item derivation, reorder/move invariants, status transitions, recurrence roll-over) must be unit-testable with **zero Spring context and no DB** involvement.
- Mock outbound ports (notifications, calendar) in automated tests; real external calls (Google Calendar, FCM, email) only via manual/smoke testing.

## Implementation Slices (in order)

1. **Create node** — walking skeleton: domain `Node` + `CreateNodeUseCase` + minimal repo/adapter + first test. Root-node handling (no parent = root) included here.
2. **Get one node by id** — smallest read slice, proves repository read path + controller/DTO round trip.
3. **List children of a node** — proves `findChildren`/`hasChildren` query pattern; first real use of list/item derivation.
4. **Edit basic node info** (name, description) — simple update use case, no hierarchy logic.
5. **Delete node** — cascade-vs-reparent-children decision made here; also unblocks easier test cleanup for later slices.
6. **Move node** (reparent + reposition, single use case) — the heaviest domain slice: cycle prevention + position assignment + reindexing both old and new sibling sets.
7. **Set node status** — optional status field, controlled transitions (`markInProgress`, `markDone`, `reopen`), explicit opt-in to assign a status at all.
8. **Computed status summary for parent nodes** — read-time-only aggregate (done/in-progress/open/untracked counts) built on top of slice 3's query; no new persistence.
9. **Recurrence** — `RecurrenceRule` value object, `rollOverForNextOccurrence()`, scheduled `ResetRecurringNodesUseCase` job.
10. **Email notifications** — generic `NotificationPort` (designed to support future channels), `NotificationRule` (duration-before-due), scheduled `SendDueNotificationsUseCase`, `EmailNotificationAdapter` via Spring Mail/SMTP. Needs a "sent" marker to avoid duplicate sends.
11. **Calendar sync** — `CalendarPort` abstraction, `SyncNodeToCalendarUseCase`, `GoogleCalendarAdapter` (OAuth2 — budget this as its own chunk of setup work). Manual/opt-in sync per node, not automatic, to avoid surprising users. Store external event id on the node for update/delete.
12. **Push notifications** — reuses the slice 10 `NotificationPort` abstraction. Blocked on having a mobile app to register device tokens against — deliberately last, co-designed with mobile work rather than built ahead of it. Uses Firebase Cloud Messaging (covers Android + iOS/APNs in one integration). Needs device registration (`RegisterDeviceUseCase`) and per-user notification channel preference (email / push / both).

## Open Items / Things to Revisit

- Whether a single implicit root node per user (vs. multiple top-level roots) is the final model — affects how "move to root" is expressed in the Move Node API.
- Whether calendar sync should ever become automatic for any dated node, vs. staying manual/opt-in indefinitely.
- Mobile app framework choice — React Native via Expo is the current plan, but not yet started; needed before slice 12 can start in earnest.
