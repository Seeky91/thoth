---
name: maintainability
argument-hint: "[<path> | list | update | double-check <ID> | crosscut | archive-clear]"
description: "Audit, track, deep-check, and resolve code maintainability debt: duplication, dead code, complexity, oversized files, inconsistent patterns, coupling, cohesion, boundary violations, architecture drift, test redundancy, config sprawl, and stale or unnecessary comments (use doc-cleanup for a dedicated comment-removal pass). Use for code-health or architecture reviews, French « audit de maintenabilité » or « dette technique », zonal or cross-project sweeps, persistent findings, controlled fixes with validation, listing or refreshing findings, deep-checking an ID, and archive cleanup. Excludes security, performance, accessibility, and stack selection."
---

# Maintainability skill

## Boundary

Diagnose and track maintainability without modifying audited code during the audit. **The skill audits and tracks first** (persistent findings with stable IDs); it modifies code only afterward, through explicit resolution after your confirmation (`update`, `fix B<n>`)—this is not a one-shot refactor. Do not use for security, performance, accessibility, or stack selection.

**Orchestration exception:** explicit invocation of `maintainability-cycle` constitutes bounded advance confirmation for its area/dimension choices, batches, fixes for GO verdicts, and archival of NO-GO verdicts with no credible reevaluation scenario. Only in that context do playbook proposals and plans become progress announcements instead of gates; all other rules, validations, and Git limits remain unchanged.

## References

This SKILL.md is a **thin router**: it sets the mode, cross-cutting conventions, and doctrine, then routes to the mode playbook. Normative details live in `references/`, loaded **on demand** (one mode does not pay the context cost of others):

