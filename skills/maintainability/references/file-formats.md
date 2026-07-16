# Project-file formats

Reference loaded by SKILL.md when the skill reads or writes a state file. Three files live in `<STATE_DIR>` resolved by SKILL.md. Strict format; follow exactly.

### Why Markdown (deliberate choice)

State is **Markdown**, not JSON/binary, **by design**: directly readable, **git-diffable** (each audit/resolution is a reviewable diff), and **manually editable** by the user (the skill assumes and anticipates this—see *ID counters > missing header* and never reusing IDs after manual deletion). An opaque format would add some parsing robustness but lose these three properties, a poor trade-off for state that must remain inspectable. Parsing robustness comes instead from the stable bullet schema below, delta writes (*SKILL.md > Cross-cutting conventions*), and counter self-healing.

## `<STATE_DIR>/maintainability_history.md`

**Append-only audit log.** One line per audit, with every **new entry prepended at the top** (newest first). The file is **never trimmed**—it accumulates for the project's lifetime.

```markdown
<!-- rolling_size: 5 -->        # optional: override active rolling size (see below)
# Maintainability audit history

- 2026-05-03 — services/billing/refund/ — 6 findings (3 HIGH, 2 MED, 1 LOW) (resolved DUP-007+SIZ-003)
- 2026-05-01 — pipeline:order-processing [api/ingest.py, validators/order.py, enrichers/customer.py, store/orders.py] — 4 findings (1 HIGH, 3 MED) (pending)
- 2026-04-22 — core/api_handler.py — 8 findings (4 HIGH, 3 MED, 1 LOW) (pending)
- 2026-04-15 — services/auth/ — 3 findings (1 MED, 2 LOW) (all resolved)
- 2026-03-30 — services/payments/ — 0 findings (clean)
- ... (one line per audit, never truncated)
```

### Format rules

- Line format: `- YYYY-MM-DD — <area> — N findings (X HIGH, Y MED, Z LOW) (status)`
- `<area>` = directory path (`services/billing/refund/`), file path (`core/api_handler.py`), `pipeline:<name> [files,…]`, or `crosscut:<DIM>` (see *Crosscut lines* below). The bracketed file list appears ONLY for pipelines.
- `(status)`: `(pending)`, `(all resolved)`, or `(resolved <ID>+<ID>+...)` when only some are resolved.
- **Find the correct line** to complete `(resolved …)` by exact **(finding `Detected` date + area) pair**, not area alone (one area may have multiple audit lines on different dates; a multi-file crosscut finding originates from `crosscut:<DIM>`). If multiple lines remain eligible after matching, **report it in chat** instead of guessing.
- Clean area (0 findings): `- YYYY-MM-DD — <area> — 0 findings (clean)`. **Still write this line**—it records that the area was examined.

### Three distinct uses

The file serves **three purposes** with different memory horizons:

1. **Active rolling**—the `N` most recent audits, excluded from next-audit candidates to avoid repetition. `N = clamp(round(Z / 4), 3, 10)`, where `Z` = current inventory area count. Optional override through `<!-- rolling_size: M -->` at file top.
2. **Historical coverage**—all areas **ever audited during the project lifetime**, used to weight selection ("never-audited areas → high priority"). Build by scanning **all** lines, not only the latest `N`.
3. **Per-area dating**—for each area, `last_audit_zone = max(date)` among history lines for that area. Used by the activity signal (`references/mode-audit.md > C. Activity signal`): compare this date with the last user commit touching the path to classify the area as `hot` / `cold`.

The same source serves all three. Rolling is a **view** of the first `N` lines (newest); coverage is the **union** across all lines; per-area dating is a **lookup** across matching lines.

### Why append-only

Trimming to `N` lines lost historical coverage: on a large project (40+ areas), after 11+ audits, actually audited areas fell out and became "never audited" for weighting, so the skill proposed them again. Append-only fixes this at negligible cost (one audit ≈ one line; 100 audits ≈ 100 lines; instant read).

### `rolling_size` override

