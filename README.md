<p align="center">
  <img src="assets/thoth-logo.png" width="200" alt="Thoth">
</p>

<h1 align="center">Thoth</h1>

<p align="center"><em>Code-quality skills written once and shared by Claude Code and Codex.</em></p>

<p align="center">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-E9B84C.svg"></a>
  <img alt="Agents" src="https://img.shields.io/badge/agents-Claude%20Code%20%C2%B7%20Codex-2E5FA3">
  <img alt="Version" src="https://img.shields.io/badge/version-0.3.0-blue">
</p>

## What is Thoth?

**Thoth** — *Toolkit for Heuristic Orchestration & Task Handling* — equips coding agents with robust, reusable code-quality workflows: **maintainability** audits, measured **performance** optimization, and **comment cleanup**.

Two principles set it apart from a simple prompt:

- **Audit before fixing.** Instead of a one-shot refactor, each skill first *diagnoses and tracks*—persistent findings with stable IDs, a dashboard, and before/after evidence—then modifies code after confirmation. Its [**autonomous cycles**](#autonomous-cycles) run the entire *audit → fix → validation* loop without supervision.
- **One source, two agents.** Each skill's content exists **once** and installs identically for **[Claude Code](https://docs.claude.com/en/docs/claude-code)** and **[Codex](https://openai.com/codex/)**. One skill is a slash command (`/maintainability`) in Claude Code and a natural-language invocation (`$maintainability …`) in Codex.

## Skills

Thoth works at two levels. **Autonomous cycles** are the toolkit's core: they run the complete *audit → double-check → fix → validation* loop for you. They build on **atomic skills**, which you can also run individually when you want control at each step.

| Skill | What it does | Example |
|---|---|---|
| [`maintainability-cycle`](#maintainability-cycle) | **Autonomous cycle**: audit → double-check → fix → validation, for one or more cycles | `/maintainability-cycle 5` |
| [`performance-cycle`](#performance-cycle) | Measured **autonomous cycle**: selection → double-check → **one** optimization → before/after benchmark | `/performance-cycle` |
| [`maintainability`](#maintainability) | Audit and tracked debt resolution: duplication, dead code, complexity, coupling, boundaries… | `/maintainability src/api` |
| [`performance`](#performance) | Diagnosis based on reproducible measurements: latency, CPU, memory, I/O, contention… | `/performance feature checkout` |
| [`doc-cleanup`](#doc-cleanup) | Remove comments that paraphrase code while preserving business rules and API contracts | `/doc-cleanup session` |

### Autonomous cycles

The most complete way to use Thoth: a native `goal`, a bounded loop, and every atomic-skill guardrail preserved. Each cycle orchestrates its corresponding atomic skill ([`maintainability`](#maintainability), [`performance`](#performance)) without ever lifting its safety or evidence rules.

#### `maintainability-cycle`

Autonomous orchestration of one or more complete cycles within a native goal: select an audit or Pending findings, mandatory GO/NO-GO double-check, bounded fixes for GO findings, validation, and ledger updates.

- one cycle by default, or `N` cycles with an early stop when nothing remains actionable;
- bounded autonomous authorization that avoids intermediate confirmations without expanding Git permissions;
- subagents organized by role and capability, with no fixed model or provider name;
- an anti-testing-creep policy and a single `doc-cleanup` closeout on files modified by the campaign.

#### `performance-cycle`

Autonomous orchestration of one or more measured cycles within a native goal: select a Pending finding or safe audit, mandatory double-check, fix a single `PERF-NNN`, comparable before/after benchmark, and ledger resolution.

- one cycle by default, or `N` cycles with an early stop when no measurable hypothesis is actionable or material coverage has been reached;
- authorization bounded to local, safe, short, unambiguous workloads without lifting production protections;
- one optimization per cycle to preserve gain attribution;
- strictly serialized measurements, profiles, builds, and mutations, including with subagents;
- a single `doc-cleanup` closeout on files modified by the campaign.

### Atomic skills

The building blocks orchestrated by cycles—run them directly for a targeted audit, dashboard, or specific fix.

#### `maintainability`

Audit, tracking, and controlled resolution of maintainability debt: duplication, dead code, complexity, size, inconsistencies, coupling, architectural boundaries, redundant tests, scattered configuration, and light documentation debt.

- zonal and cross-zone audits;
- persistent tracking with stable IDs, dashboard, and Pending rechecks;
- double-checks with blast radius and verdict before any fix;
- confirmed, test-validated fixes with cascade rechecks after resolution.

#### `performance`

Performance audit based on reproducible measurements: latency, throughput, CPU, memory, I/O, contention, and scalability under load.

- automatic audit with materiality triage—sourced exposure before any harness, scopes with a demonstrable ceiling recorded without measurement—or targeted by path/feature;
- workload contract, baseline, profiling, and comparability;
- persistent `PERF-NNN` findings and dashboard;
- double-checks that reproduce evidence, with fixes validated by tests and before/after benchmark.

#### `doc-cleanup`

Aggressive cleanup of comments and docstrings that paraphrase code while preserving business rules, non-obvious intent, safety constraints, and public API contracts.

- zone, whole-project, or session-touched-files mode;
- careful renames to make code self-documenting;
- per-zone validation and persistent coverage.

## Installation

Install Thoth **locally** with `make`: each skill is copied into the target agent's directory (an exact per-skill mirror via `rsync --delete`, without touching differently named skills).

```bash
# 1. Clone the repository
git clone https://github.com/Seeky91/thoth
cd thoth

# 2. Install for your agent
make install-claude        # → ~/.claude/skills/
make install-codex         # → ~/.agents/skills/
make install-all           # both (equivalent to `make install`)

# One skill only:
make install-claude SKILL=maintainability
```

Without a suffix, the bare aliases `make install`, `make diff`, and `make uninstall` target **both agents**. The generic form `make install AGENT=claude|codex|all` is equivalent.

| Command | Purpose |
|---|---|
| `make list` | Installation status by agent |
| `make diff-claude` / `make diff-codex` `[SKILL=x]` | Compare repository and installation |
| `make uninstall-claude` / `make uninstall-codex` `[SKILL=x]` | Uninstall (with confirmation) |
| `make validate` | Validate structure, symlinks, and manifests |

> **Plugin installation.** The repository also includes `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json`. When installed as a **plugin** (via a marketplace) instead of locally, the skill is prefixed with the plugin name (`thoth`): `/thoth:maintainability`, `/thoth:performance-cycle`, etc. The skill body is identical—only the invocation name changes.

## Usage

Both agents load the same `SKILL.md`; only explicit invocation syntax differs. Each skill can also be invoked **implicitly** when your request matches its description.

| Intent | Claude Code | Codex |
|---|---|---|
| Automatic maintainability audit | `/maintainability` | `$maintainability audit the most relevant zone` |
| Targeted audit | `/maintainability src/api` | `$maintainability audit src/api` |
| Dashboard | `/maintainability list` | `$maintainability show the dashboard` |
| Recheck Pending findings | `/maintainability update` | `$maintainability recheck Pending findings` |
| One autonomous maintainability cycle | `/maintainability-cycle` | `$maintainability-cycle run one cycle` |
| Multiple autonomous cycles | `/maintainability-cycle 5` | `$maintainability-cycle run 5 cycles` |
| Cycles without documentation closeout | `/maintainability-cycle 5 --no-doc-cleanup` | `$maintainability-cycle run 5 cycles without doc-cleanup` |
| Automatic performance audit | `/performance` | `$performance audit the most relevant target` |
| Performance targeted by path | `/performance src/api` | `$performance audit src/api` |
| Performance targeted by feature | `/performance feature checkout` | `$performance audit the checkout feature` |
| Performance board | `/performance list` | `$performance show the dashboard` |
| Remeasure Pending findings | `/performance update` | `$performance remeasure Pending findings` |
| Double-check a finding | `/performance double-check PERF-001` | `$performance double-check PERF-001` |
| One autonomous performance cycle | `/performance-cycle` | `$performance-cycle run one cycle` |
| Multiple performance cycles | `/performance-cycle 5` | `$performance-cycle run 5 cycles` |
| Performance cycles without documentation closeout | `/performance-cycle 5 --no-doc-cleanup` | `$performance-cycle run 5 cycles without doc-cleanup` |
| Targeted cleanup | `/doc-cleanup src/api` | `$doc-cleanup clean src/api` |
| Files touched in the session | `/doc-cleanup session` | `$doc-cleanup clean the touched files` |
| Explicit file list | `/doc-cleanup session --files src/a.ts src/b.ts` | `$doc-cleanup session on src/a.ts and src/b.ts only` |
| Whole project | `/doc-cleanup project` | `$doc-cleanup clean the entire project` |

### State generated in audited projects

The skills write their tracking state to a neutral directory shared by both agents at the audited project root:

```text
.code-quality/
├── maintainability_history.md
├── maintainability_findings.md
├── maintainability_resolved_archive.md
├── performance_history.md
├── performance_findings.md
├── performance_resolved_archive.md
└── doccleanup_coverage.md
```

Multi-cycle campaigns temporarily add `maintainability_campaign.md` or `performance_campaign.md`: required for `N > 1`, deleted after normal closeout, and retained only to resume an interrupted campaign.

## Architecture

Each skill's domain content exists once under `skills/`:

```text
skills/
├── maintainability/          ┐
│   ├── SKILL.md              │  atomic skills
│   ├── agents/openai.yaml   │  (SKILL.md + Codex metadata
│   └── references/          │   + references loaded on demand)
├── performance/             │
│   └── …                    │
├── doc-cleanup/             ┘
│   └── …
├── maintainability-cycle/    ┐  orchestrators
│   ├── SKILL.md             │  (SKILL.md + agents/openai.yaml)
│   └── agents/openai.yaml   ┘
└── performance-cycle/
    └── …
```

Project views are simple symlinks to this single source, and the repository includes both distribution manifests:

```text
.claude/skills/   → Claude Code view (symlinks to ../../skills/<name>)
.agents/skills/   → Codex view       (symlinks to ../../skills/<name>)
.claude-plugin/plugin.json
.codex-plugin/plugin.json
```

There are no separate command files: each skill is natively invocable as a slash command, with arguments interpreted by the `SKILL.md` dispatch.

## Contributing

To add a skill:

1. Create `skills/<name>/SKILL.md` and any resources.
2. Add `skills/<name>/agents/openai.yaml` for Codex metadata.
3. Create `.claude/skills/<name>` and `.agents/skills/<name>` symlinks to `../../skills/<name>`.
4. Run `make validate`.

`make validate` checks skill structure, frontmatter portability (the Claude/Codex intersection), cited references, symlinks, and JSON manifest validity.

## License

[MIT](LICENSE)
