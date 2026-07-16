---
name: doc-cleanup
argument-hint: "[<path> | project | session [--touched | --files <path>...]]"
description: "Aggressively remove redundant, stale, or AI-generated code comments and docstrings while preserving business rules, non-obvious intent, safety notes, and public API contracts. Use for comment cleanup, over-documentation, self-documenting renames, project-wide cleanup, or files touched in the current session; also for French requests such as « nettoyer les commentaires » or « supprimer la sur-documentation ». This skill edits code. Use maintainability instead for structural audits."
---

# Doc-cleanup skill

Aggressively clean code documentation: remove noise (comments that paraphrase code), make code self-documenting through renames, and make the few surviving comments reliable (correct drift). The deliverable is **cleaned code** in the worktree, not a report.

## Boundary

Perform the requested cleanup in code. For a structural audit (duplication, dead code, god files, coupling, architecture), use the `maintainability` skill: it *diagnoses and tracks* findings, while this skill *modifies* the documentation layer.

## References

This SKILL.md is a **thin router**: it selects the mode, defines cross-cutting conventions, and points to the playbook. Normative details live in `references/` and are loaded **on demand**:

**Doctrine (the core—read before any cleanup, in every mode)**:

- `references/doctrine.md` — the aggressive stance, the “*what* = noise / *why* = keep” heuristic, the 3 verbs (DELETE / RENAME / KEEP+de-drift), the indicative delete-on-sight list, the survivor allowlist, and guardrails (when NOT to touch). **Without this reading, cleanup drifts**—either too timid (an agent's default) or destructive.

**Mode playbooks (read and execute the current mode's playbook)**:

- `references/mode-project.md` — global campaign: bootstrap, zone inventory, coverage ledger, campaign loop, resume.
- `references/mode-zone.md` — clean a single path (or auto-select a zone).
- `references/mode-session.md` — git-diff selection, `--touched`, or an explicit `--files` list for an orchestrator.

**Orchestration and formats (load when fanning out or writing state)**:

- `references/orchestration.md` — subagent strategy when available (fan-out vs main-loop), sequential fallback, rename safety, validation granularity, and zone-agent briefing. Shared by `project` and by `zone` for large zones.
- `references/file-formats.md` — coverage-ledger format (`<STATE_DIR>/doccleanup_coverage.md`) and chat-output templates.

## Mode dispatch

Infer the mode from the user's request, independently of the agent invocation syntax:

| Request intent | Mode | Playbook | Expected input |
|---|---|---|---|
| Clean a zone, without a path | **zone (auto)** | `references/mode-zone.md` | Inventory, propose a zone, obtain approval, then clean it. |
| Clean a zone with a path | **zone (forced)** | `references/mode-zone.md` | Existing file or directory path. |
| Clean the entire project | **project** | `references/mode-project.md` | No additional argument. |
| Clean session files | **session** | `references/mode-session.md` | Optional `--touched`. |
| Clean an explicit list of touched files | **session (explicit)** | `references/mode-session.md` | `--files <path>...`; incompatible with `--touched`. |

Accept `/doccleanup`, `/doccleanup-project`, and `/doccleanup-session` as compatibility aliases. With Codex, equivalent phrasings include `$doc-cleanup sur src/`, `$doc-cleanup sur tout le projet`, `$doc-cleanup sur les fichiers touchés --touched`, and `$doc-cleanup session sur la liste explicite de fichiers suivante`. If the skill is invoked explicitly without details, choose **zone (auto)**.

**Dispatch procedure**: (1) verify the project root; (2) resolve `<STATE_DIR>`; (3) validate the remaining request input—ask for clarification only for a nonexistent path or unknown flag; (4) read `references/doctrine.md`; (5) read and execute the mode playbook. Never depend on an agent-specific variable such as `$ARGUMENTS`.

## Project-root detection

Before dispatching, confirm that `cwd` is a project root:

1. Look for a marker in `cwd`: `.git/`, `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `composer.json`, `Gemfile`, `pom.xml`, `build.gradle`, `.hg/`, `.svn/`.
2. **Found** → continue.
3. **Absent** → walk up through parents until a marker (or filesystem root).
4. **Found in a parent**: announce *"The project root appears to be `<parent>`, but `cwd` is `<cwd>`. Rerun from `<parent>` or confirm here (state will be created in the confirmed project)."* and wait.
5. **No marker**: abort with *"No project marker detected. Run the command from a project root."*

If the user supplies a `<path>` (forced-zone mode), the path is the scope and state is attached to the nearest root marker.

## State directory

`<STATE_DIR>` = `<PROJECT_ROOT>/.code-quality`, shared by Claude Code and Codex. Create it only when a mode must write.

Throughout this skill's references, an unqualified state filename such as `doccleanup_coverage.md` always means `<STATE_DIR>/doccleanup_coverage.md`.

## Cross-cutting conventions (all modes)

These rules apply to **every** mode and are not repeated in the playbooks.

1. **Read-only git.** The skill **freely edits the worktree** (that is its product), but **never** touches the index or history: `git log`/`diff`/`status`/`blame`/`show` are allowed; `git add`/`commit`/`push`/`reset`/`checkout`/`restore` are **forbidden**. Changes remain uncommitted—the user owns review and commit. The uncommitted diff **is** the skill's review surface.

2. **Validate after each fully applied zone** (never per edit). A rename touches N files: the zone is valid only after all N are done. Detect the project's lint/test command (see `references/orchestration.md > Validation`) and run it at the end of each zone. **Tests KO → do not proceed to the next zone**: announce it, then either fix it or report that the zone remains partial. No test setup detected → announce it and continue in degraded mode (compile/lint only, if available).

3. **Deterministic date.** Every date written to state (`<STATE_DIR>/doccleanup_coverage.md`) comes from `date +%F`, never from memory. If `date` is unavailable, report that in chat rather than inventing one.

4. **Delta writes.** Immediately before writing the coverage ledger, reread it and **prepend the new line** at the top without regenerating the file (it may have been edited manually).

5. **No silent big-bang renames.** Deletion cleanup is applied directly (the uncommitted diff is the review). **Renames** have a cross-file blast radius: each rename is preceded by a reference grep (see `references/doctrine.md` and `references/orchestration.md`) and **explicitly listed** in the zone output.

## Doctrine—load before any cleanup

`references/doctrine.md` **must** be read at the start of every mode: it contains the calibration that makes or breaks the skill (see its description in *References*). No mode may produce an edit without loading it.

## Chat-output conventions

Outputs follow the named templates defined in `references/file-formats.md > Templates`. Cross-cutting conventions:

- **Header**: `<Mode> complete — <scope>`.
- **Trailer** “Files updated: …” whenever the ledger is written; mention cleaned source files by count, not by exhaustive list (the git diff carries the details).
- **Normalized stats**: `<N> comments deleted, <M> renames, <K> docs de-drifted`.
- Separate the proposed-action block (launch campaign, continue, etc.) from the summary.

## End-of-mode invariants

Before returning control, verify that all expected mode writes occurred (a **not applicable** item counts as checked):

- Ledger `<STATE_DIR>/doccleanup_coverage.md` updated (one line per cleaned zone/pass).
- Validation run and result reported (or degradation announced).
- Renames listed in output.
- No `git add`/`commit` performed.

**If an item could not be checked** (tests KO, no setup, read-only file), **announce it in chat** rather than silently returning control—the user must know partial state exists. Each mode's detailed checklist is at the end of its playbook.
