# Chat output templates

Reference loaded by SKILL.md before every mode's chat output. Modes cite a template by name (e.g., `audit:summary`); this file provides its normative format. Cross-cutting conventions (header, trailer, summary/action-proposal separation) are defined in SKILL.md—not repeated here.

Follow these templates **exactly** (structure, headers, trailers, placeholders). Placeholder content adapts to context, but the skeleton does not change. This guards against format drift between invocations.

## Contents

- Selection: `selection:proposition`
- Audit: `audit:summary`, `audit:clean`, `audit:proposition`, `audit:proposition-min`
- Crosscut: `crosscut:dim-proposition`, `crosscut:summary`, `crosscut:clean`
- Tracking: `list:dashboard`, `update:summary`
- Double-check: `double-check:output`, `double-check:autonomous-batch`, and their proposals
- Resolution: `resolution:confirm`, `resolution:done`, `cascade:recap-batch`
- Archive: `archive-clear:confirm-all`, `archive-clear:confirm-partial`, `archive-clear:done`

## `selection:proposition` — Candidate-area announcement (auto audit mode)

```
I propose: <area> (<reason>, <LoC size>)
Alternatives: <alt-area-1> (<reason>, <size>) or <alt-area-2> (<reason>, <size>)
```

- `<reason>` reflects both the area's nature and activity state (see `references/mode-audit.md > C. Activity signal`):
  - **Coverage:** `never audited`, `god file`, `traceable pipeline`, `architectural landmark`, `local composition root`, `structuring public facade`.
  - **Activity:** `hot — <N> commits since the last audit (YYYY-MM-DD)`, `cold — audited on YYYY-MM-DD, no non-maintainability activity since`.
  - Both may be combined: `traceable pipeline, hot — 12 commits since 2026-03-08`.
  - In degraded mode (non-Git repo): omit all activity mentions and retain only the coverage reason.
- 2 alternatives by default. If the inventory provides fewer, list those available. Ideally, show a mix (one area at the selected priority level + one at another level to give the user a choice).

## `audit:summary` — Audit with findings

```
Audit complete — <area>

<N> new findings (<X> HIGH, <Y> MED, <Z> LOW):
  <ID> (<SEV>, Δ ~<delta>) — <short-observation>
  ... (one per finding, order: HIGH > MED > LOW, ascending ID within each)

Estimated net LoC Δ if all are applied: ~<sum> (algebraic sum—deletions and additions combined; signed detail per finding appears above).

Files updated: <STATE_DIR>/maintainability_findings.md (+<N> findings), <STATE_DIR>/maintainability_history.md (+1 line).
To investigate an item manually: invoke `maintainability` in double-check mode with `<example-ID>`.
```

Followed by the `audit:proposition` or `audit:proposition-min` block according to the number of findings.

## `audit:clean` — Clean-area audit (0 findings)

```
Audit complete — <area>. No findings produced; area clean across all examined dimensions.

Files updated: <STATE_DIR>/maintainability_history.md (+1 `0 findings (clean)` line).
```

No proposal block follows (nothing to propose).

## `audit:proposition` — Autonomous double-check proposal (3 options)

```
You can also let me investigate autonomously. Which option?
  (a) a quick-win panel: <ID-1>, <ID-2>, <ID-3> — <K> findings with a short fix and limited blast radius.
  (b) the most structurally significant finding: <heavy-ID> — <observation summary>.
  (c) nothing; I will revisit later.
```

If no quick win meets the criteria, omit (a). If there is no structurally significant HIGH/MED finding, (b) uses the largest `|Δ LoC|` with warning `"(not a heavy finding in the conventional sense)"`.

## `audit:proposition-min` — 1- or 2-finding variant

```
Would you like me to autonomously double-check <ID>?
```

For 2 findings, cite both IDs.

## `crosscut:dim-proposition` — Candidate-dimension announcement (crosscut mode)

```
I propose a crosscut on: <DIM> (<reason>)
Alternatives: <alt-DIM-1> (<reason>) or <alt-DIM-2> (<reason>)
```

- `<reason>` ∈ {`never crosscut`, `not seen for N days`, `strong signal in <areas>`, `weighted random`, etc.}
- 2 alternatives by default, from eligible dimensions `{DUP, INC, DRF, DED, BND, ARC}` other than proposed `<DIM>`. If fewer are available (restrictive rolling window), list those available.

## `crosscut:summary` — Crosscut with findings

```
Crosscut <DIM> complete

<N> new findings (<X> HIGH, <Y> MED, <Z> LOW):
  <ID> (<SEV>, Δ ~<delta>, <K> files) — <short-observation>
  ... (one per finding, order: HIGH > MED > LOW, ascending ID within each)

Estimated net LoC Δ if all are applied: ~<sum> (algebraic sum—deletions and additions combined; signed detail per finding appears above).

Files updated: <STATE_DIR>/maintainability_findings.md (+<N> findings), <STATE_DIR>/maintainability_history.md (+1 `crosscut:<DIM>` line).
To investigate an item manually: invoke `maintainability` in double-check mode with `<example-ID>`.
```

