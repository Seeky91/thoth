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

## Cadrage de la dimension IDM

`IDM` cible la non-conformité aux patterns idiomatiques du langage. Le risque de cette dimension est qu'elle dérive en linter de style — le cadrage suivant est strict.

**Détection des langages** : avant l'audit, identifier les langages via extensions et fichiers de config (`Cargo.toml`, `pyproject.toml`, `package.json`, `go.mod`, `Gemfile`, `pom.xml`, `composer.json`, …). Sur projet multi-langage, évaluer IDM zone par zone selon le langage dominant.

**Périmètre inclus** : patterns structurels avec impact maintenabilité direct — lisibilité par un dev habitué au langage, error-prone-ness évitable, friction avec l'écosystème. Familles à couvrir : gestion d'erreur idiomatique (Rust `Result`/`?`, Go error wrapping, Python `try/except` ciblé), gestion des ressources (context managers Python, `defer` Go, RAII Rust, try-with-resources Java), types et conteneurs adaptés (dataclasses Python, types stricts TS, `Optional` Java), patterns de construction du langage (builder Rust, comprehensions Python). L'agent s'appuie sur sa connaissance des idiomes du langage rencontré, pas sur une liste fermée du skill.

**Périmètre exclu** : tout ce qui est automatisable par un linter ou un formatter — naming style (snake_case vs camelCase), ordre des imports, indentation, choix de quotes, longueur de ligne, espace avant parenthèse. Hors scope du skill.

**Abstention sur méconnaissance** : si l'agent n'a pas une connaissance suffisante des idiomes d'un langage présent dans la zone, il s'abstient sur cette dimension plutôt que d'inventer des règles. Note honnête en chat type *"Je passe IDM sur ce fichier Elixir : idiomes du langage hors zone de confort."*
