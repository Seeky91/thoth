# Performance doctrine

Normative reference to read before any audit, double-check, update, or fix. It defines what warrants a `PERF` finding, how to measure, and how to prevent an optimization from needlessly degrading the code.

## Workload contract

Every conclusion applies to an explicit workload, never to "the program" in general. Describe at least:

- the scenario or operation exercised;
- the reproducible command or procedure, sanitized if it contains sensitive parameters;
- the size and synthetic/real nature of the inputs;
- the build mode and configuration affecting the measurement;
- warmup, number of repetitions, and selected statistic;
- the environment relevant to comparison (OS/architecture, runtime/toolchain, local/CI/container), without persisting secrets.

For a feature, first trace its entry point, main call sites, and data path. For a path, identify the genuinely representative operation that exercises it. An isolated microbenchmark is valid only if the isolated cost actually dominates the user scenario or if the finding explicitly concerns that primitive.

## Evidence hierarchy

Use signals in this order:

1. **Reproducible end-to-end measurement**: latency, throughput, resources, or load curve on a representative scenario.
2. **Profile linked to that measurement**: CPU samples, allocations, I/O, contention, queries, or traces localizing the cost.
3. **Controlled experiment**: temporary variant or targeted disablement confirming the hypothesis.
4. **Static inspection**: algorithmic complexity, copies, visible I/O calls, or locks. Used to formulate a hypothesis, never to prove a finding on its own.

A persistent finding requires at least levels 1 and 2, except when an inherent inability to profile is demonstrated. In that case, a level-3 controlled experiment may replace the profile if it clearly attributes the cost. Without sufficient attribution, record an `inconclusive` audit, not a finding.

## Hypotheses, exposure, and materiality

Performance evidence lives in execution; **targeting** lives in the static layer. Three epistemic levels, from least to most expensive:

1. **Hypothesis** — an assumption from code reading and exposure reasoning. It carries a location, suspected mechanism, sourced exposure, and the minimal experiment that would falsify it. It ranks targets and guides the measurement plan; it has no ID, never enters the board, and is never presented as a confirmed problem.
2. **Finding** — a hypothesis confirmed through the evidence hierarchy (measurement + attribution). Threshold unchanged.
3. **Verdict** — a finding re-verified by double-check before any fix.

### Exposure reasoning

Estimate exposure **from evidence**, never from memory: observable configs and cadences (tick interval, heartbeat frequency, cron), real-data sizes and bounds, versioned commands (Makefile, scripts, CI), documentation, and who concretely waits on the operation (operator, end user, pipeline). Never fabricate figures: exposure without evidence is declared indeterminable. On the cost side, static reading provides only a **plausible order of magnitude**—caches, compilers, and real sizes defeat intuition; concluding a cost remains the exclusive role of measurement.

### Plausible materiality

Plausible materiality of a target = sourced exposure × plausible cost order of magnitude:

- **high** — an operation someone actually and frequently waits for, or a cost growing with unbounded data;
- **medium** — real but moderate exposure, or uncertain plausible cost with no demonstrable cap;
- **capped (exposure-capped)** — a structural exposure ceiling bounds any plausible gain below materiality, supported by an explicit calculation (e.g., migration 1×/startup × a few upper-bounded ms; loop ~1 Hz × ns–µs cost). Measuring a capped scope could produce no finding regardless of the result: record it without a harness;
- **indeterminable** — no exposure evidence available; declare it, never guess.

### Refutation is a first-class result

A measured and refuted hypothesis, or a capped scope recorded with its calculation, constitutes a successful audit: it documents where time is not being lost. Do not produce a consolation finding, and do not rerun a harness to re-demonstrate an already recorded ceiling when neither code nor exposure has changed.

## Comparable measurements

- Perform warmup appropriate for caches, JIT, pools, and connections.
- Run enough repetitions to observe dispersion; prefer median and percentiles over best times.
- Measure before and after in the same environment and as close together in time as possible.
- Keep data, concurrency, configuration, build mode, and external dependencies identical.
- Report variability or a simple interval. If the difference is the same order as the dispersion, conclude `inconclusive`.
- Avoid mixing compilation/startup time and steady-state unless startup is specifically the metric.
- For scalability, measure multiple load levels or input sizes and observe the curve, saturation, and backpressure; one point does not demonstrate a scaling property.

