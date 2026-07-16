# Maintainability dimension catalog

Reference loaded by SKILL.md during an audit or crosscut to define what constitutes a finding on each axis.

## Seed dimensions

12 starting dimensions. **This is not a closed taxonomy**: if a real maintainability problem fits none, **invent a new 3-letter prefix** (e.g. `LOG-` for logging sprawl, `RAC-` for concurrency patterns). Rigor applies to factual observation, not labeling.

| Prefix | Dimension | Target |
|---|---|---|
| `DUP` | Duplication / DRY | Repeated code, copy-pasted logic with minor variations, duplicated schemas |
| `CPX` | Unnecessary complexity, factoring | Deep nesting, accumulated conditions, opportunities to extract a helper |
| `SIZ` | Excessive size | God files (≥600 source LoC), modules mixing too many responsibilities |
| `DED` | Dead code | Unused exports/imports, unreachable branches, abandoned commented-out blocks |
| `INC` | Inconsistent patterns | 3 pagination methods, 4 error conventions, 2 logging styles in one module |
| `IDM` | Language idioms | Nonconformity with idiomatic language patterns: error handling, resource management, builder pattern, strict types, etc. (see dedicated framing) |
| `BND` | Boundary violations, hidden coupling | Module A importing B's internals, public-API bypasses, frequent co-change |
| `DRF` | Type/interface drift | Nearly identical schemas accidentally diverging, front/back duplication, parallel types |
| `TST` | Tests | Redundancy, brittleness, drifting code/test ratio (tests becoming most of the code), implementation rather than contract tests |
| `CFG` | Config / feature-flag sprawl | Accumulated env vars/flags, some never flipped or read anymore |
| `DOC` | Docs/comments | Code/docs desynchronization AND unnecessary comments on self-explanatory code (paraphrasing an explicit function name) |
| `ARC` | Architecture / coupling | Inter-module cycles, misplaced responsibility (feature envy), shotgun surgery, leaky or speculative abstraction, opaque composition roots, pass-through layers, over-fragmentation (see dedicated framing) |

**Out of scope**: security, performance, accessibility, stack selection. Clarification: *internal* repo architecture is covered (`ARC`); stack/framework choice and infrastructure/deployment architecture remain excluded.

**Observation principle**: describe the problem plainly (verifiable fact, file:line, concrete impact) **before** selecting a prefix. Do not force a dimension per audit.

### Boundaries between adjacent dimensions

Several dimensions share "code structure" territory. Assignment rule (avoids reclassification disputes):

| Defect concerns… | Dimension |
|---|---|
| control flow *within a function* (nesting, inverted structure, intra-file fragmentation) | `CPX` |
| file/module size | `SIZ` |
| violation of a *declared* boundary (internal import, public-API bypass) | `BND` |
| a language *expression* idiom (errors, resources, types, construction) | `IDM` |
| mixed abstraction levels in a composition function (entrypoint, bootstrap, subsystem factory) | `ARC` |
| relationship shape *between units*: responsibility placement, dependency graph, abstraction quality | `ARC` |

`BND` vs `ARC` in one sentence: `BND` = a rule exists and is violated; `ARC` = no rule is violated, but the structure itself is defective.

## Opportunistic detection tools

Single source for tool↔dimension mapping, referenced by `references/mode-audit.md > E.1bis` and `references/mode-crosscut.md > C`. For mechanizable dimensions, deterministic tooling beats the agent on **recall** and **location**; the agent retains **judgment**. Invariant posture:

- **Opportunistic, never mandatory.** Check availability (`command -v <tool>`, or a language manifest); if absent, fall back to reading/judgment—introduce no hard dependency.
- **Execute; do not read.** Bring the tool's **output** (ideally JSON) into context, not source code—saving tokens and improving precision.
- **The tool proposes; the agent decides.** A tool hit is a **candidate to examine**, not a finding. Then apply severity, trade-off check (`references/quality.md`), and noise filtering. Crossing a tool threshold (e.g. cyclomatic complexity = 11) is *not* itself a finding.

| Dimension | Tools (JSON output if available) | Notes |
|---|---|---|
| `DUP` | `jscpd` (≈223 languages, JSON/SARIF reporters), PMD `CPD` | Returns duplicate blocks + exact location; ideal repo-wide crosscut. |
| `DED` | `knip` (JS/TS), `vulture` (Python, confidence scores), `deadcode -json` (Go), `cargo-machete`/`cargo-udeps` (Rust), `staticcheck` U1000 (Go) | Unused exports/deps. Preserve crosscut `DED` false-positive caution (public APIs, framework hooks, barrels). |
| `SIZ` / `CPX` | `scc` (LoC + complexity, `--by-file -f json`), `tokei -o json` (LoC), `lizard` (multi-language CCN), `radon cc -j` (Python) | Also supports area inventory (`references/mode-audit.md > B.0`). |
| `CFG` | targeted `ripgrep` (`rg` over env-var/flag reads), `dotenv-linter` (`.env` drift) | Find accumulated/never-read flags. |
| `BND` | import graphs: `madge --circular` (JS/TS), `go list -deps`, `import-linter` (Python), `pydeps` | Cycles, fan-in/out, boundary bypasses. |
| `ARC` | same import graphs as `BND` (+ JS/TS `dependency-cruiser`, rules + JSON), **git co-change** (`git log`, no external dependency) | Cycles, fan-in/out × churn, temporal coupling. Co-change method: see `ARC` framing below—language-agnostic signal. |
| `DRF` | schema/type comparison by judgment (no reliable general tool) | Mostly reading-based. |

