# Mode: update

Reference loaded in **update** mode. Read `references/doctrine.md` and `references/file-formats.md`. Remeasure existing findings; do not search for new bottlenecks.

## Prepare the update

1. Read every Pending entry in `performance_findings.md`.
2. Extract each scope, workload, metric, baseline, acceptance criterion, environment, and latest observation.
3. Build a plan of commands, costs, and dependencies. Invocation authorizes short, already recorded local workloads; request confirmation before any long, remote, billable, or potentially destructive load.
4. If multiple findings share exactly the same workload and protocol, measure once and reuse the same observation with attribution specific to each finding.

## Recheck each finding

### 1. Scope

- Path present: continue.
- Path absent: search for a rename or move via Git and symbol search.
  - unique/strong signal: propose relocation, then continue if validated;
  - cost clearly removed with an identifiable commit: proceed to workload remeasurement before any resolution;
  - ambiguous signal: `Status: stale (date) — scope not found: <reason>`.

### 2. Workload

- Command and fixtures available: continue.
- Command renamed with an obvious replacement in the same manifest/history: propose the amendment before execution.
- Local dependency temporarily unavailable: `blocked (date) — safe measurement impossible without <condition>`.
- Workload gone or non-reproducible: `stale (date) — workload not reproducible: <reason>`.
- Never silently substitute another workload: it would change the meaning of the baseline.

### 3. Comparability

Compare build mode, input size, concurrency, runtime/toolchain, and environment. A documented minor drift may remain comparable; drift that could explain the difference requires a new reference series. In the latter case:

- write `Latest observation (date)` as a new non-comparable measurement;
- leave Pending;
- propose explicit re-baselining instead of concluding resolved/regressed.

### 4. Measurement

1. Run the targeted correctness test.
2. Replay the recorded warmup and protocol.
3. Calculate the metric and dispersion with the same method.
4. Compare against baseline and acceptance criterion:
   - acceptance satisfied, comparable environment, correctness OK, difference beyond noise → resolve;
   - bottleneck still present → leave Pending and add `Latest observation (date)`;
   - significantly worse result → leave Pending, add the observation, and report the regression;
   - variance prevents a conclusion → leave Pending and note `inconclusive` in the latest observation.

Do not mark resolved based on a static change alone.

## Resolution writes

For each resolved finding:

1. Move it to `## Resolved` in compact format.
2. Add `(resolved YYYY-MM-DD)` to the title.
3. Record before/after measurements, gain, dispersion, tests, and maintainability guardrail in `Validation`.
4. Identify the responsible commit only without ambiguity; otherwise use `Commit: uncommitted` or `Commit: indeterminate` for an external change.
5. Complete the original history line with `(resolved <IDs>)` via date + scope.
6. Apply the Resolved cap = 8.

Then recompute the `PERF` counter from findings + archive. Backfill a `Commit: uncommitted` only when a corresponding commit is identifiable without ambiguity.

## Output

Use `update:summary`. Report resolved, still present, regressed, non-comparable, relocated, stale, and blocked separately.

## End-of-mode invariants

- Every safe and executable Pending finding remeasured with its recorded workload.
- Every unsafe or costly command confirmed before execution.
- No silently substituted workload.
- Resolution based on comparable measurement + correctness OK.
- Latest observations written as deltas for retained findings.
- Resolved findings compacted, history completed, cap applied.
- `PERF` counter recomputed.
- Partial state and unexecuted commands announced.