If `<!-- rolling_size: N -->` appears at file top (before `#`), **use it** instead of automatic calculation, even outside `[3, 10]`. The user knows what they want; do not challenge it. The override affects only **active rolling size**—not file size (always unbounded) or historical coverage (always entire file).

### Crosscut lines

Crosscut mode (see `references/mode-crosscut.md`) writes history lines with discriminator `crosscut:<DIM>` instead of an area path:

```
- 2026-05-11 — crosscut:DUP — 4 findings (1 HIGH, 3 MED) (pending)
- 2026-03-08 — crosscut:BND — 0 findings (clean)
- 2026-02-19 — crosscut:DED — 2 findings (2 MED) (pending) [partial: 8/23 areas]
```

**Partial-coverage annotation**: when the sweep covered only an area sample (tool-free fallback; see `references/mode-crosscut.md > C`), suffix `[partial: N/M areas]`. The annotation changes neither `<DIM>` extraction nor crosscut rolling (the line counts normally—no immediate re-proposal of the same dimension); it records that sampled `0 findings (clean)` is not full clean and a tool-assisted sweep remains relevant.

Filter these lines differently by use:

- **Zonal active rolling** and **zonal historical coverage** (uses 1 and 2 above): ignore `crosscut:*` lines. A crosscut consumes no zonal rolling slot.
- **Crosscut rolling** (additional use): read **only** `crosscut:*` lines, extract `<DIM>`, retain the latest `Nx = 6` to exclude those dimensions from automatic next-crosscut selection. Override with `<!-- crosscut_rolling_size: M -->` at file top.

`Nx = 6` is hard-coded (unlike zonal `N`, based on inventory size): it equals the number of default eligible dimensions, giving natural predictable round-robin once rolling fills—instead of weighted randomness returning to one dimension twice too soon (mechanism: see `references/mode-crosscut.md > B`).

## `<STATE_DIR>/maintainability_findings.md`

Source of truth for findings. Two sections (`## Pending`, `## Resolved`) plus an ID-counter header.

```markdown
# Maintainability findings

<!-- id_counters: DUP=7, SIZ=3, CPX=2, INC=2, DOC=1 -->

## Pending

### DUP-007 — HIGH — services/billing/refund_handler.py:42-67
- **Dimension:** code duplication
- **Observation:** Refund logic duplicated 3× with minor variations (l. 42, 89, 134).
- **Recommendation:** Extract to `_apply_refund_policy(order, policy)`.
- **Δ LoC:** ~-40 (3 copies of ~25 LoC merged into a ~30-LoC helper).
- **Detected:** 2026-05-03 (area audit services/billing/refund/)
- **Status:** pending

### SIZ-003 — HIGH — core/api_handler.py
- **Dimension:** god file (1842 LoC, 23 functions, 4 responsibilities)
- **Observation:** File mixes routing, validation, persistence, formatting.
- **Recommendation:** Split into `routing.py`, `validation.py`, `formatting.py`; persistence moves to `db/api_log.py`.
- **Δ LoC:** ~+120 (split into 4 modules with shared imports/signatures, ~30 LoC boilerplate per module).
- **Detected:** 2026-04-22
- **Status:** pending
- **Double-check (2026-04-25):** Blast radius: 47 imports, 12 tests affected. Effort M (~1 day, 4 incremental commits). Feasible with minor constraints (preserve transactions). Refined Δ LoC: ~+85. Verdict: GO, prioritize after TST-009. Benefit: each `api_handler` responsibility becomes independently testable and unblocks the planned routing refactor.

## Resolved

### DUP-005 — MED — services/auth/login.py:23 (resolved 2026-04-16)
- **Dimension:** code duplication
- **Resolution:** Extracted to `services/auth/_helpers.py`. Measured Δ LoC: -32. Commit: a7b3d12.
- **Audit origin:** 2026-04-15 (services/auth/)
```

### Format rules

