# Mode: project (global campaign)

Playbook loaded by SKILL.md in **project** mode. Clean the **entire** project zone by zone, using subagents when available or the main-loop otherwise, with persisted coverage for resuming. Load `references/doctrine.md` and `references/orchestration.md` before executing. For cross-cutting conventions (read-only git, per-zone validation, dates, delta), see SKILL.md.

## A. Bootstrap

1. If `<STATE_DIR>` does not exist, create it.
2. If `<STATE_DIR>/doccleanup_coverage.md` is absent, create it with `# Doc-cleanup coverage\n\n`. Resolve `<STATE_DIR>` from the project root, never from raw `cwd`.
3. Announce in chat: *"Doc-cleanup bootstrap; no prior coverage."*

## B. Zone inventory

Compute this for every campaign (never persist it). Goal: partition the project so each zone fits an agent's reading budget.

0. **Opportunistic counting**: test `command -v scc || command -v tokei`. If present, run it as per-file JSON (`scc --by-file -f json` / `tokei -o json`) to obtain source LoC per file/directory without reading code. Otherwise, use a manual walk.
1. **Walk** from the root. Exclude `node_modules`, `.git`, `dist`, `build`, `vendor`, `target`, `.venv`, and all generated content (`*.gen.*`, `*_pb2.*`, codegen output). Also exclude non-source files (`.json`, `.lock`, `.md`, `.toml`)—the skill cleans **code**.
2. **Partition**:
   - Directory with 200–2000 source LoC → candidate zone.
   - Directory > 2000 LoC → recurse into subdirectories.
   - Directory < 200 LoC → group with parent.
   - File ≥ 600 LoC → additional standalone zone.
   - In a monorepo, target a reasonable per-zone reading budget rather than absolute thresholds.

`Z` = number of zones.

## C. Resume from coverage

1. **Read all of `<STATE_DIR>/doccleanup_coverage.md`**. Parse `- YYYY-MM-DD — <zone> — <mode> — …` lines into `(zone, date)` pairs.
2. **`covered_zones`** = map `<zone> → most recent coverage date` from `project` or `zone` mode lines (paths) whose validation is **not** `tests KO` (a KO pass remains pending; see `references/file-formats.md`). `session (…)` lines do not refer to an inventory zone → ignore them for coverage (prior session cleanup merely makes a later zone lighter).
3. **Staleness** (git repos only): revalidate a covered zone as **stale** if code changed there since cleanup—`git log -1 --format=%cd --date=short -- <zone>` later than **or equal to** its coverage date (same-day equality counts as stale: whether the commit precedes or follows the pass is unknowable; a redundant rescan is better than missing new code). *Self-correction*: the user's cleanup commit may trigger stale **once**; the agent rescans, finds the zone clean, writes a current `0 deleted` line, and the zone stops being stale the next day. Non-git repo → no staleness; path-only coverage.
4. **`pending_zones`** = `(inventory − covered_zones) ∪ stale_zones`.
5. **Processing order**: **never-covered** zones first, then **stale** zones (modified since), with deterministic **path-alphabetical order** as a tie-breaker (reproducible across runs).
6. If `pending_zones` is empty (everything covered **and** nothing stale), announce that the entire project is current and offer either a full rescan (ignore coverage) or zone mode with an explicit path. Wait.

## D. Campaign plan + go-ahead

Before starting anything, show the plan using the `project:plan` template (see `references/file-formats.md`):

- pending/total zone count and resume point, if any,
- detected **validation command** (or ask once if ambiguous; see `references/orchestration.md > Validation`),
- reminder: aggressive cleanup; git remains uncommitted (review = diff).

**Wait for explicit go-ahead.** This is the campaign's only gate; afterward it runs autonomously zone by zone, with a report per zone. No per-comment approval (nonsensical for aggressive cleanup)—review the uncommitted diff at campaign end.

## E. Campaign loop

For each zone in `pending_zones`, in order:

1. **Choose executor**: if subagents are available and authorized, instantiate one with fresh context using `references/orchestration.md > Zone-subagent briefing`. Otherwise, process the zone in a segmented main-loop using that briefing as a checklist. Keep a single small zone ≲ 1500 LoC in the main-loop.
2. **Produce the summary** (files inspected, deletions, renames + sites + tool, docs de-drifted, files modified, unprocessed items, uncertainties). Do **not** load code from multiple zones simultaneously into the main context.
3. **Verify summary integrity** (see `references/orchestration.md > Summary integrity verification`): cross-check `git diff --stat -- <zone>` against the summary and scope (overflow allowed only for declared rename-propagation sites). Anomaly → investigate/rerun; **do not** mark covered.
4. **Validate** (command established in D). KO → **stop the campaign**, report the failure + zone, and let the user arbitrate. OK → step 5.
5. **Write the coverage line** (delta, at the top of `<STATE_DIR>/doccleanup_coverage.md`): see `references/file-formats.md`.
6. **Per-zone report** via `project:zone-progress`, then next zone.

Strict serialization (see orchestration): one zone at a time, with renames propagated across the entire project before the next.

## F. Final output

When `pending_zones` is exhausted (or after stopping on tests KO), show `project:summary`: processed zones, aggregate totals (comments deleted, renames, docs de-drifted), remaining zones if any, and a reminder that everything is uncommitted.

## End-of-mode invariants

- One coverage line written **per processed zone** (`project` mode).
- Validation run and reported per zone (or degradation announced once).
- Renames listed in zone summaries.
- No `git add`/`commit`.
- Campaign interrupted on KO → partial state **announced** (completed vs remaining zones), never silently return control.