`<K> files` = number of distinct locations listed in the finding's `Location` (1 for a single-file finding such as global `DED`, ≥2 for `DUP`/`INC`/`DRF`/`BND`).

Partial sweep (tool-free fallback): insert `Coverage: N/M areas scanned — tool <X> unavailable` immediately before the `Files updated` trailer, and give the cited history line the suffix `[partial: N/M areas]`.

Followed by the `audit:proposition` or `audit:proposition-min` block according to finding count (action-proposal templates are generic across audit types—there is no dedicated crosscut version).

## `crosscut:clean` — Crosscut without findings

```
Crosscut <DIM> complete. No cross-area finding produced for this dimension.

Files updated: <STATE_DIR>/maintainability_history.md (+1 `crosscut:<DIM> — 0 findings (clean)` line).
```

Partial sweep: replace the first line with `Crosscut <DIM> complete — coverage: N/M areas scanned (tool <X> unavailable). No finding in the sample.` and give the cited history line the suffix `[partial: N/M areas]`.

No proposal block follows (nothing to propose).

## `list:dashboard` — Dashboard (read-only)

```
Maintainability board — <project>

Pending (<total>):
  HIGH (<n>): <ID-1> (<50-char-desc>), <ID-2> (<desc>), …
  MED  (<n>): <ID> (<desc>), …
  LOW  (<n>): <ID> (<desc>), …

Stale (<n>) — relocate, mark resolved, or archive:
  <ID> — stale-after-<cause-ID> (<date> fix, location invalidated)
  <ID> — stale (<reason>)

Recently resolved (last 30 days):
  <ID> (<SEV>) — <date> — <fix-summary>

Rolling (N=<N>):
  <date> — <area> — <N findings (status)>
  ... (N lines, most recent first)

Rolling crosscut (Nx=<Nx>):
  <date> — crosscut:<DIM> — <N findings (status)>
  ... (at most Nx lines, most recent first)

Suggested batches (<K>):

  B1 · <area-or-multi> · Δ ~<sum> · <K> findings  [★ recommended: <reason>]
       <ID·SEV> + <ID·SEV> + … — <one-line rationale>

  B2 · <area> · Δ ~<sum> · <K> findings
       <ID·SEV> + … — <rationale>

I propose `double-check B<recommended>` (recommended).
Otherwise: direct `fix B<recommended>`, another batch (`double-check B<n>` / `fix B<n>`), or `nothing`.
```

Omissions:
- Stale section: omit if zero.
- Recently resolved section: show `"None resolved in the last 30 days."` if zero. If all 8 entries under the Resolved cap fall within the window, suffix the section title with `(window possibly truncated at the Resolved cap—the archive is not reread)`.
- Batches section: if zero batches are detected, replace it with `"No obvious batch detected—the pending findings are independent."` and **omit** the action prompt.
- If zero active pending findings: replace the line with `Active pending (0): no actionable finding.`.
- `Rolling crosscut` section: omit entirely if history has no `crosscut:*` line. If fewer than `Nx` crosscut lines exist, list those available (no padding).

## `update:summary` — Update summary

```
Update complete — <project>

Rechecked <N> pending findings:
  Resolved (<n>): <ID-1>, <ID-2>
  Auto-relocated (<n>): <ID> (<old-path> → <new-path>, <signal>)
  Auto-resolved stale (<n>): <ID> (<reason: pattern dissolved / commit <hash>>)
  Still present (<n>): <ID-3>, <ID-4>, <ID-5>
  Stale (<n>): <ID> (<reason: inconclusive investigation>)
  Stale-after (<n>): <ID> (stale-after-<cause-ID> preserved)
  Archived (<n>): <ID-1>, <ID-2> (Resolved cap reached)

Files updated: <STATE_DIR>/maintainability_findings.md, <STATE_DIR>/maintainability_history.md[, <STATE_DIR>/maintainability_resolved_archive.md].
```

Zero-count lines are omitted (e.g., no stale-after → no line, no auto-relocated → no line).

## `double-check:output` — Standard double-check output

```
Double-check <ID> — <verdict>

Location: <path:line>
Blast radius: <N> imports, <N> tests touched, <surfaces>
Feasibility: <summary>
Effort: <S|M|L> (~<time/commit estimate>)
Refined Δ LoC: ~<delta> (<comparison with initial estimate if delta >50%>)
Refined recommendation: <recommendation>
Verdict: <GO|NO-GO|GO-but-after-X>
Benefit: <concrete sentence> (only for a GO or GO-but-after-X verdict)

[Code excerpts from relevant call sites if useful to the decision]

Files updated: <STATE_DIR>/maintainability_findings.md (Double-check section added[, title amended: <SEV> → <NEW-SEV>]).
```

## `double-check:autonomous-batch` — Aggregate output for a quick-win panel or fix batch

