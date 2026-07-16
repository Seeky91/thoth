# Project file formats

Normative reference for performance state under `<STATE_DIR>`. Keep Markdown readable, diffable, and manually editable. Reread each file immediately before writing and apply only the targeted delta.

## `performance_history.md`

Append-only log, with each new line prepended:

```markdown
<!-- rolling_size: 4 -->
# Performance audit history

- 2026-07-15 — feature:checkout [src/checkout, src/db/orders] — 2 findings (1 HIGH, 1 MED) (pending) — metric: p95 latency — workload: `make bench-checkout`
- 2026-07-10 — src/serializer/ — 0 findings (clean — throughput within budget, per-call reparsing hypothesis refuted) — metric: throughput — workload: `cargo bench serializer`
- 2026-07-08 — src/db/migrations/ — skipped (exposure-capped: 1×/deployment × ~10 plausible upper-bounded ms)
- 2026-07-02 — feature:search [src/search] — 0 findings (inconclusive: unstable variance) — workload: `pytest tests/test_search.py`
```

Rules:

- Format: `- YYYY-MM-DD — <scope> — <result> — metric: <metric> — workload: <sanitized command>`. A `skipped` line has neither metric nor workload (no measurement): `- YYYY-MM-DD — <scope> — skipped (exposure-capped: <short calculation>)`.
- `<scope>` = path or `feature:<short-description> [main paths]`.
- A `feature:` scope's identity is carried by the bracketed paths, not the free text: two lines whose paths materially overlap designate the same scope even if their descriptions differ. Before writing a new feature line, reuse the exact description of an existing line that matches by paths.
- Result = `N findings (...) (pending|resolved ...)`, `0 findings (clean[ — <justification>])`, `0 findings (inconclusive: <reason>)`, or `skipped (exposure-capped: <calculation>)`.
- The result parenthetical must be **one short sentence**. Finding details live in `performance_findings.md`; a `clean` line contains at most the dominant metric, reason for immateriality, and refuted hypotheses.
- A `skipped` line is not an audit: the scope counts neither in the rolling window nor as covered by measurement. It blocks automatic reproposal of the scope until its code or exposure changes; do not duplicate it if the calculation is unchanged.
- The same scope may appear multiple times; locate the original audit by the exact date + scope pair.
- History is never trimmed. The rolling window is a view over the first 4 **audited** scopes (`skipped` lines ignored), with optional override `<!-- rolling_size: N -->`.
- An inconclusive line records the attempt but does not prove the scope is clean.

## `performance_findings.md`

Source of truth:

```markdown
# Performance findings

<!-- id_counter: PERF=7 -->

## Pending

### PERF-007 — HIGH — src/checkout/reprice.ts:88
- **Axis:** latency / I/O
- **Scope:** feature:checkout [src/checkout, src/db/orders]
- **Workload:** `make bench-checkout CASE=standard`; 200 synthetic orders, warmup 3, 15 repetitions, production build
- **Metric:** p95 latency
- **Baseline:** 428 ms p95; median 391 ms; p95 dispersion 18 ms; Linux x86_64, Node 24, production build
- **Observation:** 201 sequential reads are executed for 200 orders.
- **Evidence:** DB trace: 76% of time in `loadPrice`, called once per order from line 88.
- **Hypothesis:** loading distinct prices in one batch query will eliminate sequential round trips.
- **Recommendation:** preload distinct IDs, then resolve orders from a local map.
- **Acceptance:** p95 below the existing 250 ms budget, identical functional results, and no memory increase above the project budget.
- **Maintainability:** keep batching in the repository; do not expose the map to calling layers.
- **Detected:** 2026-07-15 (feature:checkout [src/checkout, src/db/orders])
- **Status:** pending
- **Double-check (2026-07-16):** reproduction 421 ms p95 (1.6% baseline delta); profile confirmed; blast radius 3 call sites/8 tests; effort M; verdict GO; refined plan: `loadPrices(ids)` in the repository; expected gain: eliminate 200 round trips.

## Resolved

### PERF-003 — MED — src/serializer.rs:44 (resolved 2026-07-12)
- **Axis:** CPU / allocations
- **Resolution:** buffer reused in the hot loop. Commit: uncommitted.
- **Validation:** before 82k ops/s, after 119k ops/s (+45%); dispersion 2.8%; targeted tests and project suite OK; maintainability guardrail OK.
- **Audit origin:** 2026-07-10 (src/serializer/)
```

### Pending format

Strict order: Axis, Scope, Workload, Metric, Baseline, Observation, Evidence, Hypothesis, Recommendation, Acceptance, Maintainability, Detected, Status, then optional `Latest observation` and `Double-check` sections.

Allowed statuses:

- `pending`;
- `stale (YYYY-MM-DD) — workload not reproducible: <reason>`;
- `stale (YYYY-MM-DD) — scope not found: <reason>`;
- `blocked (YYYY-MM-DD) — safe measurement impossible without <condition>` only if a specific external dependency prevents all remeasurement.

The ID is immutable. Severity, location, workload, and acceptance may be amended after double-check with a trace in the corresponding section.

### Compact Resolved format

Keep exactly four bullets: Axis, Resolution, Validation, Audit origin. `Resolution` describes the fix and states `Commit: <hash>` or `Commit: uncommitted`. `Validation` contains before/after measurements, relevant absolute/relative gain, dispersion, tests, and the maintainability guardrail verdict.

Cap `## Resolved` = 8 entries. Move the oldest to the archive after every resolution.

## `performance_resolved_archive.md`

Create lazily:

```markdown
# Performance resolved archive

### PERF-001 — MED — src/cache.ts:19 (resolved 2026-06-01)
- **Axis:** latency
- **Resolution:** ...
- **Validation:** ...
- **Audit origin:** ...
```

Do not add Pending/Resolved sections. Move intact compact entries to the end of the file. Read the archive only to recompute the counter, update, or fulfill an explicit request.

## ID counter

Use `<!-- id_counter: PERF=N -->` in `performance_findings.md`.

- Before assignment, compute `max(header_value, largest PERF-NNN present in findings)`, then increment.
- If the header is absent, scan findings and archive, compute the max, then write the header.
- On every update, rescan findings + archive and correct the header.
- Never reuse a deleted or archived ID.
- Minimum three-digit format: `PERF-001`.

## Lifecycle

1. **Audit:** create a Pending entry only with measured evidence.
2. **Double-check:** reproduce, investigate, and add a dated section; verdict GO, GO-but-after-X, NO-GO, or INCONCLUSIVE.
3. **Confirmed fix:** modify code, run tests and a comparable benchmark, then inspect the diff with the maintainability guardrail.
4. **Resolution:** only if acceptance is satisfied, correctness preserved, and gain exceeds variance. Move to compact Resolved format and complete history.
5. **Update:** remeasure pending findings; resolve those now satisfying acceptance in a comparable environment, retain those still present, tag stale ones.
6. **Archival:** if Resolved > 8, move the oldest to the archive; break ties by file order.

A fix without measurable improvement or with failing tests remains Pending. Never mark resolved because the code "looks faster."
