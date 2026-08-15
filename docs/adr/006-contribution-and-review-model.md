# ADR 006: Contribution and Review Model

Status: accepted (amended 2026-08-15)

## Context

All four repos are public. Contributors open PRs; nobody commits to `main` directly. The co-developer reviews and contributes, but their reviews must never decide merges — only the repo owner's approval or manual merge does. GitHub cannot require approval from a specific user, so the gate must be built from code-owner review + roles — the **code-owner gate**.

## Decision

- **Public repos, two contributor classes.** Outside contributors have no write access; they fork and open PRs to `main`. Fork PRs cannot be stacked (see ADR 005). The co-developer has **Write** on all four repos, which is what native stacked PRs require — stacking is same-repo only (ADR 005). Write grants them push access to their own branches and merge permission within the ruleset, but their reviews still cannot satisfy the code-owner gate.
- **Review weight comes from the code-owner gate, not from role grants.** Only a code owner's review satisfies the required review, so neither the co-developer's Write approval nor a Read user's review can complete the gate. Write approval counts toward the 1-approval rule but the gate stays unmet; a Read user's review never counts at all (only write/admin approvals count). A non-owner's request-changes can be dismissed, and the owner's bypass overrides it outright on non-stacked PRs.
- **`CODEOWNERS` = `decasamerlo` + `nesto-bot` in every repo.** Rulesets on `main` require a pull request, 1 approval, and review from code owners. The **gatekeeper** is the machine-user account `nesto-bot` (Write, PAT held by the owner only). On owner-authored PRs, only the gatekeeper's approval can satisfy both the 1-approval rule and the code-owner gate (the owner cannot self-approve); on co-developer and fork PRs, the owner's or the gatekeeper's approval satisfies it. Nobody's approval can unlock a merge without one of those two code owners signing off.
- **Stacked PRs cannot merge via the bypass list.** Native stacked PRs merge through the async merge API only, which evaluates every rule for every layer and honors no bypass, admin or otherwise. The gatekeeper is therefore what makes the owner's own stacks mergeable — `scripts/merge-layer.sh` performs the gatekeeper approval then `gh stack merge`.
- **Ruleset bypass list: `decasamerlo`, "for pull requests only".** Even the owner must open PRs; the bypass only grants the right to merge non-stacked PRs (including their own), never direct pushes to `main`. Stacked PRs are exempt from bypass entirely (see above).
- **Rulesets, not classic branch protection.** Same rule shape on all four repos; backend additionally requires its CI check.
- No merge queue, no "require branches up to date", stale-review dismissal off — the owner is the merger, so the final state is in their hands.
- **"Restrict who can dismiss reviews" is not available.** GitHub silently drops this ruleset option on personal-account-owned repos (unlike classic branch protection, where it is documented as org-only; for rulesets the limit is silent). Residual risk: a co-developer could dismiss a request-changes review. The request-changes author can always re-block, and the owner holds the merge decision, so this is accepted.

## Consequences

- Read-only reviewers and outside contributors can review, approve, request changes, and comment freely — none of it counts or blocks.
- The co-developer's reviews do move the mergeability state (approval counts toward the 1-approval rule, request-changes blocks until dismissed), but never decide the merge: only a code owner's approval unlocks, and the owner can dismiss any request-changes.
- The co-developer can never merge anything into `main`: their own PRs need a code owner's approval, and their approval can never satisfy the code-owner gate on anyone's PR.
- The owner's own stacked PRs merge via the gatekeeper flow (never blocked on the co-developer); non-stacked PRs still merge via bypass, or via gatekeeper approval.
- The owner's own work never blocks on approval; if they want a second pair of eyes, they request a reviewer's review manually.
- The gatekeeper's PAT is the single point of failure for owner self-service merges; it lives in the owner's keyring and is rotated on the documented schedule.
- Emergency escape hatch: if the gatekeeper flow is unavailable, an affected stack layer can be unstacked and merged as a normal PR via bypass, then re-stacked — see `docs/conventions/stacked-prs.md`.