# Architecture Decision Records

ADRs live in `docs/adr/` and record decisions that were hard to reverse, surprising without context, and the result of a real trade-off. This convention covers what happens to one *after* it is accepted — when it is amended, corrected, narrowed, or reversed — and how it is numbered.

Why the rule exists, and the options it rejects, are in [ADR 013](../adr/013-marking-post-acceptance-change.md).

## Status

**An ADR is born `accepted`.** The PR is its review and merging is its acceptance. `proposed` is not used here.

**`accepted` describes the state of the decision, not the state of its review.** An ADR sitting on an open PR is visibly a proposal because the PR is open — the field does not track what GitHub already shows. So an ADR under review reading `accepted` is the convention working, not a defect.

It follows that most post-acceptance change never touches `Status`: correcting a claim or appending a consequence does not alter the decision's state. Only a reversal reaches the field, and only going forward — see [Supersession](#supersession).

## What gets marked

Sort a change by **what a reader of the old text lost**. Not by which section moved, not by the size of the diff.

| Tier | Test | Gets |
| --- | --- | --- |
| **Editorial** | No claim changes | nothing |
| **Extended** | New material, nothing contradicted | an amendment entry |
| **Corrected or narrowed** | The old text was wrong, or true only in a narrower range than it claimed | an amendment entry, plus an inline marker if the misleading text is still standing |
| **Reversed** | The decision itself changed | an amendment entry; see [Supersession](#supersession) |

**Editorial covers more than typos.** Lint fixes, re-pointed links, a deduplicated fact, a tightened sentence — and **redactions made to comply with [non-public-sources.md](non-public-sources.md)**. A redaction removes evidence, not truth: no claim becomes false, the decision is untouched, and [ADR 012](../adr/012-precedent-without-evidence.md) is already the standing record of why such sentences read as they do. A per-file note would restate one global rule across every file it ever touches.

**Score a mixed commit at its highest tier and write one entry.** A commit that adds two consequences and also tightens a sentence is one extension, not an extension plus an editorial change. The reader experienced one change.

**Adding or updating an amendment marker is itself editorial**, so it earns no marker. This is what stops the notes recursing, and it needs no special rule — it falls out of the test, because a marker changes no claim.

**What an unmarked ADR means.** Never *meaningfully* amended. Silence is only misleading while it is undefined; this section defines it.

## The amendment entry

At the foot of the ADR, oldest first:

```markdown
## Amendments

- **2026-08-11** — folded the Node domain-model details into Consequences ([090b5eb](https://github.com/decasamerlo/nesto/commit/090b5eb)).
- **2026-09-15** — narrowed by ADR 010: the recursive-CTE claim holds for Spring Data derived queries only ([#71](https://github.com/decasamerlo/nesto/pull/71)).
```

- **The leading verb carries the tier**, so the tier names never appear in an ADR. *Recorded*, *added*, *folded* for an extension; *corrected*, *narrowed* for a correction; *reversed* for a reversal. A reader judges whether to care without learning this vocabulary.
- **The date is the commit's author date**, read from git rather than from when the PR merged.
- **For a narrowing from outside, the date is the narrowing ADR's commit**, not the later edit that adds the marker — a reader wants to know when the claim stopped being true, not when someone got around to saying so.
- **The pointer is a PR**, in the link form ADRs already use for issues — `[#N](https://github.com/decasamerlo/nesto/pull/N)`. Bare `#N` appears in no ADR and should not start here.
- **Commits that predate the PR workflow are linked directly**, as the first example shows. Six ADR-touching commits have no PR at all.

**Trap — `git log` truncates two of these files.** `dba4666` renamed `0005`/`0006` to `005`/`006`, so reading their full history takes `git log --follow`. A date taken without it will be wrong.

## The inline marker

Only where the misleading text is **still standing**:

```markdown
- Hierarchy is stored as an adjacency list (`parent_id`) … the latter has no Spring Data JPA support.
  — *Narrowed by [ADR 010](010-node-persistence-seam.md): true of Spring Data derived queries, not of `@Query(nativeQuery = true)`.*
```

Text corrected in place needs none — the sentence a reader sees today is true, and a marker would annotate a claim that is no longer wrong. Only the person who read the superseded version was ever at risk, and they are not reading the file now.

**The entry and the marker answer different questions**, which is why neither replaces the other. The entry is the file's changelog: *has this changed?* The marker is a guard on one claim: *is this sentence still true?* A reader who searches for a term and lands mid-file sees only the marker.

## Narrowing from outside

An ADR can be narrowed without being edited. [ADR 010](../adr/010-node-persistence-seam.md) confined an ADR 001 claim to derived queries; ADR 001's text never changed, so a reader stopping there gets something no longer true as written.

**The narrowing ADR's author writes the older ADR's marker.** They are the only one who knows the narrowing happened. This formalizes what ADR 010 and [ADR 011](../adr/011-no-conflict-detection-in-v1.md) already do informally — both already say what they do to an earlier record — and adds only the missing back-pointer.

**An affirmation is not a narrowing.** ADR 011 states that [ADR 007](../adr/007-immutable-node-entity.md) stands unamended; ADR 010 resolves a contradiction in [ADR 009](../adr/009-soft-delete-with-subtree-restore.md)'s favour. Both uphold the earlier record. Neither earns a marker, and neither is a gap.

## Supersession

**Going forward, a reversed decision is superseded, not amended.** The new decision gets its own ADR; the old one keeps its text and its number, and its `Status` becomes `superseded by ADR NNN`. This is the one case that touches the field.

**Reversals that predate this convention are marked, not split.** [ADR 006](../adr/006-contribution-and-review-model.md) was reversed in place before this rule existed. It takes an amendment entry pointing at the reversal rather than being split into a superseded pair — supersession by pointer rather than by file, for the reasons in [ADR 013](../adr/013-marking-post-acceptance-change.md). Reading the unsplit ADR 006 as the rule being broken is the mistake this paragraph exists to prevent.

## Numbering

`NNN-kebab-title.md`, three digits, taken by scanning `docs/adr/` for the highest number and adding one.

**Numbers are monotonic and gaps are never backfilled.** A number, once skipped or retired, stays spent — an ADR number appears in commit messages, issues and other ADRs, and reusing one silently re-points every reference that was written before.

**008 is a known gap.** It has never existed; `git log --all --diff-filter=A` finds no file at that number. It is not missing and must not be filled.

The numbering rule also lives in the vendored `.agents/skills/domain-modeling/ADR-FORMAT.md`, which is overwritten whenever skills update. This file is the canonical one.
