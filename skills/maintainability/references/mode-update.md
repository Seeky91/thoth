# Mode: update

Reference loaded by SKILL.md in **update** mode. **No new audit.** Re-verify all pending findings against current code and update statuses. The cross-cutting conventions (deterministic date, delta writes) live in SKILL.md and apply here.

## Flow

1. Read `maintainability_findings.md`. Iterate over each entry in `## Pending`.
2. For each finding:
   a. Read the file referenced by its location.
   b. **If the file cannot be found** (moved, deleted, renamed)—enter **self-heal investigation** before concluding. Use available tools as context warrants (git history, diff reading, codebase pattern search, history cross-check); for `stale-after-<ID>`, the primary commit is known and provides a direct signal. Three outcomes:
      - **Pattern clearly found at a new location** (strong signal: git rename ≥50% similarity, or unique pattern found at 1 location clearly matching the observation) → propose one-touch relocation (*"`<ID>` found at `<new-path>:<line>` (<signal used>). Relocate?"*). If approved: amend the title with the new path, reset `Status` to `pending`, then re-verify the pattern there as in step 2.c.
      - **Pattern dissolved** (clear pattern deletion in an identifiable commit, or no trace elsewhere in the codebase) → propose marking resolved (*"`<ID>` dissolved by <commit / refactor>. Mark resolved?"*). If approved: standard resolved flow (step 3), citing the responsible commit in `Resolution` when identifiable.
      - **Insufficient or ambiguous signals** (pattern too vague to scan, multiple non-discriminating hits, similarly named files risking a false positive, observation relying on human context) → mark `Status: stale` (or preserve a cascade-created `stale-after-<ID>`—causal information is more valuable), then handle at step 4.
      
      **Confidence threshold**: conclude only on strong evidence—a similarly named file is the classic false positive. When uncertain, fall back to stale tagging. Tool choice and sequencing remain with the agent; the skill specifies intent and constraints, not procedure.
      
      **User refusal of a self-heal proposal** (no to relocation or resolution) → treat as standard stale at step 4 (3 manual options). `Status` remains `stale` (or `stale-after-<ID>`, as applicable).
   c. **If the file exists**: verify that the observation's pattern is still present at the stated location (or nearby if lines shifted). Heuristic:
      - Read ~20 lines around the location.
      - If the described pattern (duplication, god-file size, etc.) remains recognizable → status unchanged.
      - If the pattern disappeared → move to Resolved.
      - **Multi-file finding** (`Location` bullet listing several locations, typically from a crosscut): read each and assess the pattern globally. Pattern dissolved at all locations → Resolved. Partially resolved pattern (1 of N occurrences cleared, but ≥ 2 remain) → status unchanged. If only 1 location remains, handle by dimension: `DUP` no longer makes sense with 1 copy → Resolved; `DRF`/`INC` may persist at 1 location if drift/inconsistency remains → unchanged; `ARC` (cycle, coupling) resolves when the structural **relationship** is broken (cycle broken, dependency inverted), not when one file changes → judge the relationship, not locations.
3. For each detected resolution:
   - Move the entry from `## Pending` to `## Resolved` in **compact format** (see `references/file-formats.md > Compact resolved-entry format`).
   - Add `(resolved YYYY-MM-DD)` to the title.
   - `Resolution` states `detected resolved during update (YYYY-MM-DD). Measured Δ LoC: <value>` (via `git log --since=<date> -- <file>` or direct comparison; otherwise `indeterminate`). Add `Commit: <hash>` if a downstream commit is identifiable.
   - Update the corresponding history line (the audit that created this finding): add or complete `(resolved <ID>+...)`.
4. For each stale finding **not resolved by self-heal investigation** (generic or preserved `stale-after-<ID>`): leave in Pending. `Status` was already adjusted in step 2.b. Ask the user in chat—a message adapted to the cause, briefly stating why self-heal did not conclude:
   - Generic stale: *"`<ID>` references a missing file; investigation was inconclusive (`<short-reason>`). Reopen with a new path, mark resolved (pattern no longer exists), or archive?"*
   - Stale-after: *"`<ID>` has been `stale-after-<primary-ID>` since the YYYY-MM-DD fix. Investigation was inconclusive (`<short-reason>`). Reopen with a new path, mark resolved, or archive?"*
   - **Escalate old stale entries** (termination bound for the arbitration loop): compare the date in `Status: stale (...)` / `stale-after-<ID> (...)` with the current date (`date +%F`). If older than **90 days**, stop offering the three options equally and switch to an **explicit archive default**—*"`<ID>` has been stale since <status-date> (> 90d unresolved). I will archive it (NO-GO: unresolved stale) unless you object."* The user may still reopen/relocate; this prevents an undecided stale entry from polluting the board indefinitely. Without escalation, it would remain Pending forever.
