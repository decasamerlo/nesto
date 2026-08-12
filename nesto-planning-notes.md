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
- **Frontend: React + TypeScript + Vite + library stack** (decision in ADR 004 — see `docs/adr/004-react-for-frontend.md`).


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
- Mobile app not yet started — needed before slice 12 can start in earnest.
