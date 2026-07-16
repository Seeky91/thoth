# Orchestration & execution safety

Reference loaded by `mode-project.md` (always) and `mode-zone.md` (for a large zone). Describes large-scale cleanup without saturating context or breaking code through cross-zone renames.

## Fan-out vs main-loop: when to delegate

Does a zone's cleanup fit in the current context?

- **1 file or small directory (≲ 1500 LoC)** → direct **main-loop**. No subagent: orchestration overhead exceeds the benefit.
- **Medium/large directory or multi-zone campaign, with subagents available and authorized** → **fan-out**: one fresh-context subagent per zone.
- **Subagents unavailable or forbidden by the session** → stay in a **segmented main-loop**: one zone at a time, targeted reads, then a structured summary before releasing working context and moving to the next. Never block a campaign solely because the runtime provides no subagents.

The primary driver **never** reads every zone's code at once: it maintains the inventory, coverage ledger, and one **summary** per zone. With delegation, each agent loads only its zone; without it, the main-loop preserves the same targeted-reading discipline.

## Default strategy: serialized execution by zone

Model aligned with “one agent per zone, then move to the next”:

1. The orchestrator takes the inventory's **next uncovered zone**.
2. If available, it **instantiates a subagent** (fresh context) with the briefing below, scoped to that zone. Otherwise, it executes the zone itself in a segmented main-loop using the same briefing as a checklist.
3. The executor cleans the zone (DELETE / RENAME / KEEP+de-drift), **greps the entire project before each rename**, updates all sites, then produces a **structured summary**.
4. The orchestrator **runs validation** (see *Validation*). KO → stop, report, user arbitration (no next zone). OK → write the coverage line.
5. Next zone.

**Serialized, not parallel**—deliberately: a rename has a cross-zone blast radius. Two agents mutating in parallel interfere (one renames a symbol the other is reading). Serialization guarantees only one agent writes at any time and each rename propagates across the entire project before the next zone.

### Parallel variant (optional, if the runtime permits)

If multiple subagents are available, zones are highly independent, and renames are rare or absent, acceleration is possible:

- **Phase 1—parallel R/O analysis**: N read-only agents, one per zone, that *propose* (without editing) deletions and renames + their blast radius. Safe (no mutation).
- **Phase 2—serialized apply**: the orchestrator applies changes zone by zone, processing cross-zone renames first and consistently.

Use this variant only when time savings are real; otherwise the default serialized strategy is simpler and safer. (Per-agent `worktree` isolation is possible but overkill here—reserve it for truly concurrent mutations.)

## Zone-subagent briefing

The subagent has **fresh context**: it knows neither doctrine nor rules. The briefing must be **self-contained**. Template for the orchestrator to fill in:

```
You AGGRESSIVELY clean code documentation in ONE zone: <zone path>.
Goal: delete comment noise, make code self-documenting, and make survivors reliable. Preserve behavior.

CORE RULE: a comment describing WHAT code does is noise ~90% of the time → DELETE. A comment explaining WHY (business logic, non-obvious intent) → KEEP. When uncertain about a “what,” delete it.

3 possible actions per comment/name:
1. DELETE on sight: code paraphrase, step-by-step narration, decorative banners, docstring/JSDoc repeating the signature and already declared types, dead commented-out code, stale TODOs, changelog comments.
2. RENAME to delete: if a comment only compensates for a vague name, rename the identifier and delete the comment. BUT: no unreadable sentence-long name (otherwise keep a short comment); grep is TEXTUAL and misses dynamic uses/reflection/homonyms—for a LOCAL/PRIVATE symbol, rename after disambiguated grep (word boundaries); for a CROSS-FILE rename, use a semantic tool (LSP/compiler rename, or find_referencing_symbols + rename_symbol) if available; OTHERWISE do NOT rename (keep a short comment); NEVER rename an exported symbol/public API name/serialization key.
3. KEEP + correct: keep genuine “why” (business, tradeoff, security, platform limitation, public API contract) AND correct its drift (match actual current behavior; grep its claims before keeping them).

DO NOT TOUCH: license/copyright headers, semantic directives (eslint-disable, type: ignore, noqa, @ts-expect-error, pragmas), generated/vendored files, public API contracts (keep+correct). Emoji are not a criterion.

READ-ONLY GIT: edit files, but NO git add/commit/push/reset/checkout. Leave everything in the worktree.

Cross-cutting analysis is allowed and encouraged: cross-file grep to verify rename impact and the truth of kept comments.

RETURN a structured summary (and NOTHING else):
- files inspected: <list or count>
- comments deleted: <N>
- renames performed: <list "old → new" + number of sites updated + tool used (grep / semantic)>
- docs de-drifted: <N> (+ 1 line per notable correction)
- files modified: <list>
- files/subzones explicitly NOT processed (and why): <…>
- attention points/uncertainties left unchanged: <…>
```

Adapt: for `--touched` (session mode), add *“limit yourself to the lines in these hunks: <hunks>”*. For the R/O variant, replace “edit” with “modify nothing; only propose.”

Use an agent capable enough for *what/why* classification and rename judgment. Do not assume a named model or particular service tier is available.

## Summary integrity verification

The zone summary is **not self-certifying**, whether from a subagent or the main-loop: tests prove code compiles/passes, not that the zone was inspected or the executor was aggressive enough. Before writing coverage, the driver **cross-checks the summary against the actual diff**:

- `git diff --stat -- <zone>`: consistent with the summary (declared deletions/renames → nonempty diff; `0 deleted (already clean)` → empty diff expected).
- **Scope**: diff files must remain **inside the zone**, **plus** legitimate out-of-zone rename-propagation sites declared in the summary (a cross-file rename *legitimately* expands the diff—do not treat this as an anomaly). Overflow **without** a declared rename = anomaly → investigate.
- Manifestly incomplete summary (non-trivial zone but empty `files inspected`, or empty diff while the zone is visibly noisy) → rerun the agent if possible or resume in the main-loop; **do not mark covered** based only on the summary.

## Validation

Run by the **driver** (orchestrator or main-loop), **after each fully applied zone**—never per edit (a rename is valid only after every site is updated).

Opportunistic command detection with graceful degradation:

1. Detect the runner: `package.json` scripts (`test`, `lint`, `typecheck`), `Makefile` targets (`test`, `lint`, `check`), `cargo test`/`cargo check`, `go test ./...`/`go vet`, `pytest`/`tox`, `pyproject`/`ruff`, etc.
2. **Ambiguous or multiple candidates** → ask the user **once** for the validation command at campaign start, then reuse it for all zones (do not ask again per zone).
3. **Nothing detected** → announce it (*"No test suite detected—degraded validation: compile/lint only if available; otherwise none."*) and continue.

**Tests KO in a zone**: because git is read-only, do not auto-revert. **Stop**: do not proceed to the next zone; report the failure and affected files, and let the user arbitrate (fix, or manually review/revert the zone diff).
