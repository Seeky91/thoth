# Cascade re-verification

Reference loaded by SKILL.md when a fix triggers the cascade (in-session resolution, or `fix B<n>` from `list`). Purpose: detect and update findings whose location overlaps the fix diff without rerunning a full `update`.

**No cascade in these cases**:
- NO-GO moves (no fix, no diff).
- Resolutions from `update` (already exhaustive by construction).

### Algorithm

1. **Capture paths changed by the fix**, in order of preference:
   - **(a) The list of files the agent just edited**—the nominal case: the cascade follows an in-session fix, and the agent knows exactly what it touched.
   - **(b) `git diff --name-only HEAD`** if the list is no longer reliable (fix applied earlier in the conversation)—acceptable over-approximation: it may include user WIP unrelated to the fix, which only adds a few read-only re-check candidates.
   - **(c) `git show --name-only <hash>`** if the fix is already committed (the hash comes from `Resolution`).
   
   An **uncommitted fix is normal** (the skill never commits itself; see SKILL.md > Cross-cutting conventions)—it does not disable the cascade. For batched fixes (several primaries in the same turn): union the paths across all fixes.

2. **Filter candidates** from `## Pending`, excluding primaries already moved. A finding is a candidate iff **at least one** of its paths:
   - exactly matches a diff path, or
   - is a descendant of a diff directory, or
   - is an ancestor of a diff path (god-file case where content is split into subfiles).
   
   For a single-file finding: "its paths" = the title path. For a multi-file finding (`Location` bullet listing several locations, typically from a crosscut): "its paths" = every path listed in `Location`.

   **If there are zero candidates**: silent exit, no write, no chat message.

3. **Re-check each candidate**—reuse the per-dimension logic from update mode (`references/mode-update.md`): read ~20 lines around the location and verify whether the described pattern is still recognizable. Three outcomes:
   - **Pattern still present** → leave pending. If the line shifted significantly, update `path:line` in the title. No other write.
   - **Pattern absent** (file still exists, observation no longer holds) → cascade-resolved. Move to `## Resolved` in compact format. `Resolution:` bullet format: *"resolved collaterally by fix for `<primary-ID>` (YYYY-MM-DD). Measured Δ LoC: included in `<primary-ID>`. Commit: `<primary-hash>`."*—do not fragment Δ; the global value remains in the primary's `Resolution`; align `Commit` with the primary (`uncommitted` if the primary is uncommitted—the cascaded finding never has its own commit).
   - **File missing / renamed** (path absent from the repo after the fix) → leave pending and **replace** the `Status` bullet with `Status: stale-after-<primary-ID> (YYYY-MM-DD) — location invalidated by the fix; relocate or archive`. Do not ask synchronously.

4. **Update `maintainability_history.md`**: for each cascade-resolved finding, recover the original audit area and date from the Pending entry's `Detected` bullet (read **before** the move drops it) and complete `(resolved <IDs>+...)` on the matching audit line.

5. **Apply the Resolved cap invariant** (see `references/file-formats.md > Finding lifecycle` step 5).

### User confirmation (in-session flow)

The existing in-session flow (*"This fix resolves DUP-007. Mark it resolved?"*) is extended: the cascade runs read-only **before** the prompt, and its result is included in the **same prompt** as primary confirmation. Template `resolution:confirm` (see `references/templates.md`) handles both variants (with/without cascade) in a unified format.

The user approves everything with one word. On partial pushback (*"keep INC-008 pending"*): apply the rest; do not insist.

### Chat output (pre-approved flows)

`fix B<n>` flows (list mode) already have explicit approval before execution. The cascade therefore runs **without a new prompt**; its aggregated result is included in the final recap via template `cascade:recap-batch` (see SKILL.md > Chat-output conventions, and `references/templates.md`). If overlap = 0 across all batch fixes, omit the `Cascade recheck:` line.

### Edge cases

- **Cascade resolves another item in the active batch** (`fix B<n>` case): if post-fix re-check for item #1 resolves DUP-008 and DUP-008 is batch item #2 → skip DUP-008 later with *"DUP-008 already resolved collaterally by DUP-007; skipping."*
- **`update` encounters an existing `stale-after-<ID>`**: use the self-heal investigation (see `references/mode-update.md > step 2.b`)—the primary commit is known, a direct signal. Three outcomes: auto-relocation (pattern found elsewhere), auto-resolution (pattern dissolved by the primary fix), or preserve `stale-after-<ID>` if investigation is inconclusive. In the last case, **do not replace** it with generic `stale`—causal information is more valuable.

### Idempotence and cost bound

- Idempotent: rerunning the cascade on the same commit moves nothing again (cascaded entries are already Resolved; the step 2 filter excludes them).
- Cost: ∝ |pendings ∩ diff overlap|, not |pendings|. ≤ ~20 lines read per candidate (the per-dimension re-check is itself bounded).
- Zero cost when overlap is zero (early filtering at step 2, silent exit at step 3).

### Difference from update mode

`update` is exhaustive and explicit—the user runs it to catch up with out-of-session fixes. The cascade is **targeted and automatic**—it covers fixes made in the current conversation. Both coexist: the cascade limits in-session drift; `update` sweeps more broadly when drift escaped it.
