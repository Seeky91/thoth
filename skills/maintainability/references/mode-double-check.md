# Mode: double-check

Reference loaded by SKILL.md in **double-check** mode with an ID, for example `DUP-007`. Deepens an existing finding; it does not create a new finding. The cross-cutting conventions (deterministic date, delta writes) live in SKILL.md and apply here.

## Flow

1. **Locate the finding**: scan `maintainability_findings.md` and find entry `### <ID> — …`. If absent → ask the user for a valid ID (do not invent one).
2. **Read the referenced file** in full, plus neighboring/importing files. **Multi-file finding** (`Location` bullet listing several locations): read **all** listed files; blast radius becomes the union of call sites/tests/surfaces affected by each location.
3. **Trace**:
   - **Complete location**: all call sites, imports, and references to the relevant symbol/pattern.
   - **Blast radius**: tests touching the area, affected public surfaces, hidden coupling (what breaks if the proposed fix is applied).
   - **Initial recommendation feasibility**: does it hold? Is there a constraint (typing, public signature, circular dependency, external contract) that invalidates it?
   - **Estimated effort**: `S` (≤2h), `M` (≤1d), `L` (>1d, several commits). Separate from feasibility.
   - **Refined Δ LoC**: re-estimate in light of blast radius and constraints. If the difference from the initial estimate is > 50%, briefly explain why.
   - **Refined recommendation**: adjusted for discovered constraints, or alternatives if the original no longer holds.
   - **Verdict**: GO / NO-GO / GO-but-after-X.
   - **Benefit** (only for GO or GO-but-after-X—never for NO-GO): one concrete sentence naming what improves. Generic wording such as *"improves maintainability"* remains valid only when expanded with **how** the code becomes more maintainable in this specific case.
4. **Severity reclassification option**: if analysis shows HIGH was excessive (effort L but actual impact MED), propose the change to the user. **Do not change the ID.**

## Write to the findings file

Add a `Double-check (YYYY-MM-DD):` section to the existing finding entry, **immediately after the `Status:` bullet** (last position, per the normative bullet order—see `references/file-formats.md > Format rules` and its `SIZ-003` example). Format: one bullet containing all trace elements.

If severity changes, also modify the entry title (`### SIZ-003 — MED — core/api_handler.py`).

## Output

1. Summarize the verdict using template `double-check:output`.
2. Propose an action using template `double-check:proposition` (variant filtered by GO/GO-but-after-X vs NO-GO verdict).

## Action based on the user's choice

- **Fix now** (GO / GO-but-after-X verdict):
  1. Plan (1–3 lines: files touched, order, expected Δ LoC)—reuse the refined recommendation.
  2. Display the plan and require explicit approval. If approved, execute.
  3. Before marking `Resolution`, run the test suite (detected from markers: `cargo test`, `npm test`, `pytest`, `go test ./...`; otherwise ask for the command). Tests pass → in-session resolution flow (see `references/mode-update.md > In-session detection`). Tests fail → stop; do not mark.
  4. Automatic cascade re-check (see `references/cascade.md`).
  5. Final recap via `resolution:done`.
- **Archive** (NO-GO verdict): move Pending → Resolved in compact format, `Resolution: archived after double-check (NO-GO rationale: <reason>)`. Complete the matching history line. Respect the Resolved cap (see `references/file-formats.md > Finding lifecycle` step 5).
- **Later** / **Keep pending**: finish without further writes. The dated Double-check is already persisted.

## End-of-mode invariants (double-check)

Before returning control, validate (a box **not applicable** is considered checked; see SKILL.md > *End-of-mode invariants* for the cross-cutting rule):

- `Double-check (YYYY-MM-DD):` section added to the targeted finding entry.
- If severity reclassification was approved: title changed to `### <ID> — <NEW-SEV> — …`.
- If the user chose *Fix now*: *In-session resolution* invariants (`references/mode-update.md`) apply.
- If the user chose *Archive* (NO-GO): entry moved Pending → Resolved in compact format, `Resolution: archived after double-check (NO-GO rationale: <reason>)`, matching history line completed, Resolved cap respected.
