# Chat output templates

Read before every mode output. Preserve the structure; adapt placeholders only. Modes that write end with `Files updated`, unlike `list`.

## `selection:proposition`

```text
I propose: <scope> — <reason>
Materiality: <high|medium> — <sourced exposure × plausible cost>
Workload: <sanitized command/scenario>
Metric: <primary metric>
Alternatives: <alt-scope-1> — <reason>, <alt-scope-2> — <reason>
Excluded (exposure-capped): <scope> — <short calculation>; ...
```

Add `Required information: <missing>` if no representative workload is available. Omit the `Excluded` line when there is no newly capped scope. Wait for validation.

## `selection:coverage-stop`

```text
Material performance coverage reached — no material target remains.

Excluded (exposure-capped): <scope> — <short calculation>; ...
Cold and unchanged since their last audit: <scope> (<date>); ...
Actionable pending findings: <n, or "none">

Which operation feels slow in use? A description (`feature <...>`) or path launches a targeted audit; an environment or dependency change justifies remeasurement (`update`).

Files updated: <STATE_DIR>/performance_history.md (+<k> skipped lines) [or "none"].
```

Omit empty lines. Under `performance-cycle` orchestration, this template supplies the early-stop reason in the campaign summary.

## `audit:summary`

```text
Performance audit complete — <scope>

Workload: <summary>
Baseline: <metric + value + dispersion + short environment>

<N> new findings (<X> HIGH, <Y> MED, <Z> LOW):
  <ID> (<SEV>, <axis>) — <short observation> — <short evidence>

Files updated: <STATE_DIR>/performance_findings.md (+<N>), <STATE_DIR>/performance_history.md (+1 line[, +<k> skipped lines]).
```

Follow with `audit:proposition`.

## `audit:clean`

```text
Performance audit complete — <scope>. Valid measurement, no actionable bottleneck on this workload.

Workload: <summary>
Result: <metric + value + dispersion> [budget: <budget met>]
Refuted hypotheses: <hypothesis — short measurement>; ...

Files updated: <STATE_DIR>/performance_history.md (+1 `0 findings (clean)` line[, +<k> skipped lines]).
```

Omit the `Refuted hypotheses` line if triage attached none to the target.

## `audit:inconclusive`

```text
Performance audit inconclusive — <scope>

Cause: <missing workload | unstable variance | insufficient attribution | unsafe environment | other>
To conclude: <specific information or condition>

Files updated: <STATE_DIR>/performance_history.md (+1 `0 findings (inconclusive: <reason>)` line).
```

Never call this result `clean`.

## `audit:proposition`

```text
Proposed next step: double-check <priority-ID> — <reason: severity, exposure, or evidence to confirm>.
Otherwise: double-check another ID or keep the findings pending.
```

## `list:dashboard`

```text
Performance board — <project>

Actionable pending findings (<total>):
  HIGH (<n>): <ID> (<scope>, <metric/baseline>, <short observation>)
  MED  (<n>): ...
  LOW  (<n>): ...

Stale / blocked (<n>):
  <ID> — <status and cause>

Recently resolved (last 30 days):
  <ID> (<SEV>) — <date> — <before/after gain>

Rolling (N=<N>):
  <date> — <scope> — <result>

Excluded (exposure-capped): <scope> — <short calculation>; ...

Next step: <double-check ID | update | new audit> — <reason>.
```

Omit `Stale / blocked` if empty. If zero resolved, write `None resolved in the last 30 days.` If zero pending, state it without severity lines. Omit `Excluded` if history contains no `skipped` line.

## `update:summary`

```text
Performance update complete — <project>

Remeasured <N>/<total> pending findings:
  Resolved (<n>): <IDs with before → after>
  Still present (<n>): <IDs>
  Regressed (<n>): <IDs with measurement>
  Non-comparable (<n>): <IDs with cause>
  Relocated (<n>): <ID old → new>
  Stale (<n>): <IDs>
  Blocked (<n>): <IDs>

Files updated: <exact list of modified state files>.
```

Omit zero-count categories. If some workloads were not run, state which ones and why.

## `double-check:output`

```text
Double-check <ID> — <verdict>

Reproduction: <initial baseline → current measurement, dispersion, comparability>
Attribution: <profile/experiment>
Blast radius: <call sites, tests, surfaces>
Risks: <correctness, memory/I-O/concurrency, maintainability>
Effort: <S|M|L>
Refined acceptance: <criterion>
Refined plan: <recommendation>
Verdict: <GO|GO-but-after-X|NO-GO|INCONCLUSIVE>

Files updated: <STATE_DIR>/performance_findings.md (Double-check added[, severity/location amended]).
```

## `double-check:proposition`

GO / GO-but-after-X:

```text
What should be done for <ID>?
  (a) Fix now — plan, explicit OK, tests, before/after benchmark, and maintainability guardrail.
  (b) Later — the Double-check remains on the board.
```

NO-GO:

```text
NO-GO verdict. Archive <ID> with the reason, or keep it pending?
```

INCONCLUSIVE:

```text
No fix proposed: <condition> is missing. <ID> remains pending.
```

## `resolution:confirm`

```text
<ID> meets acceptance: <before> → <after> (<gain>, dispersion <value>), tests OK, maintainability guardrail OK. Should I mark it resolved?
```

## `resolution:done`

```text
Performance resolution complete — <ID>: <before> → <after> (<gain>).

Files updated: <STATE_DIR>/performance_findings.md (move <ID> → Resolved), <STATE_DIR>/performance_history.md (resolved <ID>)[, <STATE_DIR>/performance_resolved_archive.md].
```

## `resolution:failed`

```text
Fix not validated — <ID> remains pending.

Cause: <tests failed | no gain | result within variance | unjustified maintainability debt>
Measurement: <before> → <after, dispersion>
Modified files: <list of files touched by the fix>
Diff kept in the worktree for review; no resolution status written.
To set it aside: `git stash push -- <files>` (not executed).
```