For `INC`, `IDM`, `TST`, `DOC`: no reliable substitute tool—use judgment (and for `IDM`, the strict anti-linter guardrail below).

## Paradigmatic frame of reference (cross-cutting for ARC, IDM, CPX)

The skill imposes no single architectural dogma. Evaluated invariants are **high cohesion, low coupling, structural readability**—their idiomatic form varies by paradigm (pure functional module, trait composition, cohesive class). Method:

1. **Detect language(s)**—existing `IDM` mechanism (extensions + config files).
2. **Detect the codebase's effective paradigm** through observable signals—traits/interfaces vs inheritance hierarchies, free functions vs classes, dominant immutability, composition vs extension.
3. **Reference = language idioms ∩ established codebase conventions.** On conflict, **codebase convention wins** (internal consistency beats dogma). Exception: when the codebase "fights the language" and friction is *observable and recurring* (e.g. inheritance hierarchies simulated through Go embedding, shared mutability fighting Rust's borrow checker). Rationale: otherwise the skill would produce dozens of findings against an intentionally object-oriented Python codebase—dogma, not debt.
4. **Evaluate relative to that reference**, never against a named architecture style (hexagonal, clean, DDD) itself. Logical density remains a **quality** while cohesive and scannable; it becomes actionable only with a **concrete, citable reading cost**—a real unnamed sub-concept, an important decision buried in detail, a sequence impossible to follow without holding a stack of incidental elements. "Too dense" without that cost is not a finding. Avoid regression into trivial wrappers or vague names that make navigation costlier than the original block.
5. **Abstain when unfamiliar**: same clause as `IDM` framing—if paradigm or ecosystem is outside the comfort zone, abstain and report it in chat.

No per-language table (it would age poorly): rely on knowledge of encountered language paradigms; the skill specifies method and guardrails.

## IDM dimension framing

`IDM` targets nonconformity with idiomatic language patterns. Its risk is drifting into a style linter—the following framing is strict. Evaluate against the *Paradigmatic frame of reference* above. **Boundary with `ARC`**: `IDM` judges expression *within* code (how it is written); structure *between* units belongs to `ARC`.

**Language detection**: before audit, identify languages via extensions and config (`Cargo.toml`, `pyproject.toml`, `package.json`, `go.mod`, `Gemfile`, `pom.xml`, `composer.json`, …). In a multi-language project, assess IDM area by area using the dominant language.

**Included scope**: structural patterns with direct maintainability impact—readability to a developer familiar with the language, avoidable error-proneness, ecosystem friction. Cover families: idiomatic error handling (Rust `Result`/`?`, Go error wrapping, targeted Python `try/except`), resource management (Python context managers, Go `defer`, Rust RAII, Java try-with-resources), suitable types/containers (Python dataclasses, strict TS types, Java `Optional`), language construction patterns (Rust builder, Python comprehensions). Rely on knowledge of encountered language idioms, not a closed skill list.

**Excluded scope**: anything automatable by a linter or formatter—naming style (snake_case vs camelCase), import order, indentation, quote choice, line length, space before parentheses. Outside this skill.

**Abstain when unfamiliar**: if language-idiom knowledge is insufficient, abstain on this dimension rather than inventing rules. Honest chat note such as *"Skipping IDM for this Elixir file: language idioms are outside my comfort zone."*

## ARC dimension framing

`ARC` targets structural defects **between units** (modules, layers, abstractions). It is the catalog's most subjective dimension—risking drift into an architecture linter. The following framing is strict and symmetric with `IDM`.

**Prerequisite**: evaluate against the *Paradigmatic frame of reference*, never dogma. Apply `references/quality.md > Dogma ≠ defect`: no concrete friction symptom, no finding.

**Included scope** (observable symptoms only):

- **Coupling**: inter-module cycles; temporal coupling (files repeatedly co-modified across a module boundary **without** an import relationship); high fan-in × high churn module (many depend on it AND it changes constantly—a breakage magnet).
- **Cohesion**: misplaced responsibility—feature envy (function mostly manipulating another module's data); shotgun surgery (changing one concept forces edits in N files—a missing seam).
- **Abstraction**: leaky (call sites must know internals—observable when a client imports both the module AND its internals in one file); speculative (unused generality: single-implementer interface designed "for later," parameters never varied); pass-through/middle-man layer (most exports merely delegate); **over-fragmentation** (logic split into indirection fragments where one named cohesive unit would be clearer—the mirror of `SIZ`).
- **Composition roots / local entrypoints**: application entrypoint, subsystem builder/factory, structuring public facade, or pipeline assembly mixing high-level orchestration, detailed construction of concrete dependencies, low-level config, and business logic until the boot/processing sequence is no longer scannable.

**Friction evidence required**: every `ARC` finding cites a concrete, verifiable symptom—the commit that had to touch 7 files, a call site bypassing the abstraction, a file:line cycle, recurring bug pattern, or subsystem construction forcing the parent to know internal details. "It does not follow pattern X" is never an observation.

**Incremental recommendation mandatory**: an `ARC` recommendation proposes a **first step** (invert a dependency, extract an interface, move a function, introduce a named constructor/factory owned by the subsystem), never big-bang reorganization. Δ LoC covers that first step; if the final target is larger, name it without estimating it.

**Detection heuristics** (candidates only, never findings—standard tool posture):

- **Git co-change**: across the ~200 latest non-maintainability commits (reuse `commits_maintainability` from the activity signal; see `references/mode-audit.md > C`), file pairs frequently co-modified (order of magnitude: ≥ 5 co-occurrences) across a module boundary with no import link = hidden coupling; feature commits repeatedly touching ≥ 3 modules = shotgun surgery. Exclude lockfiles and generated files.
- **Instability × churn**: combine import-graph fan-in with git churn—modules high on both axes are priority candidates.
- **Pass-through ratio**: exports that only re-export/delegate without adding anything, detectable with `rg`.
- **Architectural landmarks**: composition files/symbols (`main`, `app`, `server`, `worker`, `bootstrap`, `init`, `start`, `build`, `new`, `factory`, `router`, `pipeline`, structuring public facade). Signal only if the landmark assembles several dependencies/subsystems or sets lifecycle policy; ignore trivial helpers and simple barrels/re-exports.

### Composition roots and abstraction level

A composition root assembles concrete dependencies and sets lifecycle policy. It may be global (`main`, server, CLI) or local to a subsystem (runtime engine, web state, worker, router, pipeline, external client). The lens is **recursive but bounded**: each important boundary deserves readable composition; atomic operations need not become mini-entrypoints.

Look for **uniform abstraction level**: a composition function should read as same-level named steps ("load config → create runtime → start engine → serve web"), not alternate that story with locks, channels, maps, parsers, adapters, or internal fields.

Produce a finding only for observable friction: hard-to-scan boot/processing sequence, parent forced to know subsystem internal fields, local change requiring parent-entrypoint edits, similar wiring copied across roots, or global policy buried in incidental detail.

Expected recommendation: move detail into a named subsystem-owned constructor/factory (`Runtime::new`, `WebState::from_config`, `build_router`, `start_worker`, etc. according to language), while retaining global policies in the parent (boot order, nonfatal fallback, shutdown, mode choice). A single-use extraction is acceptable when it names a real concept or reduces density that impairs reading. **Do not recommend** pass-through wrappers or vague names that merely move the problem or hide important decisions.

**Excluded scope**: adherence to a named architecture style itself; stack/framework selection; infrastructure/deployment architecture; god files (→ `SIZ`); declared-boundary violations (→ `BND`); see *Boundaries between adjacent dimensions*.

**Zonal vs crosscut**: assess cohesion (feature envy, over-fragmentation, local abstraction, opaque composition roots) in zonal audit—with the area's import boundary (see `references/mode-audit.md > E`); deep coupling (cycles, co-change, instability × churn) belongs to `ARC` crosscut.

**Abstain when unfamiliar**: same clause as `IDM`.

## CPX dimension framing—clean design

`CPX` targets *intra-function* complexity. Doctrine: readability comes from **structure**, not formatting rules or statistical thresholds.

**Look for**:

- **Inverted structure**: missing early returns/guard clauses. Signature heuristic: **the nominal case should be the least-indented path**—a function whose nominal return is at the deepest indentation is a candidate.
- If/else chains better expressed as **flat** exhaustive pattern matching/switch in the language.
- Conditions to invert to expose the main flow.
- **Excessive intra-file fragmentation**: cascades of single-use helpers forcing reader jumps—extract a helper when it **names a real concept**, or density has a citable reading cost (unnamed sub-concept, buried decision), never mechanically to reduce length or from a sense that it is "too dense"; avoid trivial wrappers or vague names that only move code (the inter-unit form is `ARC` over-fragmentation).

**Explicit anti-threshold**: no "maximum N nesting levels," no cyclomatic-complexity-as-finding. Nesting level 4 may be the clearest form of a real domain decision tree. Tools (`lizard`, `radon`) supply candidates; judgment decides—the tool proposes, the agent decides.

**Behavior guard**: an early-return rewrite must preserve behavior—beware languages without `defer`/RAII where an early return skips cleanup. Mention this in `Recommendation` when applicable.
