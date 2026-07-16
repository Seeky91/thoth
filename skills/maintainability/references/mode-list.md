# Mode: list

Reference loaded by SKILL.md in **list** mode. **No audit, no re-verification, no file writes.** Read-only access to the two project files.

## Flow

1. Read `maintainability_findings.md` and `maintainability_history.md`.
2. Count pending findings by severity. List IDs with a descriptive one-liner (observation excerpt, ~50 chars).
3. **Count and separately list stale findings** (pending entries whose `Status` bullet is `stale ...` or `stale-after-<ID> ...`)—separate from active entries because they require user action (relocate, mark resolved, or archive) before treatment. They remain included in total Pending.
4. List findings resolved in the last 30 days (filter on the date in the Resolved title). **Deliberate scope: only the `## Resolved` section** (cap 8)—do not reread the archive (design; see `references/file-formats.md`). If all 8 section entries fall inside the window, the list is probably truncated: report this (see template).
5. List active zonal rolling entries (the first `N` **non-`crosscut:*`** history lines; see `references/file-formats.md > Crosscut lines`). In list mode, `N` is the `<!-- rolling_size: M -->` override if present, otherwise **5 as the display default**—exact `N` depends on inventory size, which read-only list mode does not recompute.
6. **Crosscut rolling**: list the most recent `Nx` `crosscut:*` history lines (`Nx = 6` by default; override `<!-- crosscut_rolling_size: M -->`). Same line format as zonal rolling: `<date> — crosscut:<DIM> — <N findings (status)>`. Omit the section if there are no crosscut lines.
7. Detect groupable batches among **active pending findings only** (stale entries are excluded; see *Suggested batches*).

## Output

Use template `list:dashboard`. Degenerate cases:

- Zero active pending findings (possibly stale): display `Active pending (0): no actionable finding.` Keep the Stale section if non-empty.
- Zero stale: omit the entire Stale section (do not display `Stale (0)`).
- Zero audits: display `No audits in history. Invoke maintainability in audit mode to begin.`

## Suggested batches

**Detection** (read-only, no code analysis):

1. For each pending finding, extract ID, dimension prefix, path (title's *primary* path for multi-file findings), audit_origin (`Detected:` date), and content of the latest `Double-check` section if present.
2. **Explicit signals** (high priority) in Double-check, case-insensitive regexes: `bundle`/`bundler`, `sequencing`/`step \d+`, `after <ID>`/`before <ID>`, `coupled with <ID>`. Each mention of another known `<ID>` creates an edge; connected components are batches.
3. **Heuristic signals** (fallback): same exact path; otherwise same parent path + same dimension prefix; otherwise same audit_origin. Crosscut findings from the same run share audit_origin (crosscut date)—they may batch via this route without a special case.
4. Keep only batches of 2–5 findings. List explicit batches first, fill with heuristic batches. Display at most 3.
5. If no valid batch: display *"No obvious batch detected—the pending findings are independent."* and **omit** the selection prompt.

**Display format**: integrated into template `list:dashboard` (*Suggested batches* section).

**Recommendation**: mark a batch `★ recommended` by these criteria, in order:

1. **Smallest scope**: prefer 1 file > module > multi-module (low blast radius).
2. **Explicit signal**: prefer an explicitly signaled batch over a heuristic one.
3. **Smallest `|Δ LoC|`** (most contained change).
4. **Tie-break**: smallest ID (`B1` > `B2` > …).

The short reason beside `★` repeats the deciding criterion (e.g. `1 file, low blast radius`, `explicit co-design`, `contained Δ LoC`).

If no batch stands out (≥ 2 batches exactly equal on all 4 criteria): do not mark `★`. The action prompt becomes *"Several equivalent batches—choose by priority (`double-check B<n>`, `fix B<n>`, `nothing`)."*

**Action based on user response**:

- **`double-check B<n>`**: run `references/mode-double-check.md` flow on each batch finding in order. Aggregate output via `double-check:autonomous-batch`, followed by `double-check:autonomous-batch-proposition`. For action after the user's choice, see `references/mode-audit.md > I. Post-batch-proposal action`.
- **`fix B<n>`** (execution always applies the checkpoints below—the user need not specify them):
  1. Plan per finding (1–3 lines: files touched, order, expected Δ LoC)—reuse `Refined recommendation` if present, otherwise `Recommendation`.
  2. Display the global plan; require explicit approval. If approved, execute in order.
  3. **Before** marking each `Resolution`, run the test suite (detected from markers: `cargo test`, `npm test`, `pytest`, `go test ./...`, etc.; otherwise ask for the command). Tests pass → in-session resolution flow. Tests fail → stop, do not mark, report; no automatic revert.
  4. Automatic **cascade re-check** after each batch resolution (see `references/cascade.md`)—without a new prompt because step 2's global-plan approval covers it.
  5. Final recap via template `cascade:recap-batch`.
- **`nothing`**: finish without action.

**Degenerate cases**: invalid batch ID (`"B5"` when only B1/B2 are listed) → ask to rerun `list`. Finding resolved between `list` and action → skip and report.

## Project without state

If `<STATE_DIR>/maintainability_*.md` do not exist, **do not bootstrap** (list mode is read-only). Report: *"No maintainability audit exists for this project. Invoke the `maintainability` skill in audit mode to bootstrap."*

## End-of-mode invariants (list)

No writes expected—verify no project file was modified during this strictly read-only mode. If the user triggered `double-check B<n>` or `fix B<n>`, the corresponding flow invariants (`references/mode-audit.md > I` or *In-session resolution* in `references/mode-update.md`) apply.
