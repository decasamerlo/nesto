# Non-Public Sources

Nesto is public — four repos, an issue tracker, and a commit history anyone can read, none of it reliably retractable once pushed. Its documents nevertheless argue from codebases that are not public: the author has access to several, and much of the precedent behind these ADRs comes from them.

This convention is where the line between those two facts is written down. It binds **agents** authoring or reviewing text bound for these repos. Human contributors are not addressed by it — effectively all work here is agent-driven, review included, so agents are where the check can actually be applied ([ADR 012](../adr/012-precedent-without-evidence.md)).

## Surfaces

Everything the public can read counts:

- commit messages, in any of the four repos;
- files in any of the four repos;
- issue bodies and issue comments;
- PR bodies and PR reviews.

**Issue and PR text is in scope, and it is the half most easily forgotten** — it feels like conversation rather than publication. It is indexed, searchable, and permanent exactly like the rest, and an issue comment is where a stray name is most likely to land.

## Limb 1 — a repository named must be verified public

Before any repository name reaches a published surface, establish that the repository is public:

```bash
gh repo view <owner>/<repo> --json isPrivate
```

Reject on `true`. Read the **visibility field**; the exit status is not the answer.

**Trap — a lookup that succeeds proves nothing.** An agent here runs as the authenticated author, who has access to the non-public repositories this rule exists to protect. Ask GitHub about one and the request succeeds: exit 0, ordinary-looking JSON, nothing to suggest the repository is anything but visible. So "the lookup worked, therefore it is public" does not merely fail to catch private repositories — it is **inverted**, passing precisely the ones the rule was written for. The only repositories such a check would reject are the ones that do not exist at all.

An unauthenticated request is the other honest test, and a useful cross-check when in doubt:

```bash
curl -s -o /dev/null -w '%{http_code}\n' https://api.github.com/repos/<owner>/<repo>
```

`200` is public; `404` is private-or-absent, and both of those answers are a rejection.

**Why this is a test and not a list.** The obvious form of this rule is an enumeration of names that must never appear — and that list, committed to a public repo, publishes exactly what it protects. Worse, it would be read as complete: a name absent from it would look cleared rather than merely unlisted. A test needs no secret input, so it can live here in full, and it covers repositories nobody thought to enumerate.

## Limb 2 — cite by shape, never by measurement

Three things never reach a published surface:

- **identifiers** lifted from a non-public codebase — class, type, and field names;
- **verbatim quotation** of its code, comments, or documentation;
- **quantitative and structural specifics** — counts of implementations, services, modules, arguments, or references.

Precedent is stated as **direction only**: which way it leans, not how far or across how many. "The dominant approach", "a minority pattern", "the newest equivalent places its guard the same way" all carry the reasoning intact.

**Why counts are on the list, when they name nothing.** A measurement is a fingerprint. A claim of the form "*N* of the *M* services do it this way" describes the size and internal shape of something the reader cannot see, and enough such numbers identify the source as surely as its name would. It also buys less than it appears to: a reader of this repo can verify no part of it, so the number carries no evidential weight it would not carry as a direction.

**Nesto's own documents are unaffected.** Quoting an ADR here, citing its number, counting anything in these four repos — all fine, and [ADR 010](../adr/010-node-persistence-seam.md) quotes [ADR 001](../adr/001-node-based-domain-model.md) exactly as it should. The limb is about non-public sources, not about quotation.

## When it fires

Twice, and the second is the one that catches what the first misses:

1. **Authoring.** Whenever an agent drafts text bound for any surface above, before it is written or posted.
2. **Review.** As a checklist item in every review pass, over the whole diff or body under review — including text a human wrote. The known instances came from there, so a rule that fires only on an agent's own drafting would have caught none of them.

## On a trip

**Write the generic form, then say that you did.** Both halves are load-bearing:

- **Do not stall for a decision.** An agent working unattended that stops to ask has abandoned the task it was sent to do, and the answer is always the same anyway.
- **Do not substitute silently.** Then nobody learns the rule fired, the substitution goes unchallenged, and a generic phrase that lost the argument passes unnoticed.

One line is enough:

```text
Rewrote a precedent claim in generic form — it counted implementations in a
codebase I could not verify as public.
```
