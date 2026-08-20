# ADR 006: Contribution and Review Model

Status: accepted

## Context

All four repos are public. Contributors open PRs; nobody commits to `main` directly. The co-developer reviews and contributes, but their reviews must never decide merges — only the repo owner's approval or manual merge does. GitHub cannot require approval from a specific user, so the gate must be built from code-owner review + roles — the **code-owner gate**.

## Decision

- **Public repos, two contributor classes.** Outside contributors have no write access; they fork and open PRs to `main`. Fork PRs cannot be stacked (see ADR 005). The co-developer has **Write** on all four repos, which is what native stacked PRs require — stacking is same-repo only (ADR 005). Write grants them push access to their own branches and merge permission within the ruleset, but their reviews still cannot satisfy the code-owner gate.
- **Review weight comes from the code-owner gate, not from role grants.** Only the code owner's review satisfies the required review, so neither the co-developer's Write approval nor a Read user's review can complete the gate. Write approval counts toward the 1-approval rule but the gate stays unmet; a Read user's review never counts at all (only write/admin approvals count). A non-owner's request-changes can be dismissed, and the owner's bypass overrides it outright.
- **`CODEOWNERS` = `decasamerlo` in every repo.** Rulesets on `main` require a pull request, 1 approval, and review from code owners — since only the owner is a code owner, only the owner's approval satisfies the code-owner gate. Authors cannot self-approve.
- **Stacked PRs never honor the bypass list.** GitHub's async stack merge evaluates every rule for every layer and honors no bypass, admin or otherwise — so the owner's own stacked layers (which they cannot self-approve) can never satisfy the gate *while they remain stacked*. The owner therefore merges an own layer in four moves: drop it from the stack (`gh stack modify`), submit the trimmed stack (`gh stack submit`, required first — a PR still linked into a GitHub stack refuses even `--admin` merges), merge it as a normal PR with `gh pr merge <n> --squash --admin` (the CLI applies the bypass list only via `--admin`), then rebase and push the layers above. This sacrifices the atomic stack merge for that one layer.
- **Ruleset bypass list: `decasamerlo`, "for pull requests only".** Even the owner must open PRs; the bypass only grants the right to merge (including their own PRs), never direct pushes to `main`. It applies to non-stacked merges only.
- **Rulesets, not classic branch protection.** Same rule shape on all four repos; backend additionally requires its CI check.
- No merge queue, no "require branches up to date", stale-review dismissal off — the owner is the merger, so the final state is in their hands.

## Consequences

- Read-only reviewers and outside contributors can review, approve, request changes, and comment freely — none of it counts or blocks.
- The co-developer's reviews do move the mergeability state (approval counts toward the 1-approval rule, request-changes blocks until dismissed), but never decide the merge: the owner's approval (or bypass) is still required, and the owner can dismiss any request-changes.
- The co-developer's PRs to `main` still need the owner's approval (or bypass). Co-developer stacked PRs are subject to the cascade rebase like anyone else's.
- The owner's own stacked layers land via the unstack → submit → bypass-merge → rebase flow; the merged layer becomes a normal squash commit and the stack above it is re-based onto `main`. Non-stacked merges need no unstacking.
- The owner's own work never blocks on approval; if they want a second pair of eyes, they request a reviewer's review manually.
