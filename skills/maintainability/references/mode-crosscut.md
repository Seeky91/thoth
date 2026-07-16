# Mode: crosscut

Reference loaded by SKILL.md in **crosscut** mode. Cross-area sweep over **one inherently cross-cutting dimension**—detects patterns a zonal audit cannot see by construction (cross-area duplication, divergent conventions, parallel types, global dead code, boundary violations). The cross-cutting conventions (deterministic date, delta writes) and evaluation doctrine live in SKILL.md and apply here.

## A. Bootstrap

Same logic as `references/mode-audit.md > A. Bootstrap`. If `<STATE_DIR>/maintainability_*.md` is absent: create it, announce *"Bootstrapping maintainability for this project; no previous history."*, then continue.

## B. Dimension selection

One dimension per invocation (fine granularity, more precise than a multi-dimension sweep). Eligible: `DUP`, `INC`, `DRF`, `DED` (global), `BND`, `ARC`. Others (`CPX`, `SIZ`, `IDM`, `TST`, `CFG`, `DOC`) are inherently intra-area—not eligible. (`ARC`, like `DUP`, also exists zonally—cohesion is judged during audit, deep coupling during crosscut; see `references/dimensions.md > ARC dimension framing`.)

Algorithm:

1. **Read all of `maintainability_history.md`**. Parse `- YYYY-MM-DD — crosscut:<DIM> — …` lines (ignore zonal lines for this computation).
2. `Nx = 6` (override via `<!-- crosscut_rolling_size: M -->` at the top of history). With 6 eligible dimensions and `Nx = 6`, active rolling is full after 6 consecutive invocations—the system then naturally switches to round-robin through the degenerate case below (each dimension is crosscut again in turn before returning to the first).
3. Views:
   - `active_crosscut_rolling` = the `Nx` most recent dimensions among crosscut lines.
   - `never_crosscut_dimensions` = `{DUP, INC, DRF, DED, BND, ARC} − {all dimensions seen in crosscut lines}`.
4. **Candidates** = `{DUP, INC, DRF, DED, BND, ARC} − active_crosscut_rolling`.
5. **Weighting**:
   - Candidates in `never_crosscut_dimensions` → high priority.
   - Otherwise, a **lightweight preliminary signal** over remaining candidates (quick examination, not a mini-audit): exports without a visible call site → `DED`; neighboring symbols/similar signatures across areas → `DUP`; cross-area internal imports → `BND`; parallel types → `DRF`; multiple styles for one concept (3 pagination methods, 2 error formats) → `INC`; import-graph cycles or repeated cross-module co-change → `ARC`. Soft signals → weighted random.
6. **Chat announcement**: template `crosscut:dim-proposition`.
7. **User approval**: accept, request an eligible alternative, or impose one (including a dimension in rolling—the user knows what they want).

**Degenerate case**: if all dimensions are in rolling (common once ≥ 6 crosscuts have occurred with default `Nx = 6`), relax it: propose the least recently crosscut dimension and announce *"All dimensions are in rolling—I selected the oldest: `<DIM>` (crosscut on YYYY-MM-DD)."* This is the expected round-robin mode.

## C. Execution

For the approved dimension, scan the **entire project** (same exclusions as zonal-audit inventory: `node_modules`, `.git`, `dist`, `build`, `vendor`, `target`, `.venv`, generated files). The area inventory (`references/mode-audit.md > B`) is a map for structuring cross-area comparisons—not for selection, only useful partitioning.