A baseline is not a bare number. Expected format: `<value> <unit>, <statistic>, <repetitions>, dispersion <value>, short environment/build`.

## Axes and severity

Seed, non-exhaustive axes:

| Axis | Example metrics |
|---|---|
| Latency | median, p95/p99, startup, time per operation |
| Throughput | requests/s, jobs/s, rows/s, bytes/s |
| CPU | CPU time, cycles, samples, utilization per unit of work |
| Memory | RSS, heap, peak memory, allocations/operation, retention |
| I/O | DB queries, reads/writes, bytes, network round trips |
| Contention | blocked time, lock wait, queue wait, pool saturation |
| Scalability | cost/size slope, throughput under concurrency, saturation point |

Severity = **measured impact × real exposure**:

- **HIGH** — SLO or capacity violation on a central/frequent path, saturation or unbounded growth threatening operation, confirmed major regression.
- **MED** — material and repeated cost, noticeably reduced capacity margin, or perceptibly slow feature, without immediate blockage.
- **LOW** — verified but low or weakly exposed cost. Do not retain a LOW whose potential gain is below noise or complexity cost.

Do not apply a universal threshold in milliseconds or percentages. One millisecond in a loop called a million times and 100 ms in a monthly task do not have the same exposure.

## When not to produce a finding

Do not create a finding when:

- no representative and safe workload is available;
- the baseline is not reproducible;
- the observed difference is absorbed by variance;
- the profiler does not link the cost to the targeted code and no experiment confirms the hypothesis;
- the cost mainly comes from an out-of-scope external service and no credible local action exists;
- the recommendation relies on intuition such as "allocations are slow" without measured impact;
- the proposed optimization trades a marginal gain for substantial correctness or maintainability debt;
- behavior is already within the agreed budget and no capacity constraint justifies the work.

An audit without a finding may be `clean` only if the workload was actually measured and meets the budget or shows no actionable bottleneck. Without sufficient measurement, use `inconclusive`.

## Maintainability guardrail

Evaluate this guardrail during recommendation, then on the fix diff:

- preserve correctness contracts and tests;
- avoid duplication, shared state, branches, and indirections without measured gain;
- confine any specialization to the demonstrated hot path;
- name concepts and document the **performance rationale** when code intentionally becomes non-obvious;
- retain or add the benchmark that makes the tradeoff verifiable;
- prefer the simplest variant when results are equivalent within variance;
- state any accepted debt in the finding and why the gain justifies it.

Cleanliness is not mechanical DRY. Locally duplicating a small loop or bypassing an abstraction may be legitimate if it removes a material cost, but only with evidence, confinement, and a regression benchmark.

## Tool selection

Prefer, in this order:

1. benchmark/load-test commands already versioned in the project;
2. native language/runtime instrumentation and profilers already available;
3. installed system tools (`hyperfine`, `/usr/bin/time`, `perf`, memory/I/O profilers);
4. an ephemeral harness under `/tmp` if the scenario remains representative and does not modify the project.

Detect tools opportunistically and adapt to the language. Do not install a dependency or contact an external service without authorization. A missing tool reduces depth, never the evidence requirements.

## Client and browser workloads

Code executed in a browser or graphical client is audited under the same doctrine; only the harness changes. A browser harness (Lighthouse, Playwright/Puppeteer with tracing, devtools profile) is a tool like any other in the preference order above and follows the same installation and authorization rules.

Web metrics are instances of the existing axes: LCP, INP, TTI, and frame time fall under latency; bundle weight and transferred bytes under I/O; script, layout, and paint time under CPU. A versioned performance budget (bundle size, Lighthouse thresholds) counts as an existing budget.

Specific requirements:

- exercise a production build served locally; a remote deployment remains subject to the explicit-authorization rule;
- fix CPU/network throttling, headless/headed mode, and browser version, and persist them in the environment signature;
- choose cold or warm cache as the measurement condition and state it; do not mix them in one series;
- browser runs are especially noisy: repetitions, median/percentiles, and dispersion apply strictly before any conclusion;
- measure bundle weight from the production build output, with the build command as the reproducible workload.

Without an available harness or a safe way to exercise the client, conclude `inconclusive`, as for any other workload.