```
Autonomous double-check complete for <K> <findings|quick-wins>:
  <ID-1> — <verdict> (Δ <delta>, <one-line-summary>) — Benefit: <sentence>
  <ID-2> — <verdict> (Δ <delta>, <summary>) — Benefit: <sentence>
  <ID-3> — <verdict> (Δ <delta>, <summary>) [no Benefit if NO-GO]

Files updated: <STATE_DIR>/maintainability_findings.md (+<K> Double-check sections).
```

## `double-check:proposition` — Action proposal after a single double-check

Shown immediately after `double-check:output`. Options are filtered by verdict.

**GO / GO-but-after-X verdict variant:**
```
What should be done for <ID>?
  (a) Fix now — plan + tests + in-session resolution.
  (b) Later — the Double-check is recorded; you can return to it via list mode.
```

**NO-GO verdict variant:**
```
NO-GO verdict. What should be done for <ID>?
  (a) Archive — mark resolved with reason `archived after double-check (NO-GO: <short-reason>)`.
  (b) Keep pending — useful if the NO-GO merits reevaluation later.
```

## `double-check:autonomous-batch-proposition` — Action proposal after a double-check batch

Shown immediately after `double-check:autonomous-batch`. Options are filtered by the batch's verdict mix.

**Mixed GO + NO-GO variant:**
```
What should be done with the <K> double-checked findings?
  (a) Fix all GOs in order: <GO-ID-1> → <GO-ID-2> → … (reason: <criterion>). Auto-archive NO-GOs: <NG-ID-1>, <NG-ID-2>.
  (b) Fix one GO — specify which from <GO-list>.
  (c) Archive NO-GOs only; keep GOs pending.
  (d) Nothing.
```

**All-GO variant:**
```
What should be done with the <K> findings (all GO)?
  (a) Fix all in order: <ID-1> → <ID-2> → … (reason: <criterion>).
  (b) Fix one — specify which from <list>.
  (c) Nothing.
```

**All-NO-GO variant:**
```
All <K> findings are NO-GO. What should be done?
  (a) Archive all (individual reason per finding).
  (b) Keep pending.
```

**Ordering rules for the "Fix all" option** (mixed and all-GO variants), in descending priority:
1. **Explicit dependencies:** a `GO-but-after-<ID>` verdict requires `<ID>` to be fixed first **if** `<ID>` is in the batch (otherwise note the external dependency and place the finding in natural order).
2. **Increasing blast radius:** findings with the most contained blast radius first (lower risk of breaking the next one).
3. **Shared path:** group findings touching the same file (one change series per file).
4. **Tie-break:** ascending ID.

The reason cited in the output reflects the deciding criterion (e.g., `explicit coupling`, `low blast radius first`, `grouped by file`).

## `resolution:confirm` — In-session confirmation (with or without cascade)

**Simple variant (overlap = 0, no cascade):**
```
This fix resolves <primary-ID> (Δ <delta>). Should I mark it resolved?
```

**Cascade variant:**
```
This fix resolves <primary-ID> (Δ <delta>). Cascade recheck on <K> pending findings touching the same files:
  - <cascade-ID-1> — pattern absent → resolved collaterally
  - <cascade-ID-2> — pattern still present (line <old> → <new>, to update)
  - <cascade-ID-3> — <file> renamed → stale-after-<primary-ID>

Should I mark <primary-ID>[+ <cascaded-IDs>] resolved[, update <shift-IDs>][, and tag <stale-IDs> stale-after]?
```

## `resolution:done` — Final in-session confirmation

```
Files updated: <STATE_DIR>/maintainability_findings.md (move <ID> → Resolved[+ <N> cascaded][+ <M> stale-after]), <STATE_DIR>/maintainability_history.md (resolved <ID>+...).
```

For partial pushback at `resolution:confirm`, the line reflects only what was applied.

## `cascade:recap-batch` — Final summary for `fix B<n>` (list mode)

```
<X>/<Y> resolved, total measured LoC Δ: <sum>, commits: <hash1>+<hash2>+...
Cascade recheck: <N> resolved collaterally (<IDs>), <M> stale-after (<IDs>).
```

If overlap = 0 across all batch fixes, **omit** the `Cascade recheck:` line. Uncommitted fixes (normal case): `commits: uncommitted (diff in worktree)` replaces the hash list.

## `archive-clear:confirm-all` — Full-purge confirmation

```
Confirm full archive deletion (<X> entries). Type 'oui' to confirm.
```

Wait for literal `oui`. Any other input → announce `"Canceled."` and finish without writing.

## `archive-clear:confirm-partial` — Partial-purge confirmation

```
<X> entries will be deleted: <ID-1>, <ID-2>, … — <Y> kept (most recent: <ID> from <date>). Confirm? (y/N)
```

## `archive-clear:done` — Purge summary

```
Archive cleared — <X> deleted, <Y> kept. Counters: DUP=<n>, SIZ=<n>, ...

Files updated: <STATE_DIR>/maintainability_resolved_archive.md[, <STATE_DIR>/maintainability_findings.md (id_counters header)].
```
