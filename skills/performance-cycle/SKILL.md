---
name: performance-cycle
argument-hint: "[<N>] [--no-doc-cleanup]"
description: "Orchestrate one or more autonomous, goal-backed performance cycles from safe workload selection or pending PERF findings through mandatory re-measurement, double-check, one attributable optimization, tests, comparable before/after validation, ledger resolution, and one final scoped doc-cleanup pass. Use when the user asks for a complete performance optimization cycle, several automatic measured cycles, autonomous bottleneck resolution, or wants to avoid repeating the audit/double-check/fix/measure prompt. Supports subagents while serializing all measurements and mutations."
---

# Performance cycle

Orchestrate an autonomous campaign on top of the `performance` and `doc-cleanup` skills. Do not redefine their doctrine or formats: load their instructions, chain their modes, and preserve all their evidence invariants.

## Dependencies

Before acting:

1. Load the `performance` skill and the references required for each atomic operation.
2. Load `doc-cleanup` only during closeout, unless `--no-doc-cleanup` is present.
3. If the runtime cannot activate a skill by name, resolve the sibling skills `../performance/SKILL.md` and `../doc-cleanup/SKILL.md` from this directory.

The atomic skill remains authoritative for the root, workloads, comparability, state formats, tests, dates, and resolution criteria. If instructions conflict, this skill overrides only the interactive gates explicitly lifted below; all evidence and safety requirements still apply.

## Input

- `<N>`: target number of cycles, a strictly positive integer; default `1`.
- `--no-doc-cleanup`: disable documentation closeout.
- An unknown argument or invalid integer requires clarification. Do not guess.

Accept equivalent phrasing regardless of runtime, for example `/performance-cycle 3` with Claude Code or `$performance-cycle run 3 cycles` with Codex.

## Native goal

Explicit invocation requests and authorizes a **single native goal** covering at most `<N>` cycles, with an early stop when no measurable, actionable finding remains, followed by optional doc-cleanup closeout.

- Reuse an active goal that already covers the request; do not nest a second one.
- Create the goal before work if the runtime exposes this mechanism. Set a budget only if the user provides one.
- Without persistent goals, run the same loop in the current thread.
- Complete the goal only after validation, state writes, campaign invariants, and the requested doc-cleanup closeout. A measured clean audit or absence of GO findings is not a blocker.
- On a genuinely blocking stop, leave the goal active or apply the runtime's native policy; never declare it artificially complete.

## Bounded autonomous authorization

Invocation counts as advance confirmation to:

- select a **local, safe, short, and unambiguous** target and workload according to the `performance` ranking;
- record `skipped (exposure-capped)` lines produced by materiality triage;
- run the audit, choose a Pending finding, double-check it, and replay its baseline;
- apply a bounded fix after a `GO` verdict;
- directly persist resolution when tests, acceptance, gain outside variance, and the maintainability guardrail are all satisfied;
- archive a `NO-GO`—refuted hypothesis, non-actionable cost, or unjustified tradeoff—with no credible reevaluation scenario.

Only within this framework do the atomic skill's selection, fix, and resolution proposals become progress announcements. Continue without requesting new approval while the action remains within this scope.

This authorization never covers:

- a production, remote, billable, destructive, real-data-based workload, or one liable to generate external load;
- an abnormally long or heavy command, dependency installation, system configuration change, or invented business/SLO requirement;
- `git add`, `commit`, `push`, a destructive operation, or another audit domain;
- an ambiguous scope or workload whose selection could change the conclusion.

Request targeted authorization in these cases, or when a fix requires overlapping protected WIP.

## Initial campaign state

1. Resolve the root through `performance` and read persistent project context (`AGENTS.md`, `CLAUDE.md`, `.code-quality` state, benchmark commands, and validation conventions).
2. If `<STATE_DIR>/performance_campaign.md` exists, announce an interrupted campaign and resume its state if the current request continues it; otherwise ask before overwriting it. Never recapture its dirty baseline.
3. Capture `baseline_dirty_source_files` from `git status --porcelain=v1 -z`. Protect these files: choose another finding or request targeted authorization before any overlap.
4. Read the performance board and history before the first selection.
5. Track in memory: counter, current scope or ID, phase, `campaign_touched_source_files` (source files actually edited by fixes), and IDs non-actionable during the campaign.

### Campaign file

`<STATE_DIR>/performance_campaign.md` persists only orchestration state absent from the ledger.

