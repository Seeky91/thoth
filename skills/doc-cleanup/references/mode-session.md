# Mode: session (touched files)

Playbook loaded by SKILL.md in **session** mode, with optional `--touched` or `--files <path>...`. Clean files modified during the current session, or an explicit list supplied by an orchestrator. Load `references/doctrine.md` before executing. For cross-cutting conventions, see SKILL.md.

## A. File selection

### Default selection

Deterministic signal = files **changed vs `HEAD`** in the session (not yet committed), **staged or not**:

1. `git status --porcelain` → **modified**, **staged**, and **untracked** files. This is the **authoritative** source: it sees the index, unlike `git diff` alone (which misses staged-only changes).
2. Filter to **source** files (exclude generated/vendored, non-code, lockfiles, `.md`/`.json`/`.toml`).
3. Set `session_files` = result.

**Staged files/index**: if the index is nonempty, **announce it**. The skill **never modifies the index** (see read-only git): editing an already staged file adds unstaged changes on top (mixed index/worktree state—expected and normal; the user will restage manually). Staged files are **included** in session scope: they are part of the session's work.

**Edge cases**:
- **No changes** (clean worktree) → `session:none`: *"No files are modified in the worktree. If your session work is already committed, invoke `doc-cleanup` in zone mode with an explicit path."* Then stop.
- **Non-git repo** → no reliable session signal: announce it and suggest zone mode with an explicit path.
- Many files (≳ 8) or very large files → serialized **fan-out** if subagents are available and authorized; otherwise a **segmented main-loop**. See `references/orchestration.md`. Keep a small scope in the main-loop.

### Explicit selection (`--files`)

`--files <path>...` entirely replaces `git status` selection. This mode notably closes a multi-cycle campaign without absorbing preexisting WIP:

1. Require at least one path. Resolve each path relative to the project root, normalize, and deduplicate while preserving order.
2. Reject every path outside the root. A nonexistent path or directory is invalid: ask for clarification rather than implicitly expanding it.
3. Filter to source files using the same exclusions as default mode.
4. Verify that each retained file is still modified in the worktree; ignore and announce any file now identical to `HEAD`.
5. Set `session_files` = this filtered list. Never add other files from `git status`.

`--files` and `--touched` are incompatible: reject the combination. If no files remain after filtering, use `session:none` with wording adapted to the explicit list and write no coverage.

## B. Scope: whole file vs hunks

- **Default and `--files`**: clean the **entire file** for each touched file. Rationale: a useless comment 5 lines above a modified line remains useless, and a rename is inherently non-local. The touched file is the *selection*; the whole file is the *work unit*.
- **`--touched`**: restrict to **modified hunks**, obtained via `git diff HEAD` (includes staged **and** unstaged; **not** `git diff` alone, which misses staged hunks). Narrow opt-in. **Untracked files**: `git diff HEAD` produces **no hunks** for them (no base version to diff)—there is nothing to restrict, so process an untracked file **in full** even with `--touched`, and announce this in output (the flag did not bound it; expected because a new file is entirely “touched”). **Warn** that this scope is partial: a rename with references outside hunks must still propagate across the entire project (rename doctrine overrides the scope restriction), and out-of-hunk noise will remain.

## C. Execution

Apply the doctrine (see `references/doctrine.md`) to the retained scope: DELETE noise, RENAME to delete (grep references across the entire project before each rename), KEEP + de-drift. With `--touched`, do not leave the hunks **except** to propagate a rename.

## D. Validation + output

1. **Validate** after all files are processed (see `references/orchestration.md > Validation`). KO → report and let the user arbitrate.
2. **Coverage line** (delta, at the top of `<STATE_DIR>/doccleanup_coverage.md`): mode `session`, scope = `session (<N> files)`, `session --touched (<N> files)`, or `session --files (<N> files)`. See `references/file-formats.md`.
3. **Output** via `session:summary`: files processed, comments deleted, renames, docs de-drifted, validation, uncommitted reminder.

## End-of-mode invariants

- Coverage line written (`session` mode).
- Validation run and reported (or degradation announced).
- Renames listed; with `--touched`, partial-scope warning emitted; with `--files`, no out-of-list file opportunistically cleaned (only propagation sites of a declared rename may be modified outside the list).
- No `git add`/`commit`.
- No touched files → `session:none`; no forced cleanup.
