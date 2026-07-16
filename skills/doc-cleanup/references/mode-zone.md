# Mode: zone (one path or auto-selection)

Playbook loaded by SKILL.md in **zone** mode, with an optional path. Surgically clean a single zone. Load `references/doctrine.md` before executing (and `references/orchestration.md` only if the zone is large). For cross-cutting conventions, see SKILL.md.

## A. Bootstrap

If `<STATE_DIR>/doccleanup_coverage.md` is absent, create it with `# Doc-cleanup coverage\n\n` and announce it. Resolve `<STATE_DIR>` from the project root, never from raw `cwd`—in forced-zone mode, use the root nearest `<path>`. (Same bootstrap as `mode-project.md > A`.)

## B. Determine the zone

**With `<path>` (forced zone)**:
1. Verify the path exists. Otherwise → ask for clarification; do not guess.
2. This is the scope. (Single file or directory.)

**Without an arg (auto zone)**:
1. Inventory zones (see `references/mode-project.md > B`).
2. Read `<STATE_DIR>/doccleanup_coverage.md`; build `covered_zones` (`project`/`zone` lines).
3. Choose a **never-covered** zone first; otherwise, the least recently covered. Break ties deterministically by path-alphabetical order.
4. **Announce the selected zone** (`zone:selection` template) with 1–2 alternatives, and wait for user approval (accept / another zone / forced path).

## C. Execution

1. **Size**: measure source LoC in the zone.
   - **Small (≲ 1500 LoC, or a single file)** → process directly in the **main-loop**: read and apply the 3 verbs (see `references/doctrine.md`).
   - **Large** → partition into coherent subdirectories. Delegate to subagents if available and authorized; otherwise process subzones in a segmented main-loop. Serialize every mutation.
2. **Apply the doctrine**: DELETE noise, RENAME to delete (grep references across the entire project **before** each rename and update every site), KEEP + de-drift survivors.
3. **Refuse > 5000 LoC** in forced-zone mode: propose subscopes instead of superficial cleanup, and ask for confirmation before forcing it.

## D. Validation

For every large zone, delegated or not, **verify summary integrity** before validation (see `references/orchestration.md > Summary integrity verification`). Then run validation (see `references/orchestration.md > Validation`) **after the zone is fully applied**. KO → report and let the user arbitrate; write the coverage line **anyway** with `tests KO (<detail>)`—it records the pass but does not count as coverage (the zone remains pending; see `references/file-formats.md`).

## E. Write + output

1. **Coverage line** (delta, at the top of `<STATE_DIR>/doccleanup_coverage.md`): mode `zone`. See `references/file-formats.md`.
2. **Output** via `zone:summary`: comments deleted, renames (list), docs de-drifted, validation result, uncommitted reminder.

## End-of-mode invariants

- Coverage line written (`zone` mode).
- Validation run and reported (or degradation announced).
- Renames listed.
- No `git add`/`commit`.
- Nonexistent/oversized forced zone → clarification requested; no blind cleanup.