- For `<N> > 1`, create it at startup.
- For a single cycle, create it only when scope warrants it: long workload, many artifacts or phases, subagent use, or concrete interruption risk. The normal short loop does not create one.
- If a single cycle without a file becomes blocked after a mutation, create the file before returning control to preserve resumability.
- Do not duplicate workloads, baselines, double-checks, or evidence already stored in `performance_findings.md`.
- This state file is not a source file: it never enters `baseline_dirty_source_files` or `campaign_touched_source_files`, and remains outside doc-cleanup scope.

Minimal format:

```markdown
# performance-cycle campaign
- Started: YYYY-MM-DD — target: <N> cycles — completed: <k>
- Current: <scope or PERF-NNN, or "none"> — phase: <selection|audit|double-check|fix|validation>
- Dirty baseline: <root-relative paths, or "none">
- Touched files: <root-relative paths, or "none">
- Non-actionable: <ID (verdict), ..., or "none">
- Blocker: <precise cause, or "none">
```

Update this file at phase boundaries, after each mutation, and after each cycle. Delete it at normal closeout; retain it on a blocking stop.

### Resume

When resuming a persisted campaign:

1. Reread the ledger and compare the current tree with the dirty baseline and recorded touched files. Treat any new campaign-external modification as protected WIP.
2. Resume `Current` and `phase` instead of selecting a new ID. Reuse no evidence whose code, workload, or relevant environment has changed.
3. In `selection`, `audit`, or `double-check` phase, cleanly replay the unfinished atomic phase.
4. In `fix` or `validation` phase, inspect the preserved diff and latest measurements before any action. Continue the same ID only if safe correction and validation remain possible within the authorized scope; otherwise preserve the blocker and request a targeted decision.
5. Never automatically delete, stash, or revert the diff of an unvalidated attempt, and never move to another finding until that attempt is resolved.

## Cycle definition

A cycle processes **one attributable performance hypothesis**: an existing Pending finding, or a finding selected after a new audit. It fixes only one `PERF-NNN`, even if the audit produces several, to preserve gain attribution.

The cycle is complete when the finding has been double-checked, then resolved, archived `NO-GO`, or declared non-actionable for the campaign. A measured clean or inconclusive audit without findings counts as a processed source, then causes an early stop instead of an artificial search for a fix. Triage concluding that material coverage has been reached stops the campaign before an audit—never run a box-checking audit on an immaterial scope. An unvalidated fix does not complete the cycle.

### 1. Choose the source

1. Prioritize an actionable Pending finding whose recorded workload is safe and reproducible.
2. With comparable evidence, rank by severity, exposure, measurement freshness, alphabetical scope, then ascending ID. Estimate exposure from evidence; never fabricate production frequency.
3. Exclude `GO-but-after-X` or `INCONCLUSIVE` IDs already encountered during the campaign while their condition remains unchanged. Reevaluate a newly satisfied prerequisite before making the ID actionable.
4. Reuse a `GO` double-check only after verifying that code, workload, relevant environment, and blast radius have not changed.
5. Without an actionable Pending finding, run `performance audit auto`, including materiality triage. Automatically retain the top target from the atomic ranking if its workload is local, safe, short, and unambiguous; announce the measurement plan without a gate. If the best material target requires a long or costly workload, request targeted authorization with estimated cost/duration instead of dropping to a more convenient immaterial candidate. If triage concludes that material coverage has been reached, record any `skipped` lines, stop the campaign early, and relay `selection:coverage-stop` in the recap.
6. If the audit produces several findings, select one ID for this cycle and leave the others Pending. If it is clean or inconclusive, count the processed source, then stop early.

### 2. Double-check

Run `performance double-check <ID>` completely before any source edit: reproduce the baseline, profile again, verify comparability, blast radius, risks, and refined acceptance, then persist the verdict. The double-check mode's same-session clause applies: a baseline and profile measured by the same cycle's audit may be reused without remeasurement when code/workload/environment remain intact—the double-check remains mandatory for alternative attribution, blast radius, risks, and acceptance.

- `GO`: proceed to the fix.
- `GO-but-after-X`: keep Pending, add to non-actionable, and do not fix before satisfaction followed by a new prerequisite check.
- `INCONCLUSIVE`: keep Pending, add to non-actionable, and propose no fix.
- `NO-GO`: archive using the atomic format regardless of reason; keep Pending only when a credible reevaluation scenario exists, then add it to non-actionable.

### 3. Fix and measure