**Mode playbooks** (one per mode—read and execute the current mode's playbook):

- `references/mode-audit.md`—area inventory, automatic selection, audit execution, autonomous double-check proposal, post-batch-proposal action.
- `references/mode-crosscut.md`—cross-cutting dimension selection, whole-project sweep, post-crosscut proposal.
- `references/mode-list.md`—read-only dashboard, detection of groupable batches.
- `references/mode-update.md`—pending re-verification, stale self-heal, in-session detection, *In-session resolution* invariants.
- `references/mode-double-check.md`—deep dive into a finding (blast radius, feasibility, verdict).
- `references/mode-archive-clear.md`—resolved-archive purge.

**Doctrine and formats** (loaded when producing a finding or writing state):

- `references/file-formats.md`—format of the three state files (`maintainability_history.md`, `maintainability_findings.md`, `maintainability_resolved_archive.md`), ID counters, finding lifecycle, Resolved cap.
- `references/cascade.md`—detailed post-fix cascade re-verification algorithm.
- `references/templates.md`—normative chat-output templates (one per use, e.g. `audit:summary`, `list:dashboard`, `resolution:confirm`). **Read before every mode chat output** to keep form stable across invocations.
- `references/dimensions.md`—catalog of 12 seed dimensions (`DUP`, `CPX`, `SIZ`, `DED`, `INC`, `IDM`, `BND`, `DRF`, `TST`, `CFG`, `DOC`, `ARC`), boundaries between adjacent dimensions, opportunistic detection tools, paradigmatic frame of reference (multi-paradigm evaluation), and framing for `IDM`, `ARC`, and `CPX`. **Read before producing a finding** when the prefix or dimension framing is not immediately obvious.
- `references/quality.md`—severity scale (HIGH/MED/LOW), anti-noise guardrails (*"When NOT to produce a finding"*), and `Δ LoC` convention. **Read before producing a finding**: these calibrations determine whether to write one at all.

## Mode dispatch

Infer the mode from the user's request, independently of agent invocation syntax:

| Request intent | Mode | Playbook | Expected input |
|---|---|---|---|
| Show the dashboard | **list** | `references/mode-list.md` | None; read-only. |
| Re-verify pending findings | **update** | `references/mode-update.md` | None. |
| Deep-check a finding | **double-check** | `references/mode-double-check.md` | ID such as `DUP-007`. |
| Purge the archive | **archive-clear** | `references/mode-archive-clear.md` | `--all`, `--keep N`, `--older-than <dur>`, or default > 6 months. |
| Audit a supplied path | **forced audit** | `references/mode-audit.md` | Existing path. |
| Audit without a path | **automatic audit** | `references/mode-audit.md` | Inventory, propose an area, obtain approval, then audit. |
| Sweep a cross-cutting dimension | **crosscut** | `references/mode-crosscut.md` | Proposed dimension among `DUP`, `INC`, `DRF`, `DED`, `BND`, `ARC`. |

Accept compatibility aliases `/maintainability`, `/maintainability-list`, `/maintainability-update`, `/maintainability-double-check`, `/maintainability-archive-clear`, and `/maintainability-crosscut`. With Codex, use the text accompanying `$maintainability` to select the same mode. If explicitly invoked without details, choose **automatic audit**.

**Dispatch procedure**: (1) verify the project root; (2) resolve `<STATE_DIR>`; (3) validate remaining request input—ask for clarification only for an invalid ID, nonexistent path, or unknown flag; (4) read and execute the mode playbook. Never depend on agent-specific variables such as `$ARGUMENTS`.

## Project-root detection

Before dispatching any mode, confirm that `cwd` is a project root:

1. Look for one of these markers in `cwd`: `.git/`, `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `composer.json`, `Gemfile`, `pom.xml`, `build.gradle`, `.hg/`, `.svn/`.
2. **If found** → continue.
3. **If absent**, walk up parent directories until a marker or filesystem root.
4. **If found in a parent**: report *"The project root appears to be `<parent-path>`, but `cwd` is `<cwd>`. Rerun from `<parent-path>` or confirm the operation here (state will be created in the confirmed project)."* and wait.
5. **If no marker is found anywhere**: abort with *"No project marker detected (.git, package.json, pyproject.toml, …). Run the command from a project root."*

This check does not apply when the user passes a `<path>` argument (absolute, or relative resolved against `cwd`)—then the path itself is the scope and state attaches to the nearest root marker above it.

## State directory

`<STATE_DIR>` = `<PROJECT_ROOT>/.code-quality`, shared by Claude Code and Codex. Create it only when a mode must write—`list` creates no directory.

Throughout this skill, an unqualified state filename such as `maintainability_findings.md` always means `<STATE_DIR>/maintainability_findings.md`.

## Cross-cutting conventions (every state-writing mode)

Three rules apply to **every** state-file write, regardless of mode. They are not repeated in each playbook—they apply everywhere.

1. **Deterministic current date.** Every `YYYY-MM-DD` date written to state (history line, `Detected:`, `(resolved …)`, `Double-check (…)` section, `Status: stale (…)`) or compared with a stored date (`archive-clear` threshold "> 6 months") must come from `date +%F`, **never from memory**. If the environment cannot run `date`, report it in chat rather than inventing a date.

2. **Delta writes, never regeneration.** Modes read state early and write late. Before writing `maintainability_findings.md` or `maintainability_history.md`, **reread the file immediately before the write**, then **insert/move only the targeted block(s)** (new finding, prepended history line, Pending → Resolved move). **Never** regenerate the entire file from memory: this may lose existing entries and overwrite an intervening manual edit (the skill explicitly supports human editing; see `references/file-formats.md`).

3. **Git: modify the worktree, never history.** Fix flows (in-session resolution, `fix B<n>`, post-double-check quick wins) freely edit project files but **never** run `git add`/`commit`/`push`—committing belongs to the user (`git log`/`diff`/`show`/`blame` remain allowed). Consequently, when resolution is written the fix is **normally uncommitted**—the `Resolution` bullet then states `Commit: uncommitted` (see `references/file-formats.md`), which `update` may fill later. The post-fix cascade also does not depend on a commit (see `references/cascade.md`).

## Evaluation doctrine

Three normative frameworks live in `references/` (fully described under *References*) and **must be consulted when producing a finding**:

- `references/dimensions.md`—dimensions, boundaries, paradigmatic frame, `IDM`/`ARC`/`CPX` framing, exclusions, tools. New 3-letter prefixes are allowed when a real issue fits no dimension.
- `references/quality.md > Severity scale`—HIGH/MED/LOW = impact × exposure; mutable severity (reclassifiable at double-check, ID retained).
- `references/quality.md > When NOT to produce a finding`—counterweight to structural overproduction bias: 0 findings is a *successful* audit, mandatory upstream trade-off check, *Dogma ≠ defect* guardrail for judgment dimensions (`ARC`, `IDM`, `CPX`).
- `references/quality.md > Δ LoC estimate`—`~±N` convention, estimation method, double-check refinement, actual resolution measurement.

## Chat-output conventions

Mode chat outputs follow normative templates in `references/templates.md`. Read that file **before every chat output** to keep form stable across invocations.

**Cross-cutting conventions** (summary):
- **Header** for writing modes: `<Mode> complete — <scope>`. List uses `Maintainability board — <project>`.
- **Trailer** `Files updated: …`: present for every writing mode (audit, update, double-check, archive-clear, in-session resolution). Absent from read-only list mode.
- User-action proposal blocks (post-audit, single post-double-check, batch post-double-check, post-list) are separate from the recap—a distinct block at message end.

Each playbook names its templates (`selection:proposition`, `audit:summary`, `resolution:confirm`, …); `references/templates.md` gives the complete index and normative format.

## End-of-mode invariants

Before returning control, the agent **must** validate that every expected write for the current mode occurred. This is a cognitive guardrail against drift in multi-write flows (in-session resolution, batch update, cascade), where a secondary step may be silently omitted after the primary one.

**Each mode's invariant checklist is at the end of its playbook** (`references/mode-<X>.md > End-of-mode invariants`). Read and check the current mode's list before finishing. Cross-cutting rules:

- A box **not applicable** to the current case (e.g. Resolved cap not exceeded so no archival, no reclassification so no amended title) is considered checked—the list targets silent omissions, not universally required operations.
- **If a box cannot be checked**: when a condition prevents an expected write (failing tests, read-only file, merge conflict in findings), **report in chat** what could not be done and why rather than returning silently. The user must know partial state exists.

## Edge cases

### Reclassification

If a finding proves miscategorized (e.g. `DUP-007` is actually complexity, not duplication):

- **Keep the ID.** `DUP-007` remains `DUP-007`.
- Add bullet `Note: Semantically reclassified to CPX; ID retained for traceability`.
- Optional: adjust the dimension in the `Dimension` bullet.

### File moved/refactored between audits

Update mode's stale logic (`references/mode-update.md` steps 2.b and 4) also applies in `double-check` when the referenced ID points to a missing file.

### Potential duplicates

If an audit produces a finding strongly resembling an existing pending finding (same file, same pattern):

- Do not duplicate it. Reference the existing ID in the chat summary: *"DUP-007 still present—not counted again."*
- Optionally refresh the detection date on the existing entry.

### Prefix conflict

If the user manually used an unusual prefix (e.g. `XXX-001`) in the findings file, respect it and continue incrementing that series when relevant. No automatic "rebasing."
