# Catalogue des dimensions de maintenabilité

Référence chargée par SKILL.md à l'exécution d'un audit ou d'un crosscut, pour cadrer ce qui constitue un finding sur chaque axe.

## Seed des dimensions

11 dimensions de départ. **Ce n'est pas une grille fermée** : si un problème de maintenabilité réel ne colle à aucune, **invente un nouveau préfixe 3 lettres** (ex. `LOG-` pour sprawl de logging, `RAC-` pour patterns concurrents). La rigueur est sur l'observation factuelle, pas sur l'étiquetage.

| Préfixe | Dimension | Cible |
|---|---|---|
| `DUP` | Duplication / DRY | Code répété, logique copiée-collée avec variations mineures, schémas dupliqués |
| `CPX` | Complexité inutile, factorisation | Imbrications profondes, accumulation de conditions, opportunités d'extraire un helper |
| `SIZ` | Taille excessive | God files (≥600 LoC source), modules mêlant trop de responsabilités |
| `DED` | Code mort | Exports/imports inutilisés, branches inatteignables, blocs commentés laissés en place |
| `INC` | Patterns incohérents | 3 façons de paginer, 4 conventions d'erreur, 2 styles de logging dans le même module |
| `IDM` | Idiomes du langage | Non-conformité aux patterns idiomatiques du langage : gestion d'erreur, gestion des ressources, builder pattern, types stricts, etc. (cf. cadrage dédié) |
| `BND` | Violations de frontière, couplage caché | Module A qui importe les internes de B, contournement de l'API publique, co-changement fréquent |
| `DRF` | Drift de types/interfaces | Schémas quasi-identiques qui divergent par accident, dup back/front, types parallèles |
| `TST` | Tests | Redondance, fragilité, ratio code/test qui dérive (tests devenant la majorité du code), tests d'impl plutôt que de contrat |
| `CFG` | Config / feature-flags sprawl | Env vars / flags accumulés, certains plus jamais flippés ou lus |
| `DOC` | Doc/commentaires | Désync code/doc, ET commentaires inutiles sur code self-explanatory (paraphrase d'un nom de fonction explicite) |

**Hors scope du skill** : sécurité, performance, accessibilité, choix de stack.

**Principe d'observation** : décrire le problème en clair (fait vérifiable, fichier:ligne, impact concret) **avant** de chercher quel préfixe coller. Ne pas forcer une dimension par audit.

## Outils de détection opportunistes

Source unique de la cartographie outil↔dimension, référencée par `references/mode-audit.md > E.1bis` et `references/mode-crosscut.md > C`. Pour les dimensions mécanisables, un outil déterministe bat l'agent en **rappel** et en **localisation** ; l'agent garde le **jugement**. Posture invariante :

- **Opportuniste, jamais obligatoire.** Tester la présence (`command -v <outil>`, ou la présence d'un manifeste de langage) ; si absent, repli sur la lecture/jugement — aucune dépendance dure n'est introduite.
- **Exécuter, ne pas lire.** C'est la **sortie** de l'outil (idéalement JSON) qui entre en contexte, pas le code source — gain de tokens et de précision.
- **L'outil propose, l'agent dispose.** Un hit outil = un **candidat à examiner**, pas un finding. L'agent applique ensuite la grille de sévérité, le trade-off check (`references/quality.md`) et peut écarter le bruit. Un seuil d'outil franchi (p.ex. complexité cyclomatique = 11) n'est *pas* un finding en soi.

| Dimension | Outils (sortie JSON si dispo) | Notes |
|---|---|---|
| `DUP` | `jscpd` (≈223 langages, reporters json/sarif), PMD `CPD` | Donne blocs dupliqués + localisation exacte ; idéal en crosscut repo-wide. |
| `DED` | `knip` (JS/TS), `vulture` (Python, scores de confiance), `deadcode -json` (Go), `cargo-machete`/`cargo-udeps` (Rust), `staticcheck` U1000 (Go) | Exports/déps inutilisés. Garder la prudence anti-faux-positif du crosscut `DED` (API publiques, hooks de framework, barrels). |
| `SIZ` / `CPX` | `scc` (LoC + complexité, `--by-file -f json`), `tokei -o json` (LoC), `lizard` (CCN multi-langage), `radon cc -j` (Python) | Sert aussi à l'inventaire de zones (`references/mode-audit.md > B.0`). |
| `CFG` | `ripgrep` ciblé (`rg` sur lectures d'env vars / flags), `dotenv-linter` (drift `.env`) | Repérer les flags accumulés / jamais lus. |
| `BND` | graphes d'imports : `madge --circular` (JS/TS), `go list -deps`, `import-linter` (Python), `pydeps` | Cycles, fan-in-out, contournements de frontière. |
| `DRF` | comparaison de schémas/types au jugement (pas d'outil générique fiable) | Reste majoritairement à la lecture. |

Pour `INC`, `IDM`, `TST`, `DOC` : pas d'outil fiable de substitution — détection au jugement (et pour `IDM`, garde-fou anti-linter strict ci-dessous).

## Cadrage de la dimension IDM

`IDM` cible la non-conformité aux patterns idiomatiques du langage. Le risque de cette dimension est qu'elle dérive en linter de style — le cadrage suivant est strict.

**Détection des langages** : avant l'audit, identifier les langages via extensions et fichiers de config (`Cargo.toml`, `pyproject.toml`, `package.json`, `go.mod`, `Gemfile`, `pom.xml`, `composer.json`, …). Sur projet multi-langage, évaluer IDM zone par zone selon le langage dominant.

**Périmètre inclus** : patterns structurels avec impact maintenabilité direct — lisibilité par un dev habitué au langage, error-prone-ness évitable, friction avec l'écosystème. Familles à couvrir : gestion d'erreur idiomatique (Rust `Result`/`?`, Go error wrapping, Python `try/except` ciblé), gestion des ressources (context managers Python, `defer` Go, RAII Rust, try-with-resources Java), types et conteneurs adaptés (dataclasses Python, types stricts TS, `Optional` Java), patterns de construction du langage (builder Rust, comprehensions Python). L'agent s'appuie sur sa connaissance des idiomes du langage rencontré, pas sur une liste fermée du skill.

**Périmètre exclu** : tout ce qui est automatisable par un linter ou un formatter — naming style (snake_case vs camelCase), ordre des imports, indentation, choix de quotes, longueur de ligne, espace avant parenthèse. Hors scope du skill.

**Abstention sur méconnaissance** : si l'agent n'a pas une connaissance suffisante des idiomes d'un langage présent dans la zone, il s'abstient sur cette dimension plutôt que d'inventer des règles. Note honnête en chat type *"Je passe IDM sur ce fichier Elixir : idiomes du langage hors zone de confort."*
