# State format & output templates

Reference loaded when a mode writes state or produces chat output.

## `<STATE_DIR>/doccleanup_coverage.md`

**Append-only coverage ledger.** One line per cleanup pass, **prepended at the top** (newest first). Never trimmed.

### Why Markdown, why one file

State uses Markdown (readable, git-diffable, hand-editable) and is **minimal by design**: the skill's deliverable is *cleaned code*, not a findings registry. The ledger serves only **two purposes**—knowing where to resume a campaign (coverage by zone) and keeping a dated record of passes.

### Format

```markdown
# Doc-cleanup coverage

- 2026-06-25 — services/api/ — project — 34 deleted, 5 renames, 2 docs de-drifted — tests OK
- 2026-06-25 — src/utils/format.ts — zone — 8 deleted, 1 rename — tests OK
- 2026-06-24 — session (7 files) — session — 22 deleted, 3 renames, 1 de-drifted — tests OK
- 2026-06-23 — services/billing/ — project — 0 deleted (already clean) — tests OK
```

- Line: `- YYYY-MM-DD — <scope> — <mode> — <N> deleted, <M> renames, <K> docs de-drifted — <validation>`
- `<scope>` = path (directory/file) for `project`/`zone`; `session (<N> files)`, `session --touched (<N> files)`, or `session --files (<N> files)` for `session`.
- `<mode>` ∈ `project` | `zone` | `session`.
- `<validation>` = `tests OK` | `tests KO (<detail>)` | `degraded validation (<what ran>)`.
- Zero stats are accepted (`0 deleted (already clean)`)—this is valid coverage recording that the zone was inspected.
- **Coverage (`project` resume)**: `covered_zones` = paths from `project`/`zone` lines whose validation is **not** `tests KO`—a failed pass remains recorded (the line is still written) but does not count as coverage, so the zone returns to pending on resume. `degraded validation` counts as coverage (cleanup happened; the environment lacks tests). `session` lines do not count as zone coverage (see `references/mode-project.md > C`).
- **Staleness**: the coverage date also supports **revalidation**. A covered zone whose code changed since then (`git log` activity dated later than **or equal to** its coverage date—equality counts as stale) returns to pending on the next `project`: noise may have reappeared. For the equality rationale and self-correction, see `references/mode-project.md > C`. Without this comparison, path-only coverage would become falsely reassuring over time.

## Chat-output templates

Follow the structure exactly (placeholder content adapts). For cross-cutting conventions (header, trailer, summary/proposal separation), see SKILL.md.

### `zone:selection`—Auto-zone announcement (zone mode, no arg)

```
I propose: <zone> (<reason: never cleaned | least recently cleaned on YYYY-MM-DD>, <LoC>)
Alternatives: <zone-alt-1> (<reason>) or <zone-alt-2> (<reason>)
```

### `zone:summary`—Cleaned zone

```
Doc-cleanup complete — <zone>

<N> comments deleted, <M> renames, <K> docs de-drifted.
Renames: <old → new (S sites)>, … (or “none”)
Validation: <tests OK | tests KO: detail | degraded>

Files updated: <STATE_DIR>/doccleanup_coverage.md (+1 line). Cleaned code is uncommitted—review via `git diff`.
```

### `project:plan`—Campaign plan (before go-ahead)

```
Doc-cleanup campaign — <project>

Zones: <pending>/<Z> to process<, resuming: <C> already covered>.
Validation: <detected command | to confirm>.
Mode: aggressive cleanup, serialized zone by zone. Nothing will be committed (review the final diff).

Launch? (go / adjust validation command / target a specific zone in zone mode)
```

### `project:zone-progress`—Per-zone progress (during campaign)

```
[<i>/<pending>] <zone> — <N> deleted, <M> renames, <K> de-drifted — <tests OK|KO>
```

### `project:summary`—Campaign completion

```
Doc-cleanup campaign complete — <project>

<Z-processed> zones processed<, <remaining> remaining (stopped because <reason>)>.
Totals: <ΣN> comments deleted, <ΣM> renames, <ΣK> docs de-drifted.

Files updated: <STATE_DIR>/doccleanup_coverage.md (+<Z-processed> lines). Everything is uncommitted—review via `git diff`, then commit manually.
```

### `session:summary`—Cleaned session

```
Doc-cleanup session complete — <N> files

<ΣN> comments deleted, <ΣM> renames, <ΣK> docs de-drifted.
Renames: <old → new (S sites)>, … (or “none”)
Validation: <tests OK | KO: detail | degraded>

Files updated: <STATE_DIR>/doccleanup_coverage.md (+1 line). Cleaned code is uncommitted—review via `git diff`.
```

### `session:none`—Nothing to clean

```
No source files are modified in the worktree. If your session work is already committed, invoke `doc-cleanup` in zone mode with an explicit path.
```