5. **Verify the Resolved cap invariant**: count `## Resolved` entries after moves. If > 8, apply automatic archival (see `references/file-formats.md > Finding lifecycle` step 5).
6. **Recompute ID counters**: rescan `maintainability_findings.md` + `maintainability_resolved_archive.md` (if present), recalculate each prefix maximum, update `<!-- id_counters: ... -->`. Self-heals drift. **During this rescan, backfill commits**: for each `Resolution` bullet with `Commit: uncommitted`, if a commit applying the fix is identifiable **unambiguously** (`git log` on cited files, diff/message matching the description), fill in the hash. Best effort—at the slightest doubt leave `uncommitted` (never guess a hash).
7. **Reconcile history → findings (read-only, report only).** The two step 6 files are already loaded; verify that every ID in `## Resolved`/archive appears in a history-line `(resolved <ID>+...)`, and conversely that no history line marks an ID still in `## Pending` as resolved. **No automatic corrective write**: on inconsistency (ambiguous date+zone matching, forgotten `(resolved …)`, or placed on the wrong line), **report it in chat** (*"inconsistent history: `<ID>` is resolved but no history line marks it—correct manually"*). `(resolved …)` is informational only (it drives no selection logic), so reporting suffices; `findings.md` remains the source of truth.

## Output

Use template `update:summary`.

## Cost

Potentially many reads (one per pending finding, plus self-heal investigation per encountered stale—proportional to stale count, not all pending findings). Acceptable: rare, explicit invocation; not run on every audit.

## In-session detection

Independently of explicit `update`, **during the conversation following an audit or double-check**, if the user applies a fix resolving a listed finding:

1. The skill **runs the cascade re-check read-only** (see `references/cascade.md`), then proposes batched confirmation via `resolution:confirm`—primary + cascaded + stale-after in one prompt. If overlap = 0 (no other pending finding on diff files): the template uses the simple variant without a cascade block.
2. If approved: apply the update flow to the primary (move Pending → Resolved, `Resolution` bullet, history line) **and** perform cascade writes (cascade-resolved in compact format, stale-after tags, completed history lines, Resolved cap respected).
3. **Confirm in chat** via `resolution:done`, detailing completed writes. On partial pushback at step 1 (user refused some items), output only what was applied.

This detection is **opportunistic, not exhaustive**. For systematic re-verification after several out-of-session fixes, the user invokes update mode.

## End-of-mode invariants

Before returning control, validate (a box **not applicable** is considered checked; see SKILL.md > *End-of-mode invariants* for the cross-cutting rule).

### Update

- Every pending finding re-verified.
- Detected resolutions moved to `## Resolved` in compact format.
- **Self-heal investigation run** on every pending finding whose file is missing (see step 2.b).
- **Auto-relocated stale entries** (strong rename/new-location signal): title amended with the new path, `Status` reset to `pending`, pattern re-verified there.
- **Auto-resolved stale entries** (pattern dissolved, fix identified): moved to `## Resolved` in compact format, `Resolution` cites the responsible commit if identifiable.
- Stale findings unresolved by investigation tagged `Status: stale`; existing `stale-after-<ID>` preserved (not overwritten). User arbitrates at step 4. **Stale > 90d escalated** to a proposed archive default (see step 4), not offered identically again.
- Matching history lines completed (`(resolved <ID>+...)`).
- Resolved cap applied (automatic archival if > 8).
- `<!-- id_counters: ... -->` header recomputed (self-heal by rescanning findings + archive); `Commit: uncommitted` backfilled when a commit is unambiguously identifiable (step 6).
- **History → findings reconciliation** run read-only (step 7); all inconsistencies reported in chat (no automatic correction).

### In-session resolution

Checklist for the *In-session detection* flow above (reused by `references/mode-double-check.md` *Fix now*, `references/mode-audit.md > I`, and `references/mode-list.md` `fix B<n>`):

- Entry moved Pending → Resolved in compact format.
- Complete `Resolution:` bullet (description + measured Δ LoC + Commit).
- `(resolved YYYY-MM-DD)` added to title.
- Matching history line updated.
- Cascade re-check triggered for a fix with a diff (see `references/cascade.md`).
- Resolved cap respected.
