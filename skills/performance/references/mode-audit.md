# Mode: audit

Reference loaded in **audit auto**, **audit path**, or **audit feature** mode. Read `references/doctrine.md` first, then `references/file-formats.md` before any write.

## Bootstrap

If performance state does not exist:

1. Create `<STATE_DIR>` if necessary.
2. Create `performance_history.md` with `# Performance audit history\n\n`.
3. Create `performance_findings.md` with `# Performance findings\n\n## Pending\n\n## Resolved\n`. Do not create a counter before the first finding.
4. Create `performance_resolved_archive.md` only when the Resolved cap first overflows.
5. Announce: `Bootstrapping performance for this project; no prior history.`

## Inventory, materiality triage, and automatic selection

### Build candidate targets

Inventory without indiscriminately reading the entire repo, combining two directions (see `references/doctrine.md > Hypotheses, exposure, and materiality`):

**Top-down — awaited operations.** Identify what someone actually waits for: versioned commands (Makefile, scripts, Cargo/Gradle targets, CI jobs), application startup, routes/pages on the user path, CLI commands, workers, jobs, and batches whose duration matters. Sources: manifests, package scripts, docs/README, `bench`/`benchmark`/`perf`/`load` directories, Lighthouse configs or performance budgets, profiling documentation.

**Bottom-up — structural hypotheses.** While scanning executable surfaces and data paths (handlers, parsing/serialization, queries, caches, processing loops), formulate static clues as **falsifiable hypotheses** attached to candidates: nested loops over variable data, N+1 I/O, visible copies/allocations, locks on a frequent path, synchronous calls in a loop, materialization of large datasets, work repeated on every call (reload, reparse). A hypothesis is never a finding and is never presented as one.

Complete the inventory:

1. Identify functional tests or fixtures able to exercise these surfaces without external traffic.
2. Cross-check Git activity: a surface modified since its last audit is `hot`. Exclude from the signal any commits identifiable as performance fixes, using the hashes stored in resolutions.
3. Exclude vendored/generated code, dependencies, huge fixtures, and build artifacts.

Each candidate carries: `<scope>`, main paths, **plausible materiality with its exposure sourcing**, any hypotheses, existing or proposed workload, possible metric, and execution safety level.

### Materiality triage

Classify each candidate as `high`, `medium`, `capped`, or `indeterminable` according to `references/doctrine.md > Plausible materiality`:

- Estimate exposure from evidence (configs, cadences, data sizes, Makefile, docs, who waits on the operation); never fabricate figures—exposure without evidence makes the candidate `indeterminable`, not `high`.
- **Capped:** the ceiling calculation must be explicit and citable (structural frequency × upper-bounded plausible cost). A capped scope leaves auto selection and is recorded in history before invocation ends—`skipped (exposure-capped: <short calculation>)`, see `references/file-formats.md`—once only: do not rewrite an existing skipped line while neither scope code nor exposure has changed. It remains auditable via an explicit path or feature.
- Triage is cheap and repeated for every auto audit; only its `skipped` conclusions are persisted.

### Select

Read all of `performance_history.md`. Build:

- `never_audited`: scope absent from every audit line in history (`skipped` lines are not audits);
- `hot`: scope code modified since its last audit—or since its `skipped` line, reopening triage;
- `cold`: no change since;
- `rolling`: the 4 most recently audited scopes (`skipped` lines ignored), or the value of `<!-- rolling_size: N -->` if present.

Compare `feature:` scopes by the bracketed paths, not the free description (see `references/file-formats.md`): a reworded feature materially covering the same paths is neither `never_audited` nor a new scope.

Prioritize deterministically, **materiality first, workload availability second**:

1. high materiality, never audited or hot, safe workload (versioned first, otherwise a credible local test/fixture/harness);
2. high materiality, never audited or hot, long or costly workload: propose this target with estimated cost/duration and request confirmation—never silently discard it for a weaker candidate that is easier to measure;
3. high materiality, never audited or hot, no known workload: propose the target and ask how to exercise it;
4. medium materiality, never audited or hot, safe workload;
5. indeterminable exposure: never the primary target while a candidate from 1–4 remains; otherwise propose it while stating the missing exposure information.

Exclude the rolling window while any candidate 1–4 exists outside it. At the same level, prefer the strongest sourced exposure, then alphabetical scope order. Estimate exposure from evidence; never fabricate a production frequency.

An unchanged cold scope is not automatically reselected: a measurement does not age when neither code, data, nor relevant environment has changed. It becomes a candidate again if it turns `hot`, on explicit request (path/feature), or when the user reports an environment or dependency change justifying remeasurement.

Use `selection:proposition` from `references/templates.md` with one primary target, its sourced materiality, up to two alternatives, proposed workload and metric, and newly excluded `exposure-capped` scopes. **Wait for user validation** before measurement.

### Material coverage reached

If no candidate 1–5 remains outside the rolling window—everything is capped, unchanged cold, or already covered—do not audit an immaterial scope merely to fill the invocation. Use `selection:coverage-stop`: summarize capped scopes with their calculations and unchanged cold scopes, then ask the usage question—*which operation feels slow?*—as a bridge to a targeted `feature` audit. Write any new `skipped` lines; write nothing else.

### Degenerate cases

