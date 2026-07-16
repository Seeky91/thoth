---
name: maintainability-cycle
argument-hint: "[<N>] [--no-doc-cleanup]"
description: "Orchestrate one or more autonomous, goal-backed maintainability cycles from audit or pending selection through mandatory GO/NO-GO double-checks, bounded fixes, validation, ledger updates, and one final scoped doc-cleanup pass. Use when the user asks for a complete maintainability cycle, several automatic cycles, autonomous technical-debt resolution, or wants to avoid repeating the audit/double-check/fix prompt. Supports subagents without provider- or model-specific names."
---

# Maintainability cycle

Orchestrate an autonomous campaign on top of the `maintainability` and `doc-cleanup` skills. This skill does not redefine their doctrine or formats: it loads their instructions, chains their modes, and preserves their invariants.

## Dependencies

Before acting:

1. Load the `maintainability` skill and the playbooks required for each atomic operation.
2. Load `doc-cleanup` only during closeout, unless `--no-doc-cleanup` is present.
3. If the runtime cannot activate a skill by name, resolve the sibling skills `../maintainability/SKILL.md` and `../doc-cleanup/SKILL.md` from this directory.

The atomic skill remains authoritative for root detection, state formats, dates, tests, cascade, and invariants. If instructions conflict, this skill overrides only the interactive gates explicitly lifted below; all safety rules still apply.

## Input

- `<N>`: target number of cycles, a strictly positive integer; default `1`.
- `--no-doc-cleanup`: disable documentation closeout.
- An unknown argument or invalid integer requires clarification. Do not guess.

Accept equivalent phrasing regardless of runtime syntax, for example `/maintainability-cycle 3` with Claude Code or `$maintainability-cycle run 3 cycles` with Codex.

## Native goal

Explicit invocation of this skill requests and authorizes creation of a **single native goal** covering the entire campaign: at most `<N>` cycles, early stop when no finding remains actionable, then optional doc-cleanup closeout.

- If an active goal already covers the request, reuse it; do not nest a second goal.
- If the runtime exposes persistent goals, create one before starting work. Set a budget only if the user provided one.
- If no goal mechanism is available, run the same loop in the current thread with the same stop conditions.
- Mark the goal complete only after campaign invariants and the requested doc-cleanup closeout. A clean audit or absence of GO findings is not a blocker.
- On a genuinely blocking stop, never mark the goal complete. Leave it active/pending or use the blocked status according to the runtime's native policy; do not invent a status or bypass its thresholds.

## Bounded autonomous authorization

Invocation counts as explicit advance confirmation to:

- choose an audit zone or crosscut dimension;
- select a coherent batch of findings;
- double-check that batch;
- apply fixes for GO verdicts within the announced scope;
- archive a NO-GO using the atomic format when no credible reevaluation scenario remains; otherwise leave it Pending with its persisted verdict and do not process it again during the same campaign.

The normally interactive `maintainability` proposals and plans become progress announcements here, not gates. Continue without requesting another "OK" while the action remains within this scope.

This authorization never covers `git add`/`commit`/`push`, a destructive operation, a production change, another audit domain, or a material scope expansion. Request a decision only when new authority is genuinely required, the root/scope is ambiguous, or validation fails without a safe correction.

## Initial campaign state

1. Resolve the root through `maintainability` and read persistent project context when present (`AGENTS.md`, `CLAUDE.md`, `.code-quality` state, validation conventions).
2. If `<STATE_DIR>/maintainability_campaign.md` already exists, a campaign was interrupted. Announce it and resume its state (baseline, cycle count, current source and phase, touched files, non-actionable IDs) if the current request continues it; otherwise ask before overwriting it. Never recapture the baseline of a resumed campaign.
3. Capture `baseline_dirty_source_files` from `git status --porcelain=v1 -z`: source files modified, staged, or untracked before the first cycle. Treat these files as protected: choose another batch instead of editing them; if a priority finding requires unavoidable overlap, request targeted authorization.
4. Initialize campaign state; for `<N> > 1`, persist it in the campaign file (see below):
   - current source and current cycle phase (`selection`, `audit`, `double-check`, `fix`, or `closeout`);
   - `campaign_touched_source_files`: source files actually edited by fixes, including rename propagation;
   - `campaign_double_checks`: map from IDs to their verdict and current evidence;
   - `campaign_non_actionable_findings`: `GO-but-after-X` and `NO-GO` IDs kept Pending, not to be processed again during this campaign while their situation remains unchanged.
5. Read the maintainability board before choosing the first source.

### Campaign file