- Entry heading: `### <ID> — <SEVERITY> — <location>` (plus `(resolved YYYY-MM-DD)` for Resolved).
- `<location>` = `path:line`, `path:start-end`, or path only (god files).
- **Multi-file findings** (typically from crosscut, `references/mode-crosscut.md`, but also possible in zonal audit when the observation naturally spans locations): title `<location>` = *primary* file (majority occurrence, or alphabetically first on a tie); `Location` bullet lists every file/line involved (multiple lines or `path1:line, path2:line, …`).
- **Pending**—bullets in this order: Dimension, Location (multi-file only), Observation, Recommendation, Δ LoC, Detected, Status, then optional sections (Double-check—always **after** `Status`). `Status` values:
  - `pending` (initial),
  - `stale (YYYY-MM-DD) — <reason>` (set by `update` when file is missing **and** self-heal investigation is inconclusive; see `references/mode-update.md > step 2.b`),
  - `stale-after-<ID> (YYYY-MM-DD) — <reason>` (set by cascade when fix for `<ID>` invalidates location; may be resolved or relocated by the next `update` through self-heal).
- **Resolved**—compact 3-bullet format: Dimension, Resolution, Audit origin. See below.
- ID is immutable. Any other attribute may be amended.
- `<!-- id_counters: PREFIX=N, ... -->` header caches ID counters for fast assignment (see *ID counters*). Absent from a freshly bootstrapped file; added on first ID assignment.
- **Resolved cap = 8** (single canonical skill value). `## Resolved` is capped at 8 entries; oldest entries automatically move to `maintainability_resolved_archive.md` (see *Finding lifecycle* step 5).

### Compact resolved-entry format

For every move to `## Resolved` (in-session, update, post-double-check NO-GO). **Drop**: Observation, Recommendation, initial Δ, Status, Double-check. **Keep** exactly 3 bullets:

```markdown
### DUP-011 — LOW — crates/bot/src/web.rs (resolved 2026-05-06)
- **Dimension:** vault scaffolding duplication
- **Resolution:** Added helper `vault_blocking<F,T>`; migrated 4 sites. Measured Δ LoC: -30. Commit: 86518fb.
- **Audit origin:** 2026-05-05 (crates/bot/src/web.rs)
```

`Resolution` must contain: short fix description + `Measured Δ LoC: <value>` + `Commit: <hash>` (or `Commits: <h1>+<h2>`). **Fix uncommitted at resolution time** (normal: the skill never commits; see SKILL.md > Cross-cutting conventions): write `Commit: uncommitted`—never invent a hash; a later `update` may fill it when identifiable (see `references/mode-update.md > step 6`). `Audit origin` repeats the date and area of the audit that produced the finding.

**Archived NO-GO case** (see `references/mode-audit.md > H. Autonomous double-check proposal`): `Resolution` gives the NO-GO rationale in 1–2 sentences; `Δ LoC: N/A (NO-GO)` replaces measured Δ.

Existing verbose Resolved entries remain valid—no retroactive rewrite.

## `<STATE_DIR>/maintainability_resolved_archive.md`

Cold storage for `## Resolved` entries exceeding the cap. **Never read by default**: load only during `update` (counter recomputation) and `archive-clear`. Lazily create on first overflow.

```markdown
# Maintainability resolved archive

### DUP-001 — MED — services/auth/login.py:23 (resolved 2026-04-16)
- **Dimension:** code duplication
- **Resolution:** Extracted to `services/auth/_helpers.py`. Measured Δ LoC: -32. Commit: a7b3d12.
- **Audit origin:** 2026-04-15 (services/auth/)

### CPX-002 — HIGH — core/api_handler.py:88 (resolved 2026-04-22)
- ...
```

### Format rules

- No `## Pending` / `## Resolved` sections (entire file is one large `## Resolved`).
- Entries use exactly the strict `## Resolved` format from findings (title + 3 compact bullets), moved intact—compaction already occurred when moved to `## Resolved`. **Legacy verbose** entries archived before compact format may remain—valid, no retroactive rewrite.
- Append-only at file end (order = resolution chronology, oldest to newest).
- Archived-entry IDs remain referenced in `maintainability_history.md` (`(resolved DUP-001+...)` lines)—no history update during archival.
- Read explicitly only by the user (`grep`, editor, or conversational request "look at the archive and …"). No dedicated skill mode.

## ID counters (cached header)

