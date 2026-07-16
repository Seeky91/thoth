# Mode: list

Reference loaded in **list** mode. Strictly read-only: do not measure, re-profile, or write anything.

## Flow

1. Read `performance_findings.md` and `performance_history.md` if they exist.
2. Count Pending findings by severity and summarize for each: ID, axis, scope, metric/baseline, and brief observation.
3. List `stale` and `blocked` separately while keeping them in the total Pending count.
4. List resolutions from the last 30 days from `## Resolved`. Do not load the archive; if all 8 capped entries are within the window, report that the view may be truncated.
5. Show the rolling window of the last N audited scopes (`N=4`, or override `<!-- rolling_size: N -->`); `skipped` lines do not count. On one line, mention `skipped (exposure-capped)` scopes present in history, with their calculation.
6. Recommend at most one next action:
   - HIGH/MED finding without a Double-check, most recent baseline first → `double-check <ID>`;
   - otherwise an already double-checked GO finding → resume its fix;
   - otherwise stale/blocked → `update` or restore the missing workload;
   - zero pending → new audit.

Use `list:dashboard` from `references/templates.md`.

## Project without state

Do not bootstrap. Announce: `No performance audit exists for this project. Invoke performance in auto, path, or feature audit mode to begin.`

## End-of-mode invariants

- No project or state file modified.
- No benchmark/profiling command executed.
- Stale/blocked distinguished from actionable pending findings.
- Recommendation based only on read state, without a new technical conclusion.
