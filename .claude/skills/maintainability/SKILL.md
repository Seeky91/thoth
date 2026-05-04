---
name: maintainability
description: Run a scoped maintainability audit on a project, manage findings with stable IDs, rotate audited zones across audits to maximize coverage. Use this skill whenever the user invokes `/maintainability`, asks for a maintainability audit, asks to identify duplication / DRY violations / dead code / god files / inconsistent patterns / test redundancy / config sprawl / unnecessary comments, asks to list or update or double-check existing maintainability findings, or asks for a structured review of code health in a specific module. The skill manages per-project state files (.claude/maintainability_history.md and .claude/maintainability_findings.md) autonomously.
---

# Maintainability skill

## Quand l'invoquer
Slash command `/maintainability` (avec ou sans args). Ne pas invoquer ce skill pour : audits de sécurité, de performance, d'accessibilité, ou choix de stack — ce sont d'autres revues.

## Dispatch des modes

Parse `$ARGUMENTS` selon ces règles, en ordre :

| Args | Mode | Action |
|---|---|---|
| `list` | **list** | Affiche le tableau de bord. Aucune écriture de fichier. |
| `update` | **update** | Re-vérifie tous les pendings, met à jour les statuts. |
| `double-check <ID>` | **double-check** | Deep-dive sur le finding `<ID>` (ex. `DUP-007`). |
| `<path>` (chemin existant dans le repo) | **audit forcé** | Audite la zone fournie. Saute la sélection auto. |
| (vide) | **audit auto** | Inventaire des zones, sélection autonome avec validation user, puis audit. |

Si l'argument ne correspond à aucune des règles ci-dessus (e.g. typo, ID invalide, path inexistant) : le skill **demande une clarification à l'utilisateur** plutôt que de deviner.

Toutes les opérations supposent que le répertoire courant est la racine d'un projet à auditer. Le skill **vérifie ce point avant tout** (voir section *Détection du root projet*). Si `.claude/` n'existe pas dans le projet, le skill bootstrappe (voir section Bootstrap).

## Détection du root projet

Avant tout dispatch de mode, le skill confirme que `cwd` est la racine d'un projet :

1. Cherche un des marqueurs suivants dans le `cwd` : `.git/`, `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `composer.json`, `Gemfile`, `pom.xml`, `build.gradle`, `.hg/`, `.svn/`.
2. **Si trouvé** → continue.
3. **Si absent**, remonter dans les parents jusqu'à trouver un marqueur (ou la racine du filesystem).
4. **Si trouvé dans un parent** : annoncer *"Le root projet semble être `<chemin-parent>`, mais le `cwd` est `<cwd>`. Relance depuis `<chemin-parent>` ou confirme l'opération ici (le `.claude/` sera créé dans le `cwd`)."* et attendre.
5. **Si aucun marqueur trouvé nulle part** : abort avec *"Aucun marqueur de projet détecté (.git, package.json, pyproject.toml, …). Lance la commande depuis la racine d'un projet."*

Ce check ne s'applique pas si l'utilisateur passe un `<path>` absolu en argument — dans ce cas, le path lui-même est le scope, et le `.claude/` est créé là où se trouve le marqueur de root le plus proche du path.

## Mode : audit

Déclenché par `/maintainability` (auto) ou `/maintainability <path>` (forcé).

### A. Bootstrap (si `.claude/maintainability_*.md` absent)

1. Si `.claude/` n'existe pas dans le projet : créer le dossier.
2. Si `maintainability_history.md` absent : créer avec `# Maintainability audit history\n\n` (rien d'autre).
3. Si `maintainability_findings.md` absent : créer avec `# Maintainability findings\n\n## Pending\n\n## Resolved\n`.
4. Annoncer en chat : *"Bootstrap maintainability sur ce projet, aucun historique préalable."*
5. Continuer le flux d'audit normalement (pas de rolling à respecter).

### B. Inventaire des zones

Calculer à chaque audit (jamais persisté). Algorithme :

1. **Walk de l'arbo** depuis la racine du projet.
2. **Pour chaque dossier**, mesurer le total LoC source (exclure `.json`, `.toml`, `.lock`, `.md`, dossiers `node_modules`, `.git`, `dist`, `build`, `vendor`, `target`, `.venv`, et tout ce qui ressemble à du généré).
3. **Règles de découpage** :
   - Dossier 200–2000 LoC → zone candidate.
   - Dossier > 2000 LoC → descendre dans ses sous-dossiers, appliquer la règle récursivement.
   - Dossier < 200 LoC → grouper avec son parent (ne pas le proposer seul).
