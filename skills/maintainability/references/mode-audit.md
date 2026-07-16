# Mode: audit

Reference loaded by SKILL.md in **auto audit** or **forced audit** mode with a path. Cross-cutting conventions (deterministic date, delta writes) and evaluation doctrine live in SKILL.md and apply here.

## A. Bootstrap (if `<STATE_DIR>/maintainability_*.md` is absent)

1. If `<STATE_DIR>` does not exist in the project, create the directory.
2. If `maintainability_history.md` is absent, create it with `# Maintainability audit history\n\n`.
3. If `maintainability_findings.md` is absent, create it with `# Maintainability findings\n\n## Pending\n\n## Resolved\n`. Do not add an `<!-- id_counters: ... -->` header yet (create lazily on first ID assignment). Also do not create `maintainability_resolved_archive.md` yet (create lazily when the Resolved cap is first exceeded).
4. Announce in chat: *"Maintainability bootstrap for this project; no prior history."*
5. Continue the audit flow normally (no rolling window to honor).

## B. Zone inventory

Compute for every audit (never persist). Algorithm:

0. **Opportunistic counting tool (optional, graceful degradation).** Before the manual walk, test `command -v scc || command -v tokei`. If present, **run it as per-file JSON** (`scc --by-file -f json` or `tokei -o json`) and derive the inventory: these tools provide actual **code** LoC (excluding comments/blank lines), per file and language, natively excluding vendored code, without reading code (their output enters context, not the files). **If neither is present**: fall back to the manual walk (steps 1–6)—the tool is never a hard dependency. Architectural-landmark detection (step 5) remains required even when a tool provides counts: it depends on file/symbol roles, not only size.
1. **Walk the tree** from the project root.
2. **For each directory**, measure total source LoC (exclude `.json`, `.toml`, `.lock`, `.md`; directories `node_modules`, `.git`, `dist`, `build`, `vendor`, `target`, `.venv`; and anything apparently generated).
3. **Partitioning rules**:
   - Directory with 200–2000 LoC → candidate zone.
   - Directory > 2000 LoC → descend into subdirectories and apply recursively.
   - Directory < 200 LoC → group with its parent (do not propose alone).
   - **Relative scale**: thresholds apply to **code** LoC (excluding comments/blank lines—natural when inventory comes from `scc`/`tokei`). These are deliberately simple defaults, not a per-language table. On a **very large repo/monorepo**, partition so each zone fits a reasonable reading budget rather than clinging to absolute 600/2000 LoC thresholds: split a large package by submodule instead of mechanically labeling it “too large.”
4. **Files ≥ 600 source LoC** (regardless of directory) → additional standalone zone. This catches god files even inside a reasonably sized directory.
5. **Architectural landmarks (ignore size)**: add files or smallest owning directories that hold a composition root or structural facade as candidate zones, even under 200 LoC. Stack-agnostic examples: application entrypoint (`main`, `app`, `server`, CLI/worker), subsystem bootstrap/init/start, builder/factory assembling several concrete dependencies, router/API composer, public facade stabilizing a module API/boundary, pipeline assembly. The zone remains a **real path** (file or directory), not a new history type. If several landmarks belong to the same small component, group them in the smallest owning directory instead of creating 10 micro-zones. Noise bound: retain only landmarks that assemble ≥3 dependencies/subsystems, establish lifecycle policy, or are heavily imported/modified; ignore trivial `init_*` helpers and simple barrels/re-exports without their own responsibility. **Deliberate exception to the `<200 LoC` rule (step 3)**: propose a below-threshold landmark itself instead of merging it into its parent; it may therefore coexist with its containing size-zone (`src/main.rs` as a landmark **and** within zone `src/`)—distinct history keys, intentionally: the landmark zone performs a role-focused audit (`E.1quater` lens), not a rescan of the entire directory.
6. **Source LoC measurement** (manual walk only—skip if step 0 provided the count): count nonempty lines excluding pure comment lines. Approximation is acceptable; no AST needed.
7. **Candidate pipelines**: if the tree walk identifies a traceable data flow (an entrypoint calling 3–5 files in sequence), it may propose a `pipeline:<name>` zone with the explicit file list. If the skill cannot concretely name the pipeline and its files, it **does not include** a pipeline candidate—do not invent one to tick a box. *Optional*: if an import-graph tool already exists in the repo (`madge --json` for JS/TS, `go list -deps`, `pydeps`), use it to confirm actual dependency closure around the entrypoint (capturing indirect imports/injection missed by visual reading); otherwise fall back to manual inspection of imports at file tops, with the abstention rule above still applying.