`<STATE_DIR>/maintainability_campaign.md` (using the `<STATE_DIR>` resolved by `maintainability`) persists orchestration state that exists nowhere else, so it survives context compaction or session interruption. Required for `<N> > 1`; for a single cycle, create it only when scope warrants it (large batch, many double-checks)—the short loop without subagents has little exposure to context loss. If a single cycle without a file becomes blocked after a mutation, create the file before returning control to preserve resumability. Detailed verdicts and evidence remain in the `maintainability` ledger: do not duplicate them here. Minimal format:

```markdown
# maintainability-cycle campaign
- Started: YYYY-MM-DD — target: <N> cycles — completed: <k>
- Current: <zone, dimension, or ID batch, or "none"> — phase: <selection|audit|double-check|fix|closeout>
- Dirty baseline: <root-relative paths, or "none">
- Touched files: <root-relative paths, or "none">
- Non-actionable: <ID (verdict), ..., or "none">
- Blocker: <precise cause, or "none">
```

Update it at step boundaries: `Current` and `phase` at each phase change, counter after each completed cycle, touched files after each fix, non-actionable IDs after each double-check, and `Blocker` as soon as a stop cause appears. This state file is not a source file: it never enters `baseline_dirty_source_files` or `campaign_touched_source_files` and remains outside doc-cleanup scope. Delete it at normal campaign closeout; retain it on a blocking stop as a diagnostic and resume artifact.

### Resume

When resuming a persisted campaign:

1. Reread the ledger and compare the current tree with the dirty baseline and recorded touched files. Treat any new campaign-external modification as protected WIP.
2. Resume `Current` and `phase` instead of selecting a new source. Rebuild `campaign_double_checks` from the ledger, rechecking that code and blast radius have not changed before reuse.
3. In `selection`, `audit`, or `double-check` phase, cleanly replay the unfinished atomic step.
4. In `fix` or `closeout` phase, inspect the preserved diff before any action. Continue the same batch only if safe correction and validation remain possible within the authorized scope; otherwise preserve the blocker and request a targeted decision.
5. Never automatically delete, stash, or revert the diff of an unvalidated attempt, and never move to another source until that attempt is resolved.

## Cycle definition

A cycle processes **one coherent source**: either a batch of Pending findings or findings from a new zonal/crosscut audit. It is complete when the selected source has been audited if necessary, double-checked, resolved within the retained GO batch, validated, and persisted. A clean source or a batch with no GO counts as a processed cycle; never invent a fix to fill the quota.

### 1. Choose the source

1. Prioritize an actionable, coherent Pending batch when one exists: file proximity, shared cause, or reasonable dependency order.
2. Exclude IDs in `campaign_non_actionable_findings`, unless a current-cycle fix satisfies their prerequisite or explicitly invalidates their evidence. A previously double-checked GO left outside the fix remains eligible for the next cycle.
3. Without an actionable Pending batch, autonomously choose between auto audit and crosscut based on history, coverage, and project signals. Default to auto audit; choose crosscut only on a concrete cross-cutting signal, or when the last two new sources were zonal and eligible crosscut coverage is older or absent. On a tie, use auto audit. Do not request confirmation for the selection.
4. Bound the batch: an audit may produce more findings than the cycle can absorb. Double-check every finding **in the retained batch**, not necessarily the audit's entire output; explicitly leave the remainder Pending for a later cycle instead of producing an overly broad fix.

### 2. Audit if necessary

Run the selected `audit` or `crosscut` mode completely, including doctrine, delta writes, history, and invariants. For an already Pending source, do not create an artificial audit.

An audit with zero findings is successful. If no other actionable finding exists, stop the campaign after counting this clean cycle.

### 3. Mandatory double-check

Before any code edit:

1. Run the `maintainability double-check` playbook on **every** batch finding that does not already have current evidence in `campaign_double_checks`.
2. Produce a current `GO`, `NO-GO`, or `GO-but-after-X` verdict based on the current tree. Campaign evidence may be reused only after verifying that its code and blast radius have not changed; otherwise repeat and persist the double-check again.
3. Persist each new double-check using the atomic format, then record verdict and evidence in `campaign_double_checks`.
4. Archive `NO-GO` findings with no credible reevaluation scenario using the atomic format; add retained `NO-GO` and `GO-but-after-X` findings to `campaign_non_actionable_findings`. Keep unfixed GO findings eligible for the next cycle with reusable evidence.

No source file may be edited before this step is complete for the entire retained batch.

### 4. Fix the GO batch