- No executable code or identifiable workload: finish with `audit:inconclusive` and record the inconclusive result in history.
- All remaining candidates are rolling, capped, or unchanged cold: apply *Material coverage reached*.
- Non-Git repo: ignore the hot/cold signal and announce the degraded selection.
- Command estimated to be long, costly, or load-generating: request confirmation with expected cost/duration before execution.

## Path-targeted audit

1. Verify the path exists and belongs to the project.
2. Read all source files in the reasonable scope, plus the call sites/tests/benchmarks needed to know how to exercise it.
3. If the path exceeds a credible reading budget or contains multiple independent subsystems, propose 2–3 subscopes; continue over the whole path only if the user insists.
4. Identify an operation that actually exercises the path. Do not benchmark an isolated function if its cost does not represent its usage.
5. If multiple workloads are plausible and would change the conclusion, present them and ask which to retain.
6. An explicitly requested path is audited even if prior triage classified it `exposure-capped`: restate the expected ceiling in the measurement plan—documentary measurement remains legitimate on request.

## Feature-targeted audit

1. Restate the feature as an observable scenario without broadening the intent.
2. Locate entry points via routes, commands, UI/API contracts, tests, and symbol search.
3. Trace main call sites and the data path to I/O boundaries; produce an explicit path list.
4. Identify the test, benchmark, or local scenario exercising this feature.
5. If the feature → code or workload mapping remains ambiguous, show the resolved scope and request validation before measurement.
6. Keep `feature:<short-description> [main paths]` as the history key. If a history line already materially covers the same paths, reuse its exact description instead of rewording it.

## Measurement plan

Before execution:

1. Define the workload according to `references/doctrine.md > Workload contract`.
2. Choose one primary metric and at most two useful secondary metrics.
3. If triage attached hypotheses to the target, define the minimal experiment that would falsify each—measurement tests hypotheses; it does not "see what happens."
4. Identify an existing budget/SLO. If none exists, do not invent one; define what would constitute a difference both beyond variance and material relative to exposure (the gain order of magnitude that would justify the change), then note that the business target remains to be specified. Acceptance reduced to "better than noise" would resolve immaterial gains.
5. Choose warmup, repetitions, and statistic.
6. Capture a short environment signature: build mode, relevant runtime/toolchain versions, OS/architecture or container/CI.
7. Define the minimal correctness command to run before/after if one exists.
8. Sanitize every command intended for state.

For an auto audit, the plan is part of the target proposal. For an explicit path/feature, proceed directly if the workload is safe, local, and unambiguous; otherwise request validation.

## Execution

1. Verify the scenario works and targeted correctness tests pass. A functional error is not a valid performance measurement.
2. Run warmup, then the baseline with enough repetitions. Retain aggregate values and dispersion, not only the best run.
3. Repeat a small sample if results are unstable. If instability remains too high, conclude `inconclusive`.
4. Profile the same workload with the most relevant available tool. Avoid directly comparing profiler-overhead time with unprofiled time.
5. Link dominant costs to files/lines, queries, locks, allocations, or I/O boundaries.
6. Compare triage hypotheses with the profile: confirmed, refuted, or replaced by what measurement reveals. For each retained lead, formulate a falsifiable hypothesis and bounded recommendation; do not implement during the audit. Record a refuted hypothesis in the history line—a first-class result, not a failure.
7. Apply the maintainability guardrail from `references/doctrine.md`.

## Producing and writing findings

Produce a finding only if all conditions hold:

- explicit and reproducible workload;
- quantified baseline with measurement context;
- material impact relative to dispersion, budget, or exposure;
- evidence localizing or attributing the cost;
- credible local action;
- evaluated maintainability/correctness tradeoff.

For each finding:

1. Calibrate HIGH/MED/LOW via `references/doctrine.md`.
2. Assign the next `PERF-NNN` ID according to `references/file-formats.md`.
3. Write the strict Pending format, with sanitized workload and commands.
4. If an existing pending finding describes the same scope + metric + bottleneck, do not duplicate it. Add or refresh a `Latest observation (date)` section and cite the existing ID in the output.

Then prepend a line to `performance_history.md`: findings, measured clean, or inconclusive. The result parenthetical is one short sentence—the dominant metric, reason for immateriality, and refuted hypotheses where applicable; detailed narrative does not belong in history (see `references/file-formats.md`). At the same time, write `skipped` lines for scopes newly capped during triage. Never trim history.

## Output

- Findings produced: `audit:summary`.
- Valid measurement without an actionable bottleneck: `audit:clean`.
- Insufficient evidence or impossible workload: `audit:inconclusive`.
- Triage with no remaining material target: `selection:coverage-stop`.
- With findings, propose a double-check via `audit:proposition`.

## End-of-mode invariants

- Workload, metric, baseline, and environment present for every finding.
- No finding derived from a static signal alone.
- Auto target selected by sourced materiality; no `exposure-capped` scope selected automatically.
- `skipped` lines written for newly capped scopes, deduplicated against existing ones.
- Findings added as deltas under `## Pending` and counter updated, or none if clean/inconclusive.
- A history line prepended for every executed audit; refuted hypotheses mentioned in the clean line.
- Persisted commands sanitized.
- Source code unmodified.
- Result explicitly distinguished among `clean`, `inconclusive`, and triage stop without an audit.
