---
name: performance
argument-hint: "[<path> | feature <description> | list | update | double-check <PERF-ID>]"
description: "Measure, audit, track, deep-check, and resolve software performance bottlenecks with reproducible workloads and before/after evidence. Use for targeted paths or product features, automatic performance audits, latency/throughput/CPU/memory/I/O/contention/scalability investigations, performance regression triage, persistent PERF findings, board/update workflows, and measured optimization fixes. Excludes speculative optimization, unrelated correctness or security audits, accessibility, and stack selection."
---

# Performance skill

## Scope

Measure, diagnose, track, and resolve performance problems without turning static intuitions into conclusions. **The skill measures first**: no persistent finding without an explicit workload, quantified baseline, and localized evidence. It does not modify audited code during an audit or double-check; a fix occurs only after a verdict and explicit confirmation, then must be validated by tests and comparable before/after measurements.

Include latency, throughput, CPU, memory/allocations, I/O, contention/concurrency, and scalability under measured load. Exclude general maintainability, security, accessibility, and stack-selection audits; verify correctness and maintainability as change guardrails, without making them independent audit axes.

**Orchestration exception:** an explicit invocation of the `performance-cycle` skill counts as bounded advance confirmation to select a safe, unambiguous local workload, double-check a finding, apply the fix from a GO verdict, persist its resolution if all before/after evidence requirements are satisfied, and archive a NO-GO verdict with no credible reevaluation scenario. Only in this context do selection, fix, resolution, and archival proposals become progress announcements; external-load, comparability, validation, and Git limits remain unchanged.

## References

This `SKILL.md` is a **thin router**. Read the references required by the current mode without loading the others:

- `references/doctrine.md` — workload contract, evidence hierarchy, hypotheses and exposure reasoning, measurement reliability, axes, severity, noise control, and maintainability guardrail. **Read before any audit, double-check, update, or fix.**
- `references/mode-audit.md` — bootstrap, inventory, materiality triage and automatic selection, path- or feature-targeted audit, measurement, profiling, and finding production.
- `references/mode-list.md` — read-only dashboard.
- `references/mode-update.md` — remeasurement of pending findings and handling of stale workloads or scopes.
- `references/mode-double-check.md` — in-depth reproduction, blast radius, verdict, and measured resolution.
- `references/file-formats.md` — normative formats for the three state files and finding lifecycle.
- `references/templates.md` — normative chat output formats. **Read before every mode output.**

## Mode dispatch

Infer the mode from user intent, independently of agent-specific syntax:

| Intent | Mode | Playbook | Input |
|---|---|---|---|
| Show the dashboard | **list** | `references/mode-list.md` | None |
| Remeasure pending findings | **update** | `references/mode-update.md` | None |
| Investigate a finding | **double-check** | `references/mode-double-check.md` | `PERF-NNN` ID |
| Audit a path | **audit path** | `references/mode-audit.md` | Existing path |
| Audit a feature | **audit feature** | `references/mode-audit.md` | `feature <description>` or unambiguous functional description |
| Automatically find the most relevant target | **audit auto** | `references/mode-audit.md` | None |

Accept compatible forms `/performance`, `/performance list`, `/performance update`, `/performance double-check PERF-001`, `/performance src/api`, and `/performance feature checkout`. With Codex, use the text accompanying `$performance` to choose the same mode.

Parsing rules:

1. An argument resolving to an existing path triggers `audit path`.
2. The `feature` prefix triggers `audit feature` with the remaining text.
3. Free text clearly describing product behavior triggers `audit feature`.
4. A direct fix request (`fix PERF-001`, French: "corrige PERF-001") routes to `double-check` for that ID: there is deliberately no standalone fix mode; re-baselining and the verdict precede any modification.
5. A path-like but nonexistent argument, invalid ID, or unknown flag requires clarification; do not silently reinterpret it.
6. Without specifics, choose `audit auto`.

## Project root detection

Before any dispatch, confirm the root from `.git/`, `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `composer.json`, `Gemfile`, `pom.xml`, `build.gradle`, `.hg/`, or `.svn/`.

- Marker in `cwd`: continue.
- Marker in a parent: announce the detected root and ask to rerun from that root or confirm the operation here.
- No marker: stop and ask to run from a project.
- Explicit path: attach state to the root nearest that path.

## State directory

`<STATE_DIR>` = `<PROJECT_ROOT>/.code-quality`, shared by Claude Code and Codex. Create it only in a mode that writes. Unqualified names always mean:

- `<STATE_DIR>/performance_history.md`
- `<STATE_DIR>/performance_findings.md`
- `<STATE_DIR>/performance_resolved_archive.md`

The `list` mode creates nothing.

## Cross-cutting conventions

1. **Deterministic date.** Obtain every written or compared date with `date +%F`. If the command is unavailable, report it instead of inventing one.
2. **Delta writes.** Read state early, reread it immediately before writing, then insert or move only targeted blocks. Never regenerate an entire file from memory.
3. **Git without history mutation.** Freely read `git log/diff/show/blame/status`. Edit the tree only during a confirmed fix. Never run `git add`, `commit`, or `push`.
4. **Read-only source audit.** Audits and double-checks may produce build/profiling artifacts or ephemeral scripts under `/tmp`, but do not modify source code or versioned benchmarks.
5. **No implicit external load.** Never run a load test against production, a remote service, real data, or a billable operation without explicit authorization. Prefer the smallest representative local workload.
6. **Comparability before conclusions.** Compare only measurements obtained with the same workload, configuration, build mode, input size, and a sufficiently stable environment. Otherwise conclude `inconclusive`.
7. **Secret-free state.** Sanitize persisted commands and workloads: no token, secret, authentication header, personal payload, or sensitive environment value.

## Evaluation doctrine

Read `references/doctrine.md` before any decision. Essential invariants:

- A static signal or profiler hit is a candidate, never a finding by itself.
- Auto selection ranks by plausible materiality (sourced exposure × cost order of magnitude), never merely by workload availability; a scope with a demonstrable exposure ceiling is recorded as `skipped (exposure-capped)` without a harness.
- A hypothesis refuted by measurement or a recorded ceiling is a successful audit, not a failure.
- A finding requires a reproducible baseline, a metric, exposure, and evidence linking the cost to a concrete location or relationship.
- A gain below measurement noise is not a gain.
- An optimization that needlessly degrades correctness or maintainability is rejected or reframed.
- A less abstract specialization may be accepted if its gain is material, measured, localized, and documented.

## Chat outputs

Read `references/templates.md` before every output. Modes that write end with `Files updated: ...`; `list` remains strictly read-only. Separate the summary from any proposed action.

## End-of-mode invariants

Read and check the checklist at the end of the current playbook. A non-applicable item counts as checked. If an expected measurement, test, or write could not be performed, announce the partial state and its cause; never present an incomplete result as validated.
