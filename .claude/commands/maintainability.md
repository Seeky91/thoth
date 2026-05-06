---
description: Maintainability audit. Usage: /maintainability [path|list|update|double-check <ID>|archive-clear]
argument-hint: "[path | list | update | double-check <ID> | archive-clear [--all|--keep N|--older-than <dur>]]"
---

Invoke the maintainability skill at `~/.claude/skills/maintainability/SKILL.md`.

Arguments: $ARGUMENTS

Parse the arguments and dispatch to the appropriate mode (audit, list, update, double-check, archive-clear) per the skill's dispatch table. If `$ARGUMENTS` is empty, run an audit with autonomous zone selection.
