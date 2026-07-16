# Cleanup doctrine

Reference loaded by SKILL.md at the start of **every** mode. This is the skill's core: calibration of what to delete, rename, or keep. Read before any edit.

## Stance: aggressive by default

A competent agent **spontaneously under-deletes**. Left alone, it keeps comments “just in case,” finds a justification for almost every comment, and leaves the code buried. This skill corrects that bias by **reversing the burden of proof**:

> A comment is noise **until proven useful**. Deletion is the default.

In practice: when uncertain about a comment, **delete it**. The allowlist below is intentionally narrow; anything that does not clearly fit is removed. The guardrail against excess is not timidity; it is the allowlist + validation (tests) + the uncommitted diff the user reviews.

## Core heuristic

> A comment describing **what** the code does is noise in ~90% of cases → **delete**.
> A comment explaining **why**—business logic, non-obvious intent—has real value → **keep**.

Code already says *what it does*. Restating it in prose adds nothing and becomes false as soon as code changes (drift). The ~10% of “*what*” comments to keep summarize a dense, non-trivial algorithm in one line that saves reading time (and even then, prefer a good name).

## The 3 verbs

For every comment/name encountered, take exactly one of three actions:

1. **DELETE**—noise (the majority). Indicative list below.
2. **RENAME to delete**—when a comment only compensates for a vague name: rename the identifier, then delete the comment.
3. **KEEP (+ de-drift)**—allowlisted “*why*”: preserve it and correct any drift.

## 1. DELETE on sight

This list is **indicative, not exhaustive**—it primes judgment rather than replacing it. The core heuristic remains the criterion.

- **Code paraphrases**: `// increment i`, `# loop over items`, `// return the result`, `// constructor`.
- **Step-by-step narration** that duplicates reading the function body.
- **Decorative banners/separators**: `// ===== SECTION =====`, `//////// HELPERS ////////`.
- **Docstrings/JSDoc/doc-comments that repeat the signature**: restate the name, parameters, and statically declared types without adding anything (`@param user the user`).
- **Redundant type documentation** on already typed code.
- **Commented-out code** left in place (dead)—delete it; git history preserves it.
- **Stale TODO/FIXME** or items without actionable content; mini-changelogs in comments (`// changed on 12/03 by X`)—git history is the source.
- **Any “*what*” comment** on already readable code.

Emoji in a comment are **not themselves a deletion criterion**. Judge the comment on substance (useful → keep its emoji; noise → delete the whole comment).

## 2. RENAME to delete the comment

Many comments exist only to **compensate for a vague name**. Move the information into the name, then delete the comment.

```
let d = 86400; // seconds in a day                 →   let seconds_per_day = 86400;
function proc(x) { // validates and normalizes email → function validateAndNormalizeEmail(email) {
```

**Pragmatism guardrail** (without it, renaming runs amok):

- **No unreadable sentence-long names.** If the information does not fit in a reasonable identifier, **keep** a short comment instead of creating `processAndValidateAndNormalizeUserEmailThenLog`.
- **No rename that breaks a public contract.** Do not rename an exported symbol/public API name/serialization key for internal readability (see *When NOT to touch*).
- If logic is **structurally too dense** for a name to summarize, keep and **compress** the comment (reduce it to its “*why*”).

**Rename safety—`grep` is textual, not semantic**: it misses dynamic imports, reflection, protocol strings, serialization keys, overloads, homonyms, indirect re-exports, and uses outside the repo. Because the skill *encourages* renaming, this is the main danger. Proceed by **risk tier**:

- **Local/private symbol, clear lexical scope** → rename directly after a **disambiguated** grep (word boundaries, exclude homonyms). This is the most common and safest case.
- **Cross-file rename** → grep is **insufficient**. Use a **semantic tool when available** (LSP rename, compiler/IDE rename, or `find_referencing_symbols` + `rename_symbol`): it provides the exhaustive reference list; the agent validates it. The tool proposes; the agent decides.
- **No semantic tool available for a cross-file rename** → **do not auto-rename**: keep a short comment (the pragmatic fallback above) rather than risk an uncertain textual rename. (The user may still explicitly force a rename.)
- **Never**: exported symbol/public API name/serialization key (see *When NOT to touch*).

(For multi-zone orchestration, see `references/orchestration.md`.)

## 3. KEEP (narrow allowlist) + de-drift

**Keep** a comment only when it conveys knowledge the code cannot express by itself. Allowlist (modeled on a strict comment policy):

- **Business logic/rules** not inferable from code (“refunds > 30 days use the manual flow—legal requirement”).
- **Non-obvious intent/why-not**: why this approach rather than the obvious one (“no `Promise.all` here: the API limits requests to 1/s”).
- **Subtle tradeoffs**, counterintuitive performance choices.
- **Platform limitations/workarounds** (library bug, browser quirk, OS constraint).
- **Security/safety**: invariants not to break, reason for a check.
- **Public API contracts**: documentation for an exported/public symbol that serves consumers (see language cases below).

**De-drift survivors** (audit directive): a kept comment must be **true**. For each one:

- Verify that it describes the code's **actual current** behavior (drift is common: code evolves, comments do not).
- Correct stale data, clarify imprecision, and resolve every comment ↔ code mismatch.
- **Verify cross-cutting claims**: if a comment asserts a fact (“called only by X,” “always non-null here”), confirm it by grep/reading call sites before keeping it. A lying comment is worse than no comment—correct or delete it.

## When NOT to touch (guardrails)

These guardrails protect a **minority** of cases. They are not an invitation to timidity: when uncertain about an ordinary “*what*” comment, **deletion** remains the default.

- **Do not delete** an allowlisted genuine “*why*” comment, even if awkwardly worded (rewrite it instead).
- **Do not change behavior.** Cleanup is behavior-preserving. Beware languages without `defer`/RAII: a rename or move must not alter execution order or cleanup.
- **Preserve legal headers**: licenses, copyright, SPDX notices, mandatory generated notices—these are not code documentation.
- **Preserve semantic directives**: `// eslint-disable`, `# type: ignore`, `# noqa`, `// @ts-expect-error`, pragmas, build/lint annotations. These are code, not comments.
- **Generated files** (`*.gen.*`, `*_pb2.py`, codegen output, vendored): do not touch them.
- **Public API contracts**: see language cases.

## Language cases: private doc-comment vs public contract

A doc-comment's nature depends on symbol **exposure**, and syntax varies by language (Rust `///`, Python docstrings, JSDoc/TSDoc, Go doc comments, Javadoc):

- **Private/internal symbol**: a doc-comment that paraphrases the signature is noise → **delete** (aggressive default).
- **Public/exported symbol** (library consumed by others, public API, source of generated docs): the doc-comment is a **contract** → **keep and de-drift**. Still delete purely redundant parts (a `@param` that merely restates the type remains noise, even on public code).

When exposure is uncertain (is the symbol truly consumed externally?), **grep usages** before deciding. For a poorly understood public API, abstain cautiously: keep and de-drift rather than delete.