**Scalability (crosscut lacks zonal audit's 5000-LoC guardrail—`references/mode-audit.md > D.3`—by construction).** A whole-project scan by full reading does not scale on a large repo, especially for `DUP`/`DED`, which compare all areas. Therefore:
- **Prefer a tool** when available (see `references/dimensions.md > Opportunistic detection tools`—repo-wide `jscpd` for `DUP`, `knip`/`deadcode`/`cargo-udeps` for global `DED`, etc.), then judge candidates. This is the nominal path on a real-sized project.
- **Otherwise, bounded fallback**: sample the most relevant areas using the inventory map (same top-N as the *Activity signal* cost guardrail), rather than pretending to read everything, and **announce partial coverage** in chat (`coverage: N of M areas scanned—tool X unavailable`). Never imply false exhaustiveness—and **persist this limitation**: suffix the history line with `[partial: N/M areas]` (see `references/file-formats.md > Crosscut lines`). Without this annotation, a partial sweep enters rolling as complete and the restriction disappears after chat ends.

Intent by dimension (judgment, not prescriptive algorithm):

- **`DUP`**: functionally equivalent functions/blocks across areas. Prefer utility helpers (easy to factor); do not force business logic (often legitimately separate).
- **`INC`**: recurring concepts (pagination, error handling, logging, config, retries) implemented differently across areas.
- **`DRF`**: parallel types/schemas accidentally diverging (`User` in API + DB + client, `Order` in service + worker, etc.).
- **global `DED`**: public exports without a project call site. Bound to reasonable candidates (skip public plug-in APIs, framework hooks, exports re-exposed through barrel files).
- **`BND`**: cross-area imports bypassing the public API (`_*` Python, `internal/` Go, deep relative imports). Each violation = one finding (or a group for a repeated pattern). **Inter-module cycles/fan-in-out** revealed by an import-graph tool belong to `ARC`, not `BND` (see `references/dimensions.md > Boundaries between adjacent dimensions`: `BND` = declared boundary violated; `ARC` = the structure itself is defective).
- **`ARC`**: dependency-graph shape and project-wide responsibility placement—inter-module cycles, high fan-in × high-churn modules, temporal coupling (git co-change across boundaries without an import link), shotgun surgery, cross-cutting leaky abstractions. For heuristics, required friction evidence, and incremental recommendation, see `references/dimensions.md > ARC dimension framing`. Prefer graph tools + `git log` (language-agnostic)—full reading cannot reveal these patterns, and co-change needs no external dependency.

**Multi-file finding conventions**:
- Title: *primary* file (majority occurrence, or alphabetically first on a tie).
- `Location`: list every involved file/line (field accepts multiple lines).
- Prefix: standard (`DUP`, `INC`, `DRF`, `DED`, `BND`)—**no "crosscut" marker in the entry**. Cross-cutting nature is visible in multi-file `Location` and the matching history line.

**Existing applicable edge cases**: potential duplicates (reference existing ID in chat without duplicating), trade-off check (see `references/quality.md > When NOT to produce a finding`), reclassification (keep ID).

## D. Writes (append-only)

1. **Append findings** to `## Pending` in `maintainability_findings.md`. Assign IDs through the normal mechanism (same `<!-- id_counters: ... -->` counters as zonal audits—no fork).
2. **Prepend a new line** to `maintainability_history.md`:
   ```
   - YYYY-MM-DD — crosscut:<DIM> — N findings (X HIGH, Y MED, Z LOW) (pending)
   ```
   Partial sweep (sampled fallback): suffix `[partial: N/M areas]`.
3. **Do not trim**—append-only, like zonal audits.

### Clean dimension (0 findings)

- History line: `- YYYY-MM-DD — crosscut:<DIM> — 0 findings (clean)`—suffixed `[partial: N/M areas]` for a sampled sweep (partial "clean" is not complete clean).
- Append nothing to findings.
- Chat output: template `crosscut:clean`.

The history line matters—without it, crosscut rolling would propose the dimension again too soon.

## E. Chat output (post-crosscut)

- Findings produced → template `crosscut:summary`.
- 0 findings → template `crosscut:clean`.

## F. Post-crosscut proposal

If findings ≥ 1, **reuse** `references/mode-audit.md > H. Autonomous double-check proposal` unchanged (`audit:proposition` or `audit:proposition-min` depending on finding count), then `references/mode-audit.md > I. Post-batch-proposal action` for execution. Panel selection, criteria, and execution flows are **identical**—no duplication. Templates and mechanics are generic across audit types.

## End-of-mode invariants (crosscut)

Before returning control, validate (a box **not applicable** is considered checked; see SKILL.md > *End-of-mode invariants* for the cross-cutting rule):

- User approved the dimension (template `crosscut:dim-proposition`) before execution.
- Findings appended to `## Pending` in `maintainability_findings.md`—one per produced finding (or none if clean). Multi-file findings use title `<location>` = primary + `Location` bullet listing all files.
- `<!-- id_counters: ... -->` header incremented for every used prefix (same counters as zonal audits, no fork).
- New line prepended to `maintainability_history.md` in `- YYYY-MM-DD — crosscut:<DIM> — ...` format, suffixed `[partial: N/M areas]` for sampled sweeps. **No trim**—history is append-only.
- If bootstrap occurred: `<STATE_DIR>/maintainability_*.md` files created with initial content.
- If post-crosscut proposal was selected: corresponding mode invariants (`references/mode-double-check.md` for single, *In-session resolution* in `references/mode-update.md` for fix) apply.
