# ADR 012: Precedent Without Evidence

Status: accepted

## Context

Nesto's ADRs argue from precedent. [ADR 010](010-node-persistence-seam.md) weighs how the same seam is shaped elsewhere before departing from it; [ADR 011](011-no-conflict-detection-in-v1.md) rejects an option partly on what it has cost the places that adopted it. That precedent comes from non-public codebases the author has access to through work — which is why the arguments are worth anything, and also the problem.

Nesto is public. Four repos, an issue tracker, and a commit history anyone can read, none of it reliably retractable.

Until now, the constraint holding those two facts apart lived in one machine's agent memory. It held — a scan of the published surfaces found no identifying reference — but it held by luck of location. An agent on another machine, a contributor, or a standalone clone of a sub-repo could not reach it. An unwritten rule also cannot be reviewed, argued with, or applied by anyone who has not already met it, and it fails exactly when the work moves somewhere new.

Writing it down raises a difficulty of its own, and it is the reason this needed deciding rather than just typing. The obvious form of the rule is a list of names that must not appear — and such a list, committed here, publishes what it protects.

## Decision

Two rules, stated in full in [non-public-sources.md](../conventions/non-public-sources.md) and extracted into all four `AGENTS.md` files.

**Repository names are verified, not remembered.** Any repository named in published text must be established public by reading the visibility field — not by a lookup succeeding. This is what makes the convention publishable at all: it is a *test*, and a test needs no secret input. The trap it exists to name is documented with it — an agent authenticated as the author sees a private repository as an entirely ordinary one, so an existence check passes precisely the repositories the rule was written to catch.

**Material from non-public codebases is cited by shape, never by measurement.** No identifiers, no verbatim quotation, no counts. Precedent is stated as direction: which way it leans, not how many instances lean that way.

**The rule binds agents, not human contributors.** Effectively all work here is agent-driven, review included, so agents are where a check can actually run. A rule addressed to contributors who do not yet exist would be enforcement theatre, and would leave the actual authors unbound.

**The extract is duplicated into each sub-repo rather than linked.** A standalone clone reaches no meta-repo document, and a pointer to an unreachable file tells an agent that a constraint exists without telling it what — which invites a guess, in exactly the situation the rule exists to prevent. The copies can drift; that is accepted, and the convention file stays canonical.

## Consequences

**Precedent claims in this repo carry no evidence, and that is deliberate.** An ADR saying an approach is dominant does not say across how many codebases, does not name one, and does not quote the passage that convinced the author. A reader cannot check the claim. Neither can a reviewing agent.

**This entry is what stops that reading as a defect.** Anyone who notices the gap and moves to close it — restoring the counts, naming the sources, quoting the documentation — would be undoing this decision without knowing it was made. The missing evidence is the rule working, not a lapse in rigour, and this ADR is the reason to leave it missing.

**What a precedent claim is worth, having lost its evidence.** Less. "The dominant approach" is weaker than a count and far weaker than a name, and it should be read for what it is: a report of the author's experience, offered on the author's word. It stays worth writing because the *direction* is the part that actually transferred into the decision — no ADR here turned on the exact number — and because a reader of a public repo could never have verified the number anyway. What is lost is the ability to audit the author's memory, not the ability to follow the reasoning.

**Existing published text is not yet compliant**, and correcting it is [#81](https://github.com/decasamerlo/nesto/issues/81), deliberately separate. Passages written before this decision still name, quote, or measure. Redacting them is not mechanical: an argument whose evidence is deleted needs its reasoning re-made, or it degrades into an assertion — editorial work on the author's own thinking, which is why it is a human task rather than a follow-up commit here.

**No mechanical enforcement.** Considered and rejected. With the rule a test rather than a list, the only greppable pattern left is `owner/repo`-shaped tokens, which catches none of the prose cases, none of the quotations, and none of the measurements. A check that misses most of what it appears to cover is worse than no check, because it gets trusted. [#73](https://github.com/decasamerlo/nesto/issues/73) already puts CI out of scope until there is any.