`Z` = total number of candidate zones from this inventory.

## C. Selection (auto mode, empty args)

History serves **three distinct purposes** with different memory horizons—the selection uses them separately:

1. **Read all of `maintainability_history.md`.** Parse every `- YYYY-MM-DD — <zone> — …` line and extract zones (`crosscut:*` lines are ignored for zone selection).
2. Compute `N = clamp(round(Z / 4), 3, 10)` (overridable via `<!-- rolling_size: M -->` at the top of history).
3. Build two views over parsed zones:
   - **`active_rolling`** = the `N` most recent zones (the file's first `N` lines; prepend order = newest-first).
   - **`never_audited_zones`** = `inventory − {all zones appearing in the file, with no date limit}`.
4. **Compute activity signal per zone** (see *Activity signal* below). Classify every inventory zone as:
   - **`never_audited`**—zone absent from all history.
   - **`hot`**—audited zone with `last_touch_outside_maintainability > last_audit_zone`. User code changed since the last audit.
   - **`cold`**—audited zone with no non-maintainability activity since the last audit.
5. **Candidates** = `inventory − active_rolling`.
6. **Three-tier weighting**:
   - **Top**: `never_audited` candidates → new coverage, absolute priority.
   - **High**: `hot` candidates → the zone recently changed; re-audit has high ROI (new code to examine).
   - **Low**: `cold` candidates → legitimate but marginal re-audit (the zone did not change outside maintainability fixes).
   
   Selection: take the highest nonempty tier, then **break ties deterministically** (reproducible and auditable through history)—oldest `last_audit_zone` first (`never_audited` have none → treat as oldest), then, for remaining ties, **zone-path alphabetical order**. This still spreads coverage (every zone eventually becomes oldest) while remaining reproducible across runs. The low tier is never blocked—it is merely consulted last. To audit a cold zone, the user invokes audit mode with an explicit path.
7. **Pipeline target ~30%**: if `pipeline:` candidates exist and no pipeline was audited recently (rolling), increase their weighting to reach approximately 30% of audits over time. Pipeline targeting combines with activity weighting—a hot pipeline remains higher priority than a cold one.
8. **Architectural landmarks**: candidates from `B.5` participate in normal weighting (never audited/hot/cold). Do not give them permanent absolute priority: their value comes from their central role, but rolling and activity still prevent repetition. Their announcement reason is `architectural landmark` or more specific (`local composition root`, `structuring public facade`, `subsystem bootstrap`).
9. **Chat announcement**: use the `selection:proposition` template (see `references/templates.md`). `<reason>` reflects both coverage (`never audited`, `god file`, `traceable pipeline`, `architectural landmark`) and activity signal (`hot — <N> commits since last audit`, `cold — audited on YYYY-MM-DD, no non-maintainability activity since`).
10. **User validation**: accept, request a listed alternative, or impose another path. Wait before starting the audit.

**Why separate these**: trimming history (old behavior) lost historical coverage and reproposed already covered zones (details: `references/file-formats.md > Why append-only`). History is now append-only; rolling is a view over the first `N` lines, coverage uses the entire file, and activity signal prevents a second loop mode: sticking to the same few non-rolling zones in a large project where weighted randomness alone does not sufficiently favor actually modified zones.

### Activity signal

Cross-reference actual code changes (user commits) with audit history to favor zones where auditing adds real value.

**a. Identify maintainability commits** (exclude from activity computation—they do not reflect a user change):
- Scan `maintainability_findings.md` (Pending **and** Resolved sections): extract all hashes after `Commit: ` or `Commits: ` (one hash, or several separated by `+`).
- Scan `maintainability_resolved_archive.md` if it exists: same.
- Set `commits_maintainability` = union of extracted hashes (typically short, 7–8 chars).

**b. Compute `last_touch_outside_maintainability` per candidate zone**:
- For a simple zone (directory or file): run `git log --format=%H %cI -- <path>`, then filter lines whose hash **starts with** one of the `commits_maintainability` hashes (prefix matching because the set contains short hashes while `%H` is long). `last_touch = max(date)` among the remainder.
- For a pipeline (`pipeline:<name>` with explicit files): apply the computation over the union of files, `last_touch = max` across all.
- If no non-maintainability commit exists for the zone (zone introduced only by maintainability fixes, rare): `last_touch = epoch`. The zone naturally falls into `cold` at point c—consistent.
- **If the repo is not a git repo** (`.git/` absent at root): skip activity signal and fall back to historical two-tier weighting (never audited = high, otherwise random). Announce *"Non-git repo: activity signal unavailable; using degraded weighting."*

**c. Compute `last_audit_zone` per zone**:
- Scan history lines (excluding `crosscut:*`) whose zone matches exactly (exact path, or `pipeline:<name>` with the same name).
- `last_audit_zone = max(date)` among these lines. This computation is unnecessary for a zone in `never_audited_zones` (it is top priority anyway).

**d. Classification**:
- `never_audited` iff zone is in `never_audited_zones`.
- Otherwise `hot` iff `last_touch > last_audit_zone`. **Compare by day** (`last_touch` is a full timestamp, `last_audit_zone` a date); **same day → `hot`**: whether the commit precedes or follows the same-day audit is unknowable, and over-prioritizing a zone is the cheapest bias (rolling protects recently audited zones anyway).
- Otherwise `cold`.

**Cost**: one `git log` per candidate zone. For Z = 40 zones, ~40 calls—a few seconds during auto-selection, negligible against the audit itself. For Z > 80, cost becomes noticeable; activity signal remains useful, but the skill may limit it to a sample of the top 30 zones by LoC (zones < 200 LoC were already grouped in *Zone inventory*, so size filtering is natural).

### Degenerate selection cases

- **No candidates** (typically a small project with a `rolling_size` override excluding everything): relax rolling and choose the least recently audited zone among **all** inventory zones. Announce *"All zones are in rolling—I selected the least recent: `<zone>` (audited 2026-04-22)."* Break ties by path-alphabetical order (same deterministic tie-break as C.6).
- **All candidate zones are cold**: consult the low tier and choose the least recently audited `cold` (break ties by path-alphabetical order). Announce *"No zone changed since its last audit—re-auditing a cold zone: `<zone>` (audited on YYYY-MM-DD, no activity since)."* Do not block—the audit remains meaningful, if only for deeper examination.
- **Empty inventory** (`Z = 0`): abort with *"No auditable zone detected (every directory has < 200 source LoC or is excluded). Is the project empty, or do you want to audit a specific path manually?"*
- **Only one candidate zone after exclusion**: propose no alternatives; announce the sole zone and ask whether to start.

## D. Forced audit (`<path>` mode)

0. If bootstrap is required (`<STATE_DIR>/maintainability_*.md` absent), follow *A. Bootstrap* before the steps below.
1. Verify that the path exists in the current project.
2. Measure zone size (aggregate source LoC).
3. **If > 5000 LoC**: refuse a blind audit. Announce the size, propose a subscope (e.g. *"too large at 6200 LoC. Possible subscopes: `<path>/sub1/`, `<path>/sub2/`"*), and request confirmation. The user may force it if they insist, knowing the audit will be less deep.
4. Otherwise: audit directly, without auto-selection.

## E. Audit execution

For the approved zone:

1. **Read all zone code** (every source file in scope).
1bis. **Tool-assisted signals (optional, graceful degradation).** Before judgment-based review, if deterministic detection tools exist in the environment, run them on the zone to obtain precise, localized candidates (duplication, dead exports, complexity, god files). See `references/dimensions.md > Opportunistic detection tools` for tool↔dimension mapping and stance (the tool supplies **recall and localization**; the agent retains **judgment**—whether to produce the finding, severity, trade-off check). **No hard dependency**: absent tool → fall back to reading/judgment in step 2.
1ter. **Import boundary (for `ARC`).** A zone audit reads the zone, but coupling is visible only at its boundary: supplement with incoming/outgoing zone imports (`rg` imports, or a graph if available), **without fully reading outside the zone**. Assess cohesion (feature envy, over-fragmentation, local abstraction) here; deep cross-zone coupling (cycles, co-change, instability × churn) belongs to crosscut `ARC` (see `references/dimensions.md > ARC dimension framing`).
1quater. **Composition-root/abstraction-level lens (for `ARC`).** If the zone contains an architectural landmark (see `B.5`), examine the composition roots it owns—not only the application entrypoint, but also local subsystem roots. See `references/dimensions.md > Composition roots and abstraction level` for the principle (uniform abstraction level), required concrete friction bar, and bounded recommendation (subsystem-owned constructor/factory, anti-wrappers).
2. **Systematically examine every catalog dimension** (see `references/dimensions.md`). For each:
   - Look for concrete pattern occurrences in the zone.
   - For every occurrence: observe (verifiable fact, file:line, context), assess severity (impact × exposure; see `references/quality.md > Severity scale`), and **estimate the Δ LoC** produced by applying the recommendation (see `references/quality.md > Δ LoC estimate`).
   - **Apply the trade-off check** before producing (see `references/quality.md > When NOT to produce a finding`)—performance, security, scalability, paradoxical readability. If the trade-off is significant, do not produce; otherwise annotate it in `Recommendation`.
   - **Do not force findings.** A dimension may legitimately produce 0 findings when code is clean on that axis.
3. **If a real problem fits no dimension**: create a new 3-letter prefix (see `references/dimensions.md > Seed dimensions`). Briefly document in the finding why this new category is needed.
4. **ID assignment**: follow `references/file-formats.md > ID counter` (read the `<!-- id_counters: ... -->` header, **recalibrate it to the greatest NNN actually present in findings before incrementing**—collision guardrail if the header drifted; update the header line). Use 3-digit format (`DUP-007`).

## F. Writes (append-only)

1. **Append findings** under `## Pending` in `maintainability_findings.md`. Strict format: see `references/file-formats.md`.
2. **Prepend a new line at the top** of `maintainability_history.md`:
   ```
   - YYYY-MM-DD — <area> — N findings (X HIGH, Y MED, Z LOW) (pending)
   ```
3. **No trimming.** History is append-only—the file accumulates over the project's lifetime. Apply active rolling size `N` when reading (view over the first `N` lines), never when writing.

### Clean-zone case (0 findings)

If the audit produces zero findings (zone genuinely clean across all dimensions):

- **Still write the history line**, using the adapted format:
  ```
  - YYYY-MM-DD — <zone> — 0 findings (clean)
  ```
- Append **nothing** to `maintainability_findings.md` (create no pending entry).
- Chat output: use the `audit:clean` template.

Writing the history line is **important**: without it, the zone would be reproposed too soon and historical coverage would lose the fact that the zone was examined.

## G. Chat output (post-audit)

- Audit with findings → `audit:summary` template.
- Audit without findings (clean zone) → `audit:clean` template.
- Next: autonomous double-check proposal (see H below).

## H. Autonomous double-check proposal (post-audit)

After the chat summary, if the audit produced ≥ 1 finding, offer the user three options via the `audit:proposition` template (3 options: quick-wins / heavy / nothing), then wait for their answer.

**Panel-selection criteria**:

- **(a) Quick-wins**: panel of 3–5 “low effort, direct fix” findings.
  - Prioritize LOW severity; supplement with MED as needed to reach 3.
  - Small `|Δ LoC|` (≤ 30) or single-file recommendation with no identifiable blast radius.
  - **No HIGH finding in this panel**—a HIGH is never a quick-win.
- **(b) Heavy finding**: one finding, the most structural.
  - Prioritize HIGH severity (otherwise the widest-scope MED).
  - Widest scope first: god file > structural duplication 3+ > cross-cutting drift > local complexity.
  - Tie-break: greatest estimated `|Δ LoC|`.
- **(c) Nothing**: the user will revisit later.

**Degenerate cases**:

- 0 findings: do not show this proposal (already covered by the clean-zone case).
- 1 or 2 findings: replace with the `audit:proposition-min` template (simple question about 1 ID).
- No candidate meets quick-win criteria (e.g. every finding is HIGH with a large blast radius): offer only (b) and (c).
- No HIGH finding or wide-scope MED: for (b), propose the finding with greatest estimated `|Δ LoC|`, warning that it is not “heavy” in the conventional sense.

**Execution based on user choice**:

- **(a) Quick-wins**: for each panel finding, execute the `references/mode-double-check.md` flow (file read, trace, blast radius, refined Δ LoC, refined recommendation, verdict). Write the `Double-check (date)` section in each findings-file entry. **Aggregate output** via `double-check:autonomous-batch`, followed by `double-check:autonomous-batch-proposition` (see *I. Post-batch-proposal action* below).
- **(b) Heavy finding**: execute the `references/mode-double-check.md` flow on the selected finding. Full output via standard `double-check:output`, followed by `double-check:proposition` (see `references/mode-double-check.md > Action based on the user's choice`).
- **(c) Nothing**: end the command. No additional writes.

## I. Post-batch-proposal action

Triggered by the `double-check:autonomous-batch-proposition` proposal (after `(a) Quick-wins` above or `double-check B<n>` from `references/mode-list.md`). Based on user choice:

- **Fix all GO**:
  1. Establish ordering (rules in `references/templates.md > double-check:autonomous-batch-proposition`).
  2. Plan per finding (1–3 lines: touched files, order, expected Δ LoC)—reuse `Refined recommendation`.
  3. Display global plan; require explicit OK. If OK, execute in order.
  4. Before every `Resolution` mark, run the test suite. Tests OK → in-session resolution flow. Tests KO → stop; do not mark.
  5. Automatic cascade re-check after each resolution (see `references/cascade.md`).
  6. For mixed GO+NO-GO: immediately archive remaining NO-GOs (move Pending → compact Resolved, `Resolution: archived after double-check (NO-GO rationale: <reason>)`, complete history lines, honor Resolved cap).
  7. Final recap via `cascade:recap-batch`.
- **Fix one**: apply steps 2–5 above to the selected finding.
- **Archive NO-GOs** (mixed variant, partial archive) or **Archive all** (all-NO-GO variant): for each NO-GO, move Pending → Resolved in compact format, add `Resolution: archived after double-check (NO-GO rationale: <reason>)`, and complete the history line. Honor the Resolved cap.
- **Nothing** / **Keep pending**: finish without additional writes.

## End-of-mode invariants (auto or forced audit)

Before returning control, validate (an item **not applicable** to the current case counts as checked; see SKILL.md > *End-of-mode invariants* for the cross-cutting rule):

- Findings appended under `## Pending` in `maintainability_findings.md`—one per produced finding (or none for a clean zone).
- `<!-- id_counters: ... -->` header incremented for every used prefix.
- Line prepended at the top of `maintainability_history.md`. **No trimming**—history is append-only.
- If bootstrap occurred: `<STATE_DIR>/maintainability_*.md` files created with initial content.
- If the user selected a panel in proposal H: corresponding mode invariants apply (`references/mode-double-check.md` for single, *In-session resolution* in `references/mode-update.md` for fix).
