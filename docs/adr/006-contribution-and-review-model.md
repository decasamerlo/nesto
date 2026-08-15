# ADR 006: Contribution and Review Model

Status: accepted

## Context

All four repos are public. Contributors open PRs; nobody commits to `main` directly. A second user (northoncardoso) reviews and contributes, but their reviews must never block or unblock merges — only the repo owner's approval or manual merge decides. GitHub cannot require approval from a specific user, so the gate must be built from code-owner review + roles.

## Decision

- **Public repos, fork-based contribution.** Contributors have no write access; they fork and open PRs to `main`. Fork PRs cannot be stacked (native stacks are same-repo only).
- **northoncardoso gets Triage** on all four repos. Verified GitHub mechanics: Triage approvals never count toward required approvals (only write/admin count) and Triage "request changes" never blocks merging. His reviews are advisory by construction.
- **`CODEOWNERS` = `decasamerlo` in every repo.** Rulesets on `main` require a pull request, 1 approval, and review from code owners — since only the owner has write, only the owner's approval satisfies the gate. Authors cannot self-approve, so stacked PRs of the owner are merged via bypass, never by approval.
- **Ruleset bypass list: `decasamerlo`, "for pull requests only".** Even the owner must open PRs; the bypass only grants the right to merge (including own PRs), never direct pushes to `main`.
- **Rulesets, not classic branch protection.** Same rule shape on all four repos; backend additionally requires its CI check.
- No merge queue, no "require branches up to date", stale-review dismissal off — the owner is the merger, so the final state is in their hands.

## Consequences

- Nothing merges into `main` without the owner: a contributor's PR needs the owner's approval; the owner's own PRs need the owner's manual merge.
- The reviewer user can review, approve, request changes, and comment freely — none of it affects mergeability.
- Public repos mean anyone may open a PR; each is vetted by the owner's review before merging.
- The owner's own work never blocks on approval; if they want a second pair of eyes, they request Northon's review manually.