1. Announce a short plan: files, mechanism, tests, benchmark, and maintainability risk.
2. If necessary, recapture an immediate `before` measurement with the recorded protocol.
3. Implement the smallest credible change without touching the Git index or history.
4. Add source files actually modified to `campaign_touched_source_files`; do not include files solely under `.code-quality` or build artifacts.
5. Run targeted tests, then proportionate project checks. Add only the minimum test or benchmark needed to protect a changed contract or non-obvious performance tradeoff.
6. Replay the exact comparable benchmark, calculate gain and dispersion, then inspect the diff with the maintainability guardrail.
7. If all atomic conditions are satisfied, move the ID directly to Resolved, complete history, apply the cap, and announce resolution without further confirmation.
8. If tests fail, gain is absent or within variance, measurement becomes non-comparable, or debt is unjustified: leave the ID Pending, preserve the diff without automatic revert, create or retain the campaign file with the cause under `Blocker`, then stop the campaign for review.
9. Never auto-resolve neighboring findings. Report those sharing the workload or paths as candidates for later remeasurement.

### 4. Count and continue

After the invariants of a completed cycle, increment the counter. Continue until the first event:

- `<N>` cycles completed;
- a newly audited source is `clean`, `inconclusive`, or leaves no immediately actionable finding;
- triage concludes that material coverage has been reached—no material candidate remains, before an audit even runs;
- no actionable Pending finding remains and no new safe workload can be selected;
- validation or authority becomes genuinely blocking.

A board emptied by a fix does not suffice to stop a multi-cycle campaign: run a new audit if the target has not been reached. Never invent a workload, finding, or optimization to fill the quota.

## Measurements, subagents, and mutations

Prioritize experimental integrity over execution speed.

- Serialize all benchmarks, profiles, builds, and other CPU, memory, or I/O work liable to disturb a measurement. Never compare runs obtained during controllable concurrent activity.
- For `<N> > 1`, use subagents when exposed by the runtime for inventories, call sites, blast radius, and read-only diff reviews. For a single cycle, use them only when scope warrants it.
- Suspend or await all subagents before every warmup, baseline, profile, and post-fix measurement. No subagent runs its own performance workload.
- Serialize ledger and code writes. Only one writer acts at a time, and the orchestrator verifies its evidence and diff.
- Remain provider- and model-agnostic: describe the required capability, then let the runtime choose its stable default.

## Campaign doc-cleanup closeout

Unless `--no-doc-cleanup` is set, run **one** documentation closeout after the entire loop stops normally, never after each cycle. If the campaign stops on failure with unvalidated source edits, do not layer cleanup on top: preserve the diff for diagnosis, retain the campaign file for resume, report that closeout did not run, and do not complete the goal.

1. Compute `cleanup_files = campaign_touched_source_files - baseline_dirty_source_files`, reduced to existing source files still modified at the end; the union covers every cycle.
2. If `cleanup_files` is empty, announce that closeout is not applicable and do not force a pass.
3. Otherwise, load `doc-cleanup` and run its `session --files <explicit list>` mode. Never silently fall back to global `git status` scope.
4. During this orchestrated closeout, do not perform a rename whose blast radius leaves `cleanup_files`, including into `baseline_dirty_source_files`; keep or de-drift a short comment instead. The final scope thus remains exact and no new file is introduced after calculation.
5. Let `doc-cleanup` apply its doctrine, validate the aggregate scope once, and write a single session coverage line.

Files dirty before the campaign remain excluded if the user exceptionally authorized an overlapping fix: preserving pre-existing WIP takes precedence over cleanup completeness. List them in the recap as excluded from closeout.

## Final recap and invariants

After normal closeout—doc-cleanup run, declared not applicable, or disabled by `--no-doc-cleanup`—delete `performance_campaign.md` if it exists. Return a compact recap: completed/target cycles, measured scopes, `exposure-capped` scopes rejected with their calculations, IDs and verdicts, before/after, validations, doc-cleanup closeout, protected or touched files, remaining actionable findings, and stop reason. If the campaign stopped because material coverage was reached, relay the `selection:coverage-stop` question—which operation feels slow in use—to open a targeted `feature` audit.

Before finishing, verify:

- no source modification preceded its `GO` double-check;
- no audit ran on a scope with a demonstrable exposure ceiling;
- every resolution rests on comparable measurements, gain outside variance, passing tests, and the maintainability guardrail;
- only one finding was fixed per cycle and no neighbor was auto-resolved;
- no potentially concurrent measurement ran;
- no `git add`, `commit`, `push`, external workload, or destructive operation ran without authorization;
- doc-cleanup ran at most once, on the aggregate explicit list, or its absence is explained;
- the campaign file is absent after normal closeout, or retained and reported on a blocking stop;
- the native goal is complete only if the campaign and requested closeout are genuinely complete.