4. **Fichiers ≥ 600 LoC source** (peu importe leur dossier) → zone autonome additionnelle. Chasse les god files même quand ils sont noyés dans un dossier raisonnable.
5. **Mesure LoC source** : compter les lignes non vides hors lignes-commentaires pures. Approximation acceptable, pas besoin d'AST.
6. **Pipelines candidats** : si en parcourant l'arbo le skill identifie un flux de données traçable (un point d'entrée qui appelle 3-5 fichiers en chaîne), il peut le proposer comme zone `pipeline:<nom>` avec la liste explicite des fichiers. Si le skill n'arrive pas à nommer le pipeline et ses fichiers concrètement, il **n'inclut pas** de pipeline dans les candidats — on n'invente pas de pipeline pour cocher la case.

`Z` = nombre total de zones candidates issu de cet inventaire.

### C. Sélection (mode auto, args vides)

1. **Lire le rolling** dans `maintainability_history.md` (parser les lignes `- YYYY-MM-DD — <zone> — …` et extraire la zone).
2. Calculer `N = clamp(round(Z / 4), 3, 8)` (override possible via `<!-- rolling_size: M -->` en tête de history, voir *Format des fichiers projet*).
3. **Candidats** = `inventaire - rolling` (les `N` derniers).
4. **Pondération** :
   - Zones jamais auditées (n'apparaissant dans aucune ligne du history actuel) → priorité haute.
   - Sinon, sélection aléatoire pondérée parmi les candidats restants.
5. **Visée pipeline ~30%** : si des candidats `pipeline:` existent et qu'on n'a pas audité de pipeline récemment (rolling), augmenter leur pondération pour atteindre approximativement 30% des audits sur la durée.
6. **Annonce en chat** :
   ```
   Je propose : services/billing/refund/ (jamais auditée, ~800 LoC)
   Alternatives : core/api_handler.py (god file, 1842 LoC) ou pipeline:order-processing [api/ingest.py, validators/order.py, enrichers/customer.py, store/orders.py]
   ```
7. **Validation utilisateur** : accepter, demander une alternative listée, ou imposer un autre chemin. Attendre avant de lancer l'audit.

#### Cas dégénérés de la sélection

- **Candidats vides** (typiquement petit projet avec un override `rolling_size` qui exclut tout) : relâcher le rolling, choisir la zone la moins récemment auditée parmi **toutes** les zones de l'inventaire. Annoncer *"Toutes les zones sont dans le rolling — j'ai pris la moins récente : `<zone>` (auditée 2026-04-22)."* Si égalité, aléatoire.
- **Inventaire vide** (`Z = 0`) : abort avec *"Aucune zone auditable détectée (chaque dossier fait < 200 LoC source ou est exclu). Le projet est-il vide, ou veux-tu auditer manuellement un chemin précis via `/maintainability <path>` ?"*
- **Une seule zone candidate après exclusion** : pas d'alternatives à proposer, annoncer la zone unique et demander si on lance.

### D. Audit forcé (mode `<path>`)

1. Vérifier que le chemin existe dans le projet courant.
2. Mesurer la taille de la zone (LoC source agrégée).
3. **Si > 5000 LoC** : refuser un audit aveugle. Annoncer la taille, proposer un sous-scope (ex. *"trop large à 6200 LoC. Sous-scopes possibles : `<path>/sub1/`, `<path>/sub2/`"*) et demander confirmation. L'utilisateur peut forcer s'il insiste, en sachant que l'audit sera moins profond.
4. Sinon : audit direct, pas de sélection auto.

### E. Exécution de l'audit

Pour la zone validée :

1. **Lire le code de la zone** intégralement (tous les fichiers source dans le scope).
2. **Examiner systématiquement toutes les dimensions** du catalogue. Pour chacune :
   - Chercher des occurrences concrètes du pattern dans la zone.
   - Pour chaque occurrence : observer (fait vérifiable, fichier:ligne, contexte), évaluer la sévérité (impact × exposition selon la grille), **estimer le Δ LoC** que produirait l'application de la reco (négatif si la reco supprime du code, positif si elle en ajoute, format `~±N`). Voir section *Estimation Δ LoC*.
   - **Ne pas forcer la production de findings.** Une dimension peut très bien produire 0 finding si le code est propre sur cet axe.
3. **Si un problème réel ne colle à aucune dimension** : créer un nouveau préfixe 3 lettres. Documenter brièvement dans le finding pourquoi cette nouvelle catégorie.
4. **Assignation des IDs** : pour chaque finding nouveau, scanner le findings file, max existant pour le préfixe → incrément. Format à 3 chiffres (`DUP-007`).

### F. Écritures

1. **Append des findings** dans `## Pending` de `maintainability_findings.md`. Format strict (voir section *Format des fichiers projet*).
2. **Préfixer une nouvelle ligne en tête** de `maintainability_history.md` :
   ```
   - YYYY-MM-DD — <zone> — N findings (X HIGH, Y MED, Z LOW) (pending)
   ```
3. **Trim** : recalculer la taille rolling et supprimer les lignes en surplus du bas.

#### Cas zone propre (0 findings)

Si l'audit produit zéro finding (zone réellement clean sur toutes les dimensions) :

- **Écrire quand même la ligne history**, format adapté :
  ```
  - YYYY-MM-DD — <zone> — 0 findings (clean)
  ```
- Ne **rien appender** dans `maintainability_findings.md` (pas de pending à créer).
- Sortie en chat : *"Audit terminé — `<zone>`. Aucun finding produit, zone propre sur toutes les dimensions examinées."*

L'écriture de la ligne history est **importante** : sans elle, la zone serait re-proposée trop tôt par le rolling. Une zone propre reste légitimement dans le rolling pour éviter le ressassement.

### G. Sortie en chat

Format type :

```
Audit terminé — services/billing/refund/

6 nouveaux findings (3 HIGH, 2 MED, 1 LOW) :
  DUP-007 (HIGH, Δ ~-40) — duplication logique refund 3×
  SIZ-009 (HIGH, Δ ~+60) — refund_handler.py 1200 LoC, 5 responsabilités
  CPX-012 (HIGH, Δ ~-15) — boucle imbriquée 4 niveaux dans apply_refund
  TST-005 (MED, Δ ~-20) — assertions sur impl plutôt que contrat (4 tests)
  INC-008 (MED, Δ ~±5) — 2 conventions d'erreur dans le même module
  DOC-011 (LOW, Δ ~-3) — docstring obsolète sur process_refund

Δ LoC total estimé si tout est appliqué : ~-23.

Détails dans `.claude/maintainability_findings.md`.
Pour creuser un item à la main : /maintainability double-check DUP-007.

Tu peux aussi me laisser creuser en autonomie. Sur quoi ?
  (a) un panel de quick-wins : DOC-011, INC-008, TST-005 — 3 findings au fix court et peu de blast radius.
  (b) le finding le plus structurant : SIZ-009 — god file 1200 LoC, 5 responsabilités.
  (c) rien, je verrai plus tard.
```

Le résumé n'inclut pas les Reco — elles sont dans le fichier. Le but est l'orientation, pas la duplication.

### H. Proposition de double-check autonome (post-audit)

Après le résumé en chat, si l'audit a produit ≥ 1 finding, proposer trois options à l'utilisateur (cf. exemple ci-dessus) puis attendre sa réponse.

**Critères de sélection des panels :**

- **(a) Quick-wins** : panel de 3 à 5 findings « bas effort, fix direct ».
  - Sévérité LOW en priorité, complétée par des MED si nécessaire pour atteindre 3.
  - `|Δ LoC|` faible (≤ 30) ou reco mono-fichier sans blast radius identifiable.
  - **Pas de finding HIGH dans ce panel** — un HIGH n'est jamais un quick-win.
- **(b) Heavy finding** : un seul finding, le plus structurant.
  - Sévérité HIGH en priorité (sinon le MED de plus large scope).
  - Plus large scope d'abord : god file > duplication structurante 3+ > drift transverse > complexité locale.
  - Tie-break : `|Δ LoC|` estimé le plus élevé.
- **(c) Rien** : l'utilisateur verra plus tard.

**Cas dégénérés :**

- 0 finding : ne pas afficher cette proposition (déjà couvert par le cas zone propre).
- 1 ou 2 findings : remplacer la proposition à 3 options par une question simple : *"Veux-tu que je fasse un double-check autonome sur `<ID>` ?"*
- Aucun candidat ne tient les critères de quick-win (e.g. tous les findings sont HIGH avec gros blast radius) : ne proposer que (b) et (c).
- Aucun finding HIGH ni MED de gros scope : pour (b), proposer le finding au plus grand `|Δ LoC|` estimé, en avertissant que ce n'est pas un finding « lourd » au sens classique.

**Exécution selon le choix utilisateur :**

- **(a) Quick-wins** : pour chaque finding du panel, exécuter le flux *Mode : double-check* (lecture du fichier, trace, blast radius, Δ LoC affiné, reco affinée, verdict). Écrire la section `Double-check (date)` dans chaque entrée du fichier findings. **Résumer en chat un seul message agrégé** avec un verdict par ID, pas un message par finding. Exemple :
  ```
  Double-check autonome terminé sur 3 quick-wins :
    DOC-011 — GO (Δ -3, fix trivial : suppression docstring + commit unique)
    INC-008 — GO-après-DUP-007 (Δ ±5, à fusionner avec le refactor de refund pour éviter de toucher 2× le même fichier)
    TST-005 — NO-GO (Δ -20 mais les 4 tests d'impl couvrent un edge case que le contrat ne capture pas — à archiver)

  Détails complets dans .claude/maintainability_findings.md.
  ```

- **(b) Heavy finding** : exécuter le flux *Mode : double-check* sur le finding sélectionné. Sortie complète comme un double-check standard (pas d'agrégation).

- **(c) Rien** : terminer la commande. Aucune écriture supplémentaire.

**Cas NO-GO en autonomie** : si une exécution autonome conclut NO-GO sur un finding et que l'utilisateur le confirme dans la foulée, marquer dans Resolved avec `Resolution: archivé après double-check (NO-GO motivé : <raison>)` plutôt que de le laisser en pending indéfiniment.

## Mode : list

Déclenché par `/maintainability list`. **Pas d'audit, pas de re-vérification, aucune écriture de fichier.** Lecture seule des deux fichiers projet.

### Flux

1. Lire `maintainability_findings.md` et `maintainability_history.md`.
2. Compter les pending par sévérité. Lister les IDs avec un one-liner descriptif (extrait de l'observation, ~50 chars).
3. Lister les résolus des 30 derniers jours (filtrer par la date dans le titre Resolved).
4. Lister les entrées du rolling (taille `N` actuelle).

### Sortie type

```
Maintainability board — services/example-project/

Pending (8) :
  HIGH (3) : DUP-007 (duplication refund), SIZ-003 (god file api_handler), INC-002 (3 patterns paginate)
  MED  (4) : CPX-005, TST-001, DRF-002, CFG-003
  LOW  (1) : DOC-006

Recently resolved (30 derniers j.) :
  DUP-005 (MED) — 2026-04-16 — extraction _validate_token
  CPX-002 (HIGH) — 2026-04-10 — flatten boucle imbriquée

Rolling (N=4) :
  2026-05-03 — services/billing/refund/ — 6 findings (résolus DUP-007+SIZ-003)
  2026-05-01 — pipeline:order-processing — 4 findings (pending)
  2026-04-22 — core/api_handler.py — 8 findings (pending)
  2026-04-15 — services/auth/ — 3 findings (résolus tous)
```

Si zéro pending : afficher `Pending (0) : aucun finding actif.`
Si zéro audit : afficher `Aucun audit dans l'historique. Lance /maintainability pour commencer.`

### Cas du projet sans state

Si `.claude/maintainability_*.md` n'existent pas, **ne pas bootstrapper** (mode list est lecture seule). Annoncer : *"Aucun audit de maintenabilité sur ce projet. Lance `/maintainability` pour bootstrapper."*

## Mode : update

Déclenché par `/maintainability update`. **Pas d'audit nouveau.** Re-vérifie tous les pendings contre l'état actuel du code et met à jour les statuts.

### Flux

1. Lire `maintainability_findings.md`. Itérer sur chaque entrée de la section `## Pending`.
2. Pour chaque finding :
   a. Lire le fichier référencé en localisation.
   b. **Si le fichier est introuvable** (déplacé, supprimé, renommé) : marquer `Status: stale`, ne pas conclure résolu/pending. **Ne pas tenter de re-locater automatiquement** (risque de faux positif sur un fichier au nom voisin). Noter la situation.
   c. **Si le fichier existe** : vérifier que le pattern décrit dans l'observation est toujours présent à la localisation indiquée (ou nearby si les lignes ont bougé). Heuristique :
      - Lire les ~20 lignes autour de la localisation.
      - Si le pattern décrit (duplication, god file taille, etc.) est encore reconnaissable → status inchangé.
      - Si le pattern a disparu → bascule en Resolved.
3. Pour chaque résolu détecté :
   - Déplacer l'entrée de `## Pending` vers `## Resolved`.
   - Ajouter `(résolu YYYY-MM-DD)` au titre.
   - Ajouter bullet `Resolution: détecté résolu lors de update (YYYY-MM-DD). Δ LoC mesuré : <valeur>` (mesurer via `git log --since=<date détectée> -- <fichier>` ou comparaison directe avec l'estimation initiale ; si non mesurable, noter `Δ LoC mesuré : indéterminé`).
   - Mettre à jour la ligne history correspondante (l'audit qui a créé ce finding) : ajouter ou compléter le `(résolus <ID>+...)`.
4. Pour chaque stale : laisser dans Pending mais ajouter `Status: stale (YYYY-MM-DD) — fichier introuvable, à rouvrir manuellement avec nouveau path ou archiver`. Demander à l'utilisateur en chat : *"M-XX référence un fichier introuvable. Rouvrir avec nouveau path ou archiver ?"*

### Sortie en chat

```
Update terminé — services/example-project/

Re-vérifié 8 pendings :
  Résolus (2) : DUP-005, CPX-008
  Toujours présents (5) : DUP-007, SIZ-003, INC-002, TST-001, DRF-002
  Stale (1) : CFG-003 (config/flags.toml introuvable, déplacé ?)

Files mis à jour : .claude/maintainability_findings.md, .claude/maintainability_history.md
```

### Coût

Cette commande lit potentiellement beaucoup de fichiers (un par pending). Acceptable car invocation rare et explicite — pas appelée à chaque audit.

### Détection intra-session

Indépendamment de la commande `update` explicite, **pendant la conversation qui suit un audit ou un double-check**, si l'utilisateur applique un fix qui résout un finding listé :

1. Le skill propose : *"Ce fix résout DUP-007. Je marque comme résolu ?"*
2. Si oui : applique le même flux que update sur cet ID unique (déplacer en Resolved, ajouter Resolution, mettre à jour history).

Cette détection est **opportuniste, pas exhaustive**. Pour une re-vérification systématique après plusieurs fixes hors-session, l'utilisateur lance `/maintainability update`.

## Mode : double-check

Déclenché par `/maintainability double-check <ID>` (ex. `/maintainability double-check DUP-007`). Approfondit un finding existant, ne crée pas de nouveau finding.

### Flux

1. **Localiser le finding** : scanner `maintainability_findings.md`, trouver l'entrée `### <ID> — …`. Si absent → demander à l'utilisateur un ID valide (ne pas inventer).
2. **Lire le fichier référencé** intégralement, plus les fichiers voisins / importeurs.
3. **Trace** :
   - **Localisation complète** : tous les call sites, imports, références au symbole/pattern concerné.
   - **Blast radius** : tests qui touchent la zone, surfaces publiques affectées, couplages cachés (ce qui casse si on applique le fix proposé).
   - **Faisabilité de la reco initiale** : tient-elle ? Y a-t-il une contrainte (typage, signature publique, dépendance circulaire, contrat externe) qui invaliderait la reco ?
   - **Effort estimé** : `S` (≤2h), `M` (≤1j), `L` (>1j, plusieurs commits). Distinct de la faisabilité.
   - **Δ LoC affiné** : ré-estimer à la lumière du blast radius et des contraintes. Si l'écart avec l'estimation initiale est > 50 %, expliquer brièvement pourquoi.
   - **Reco affinée** : ajustée à la lumière des contraintes découvertes, ou alternatives si l'originale ne tient plus.
   - **Verdict** : GO / NO-GO / GO-mais-après-X.
4. **Possibilité de reclasser la sévérité** : si l'analyse montre que HIGH était excessif (effort L mais impact en réalité MED), proposer le changement à l'utilisateur. **Ne pas changer l'ID.**

### Écriture dans le fichier findings

Ajouter une section au sein de l'entrée existante du finding (avant la ligne `Status:` ou après `Détecté:`) :

```markdown
- **Double-check (YYYY-MM-DD) :** Blast radius : 47 imports dans le projet, 12 tests touchés. Effort M (~1 jour, 4 commits incrémentaux). Faisabilité OK avec contraintes mineures (transactions à préserver). Δ LoC affiné : ~+85 (au lieu de ~+120 estimé : on regroupe routing + middleware au lieu de splitter en 5 fichiers). Reco affinée : splitter d'abord routing puis validation, persistance en dernier. Verdict : GO, prioriser après TST-009.
```

Si la sévérité change, **également** modifier le titre de l'entrée :
```
### SIZ-003 — MED — core/api_handler.py
```

### Sortie en chat

Réponse complète en chat (l'utilisateur veut le détail pour décider) avec une copie de ce qui a été écrit dans le fichier + tout contexte additionnel utile (extraits de code des call sites, etc.).

## Catalogue des dimensions (seed)

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

### Cadrage de la dimension IDM

`IDM` cible la non-conformité aux patterns idiomatiques du langage. Le risque de cette dimension est qu'elle dérive en linter de style — le cadrage suivant est strict.

**Détection des langages** : avant l'audit, identifier les langages présents dans la zone via les extensions de fichiers et les fichiers de configuration (`Cargo.toml`, `pyproject.toml`, `package.json`, `go.mod`, `Gemfile`, `pom.xml`, `composer.json`, …). Sur projet multi-langage, évaluer IDM zone par zone selon le langage dominant de la zone.

**Périmètre inclus** : patterns structurels avec impact maintenabilité direct (lisibilité par un dev habitué au langage, error-prone-ness évitable, friction avec l'écosystème). Liste indicative, à étendre selon les langages rencontrés :
- **Rust** : `Result`/`Option` plutôt qu'`unwrap`/`panic` en code production, opérateur `?`, builder pattern (`with_xxx`), traits cohérents (`Display`, `Debug`, `Default`), RAII pour la gestion des ressources.
- **Python** : context managers (`with`) plutôt que try/finally manuels, dataclasses au lieu de dicts ad-hoc pour structures typées, `pathlib` pour les chemins, comprehensions quand approprié.
- **Go** : `defer` pour le cleanup, error wrapping avec `fmt.Errorf("...: %w", err)`, interfaces définies côté consommateur.
- **JS/TS** : async/await plutôt que chaînes de Promise, types stricts en TS (pas `any` systématique), destructuration quand elle clarifie.
- **Java** : try-with-resources, `Optional` plutôt que null, streams quand approprié.

**Périmètre exclu** : tout ce qui est automatisable par un linter ou un formatter — naming style (snake_case vs camelCase), ordre des imports, indentation, choix de quotes, longueur de ligne, espace avant parenthèse. Hors scope du skill.

**Abstention sur méconnaissance** : si l'agent n'a pas une connaissance suffisante des idiomes d'un langage présent dans la zone, il s'abstient sur cette dimension plutôt que d'inventer des règles. Note honnête en chat type *"Je passe IDM sur ce fichier Elixir : idiomes du langage hors zone de confort."*

## Grille de sévérité

Sévérité = **impact × exposition**. Ce n'est pas un goût, c'est une calibration sur l'effet sur la maintenabilité du code.

- **HIGH** — bloque ou alourdit toute évolution future de la zone.
  Exemples : god file dans un hot path, duplication structurante (3+ copies de logique), drift de contrat utilisé partout, tests fondants empêchant tout refactor.
- **MED** — friction notable mais contournable.
  Exemples : incohérence locale de pattern, redondance modérée de tests, sprawl de config sur 2-3 modules, duplication 2x sur fonction utilitaire.
- **LOW** — cosmétique, nettoyage sans impact comportemental.
  Exemples : commentaire stale, var inutilisée, doublon trivial dans helper jamais touché, doc d'une fonction self-explanatory.

**La sévérité est mutable.** Un `double-check` peut révéler que ce qu'on pensait HIGH est en fait MED (ou inversement). Dans ce cas : amender l'attribut sévérité dans l'entrée, **ne pas changer l'ID**.

## Quand ne PAS produire de finding

Le skill est intrinsèquement orienté détection, ce qui crée un biais structurel à sur-produire des findings pour "justifier" l'invocation. Sans contre-poids, l'audit dérive vers du **paperclip maximizing** : on optimise la maintenabilité jusqu'à dégrader d'autres aspects du projet. Cette section est le contrepoids.

### Conscience du biais à sur-produire

Une zone qui produit 0 finding sur toutes les dimensions est un audit **réussi**, pas un audit raté (cf. *Cas zone propre* déjà documenté). Corollaires opérationnels :

- Ne pas remplir du vide pour rentabiliser l'invocation.
- Si une dimension n'a rien produit après examen sérieux, passer à la suivante sans forcer.
- Si la zone entière est propre, l'écrire (ligne history `0 findings (clean)`) et s'arrêter là — pas de finding "consolation" pour avoir l'air d'avoir travaillé.
- Une dimension qui ne produit jamais rien sur une zone donnée n'est pas un échec d'audit ; le code peut être propre sur cet axe.

### Trade-off check sur les autres axes du projet

Si la reco améliorerait la maintenabilité au prix d'une dégradation visible sur un autre axe : **ne pas produire le finding** par défaut, ou le produire en annotant explicitement le trade-off dans la bullet `Reco`. Axes à vérifier avant production :

- **Performance** : abstraction qui ajoute du coût per-call dans un hot path, allocation supplémentaire, indirection runtime introduite par un helper, copies de données en plus.
- **Sécurité** : suppression d'un check, élargissement d'une surface d'attaque, partage d'état précédemment isolé, secret précédemment scopé qui devient transitif.
- **Scalabilité** : suppression d'un seam d'extension, fusion de variantes "presque identiques" qui pourraient diverger demain, aplatissement qui bloque l'ajout futur d'une nouvelle responsabilité, suppression d'une couche d'indirection qui était un point de branchement. Trop simplifier aujourd'hui se paye cher quand on voudra accueillir une feature.
- **Lisibilité paradoxale** : sur-abstraction qui crée des indirections plus difficiles à suivre que la duplication originale (DRY pathologique : 3 copies divergentes fusionnées en un helper paramétré incompréhensible avec un boolean qui change le comportement à mi-chemin).

**Règle par défaut** : si le trade-off est significatif, ne pas produire le finding. Si le finding est produit malgré un trade-off identifié, l'annoter dans la bullet `Reco` (ex. *"Reco : extraire `_apply_refund_policy`. Trade-off : si une 4e variante de refund émerge, le helper devra être paramétré — accepter ce coût plus tard plutôt que maintenant."*) pour que l'utilisateur puisse trancher en connaissance de cause.

Ce check intervient **en amont** de la production du finding. Il ne remplace pas le double-check (qui creuse la faisabilité d'un finding existant) — il intervient une étape avant, à la décision même de produire.

## Estimation Δ LoC

Chaque finding doit indiquer un `Δ LoC` estimé : la variation de lignes de code source que produirait l'application de la reco. Format `~±N` (le `~` marque l'estimation, le signe indique l'effet net).

**Convention de signe :**
- **Négatif** (`~-40`) : la reco réduit le code (extraction de duplication, suppression de dead code, fusion de variantes).
- **Positif** (`~+30`) : la reco ajoute du code (split d'un god file en modules avec boilerplate, ajout d'une couche d'abstraction).
- **Quasi-nul** (`~±5`) : la reco déplace ou réécrit sans réduire (renommage transverse, restructuration locale, harmonisation de pattern).

**Méthode d'estimation à l'audit :**
- Mesurer la taille des occurrences impliquées (lignes du pattern × nombre de copies).
- Soustraire la taille du helper / module extrait, en incluant un peu de boilerplate (signature, imports, docstring si nécessaire).
- Pour les splits de god files : estimer à partir de la taille des responsabilités identifiées + ~10-20 % de boilerplate (imports, signatures, ré-exports).
- Si l'estimation est trop incertaine pour être utile (e.g. la reco dépend de choix d'architecture non tranchés) : noter `Δ LoC : indéterminé — à affiner en double-check`.

**À l'application du fix (résolution) :** mesurer le delta réel via `git diff --stat` ou comptage direct, et le consigner dans `Resolution :`. Format `Δ LoC mesuré : -47`. C'est cette valeur qui compte dans les bilans, pas l'estimation initiale.

**À un double-check :** raffiner l'estimation à la lumière du blast radius et des contraintes découvertes. Format `Δ LoC affiné : ~-35`. Si le raffinement contredit l'estimation initiale (> 50 % d'écart), expliquer brièvement pourquoi (ex. *"on regroupe routing + middleware au lieu de splitter en 5 fichiers"*).

**Chat summary post-audit :** afficher un Δ LoC compact par finding (e.g. `(HIGH, Δ ~-40)`) et un Δ LoC total estimé sur l'ensemble si tout était appliqué. C'est une indication d'orientation, pas un objectif (un Δ très positif sur un split de god file peut être pleinement justifié).

## Format des fichiers projet

Deux fichiers vivent dans `<projet>/.claude/`. Le skill les crée/lit/écrit. Format strict, à respecter à la lettre.

### `.claude/maintainability_history.md`

Une ligne par audit. Taille adaptative `N = clamp(round(Z / 4), 3, 8)` où `Z` est le nombre de zones inventoriées au moment de l'écriture. Au write-time, recalcule N et trim le surplus du plus ancien.

```markdown
<!-- rolling_size: 5 -->        # commentaire optionnel : override manuel
# Maintainability audit history

- 2026-05-03 — services/billing/refund/ — 6 findings (3 HIGH, 2 MED, 1 LOW) (résolus DUP-007+SIZ-003)
- 2026-05-01 — pipeline:order-processing [api/ingest.py, validators/order.py, enrichers/customer.py, store/orders.py] — 4 findings (1 HIGH, 3 MED) (pending)
- 2026-04-22 — core/api_handler.py — 8 findings (4 HIGH, 3 MED, 1 LOW) (pending)
- 2026-04-15 — services/auth/ — 3 findings (1 MED, 2 LOW) (résolus tous)
```

Règles :
- Format ligne : `- YYYY-MM-DD — <zone> — N findings (X HIGH, Y MED, Z LOW) (status)`
- `<zone>` = chemin dossier (`services/billing/refund/`), chemin fichier (`core/api_handler.py`), ou `pipeline:<nom> [fichiers,…]` (le bracket fichiers n'apparaît QUE pour les pipelines).
- `(status)` : `(pending)`, `(résolus tous)`, ou `(résolus <ID>+<ID>+...)` quand certains seulement sont résolus.
- Si `<!-- rolling_size: N -->` est présent en tête de fichier, **respecter cette valeur** au lieu du calcul auto, même si elle tombe hors `[3, 8]`. L'utilisateur sait ce qu'il veut ; le skill ne discute pas la valeur.

### `.claude/maintainability_findings.md`

Source de vérité. Findings groupés en deux sections.

```markdown
# Maintainability findings

## Pending

### DUP-007 — HIGH — services/billing/refund_handler.py:42-67
- **Dimension :** duplication de code
- **Observation :** Logique de refund dupliquée 3× avec variations mineures (l. 42, 89, 134).
- **Reco :** Extraire dans `_apply_refund_policy(order, policy)`.
- **Δ LoC :** ~-40 (3 copies de ~25 LoC fusionnées dans un helper de ~30 LoC).
- **Détecté :** 2026-05-03 (audit zone services/billing/refund/)
- **Status :** pending

### SIZ-003 — HIGH — core/api_handler.py
- **Dimension :** god file (1842 LoC, 23 fonctions, 4 responsabilités)
- **Observation :** Fichier mêle routing, validation, persistance, formatting.
- **Reco :** Splitter en `routing.py`, `validation.py`, `formatting.py` ; persistence va dans `db/api_log.py`.
- **Δ LoC :** ~+120 (split en 4 modules avec imports/signatures partagées, ~30 LoC de boilerplate par module).
- **Détecté :** 2026-04-22
- **Status :** pending
- **Double-check (2026-04-25) :** Blast radius : 47 imports, 12 tests touchés. Effort M (~1 jour, 4 commits incrémentaux). Faisabilité OK avec contraintes mineures (transactions à préserver). Δ LoC affiné : ~+85. Verdict : GO, prioriser après TST-009.

## Resolved

### DUP-005 — MED — services/auth/login.py:23 (résolu 2026-04-16)
- **Dimension :** duplication de code
- **Observation :** Validation token dupliquée avec `services/auth/refresh.py:18`.
- **Reco :** Helper `_validate_token()`.
- **Δ LoC :** ~-25 (estimation initiale).
- **Resolution :** Extrait vers `services/auth/_helpers.py`. Δ LoC mesuré : -32.
```

Règles :
- En-tête entrée : `### <ID> — <SÉVÉRITÉ> — <localisation>` (avec `(résolu YYYY-MM-DD)` ajouté pour les Resolved).
- `<localisation>` = `path:line` ou `path:start-end` ou juste `path` (pour les god files).
- Bullets dans cet ordre : Dimension, Observation, Reco, Δ LoC, Détecté, Status, puis sections optionnelles (Double-check, Resolution).
- L'ID est immuable. Tout autre attribut peut être amendé.

### Compteur d'IDs (implicite)

Pour assigner un nouvel ID `<PREFIX>-NNN` : scanner le fichier findings, repérer le max `N` existant pour ce préfixe, incrémenter. Format à 3 chiffres (`DUP-007`), peut grandir au-delà sans souci (`DUP-1042` reste lisible).

**Jamais de réutilisation d'ID**, même après suppression manuelle d'une entrée par l'utilisateur. Si max trouvé = `DUP-005` mais l'utilisateur a supprimé `DUP-005`, le prochain est `DUP-006` (pas `DUP-005`).

## Cycle de vie d'un finding

1. **Création** lors d'un audit → entrée `## Pending` avec ID, dimension, sévérité, observation, reco, date, `Status: pending`.
2. **Double-check** (`/maintainability double-check <ID>`) → ajoute une section `Double-check (date)` dans l'entrée existante. Peut amender la reco. Peut révéler un changement de sévérité (proposer à l'utilisateur, valider, puis amender l'attribut).
3. **Résolution intra-session** → quand l'utilisateur applique un fix dans la conversation qui suit un audit ou un double-check, le skill **propose** de marquer résolu :
   - Déplace l'entrée en `## Resolved`
   - Ajoute `(résolu YYYY-MM-DD)` dans le titre
   - Ajoute bullet `Resolution: <description courte du fix>. Δ LoC mesuré : <valeur>` (mesurer via `git diff --stat` sur la zone du fix, ou comptage direct sur les fichiers touchés). Si le fix est dans le même tour de conversation : faire la mesure tout de suite.
   - Met à jour la ligne history correspondante : `(résolus DUP-007)` → `(résolus DUP-007+SIZ-003)` si plus d'un fix
4. **Update** (`/maintainability update`) → re-vérifie chaque pending :
   - Pattern toujours présent → status inchangé.
   - Pattern absent → `Resolution: détecté résolu lors de update (YYYY-MM-DD)`. Bascule en Resolved.
   - Fichier disparu / déplacé → `Status: stale`. Demande à l'utilisateur de confirmer (rouvrir avec nouveau path, ou archiver).

## Bootstrap & edge cases

### Bootstrap (premier audit)
Voir Mode : audit > A. Bootstrap. En résumé : créer `.claude/` et les deux fichiers vides avec headers, annoncer le bootstrap, continuer le flux.

### Override rolling_size
Voir *Format des fichiers projet > maintainability_history.md* pour la règle canonique.

### Reclassification
Si un finding s'avère mal catégorisé (e.g. `DUP-007` est en réalité un problème de complexité, pas de duplication) :
- **Garder l'ID.** `DUP-007` reste `DUP-007`.
- Ajouter une bullet `Note: Reclassifié sémantiquement vers CPX, ID conservé pour traçabilité`.
- Optionnel : ajuster la dimension dans la bullet `Dimension`.

### Scope refusé (>5000 LoC)
Sur `/maintainability <path>`, si la zone agrège plus de 5000 LoC source :
- Ne pas lancer l'audit.
- Annoncer : *"Zone trop large (XYZ LoC). Pour une analyse profonde, je propose de découper. Sous-scopes possibles : <path>/A, <path>/B, …"*
- Demander confirmation. Si l'utilisateur insiste, lancer en avertissant que l'audit sera moins profond.

### Fichier déplacé / refactoré entre audits
Voir *Mode : update > Flux* (étape 2.b et étape 4) pour le flux canonique de gestion des stale. S'applique aussi en `double-check` quand l'ID référencé pointe vers un fichier disparu.

### Doublons potentiels
Si un audit produit un finding qui ressemble fortement à un finding pending existant (même fichier, même pattern) :
- Ne pas créer de doublon. Référencer l'ID existant dans le résumé chat : *"DUP-007 toujours présent — pas re-comptabilisé."*
- Rafraîchir éventuellement la date de détection sur l'entrée existante.

### Conflit de prefix
Si l'utilisateur a manuellement utilisé un préfixe inhabituel (e.g. `XXX-001`) dans le findings file, le skill le respecte et continue à incrémenter dans cette série si pertinent. Aucun "rebasage" automatique.