`maintainability_findings.md` contains an HTML-comment header caching the assigned maximum per prefix:

```markdown
<!-- id_counters: DUP=12, CPX=8, SIZ=5, INC=4, DRF=2, BND=1, TST=2, DOC=4, DED=4, CFG=1 -->
```

**Assigning a new ID**: read the prefix counter from the header and **reconcile it with actual data before incrementing**: `effective_counter = max(header_value, largest NNN observed for this prefix in findings)`, then increment, write the finding with the new ID, and update the header line. Scanning findings alone prevents an **active collision** (two live entries sharing an ID) after manual header drift—near-zero cost because findings is already in context. The archive need not be reread then (archived IDs are covered by the `update`/`archive-clear` self-heal recomputation scanning both files): the header remains a data **cache**, never an independent source of truth.

**New prefix** (first finding in a new dimension such as `LOG-`, `RAC-`, or another invention): add `<PREFIX>=1` to the header.

**Missing header** (migration from pre-archive state, or manual deletion): one-shot scan of `maintainability_findings.md` + `maintainability_resolved_archive.md` (if present), compute maxima per prefix, write header. One-time cost, never repeated afterward.

**Self-healing**: on every `update`, recompute counters by rescanning both files. Together with `archive-clear`, these are the only times the archive is read—acceptable because both operations are rare and explicit.

Format: 3 digits (`DUP-007`); may grow beyond (`DUP-1042` remains readable).

**Never reuse an ID**, even after the user manually deletes an entry, and even after archival. Counter increases monotonically. If maximum found = `DUP-005` but the user deleted `DUP-005`, next is `DUP-006` (not `DUP-005`).

## Finding lifecycle

1. **Creation** during audit → `## Pending` entry with ID, dimension, severity, observation, recommendation, date, `Status: pending`.
2. **Double-check** (`double-check` mode with `<ID>`) → add a dated `Double-check` section to the existing entry. May amend recommendation. May reveal severity change (propose to user, approve, then amend attribute).
3. **In-session resolution** → when the user applies a fix in the conversation following an audit or double-check, propose marking resolved:
   - Move entry to `## Resolved` in **compact format**—drop Observation, Recommendation, initial Δ, Status, Double-check.
   - Add `(resolved YYYY-MM-DD)` to title.
   - `Resolution` contains short fix description + `Measured Δ LoC: <value>` (measure via `git diff --stat` or direct count; measure during the conversational turn where possible) + `Commit: <hash>` for the commit applying the fix.
   - Update matching history line: `(resolved DUP-007)` → `(resolved DUP-007+SIZ-003)` for multiple fixes.
   - **Trigger cascade re-verification** on pending findings whose locations overlap the fix diff (see `references/cascade.md`). Integrate result into the **same primary confirmation prompt**.
4. **Update** (`update` mode) → re-verify each pending finding:
   - Pattern still present → status unchanged.
   - Pattern absent → move to Resolved in compact format; `Resolution` says `detected resolved during update (YYYY-MM-DD)` + measured Δ + `Commit: <hash>` if identifiable via `git log`.
   - File missing/moved → **self-heal investigation** (see `references/mode-update.md > step 2.b`). Outcomes: pattern found elsewhere → one-touch relocation; pattern dissolved → auto-resolve with cited commit; insufficient signals → `Status: stale` (or preserve cascade-set `stale-after-<ID>`), then user arbitration.
5. **Automatic archival** → after each move to `## Resolved` (steps 3, 4, or audit mode's autonomous *NO-GO case*):
   - Count entries in findings `## Resolved`.
   - If > cap (8): move oldest entry/entries to `maintainability_resolved_archive.md` until count equals cap. Determine age from `(resolved YYYY-MM-DD)` title date—smallest date moves first. Date tie-break: file order (highest entry in section moves first).
   - If archive absent, create it with header `# Maintainability resolved archive\n\n`, then append the entry.
   - Append at archive end (archival order = resolution chronology).
   - Move entry intact (compaction already happened on move to `## Resolved`).
   - Findings `<!-- id_counters: ... -->` header is unaffected (IDs remain monotonically increasing).
