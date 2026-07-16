# Mode: archive-clear

Reference loaded by SKILL.md in **archive-clear** mode, with `[--all|--keep N|--older-than <duration>]`. Purge `maintainability_resolved_archive.md` according to the criteria. Always confirm before writing. The cross-cutting conventions (deterministic date) live in SKILL.md and apply here.

## Flow

1. If the archive does not exist: abort with *"No archive in this project; nothing to clear."*
2. Parse archive entries: extract the `ID` and `(resolved YYYY-MM-DD)` date from the title.
3. Compute `dropped` / `kept` from the args:
   - **Default** (no flag): drop entries resolved > 6 months ago.
   - `--older-than <duration>`: format `<integer><unit>` with units `d`/`m`/`y` (`m`=30d, `y`=365d). E.g. `6m`, `1y`, `90d`. Parse failure → *"Unrecognized duration `<input>`. Expected format: `6m`, `1y`, `90d`."*
   - `--keep N`: keep the N most recent entries (title date).
   - `--all`: drop everything.
4. **Recompute ID counters in memory**: scan findings + the complete archive **before** deletion and compute the future `<!-- id_counters: ... -->` header. This guarantees that future IDs remain monotonically increasing. **Write nothing at this stage**—confirmation has not yet occurred.
5. **User confirmation**: use template `archive-clear:confirm-all` (`--all`) or `archive-clear:confirm-partial` (other cases).
6. **Only after confirmation**, apply both writes together: the recomputed header in `maintainability_findings.md`, then rewrite the archive with only `kept` entries. If `kept = []` (`--all`): delete the file (lazy recreation on the next overflow). Refusal or cancellation → no writes, including the header.
7. Report in chat via template `archive-clear:done`.

## Guardrails

- Do not modify `maintainability_findings.md` (except the counters header) or `maintainability_history.md`. Dangling history references to a deleted archived entry remain—"see git" convention.
- Confirmation is mandatory in all cases, including the default—and **nothing is written before it** (the step 4 recomputation remains in memory until step 6).
- If the filter captures no entries: *"Filter `<criterion>` captures no entries. Archive unchanged."*—no write, not even the header.

## End-of-mode invariants (archive-clear)

Before returning control, validate (a box **not applicable** to the current case is considered checked; see SKILL.md > *End-of-mode invariants* for the cross-cutting rule):

- Archive rewritten with only `kept` entries (or deleted if `kept = []`, the `--all` case).
- `<!-- id_counters: ... -->` header recomputed—**calculated before** deletion, **written after** confirmation, never written if the user cancels.
- No write to history or findings (except the counters header).
