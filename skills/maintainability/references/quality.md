# Finding evaluation quality

Reference loaded by SKILL.md while running an audit, crosscut, or double-check to calibrate severity, anti-noise guardrails, and Δ LoC estimates.

## Severity scale

Severity = **impact × exposure**. It is not a preference; it calibrates the effect on code maintainability.

- **HIGH**—blocks or burdens every future change in the area.
  Examples: god file on a hot path; central composition root forcing every boot/runtime/web change into the parent; structural duplication (3+ copies of logic); widely used contract drift; brittle tests preventing any refactor; cycle between core modules; recurring shotgun surgery (each feature touches 5+ files).
- **MED**—noticeable but avoidable friction.
  Examples: entrypoint or subsystem root mixing orchestration and detailed wiring; local pattern inconsistency; moderate test redundancy; config sprawl across 2–3 modules; 2× duplication in a utility function; pass-through layer; localized feature envy.
- **LOW**—cosmetic cleanup without behavioral impact.
  Examples: stale comment; unused variable; trivial duplication in a rarely touched helper; documentation for a self-explanatory function; speculative generality in a rarely touched helper.

**Severity is mutable.** A `double-check` may reveal that something believed HIGH is actually MED (or vice versa). Then amend the entry's severity attribute; **do not change the ID.**

## When NOT to produce a finding

The skill is inherently detection-oriented, creating a structural bias toward overproducing findings to "justify" invocation. Without a counterweight, the audit drifts into **paperclip maximizing**: optimizing maintainability until other project qualities degrade. This section is that counterweight.

### Awareness of overproduction bias

An area yielding 0 findings across all dimensions is a **successful** audit, not a failed one. Operational consequences:

- Do not fill empty space to justify the invocation.
- If a dimension yields nothing after serious examination, move to the next without forcing it.
- If the entire area is clean, record it (history line `0 findings (clean)`) and stop—no "consolation" finding to appear productive.
- A dimension that never yields anything in a given area is not an audit failure; the code may be clean on that axis.

### Trade-off check against other project axes

If the recommendation would improve maintainability at the cost of visible degradation on another axis: **do not produce the finding** by default, or produce it while explicitly annotating the trade-off in `Recommendation`. Check these axes before production:

- **Performance**: abstraction adding per-call cost on a hot path, extra allocation, runtime indirection introduced by a helper, additional data copies.
- **Security**: removal of a check, widening an attack surface, sharing previously isolated state, making a previously scoped secret transitive.
- **Scalability**: removal of an extension seam; merging "nearly identical" variants that may diverge tomorrow; flattening that blocks a future responsibility; removing a layer of indirection that was a branching point. Oversimplifying today is costly when a feature must be accommodated later.
- **Paradoxical readability**: over-abstraction creating indirections harder to follow than the original duplication (pathological DRY: 3 divergent copies merged into an incomprehensible parameterized helper with a boolean changing behavior midway), or a dense functional chain/clever one-liner replacing three obvious lines with an expression that must be mentally unpacked.

**Default rule**: if the trade-off is significant, do not produce the finding. If a finding is produced despite an identified trade-off, annotate it in `Recommendation` so the user can decide with full context.

This check occurs **before** finding production. It does not replace double-check (which investigates feasibility of an existing finding)—it occurs one step earlier, at the decision to produce anything.

### Dogma ≠ defect

This applies especially to judgment dimensions (`ARC`, `IDM`, `CPX`). Deviation from a paradigm, pattern, or architecture school is **not** itself a finding. A finding requires a **concrete, citable, verifiable maintainability-friction symptom**: a change that had to touch N files, a call site bypassing the abstraction, a recurring bug pattern, a function nobody dares touch. "It does not follow X" (hexagonal, clean architecture, pure functional style, etc.) is never an observation—it is a preference. High density faces the **same bar**: it is a symptom only when the reading cost is concrete and citable (a real unnamed sub-concept, an important decision buried in detail, a sequence impossible to follow without retaining a stack of incidental elements), never from a mere sense that "it is too dense." The goal remains to make responsibilities legible without hiding important decisions behind vague names. Without a symptom: abstain. The multi-paradigm evaluation framework lives in `references/dimensions.md > Paradigmatic frame of reference`; this guardrail is its production-decision counterpart.

## Δ LoC estimate

Each finding must state an estimated `Δ LoC`: the source-line change produced by applying the recommendation. Format `~±N` (`~` marks an estimate; the sign shows net effect).

**Sign convention:**
- **Negative** (`~-40`): recommendation reduces code (deduplicating, removing dead code, merging variants).
- **Positive** (`~+30`): recommendation adds code (splitting a god file into modules with boilerplate, adding an abstraction layer).
- **Near-zero** (`~±5`): recommendation moves or rewrites without reducing (cross-cutting rename, local restructure, pattern harmonization).

**Audit estimation method:**
- Measure the size of involved occurrences (pattern lines × number of copies).
- Subtract the extracted helper/module size, including some boilerplate (signature, imports, docstring if needed).
- For god-file splits: estimate from the size of identified responsibilities + ~10–20% boilerplate (imports, signatures, re-exports).
- If the estimate is too uncertain to be useful (e.g. recommendation depends on unresolved architecture choices): record `Δ LoC: indeterminate—refine during double-check`.

**When applying the fix (resolution):** measure actual delta via `git diff --stat` or direct counting and record it in `Resolution:`. Format `Measured Δ LoC: -47`. This value, not the initial estimate, counts in summaries.

**During a double-check:** refine the estimate using the blast radius and discovered constraints. Format `Refined Δ LoC: ~-35`. If refinement contradicts the initial estimate (> 50% difference), briefly explain why.
