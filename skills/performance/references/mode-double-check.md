# Mode: double-check

Reference loaded with a `PERF-NNN` ID. Read `references/doctrine.md`, `references/file-formats.md`, and the complete targeted source file. Investigate an existing finding without producing a new finding.

## Analysis flow

1. Locate the entry in `## Pending`. If the ID is absent, resolved, or invalid, request a valid pending ID.
2. Replay the recorded workload and protocol as close as possible to the baseline. **Same-session clause:** if the baseline (and profile) were just measured in the same session and neither scope code, workload, nor environment has changed since, reuse them instead of remeasuring and declare this in the bullet (`reproduction: reused same-session baseline`); the double-check then focuses on alternative attribution, blast radius, risks, and acceptance. At the slightest doubt about any invariant, remeasure.
3. Verify comparability and variance. If the baseline does not reproduce beyond expected dispersion, investigate the cause before any recommendation.
4. Read every path in scope, call sites, tests, and involved I/O boundaries.
5. Re-profile the workload and confirm the attributed cost remains dominant—unless reusing a fresh same-session profile.
6. Test the hypothesis without modifying the project if possible: runtime option, controlled experiment, isolated query, or harness under `/tmp`. A source modification belongs to the post-confirmation fix flow.
7. Evaluate:
   - baseline reproducibility;
   - cost attribution and plausible alternatives;
   - functional blast radius and public surfaces;
   - risk of moving concurrency/memory/I/O elsewhere;
   - effort `S` (≤2h), `M` (≤1d), `L` (>1d);
   - maintainability guardrail;
   - refined before/after protocol and acceptance.
8. Produce a verdict:
   - `GO`: stable evidence, bounded fix, credible validation;
   - `GO-but-after-X`: explicit prerequisite;
   - `NO-GO`: refuted hypothesis, unactionable cost, or unjustified tradeoff;
   - `INCONCLUSIVE`: insufficient measurement or attribution.
9. Propose a severity reclassification if measured impact/exposure changed. Keep the ID.

## Writing the Double-check

Add one bullet after `Status`:

```markdown
- **Double-check (YYYY-MM-DD):** reproduction <values>; comparability <state>; profile <evidence>; blast radius <summary>; risks <summary>; effort <S|M|L>; refined acceptance <criterion>; verdict <...>; refined plan <...>.
```

Amend location, workload, acceptance, or severity only with justification in this bullet. Use `double-check:output`, then the appropriate `double-check:proposition`.

## Action according to user choice

### Fix now — GO or GO-but-after-X

1. Present a short plan: files, order, expected mechanism, tests, benchmark, and maintainability risk.
2. Wait for explicit OK before any source modification.
3. If needed, recapture an immediate `before` measurement with the recorded protocol.
4. Implement the smallest credible change without touching the Git index or history.
5. Run targeted tests, then appropriate suite/lint.
6. Replay exactly the comparable benchmark and calculate gain + dispersion.
7. Inspect the diff using `references/doctrine.md > Maintainability guardrail`.
8. Outcomes:
   - tests OK + acceptance satisfied + gain beyond noise + guardrail OK → use `resolution:confirm`; after confirmation, move to compact Resolved format, complete history, and apply the cap;
   - tests fail, gain absent/inconclusive, or unjustified debt → do not mark resolved, use `resolution:failed`, keep the diff for review without automatic revert, list touched files, and propose `git stash push -- <files>` without executing it.
9. Find other pending findings sharing the workload or paths and recommend `update`. Do not resolve them without remeasurement.

### NO-GO

Propose:

- archive in compact Resolved format with `Resolution: archived after double-check (NO-GO: <reason>)`, `Validation: N/A — hypothesis refuted or tradeoff unjustified`;
- or keep Pending if future reevaluation is credible.

### INCONCLUSIVE

Keep Pending. Explain the missing measurement, data, or condition; do not propose a fix.

## End-of-mode invariants

- Baseline replayed, reused via the declared same-session clause, or impossibility explicitly documented.
- Attribution re-verified with a profile or experiment.
- Double-check section written as a delta.
- Verdict consistent with evidence quality.
- No code modified before explicit OK.
- After fix: tests + comparable benchmark + maintainability guardrail executed.
- Finding resolved only after complete validation and confirmation.
- Neighboring findings never auto-resolved without measurement.
