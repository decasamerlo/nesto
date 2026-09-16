# ADR 013: Marking Post-Acceptance Change

Status: accepted

## Context

Seven of the eleven ADRs in this repo have been edited after `Status: accepted`, and every one of those edits was silent. They range from a trailing newline added by a lint fix to a Decision section rewritten into its own opposite — [ADR 006](006-contribution-and-review-model.md)'s `b97543b` reversed the co-developer's role, and the field read `accepted` before and after.

The review comment that raised this ([#74](https://github.com/decasamerlo/nesto/issues/74)) asked for a one-line amendment note on [ADR 003](003-polyrepo-over-monorepo.md), whose amendment appended two consequences and contradicted nothing. The principle is right and applying it there first would have made things worse. Today the silence is uniform, so it carries no information; the moment one ADR carries a note, the absence of a note begins to assert *never amended* — false for several files, and most false for the one whose decision actually changed.

**There was no convention to appeal to.** `docs/conventions/` had no ADR document at all. The only format guide in the tree is a vendored skill file, deliberately minimal, which offers `Status` as an optional field and has no concept of an amendment — and which is overwritten whenever skills update, so it cannot hold a rule of ours in the first place.

A second question arrived with it and could not be answered separately, because it is the same field: **when does a decision become `accepted`?** Every ADR here was born `accepted`, and `Status: proposed` has never appeared in any ref. Deciding the amendment rule without deciding this one would grow two conventions for one line of text.

## Decision

**Sort a post-acceptance change by what a reader of the old text lost.** Not by which section changed, not by the size of the diff. Four tiers follow from that test — editorial, extended, corrected-or-narrowed, reversed — and the operational rule is in [adr.md](../conventions/adr.md).

**The floor is the load-bearing part.** Editorial changes are marked by nothing. Without a floor, ADR 004 would carry a permanent note recording that it once lacked a trailing newline, and the notes would bury the changes that matter under the changes that don't.

**A redaction under [ADR 012](012-precedent-without-evidence.md) is editorial.** It removes evidence, not truth: no claim becomes false, no decision moves, and ADR 012 is already the standing record of why such sentences read as they do. Marking each affected file would restate one global rule everywhere it ever lands. This is the tier assignment most likely to be questioned, which is why it is written here rather than only in the convention — a reader who thinks the lost auditability deserves a per-file note is disagreeing with a decision, not spotting an oversight.

**An ADR is born `accepted`, and `accepted` describes the decision rather than its review.** An ADR on an open PR is visibly a proposal because the PR is open. Entering as `proposed` and flipping on merge would cost a second commit per ADR and sit badly with squash merge — the flip either rides inside the same squash, leaving the field reading `accepted` during review exactly as before, or needs a follow-up PR. Writing down what eleven of eleven ADRs already do beats adding ceremony that would not fix the thing it was proposed to fix.

**Supersession is forward-only**, and reversals predating this rule are marked in place rather than split. Going forward, a reversal produces a new ADR and leaves the old one superseded — by then the superseded text is already a standalone file and simply stays put. Retroactively it is not. [ADR 006](006-contribution-and-review-model.md)'s original text exists only as a diff, so superseding it now would have to *manufacture* the very artifact supersession exists to preserve: a document in the tree that is wrong, that competes with the correct one for a reader's attention, and that describes a model operated for about two weeks. It takes an amendment entry pointing at the reversal instead.

## Consequences

**An unmarked ADR now asserts something.** It says *never meaningfully amended*, and that claim is only as good as the discipline behind it. Silence was safe while it was undefined; it is not any more. Six post-acceptance edits in five weeks is a rate at which this is kept by hand — the discovery problem is mechanizable and the tier judgment is not, so no check is proposed here.

**Two rejected options, so nobody re-proposes them cold.**

*Letting `Status` carry the amendment* — `Status: accepted (amended 2026-09-10)`. It reuses a field that already exists and gives one place to look, and it is ruled out by the same decision that settled when `accepted` applies. `Status` tracks the state of the decision; an appended consequence or a corrected claim does not change that state. Conflating "what state is this decision in" with "when was this text last touched" costs the field the one meaning it has.

*Superseding everything* — the strict Nygard model, where an accepted ADR is immutable and any change produces a new record. Honest for a reversal and absurd for ADR 003, where two consequences were appended and nothing was contradicted. It would also multiply the record: eleven ADRs would already be more than twenty, most of them differing from their predecessor by a sentence.

**The notes do not recurse, and no rule was needed to stop them.** Adding an amendment marker changes no claim, so it is editorial, so it earns no marker. The floor absorbed a trap that looked like it needed its own carve-out — which is the main evidence that the reader's-loss test is cutting at the right joint.

**One ADR is marked as narrowed by another, and that is a new obligation.** An ADR that confines an earlier one's claim now owes the older file a back-pointer. ADR 010 and [ADR 011](011-no-conflict-detection-in-v1.md) already say what they do to earlier records; what changes is that the older file learns about it too. The cost is a small edit to a file the author was not otherwise touching, and forgetting it is the most likely way this convention decays.

**This ADR complies with its own rule from the moment it lands**, carrying no amendment section because it has never been amended. That is the ordinary state, not an exemption.