1. Choose a GO subset whose scope and validation remain coherent; leave the rest Pending for a later cycle.
2. Briefly announce the plan and order, then execute it without another gate.
3. Serialize mutations. After each fix: proportionate validation, persisted resolution, Resolved cap, and cascade according to `maintainability`.
4. Add source files actually modified to `campaign_touched_source_files`. Do not add files solely under `.code-quality`.
5. Leave `GO-but-after-X` and retained `NO-GO` findings Pending with their evidence; do not select them again in the same campaign.

### 5. Count and continue

After cycle invariants, increment the counter. Continue until the first event:

- `<N>` cycles completed;
- after double-checking a new audit/crosscut, no immediately executable GO verdict remains and no other Pending candidate for double-check or fix remains;
- genuinely blocking validation or authority.

A board emptied by one cycle's fixes is not itself a stop condition: if the target has not been reached, run a new audit/crosscut to feed the next cycle. Conversely, stop early instead of artificially changing zones when a newly audited source is clean or produces only non-actionable verdicts. Findings left outside the batch naturally justify the next cycle.

## Subagents and model selection

For `<N> > 1`, use subagents when exposed by the runtime to preserve the main context. For a single cycle, use them only when scope warrants it.

- Delegate candidate inventories/audits and double-check tracing in **read-only** mode; they return localized, compact evidence.
- Independent analyses may run concurrently. Ledger and code writes remain serialized.
- A fix agent may edit code, but only one writer acts at a time and the orchestrator verifies its diff before persisting resolution.
- Never let two agents mutate the same worktree or `.code-quality` files simultaneously.

**Model selection: remain runtime- and time-agnostic.** Name no provider, family, version, or commercial tier, and define no default model selector. Describe only the required capability in the briefing (code reasoning and blast radius for audit/double-check; precise editing and validation for fixes), then let the runtime select or inherit its model. If the runtime requires a selector, use its default or a stable native capability class, never a memorized name. Lack of manual model selection is not a blocker.

Each subagent receives the scope, role, mutation constraints, relevant state paths, and return format, but not the expected conclusion. The orchestrator verifies evidence and remains responsible for normative writes.

## Anti-testing-creep policy

- First use existing tests, checks, linters, or builds that reasonably cover the change.
- Lack of coverage alone does not block a GO fix and does not mechanically justify new tests.
- Add the minimum tests only when changed behavior or a non-obvious contract would otherwise lack realistic protection.
- When scope already contains redundant tests, prefer consolidating or parameterizing them if directly related to the finding; do not launch an out-of-scope test campaign.
- Clearly distinguish degraded validation from a fix failure.

## Multi-cycle doc-cleanup closeout

Unless `--no-doc-cleanup` is set, run **one** closeout after the entire loop stops normally, never after each cycle. If the campaign stops on failure with unvalidated source edits, do not layer aggressive cleanup on top: preserve the diff for diagnosis, retain the campaign file for resume, report that closeout did not run, and do not complete the goal.

1. Compute `cleanup_files = campaign_touched_source_files - baseline_dirty_source_files`.
2. Keep only existing source files still modified at the end. This union covers all cycles, including files touched by rename propagation.
3. If `cleanup_files` is empty, announce that closeout is not applicable and do not force a pass.
4. Otherwise, load `doc-cleanup` and run its `session --files <explicit list>` mode. Never silently fall back to global `git status` scope.
5. During this orchestrated closeout, do not perform a rename whose blast radius leaves `cleanup_files`, including into `baseline_dirty_source_files`; keep or de-drift a short comment instead. The final scope thus remains exact and no new file is introduced after calculation.
6. Let `doc-cleanup` apply its doctrine, validate the aggregate scope once, and write a single session coverage line.

Files dirty before the campaign remain excluded if the user exceptionally authorized an overlapping fix: preserving pre-existing WIP takes precedence over cleanup completeness. List them in the recap as excluded from closeout.

## Final recap and invariants

After normal closeout—doc-cleanup run, declared not applicable, or disabled by `--no-doc-cleanup`—delete `maintainability_campaign.md` if it exists: a remaining campaign file always signals an interrupted campaign.

Return a compact recap containing: completed/target cycles, selected sources, IDs and verdicts, fixed GO findings, archived NO-GO findings, validations, doc-cleanup closeout, files excluded because already dirty, remaining actionable findings, and stop reason.

Before finishing, verify:

- no fix preceded its double-check;
- all expected atomic writes and cascades are present;
- only one writer mutated the worktree at any time;
- no `git add`/`commit`/`push` occurred;
- doc-cleanup ran at most once, on the aggregate explicit list, or its absence is explained;
- the campaign file is deleted after normal closeout, or retained and reported on a blocking stop;
- the native goal is complete only if the campaign and requested closeout are genuinely complete.
