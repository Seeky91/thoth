---
name: maintainability
description: Use when the user invokes `/maintainability`, asks for a maintainability audit on a codebase, wants to identify duplication / DRY violations / dead code / god files / inconsistent patterns / test redundancy / config sprawl / unnecessary comments in a project, asks to list or update or double-check existing maintainability findings, or wants a structured code-health review of a specific module or pipeline.
---

# Maintainability skill

## Quand l'invoquer

Famille de slash commands :

- `/maintainability` — audit (auto si pas d'arg, forcé si `<path>` fourni)
- `/maintainability-list` — tableau de bord, lecture seule
- `/maintainability-update` — re-vérification de tous les pendings
- `/maintainability-double-check <ID>` — deep-dive sur un finding existant
- `/maintainability-archive-clear [--all|--keep N|--older-than <dur>]` — purge de l'archive

Chaque command file invoque ce skill avec un mode pré-déterminé. Ne pas invoquer ce skill pour : audits de sécurité, de performance, d'accessibilité, ou choix de stack — ce sont d'autres revues.

## Références

Ce SKILL.md est le hub de contrôle. Les détails normatifs vivent dans :

- `references/file-formats.md` — format des trois fichiers d'état (`maintainability_history.md`, `maintainability_findings.md`, `maintainability_resolved_archive.md`), compteur d'IDs, cycle de vie d'un finding, cap Resolved.
- `references/cascade.md` — algorithme détaillé de la re-vérification en cascade post-fix.
- `references/templates.md` — templates normatifs des sorties chat (un par usage, e.g. `audit:summary`, `list:dashboard`, `resolution:confirm`). **Lire avant chaque sortie chat** d'un mode pour garder la forme stable d'une invocation à l'autre.

Le skill lit ces fichiers **à la demande** quand il doit écrire ou appliquer une mécanique transverse. Pour le flux décisionnel des modes, ce SKILL.md suffit.

## Dispatch des modes

Le mode est fixé par la slash command utilisée (cf. ci-dessus). La table ci-dessous est la référence canonique de l'argument que chaque mode attend dans `$ARGUMENTS` :

| Command | Mode | `$ARGUMENTS` attendu |
|---|---|---|
| `/maintainability-list` | **list** | (aucun) — affiche le tableau de bord, aucune écriture. |
| `/maintainability-update` | **update** | (aucun) — re-vérifie tous les pendings, met à jour les statuts. |
| `/maintainability-double-check` | **double-check** | `<ID>` (ex. `DUP-007`) — deep-dive sur le finding. |
| `/maintainability-archive-clear` | **archive-clear** | `[--all\|--keep N\|--older-than <dur>]` — défaut : > 6 mois. Confirme avant d'écrire. |
| `/maintainability <path>` | **audit forcé** | chemin existant dans le repo — audite la zone fournie. |
| `/maintainability` (vide) | **audit auto** | (aucun) — inventaire des zones, sélection autonome avec validation user, puis audit. |

Si `$ARGUMENTS` ne respecte pas le format attendu pour la command invoquée (e.g. ID invalide pour double-check, path inexistant pour audit forcé) : le skill **demande une clarification à l'utilisateur** plutôt que de deviner.

Toutes les opérations supposent que le répertoire courant est la racine d'un projet à auditer. Le skill **vérifie ce point avant tout** (cf. section *Détection du root projet*). Si `.claude/` n'existe pas dans le projet, le skill bootstrappe (cf. *Mode audit > A. Bootstrap*).

## Détection du root projet

Avant tout dispatch de mode, le skill confirme que `cwd` est la racine d'un projet :

1. Cherche un des marqueurs suivants dans le `cwd` : `.git/`, `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `composer.json`, `Gemfile`, `pom.xml`, `build.gradle`, `.hg/`, `.svn/`.
2. **Si trouvé** → continue.
3. **Si absent**, remonter dans les parents jusqu'à trouver un marqueur (ou la racine du filesystem).
4. **Si trouvé dans un parent** : annoncer *"Le root projet semble être `<chemin-parent>`, mais le `cwd` est `<cwd>`. Relance depuis `<chemin-parent>` ou confirme l'opération ici (le `.claude/` sera créé dans le `cwd`)."* et attendre.
5. **Si aucun marqueur trouvé nulle part** : abort avec *"Aucun marqueur de projet détecté (.git, package.json, pyproject.toml, …). Lance la commande depuis la racine d'un projet."*

Ce check ne s'applique pas si l'utilisateur passe un `<path>` en argument (absolu, ou relatif résolu vs `cwd`) — dans ce cas, le path lui-même est le scope, et le `.claude/` est créé là où se trouve le marqueur de root le plus proche du path.

## Mode : audit

Déclenché par `/maintainability` (auto) ou `/maintainability <path>` (forcé).

### A. Bootstrap (si `.claude/maintainability_*.md` absent)

1. Si `.claude/` n'existe pas dans le projet : créer le dossier.
2. Si `maintainability_history.md` absent : créer avec `# Maintainability audit history\n\n`.
3. Si `maintainability_findings.md` absent : créer avec `# Maintainability findings\n\n## Pending\n\n## Resolved\n`. Pas de header `<!-- id_counters: ... -->` à ce stade (création paresseuse à la première assignation d'ID). Pas non plus de `maintainability_resolved_archive.md` (création paresseuse au premier débordement du cap Resolved).
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

L'historique sert **deux usages distincts** qui ont des horizons de mémoire différents — la sélection les exploite séparément :

1. **Lire `maintainability_history.md` en entier.** Parser toutes les lignes `- YYYY-MM-DD — <zone> — …` et extraire les zones.
2. Calculer `N = clamp(round(Z / 4), 3, 10)` (override possible via `<!-- rolling_size: M -->` en tête de history).
3. Construire deux vues sur les zones parsées :
   - **`rolling_actif`** = les `N` zones les plus récentes (les `N` premières lignes du fichier, qui est en ordre prepend = newest-first).
   - **`zones_jamais_auditees`** = `inventaire − {toutes les zones apparaissant dans le fichier, sans limite de date}`.
4. **Candidats** = `inventaire − rolling_actif`.
5. **Pondération** :
   - Zones du candidate set qui sont dans `zones_jamais_auditees` → **priorité haute** (pas encore couvertes dans la vie du projet).
   - Sinon, sélection aléatoire pondérée parmi les candidats restants (déjà couvertes mais sorties du rolling actif — re-audit légitime).
6. **Visée pipeline ~30%** : si des candidats `pipeline:` existent et qu'on n'a pas audité de pipeline récemment (rolling), augmenter leur pondération pour atteindre approximativement 30 % des audits sur la durée.
7. **Annonce en chat** : utiliser le template `selection:proposition` (cf. `references/templates.md`).
8. **Validation utilisateur** : accepter, demander une alternative listée, ou imposer un autre chemin. Attendre avant de lancer l'audit.

**Pourquoi cette séparation** : trimmer history (ancien comportement) faisait perdre la couverture historique. Sur gros projet (40+ zones), après 11+ audits, des zones réellement auditées sortaient du fichier et redevenaient « jamais auditées » du point de vue de la pondération — le skill re-proposait alors des zones déjà couvertes. History est désormais append-only ; le rolling est une vue sur les `N` premières lignes, la couverture est sur le fichier entier.

#### Cas dégénérés de la sélection

- **Candidats vides** (typiquement petit projet avec un override `rolling_size` qui exclut tout) : relâcher le rolling, choisir la zone la moins récemment auditée parmi **toutes** les zones de l'inventaire. Annoncer *"Toutes les zones sont dans le rolling — j'ai pris la moins récente : `<zone>` (auditée 2026-04-22)."* Si égalité, aléatoire.
- **Inventaire vide** (`Z = 0`) : abort avec *"Aucune zone auditable détectée (chaque dossier fait < 200 LoC source ou est exclu). Le projet est-il vide, ou veux-tu auditer manuellement un chemin précis via `/maintainability <path>` ?"*
- **Une seule zone candidate après exclusion** : pas d'alternatives à proposer, annoncer la zone unique et demander si on lance.

### D. Audit forcé (mode `<path>`)

0. Si bootstrap nécessaire (`.claude/maintainability_*.md` absent) : suivre la section *A. Bootstrap* avant les étapes ci-dessous.
1. Vérifier que le chemin existe dans le projet courant.
2. Mesurer la taille de la zone (LoC source agrégée).
3. **Si > 5000 LoC** : refuser un audit aveugle. Annoncer la taille, proposer un sous-scope (ex. *"trop large à 6200 LoC. Sous-scopes possibles : `<path>/sub1/`, `<path>/sub2/`"*) et demander confirmation. L'utilisateur peut forcer s'il insiste, en sachant que l'audit sera moins profond.
4. Sinon : audit direct, pas de sélection auto.

### E. Exécution de l'audit

Pour la zone validée :

1. **Lire le code de la zone** intégralement (tous les fichiers source dans le scope).
2. **Examiner systématiquement toutes les dimensions** du catalogue. Pour chacune :
   - Chercher des occurrences concrètes du pattern dans la zone.
   - Pour chaque occurrence : observer (fait vérifiable, fichier:ligne, contexte), évaluer la sévérité (impact × exposition selon la grille), **estimer le Δ LoC** que produirait l'application de la reco (négatif si la reco supprime du code, positif si elle en ajoute, format `~±N`). Cf. *Estimation Δ LoC*.
   - **Ne pas forcer la production de findings.** Une dimension peut très bien produire 0 finding si le code est propre sur cet axe.
3. **Si un problème réel ne colle à aucune dimension** : créer un nouveau préfixe 3 lettres. Documenter brièvement dans le finding pourquoi cette nouvelle catégorie.
4. **Assignation des IDs** : suivre le mécanisme de `references/file-formats.md > Compteur d'IDs` (lire le header `<!-- id_counters: ... -->`, incrémenter, mettre à jour la ligne header). Format à 3 chiffres (`DUP-007`).

### F. Écritures (append-only)

1. **Append des findings** dans `## Pending` de `maintainability_findings.md`. Format strict cf. `references/file-formats.md`.
2. **Préfixer une nouvelle ligne en tête** de `maintainability_history.md` :
   ```
   - YYYY-MM-DD — <zone> — N findings (X HIGH, Y MED, Z LOW) (pending)
   ```
3. **Pas de trim.** History est append-only — le fichier accumule sur la durée de vie du projet. La taille du rolling actif `N` est appliquée à la lecture (vue sur les `N` premières lignes), jamais à l'écriture.

#### Cas zone propre (0 findings)

Si l'audit produit zéro finding (zone réellement clean sur toutes les dimensions) :

- **Écrire quand même la ligne history**, format adapté :
  ```
  - YYYY-MM-DD — <zone> — 0 findings (clean)
  ```
- Ne **rien appender** dans `maintainability_findings.md` (pas de pending à créer).
- Sortie en chat : utiliser le template `audit:clean`.

L'écriture de la ligne history est **importante** : sans elle, la zone serait re-proposée trop tôt et la couverture historique perdrait l'info que la zone a été examinée.

### G. Sortie en chat (post-audit)

- Audit avec findings → template `audit:summary`.
- Audit sans finding (zone propre) → template `audit:clean`.
- Suite : la proposition de double-check autonome (cf. H ci-dessous).

### H. Proposition de double-check autonome (post-audit)

Après le résumé en chat, si l'audit a produit ≥ 1 finding, proposer trois options à l'utilisateur via le template `audit:proposition` (3 options : quick-wins / heavy / rien), puis attendre sa réponse.

**Critères de sélection des panels** :

- **(a) Quick-wins** : panel de 3 à 5 findings « bas effort, fix direct ».
  - Sévérité LOW en priorité, complétée par des MED si nécessaire pour atteindre 3.
  - `|Δ LoC|` faible (≤ 30) ou reco mono-fichier sans blast radius identifiable.
  - **Pas de finding HIGH dans ce panel** — un HIGH n'est jamais un quick-win.
- **(b) Heavy finding** : un seul finding, le plus structurant.
  - Sévérité HIGH en priorité (sinon le MED de plus large scope).
  - Plus large scope d'abord : god file > duplication structurante 3+ > drift transverse > complexité locale.
  - Tie-break : `|Δ LoC|` estimé le plus élevé.
- **(c) Rien** : l'utilisateur verra plus tard.

**Cas dégénérés** :

- 0 finding : ne pas afficher cette proposition (déjà couvert par le cas zone propre).
- 1 ou 2 findings : remplacer par le template `audit:proposition-min` (question simple sur 1 ID).
- Aucun candidat ne tient les critères de quick-win (e.g. tous les findings sont HIGH avec gros blast radius) : ne proposer que (b) et (c).
- Aucun finding HIGH ni MED de gros scope : pour (b), proposer le finding au plus grand `|Δ LoC|` estimé, en avertissant que ce n'est pas un finding « lourd » au sens classique.

**Exécution selon le choix utilisateur** :

- **(a) Quick-wins** : pour chaque finding du panel, exécuter le flux *Mode : double-check* (lecture du fichier, trace, blast radius, Δ LoC affiné, reco affinée, verdict). Écrire la section `Double-check (date)` dans chaque entrée du fichier findings. **Sortie agrégée** via `double-check:autonomous-batch`, suivie de `double-check:autonomous-batch-proposition` (cf. *I. Action post-proposition batch* ci-dessous).
- **(b) Heavy finding** : exécuter le flux *Mode : double-check* sur le finding sélectionné. Sortie complète via `double-check:output` standard, suivie de `double-check:proposition` (cf. *Mode : double-check > Action selon le choix utilisateur*).
- **(c) Rien** : terminer la commande. Aucune écriture supplémentaire.

### I. Action post-proposition batch

Déclenché par la proposition `double-check:autonomous-batch-proposition` (suite à `(a) Quick-wins` ci-dessus ou à `double-check B<n>` depuis *Mode : list*). Selon le choix utilisateur :

- **Fix tous les GO** :
  1. Établir l'ordering (règles dans `references/templates.md > double-check:autonomous-batch-proposition`).
  2. Plan par finding (1-3 lignes : fichiers touchés, ordre, Δ LoC attendu) — réutilise `Reco affinée`.
  3. Plan global affiché, OK explicite. Si OK, exécuter dans l'ordre.
  4. Avant chaque marquage `Resolution`, lancer la suite de tests. Tests OK → flux résolution intra-session. Tests KO → arrêt, ne pas marquer.
  5. Cascade re-check automatique après chaque résolution (cf. `references/cascade.md`).
  6. Si variante mix GO+NO-GO : archiver les NO-GO restants dans la foulée (move Pending → Resolved compact, `Resolution: archivé après double-check (NO-GO motivé : <raison>)`, lignes history complétées, cap Resolved respecté).
  7. Récap final via `cascade:recap-batch`.
- **Fix un seul** : étapes 2-5 ci-dessus sur le finding choisi.
- **Archiver les NO-GO** (variante mix, archive partielle) ou **Archiver tous** (variante tous NO-GO) : pour chaque NO-GO, move Pending → Resolved au format compact, `Resolution: archivé après double-check (NO-GO motivé : <raison>)`, ligne history complétée. Cap Resolved respecté.
- **Rien** / **Garder pending** : terminer sans écriture supplémentaire.

## Mode : list

Déclenché par `/maintainability-list`. **Pas d'audit, pas de re-vérification, aucune écriture de fichier.** Lecture seule des deux fichiers projet.

### Flux

1. Lire `maintainability_findings.md` et `maintainability_history.md`.
2. Compter les pending par sévérité. Lister les IDs avec un one-liner descriptif (extrait de l'observation, ~50 chars).
3. **Compter et lister à part les findings stale** (pending dont la bullet `Status` est `stale ...` ou `stale-after-<ID> ...`) — distincts des actifs car ils nécessitent une action utilisateur (relocaliser, marquer résolu, ou archiver) avant de pouvoir être traités. Ils restent inclus dans le total Pending.
4. Lister les résolus des 30 derniers jours (filtrer par la date dans le titre Resolved).
5. Lister les entrées du rolling actif (les `N` premières lignes de history).
6. Détecter les batches groupables parmi les pending **actifs uniquement** (les stale sont exclus du batching, cf. *Batches suggérés*).

### Sortie

Utiliser le template `list:dashboard`. Cas dégénérés :

- Zéro pending actif (peut-être stale) : afficher `Pending actifs (0) : aucun finding actionnable.` La section Stale reste affichée si non vide.
- Zéro stale : omettre entièrement la section Stale (ne pas afficher `Stale (0)`).
- Zéro audit : afficher `Aucun audit dans l'historique. Lance /maintainability pour commencer.`

### Batches suggérés

**Détection** (lecture seule, pas d'analyse de code) :

1. Pour chaque pending, extraire ID, dimension prefix, path, audit_origin (date `Détecté:`), et contenu de la dernière section `Double-check` si présente.
2. **Signaux explicites** (haute priorité) dans le Double-check, regex insensibles à la casse : `bundle`/`bundler`, `sequencing`/`étape \d+`, `après <ID>`/`avant <ID>`, `couplé avec <ID>`. Chaque mention d'un autre `<ID>` connu crée une arête ; composantes connexes = batches.
3. **Signaux heuristiques** (fallback) : même path exact ; sinon même path parent + même dimension prefix ; sinon même audit_origin.
4. Garder seulement les batches de 2 à 5 findings. Lister explicites en premier, compléter avec heuristiques. Max 3 affichés.
5. Si aucun batch valide : afficher *"Pas de batch évident détecté — les pendings sont indépendants."* et **omettre** le prompt de sélection.

**Format d'affichage** : intégré dans le template `list:dashboard` (section *Batches suggérés*).

**Recommandation** : marquer un batch `★ recommandé` selon ces critères, dans l'ordre :

1. **Scope minimal** : préférer 1 fichier > module > multi-modules (blast radius bas).
2. **Signal explicite** : préférer un batch issu d'un signal explicite sur un batch heuristique.
3. **`|Δ LoC|` le plus faible** (changement le plus contenu).
4. **Tie-break** : ID le plus petit (`B1` > `B2` > …).

La raison courte affichée à côté du `★` reprend le critère qui a tranché (ex. `1 fichier, blast radius bas`, `co-design explicite`, `Δ LoC contenu`).

Si aucun batch ne se distingue (≥ 2 batches strictement équivalents sur les 4 critères) : ne pas marquer `★`. Le prompt d'action devient *"Plusieurs batches équivalents — choisis selon ta priorité (`double-check B<n>`, `fix B<n>`, `rien`)."*

**Action selon la réponse utilisateur** :

- **`double-check B<n>`** : exécuter le flux *Mode : double-check* sur chaque finding du batch dans l'ordre. Sortie agrégée via `double-check:autonomous-batch`, suivie de `double-check:autonomous-batch-proposition`. Action selon choix utilisateur : cf. *Mode : audit > I. Action post-proposition batch*.
- **`fix B<n>`** (l'exécution applique systématiquement les checkpoints décrits ci-dessous — l'utilisateur n'a pas à le préciser) :
  1. Plan par finding (1-3 lignes : fichiers touchés, ordre, Δ LoC attendu) — réutilise `Reco affinée` si présente, sinon `Reco`.
  2. Afficher le plan global, demander un OK explicite. Si OK, exécuter dans l'ordre.
  3. **Avant** chaque marquage `Resolution`, lancer la suite de tests (détectée via marqueurs : `cargo test`, `npm test`, `pytest`, `go test ./...`, etc. ; sinon demander la commande). Tests OK → flux résolution intra-session. Tests KO → arrêt, ne pas marquer, annoncer ; pas de revert auto.
  4. **Cascade re-check** automatique après chaque résolution du batch (cf. `references/cascade.md`) — sans nouveau prompt puisque l'OK plan global de l'étape 2 couvre.
  5. Récap final via le template `cascade:recap-batch`.
- **`rien`** : terminer sans rien faire.

**Cas dégénérés** : batch ID invalide ("B5" alors que seuls B1/B2 listés) → demander relance de `list`. Finding déjà résolu entre `list` et action → skip avec annonce.

### Cas du projet sans state

Si `.claude/maintainability_*.md` n'existent pas, **ne pas bootstrapper** (mode list est lecture seule). Annoncer : *"Aucun audit de maintenabilité sur ce projet. Lance `/maintainability` pour bootstrapper."*

## Mode : update

Déclenché par `/maintainability-update`. **Pas d'audit nouveau.** Re-vérifie tous les pendings contre l'état actuel du code et met à jour les statuts.

### Flux

1. Lire `maintainability_findings.md`. Itérer sur chaque entrée de la section `## Pending`.
2. Pour chaque finding :
   a. Lire le fichier référencé en localisation.
   b. **Si le fichier est introuvable** (déplacé, supprimé, renommé) :
      - Si `Status: stale-after-<ID>` est déjà présent (posé par la cascade) : laisser tel quel, ne pas le remplacer par un `stale` générique — l'info de cause est plus précieuse.
      - Sinon : marquer `Status: stale`, ne pas conclure résolu/pending. **Ne pas tenter de re-locater automatiquement** (risque de faux positif sur un fichier au nom voisin).
   c. **Si le fichier existe** : vérifier que le pattern décrit dans l'observation est toujours présent à la localisation indiquée (ou nearby si les lignes ont bougé). Heuristique :
      - Lire les ~20 lignes autour de la localisation.
      - Si le pattern décrit (duplication, god file taille, etc.) est encore reconnaissable → status inchangé.
      - Si le pattern a disparu → bascule en Resolved.
3. Pour chaque résolu détecté :
   - Déplacer l'entrée de `## Pending` vers `## Resolved` au **format compact** (cf. `references/file-formats.md > Format compact d'une entrée résolue`).
   - Ajouter `(résolu YYYY-MM-DD)` au titre.
   - La bullet `Resolution` indique `détecté résolu lors de update (YYYY-MM-DD). Δ LoC mesuré : <valeur>` (via `git log --since=<date> -- <fichier>` ou comparaison directe ; sinon `indéterminé`). Ajouter `Commit : <hash>` si un commit aval est identifiable.
   - Mettre à jour la ligne history correspondante (l'audit qui a créé ce finding) : ajouter ou compléter le `(résolus <ID>+...)`.
4. Pour chaque stale (générique ou `stale-after-<ID>` posé par la cascade) : laisser dans Pending. Le `Status` a déjà été ajusté à l'étape 2.b. Demander à l'utilisateur en chat — message adapté à la cause :
   - Stale générique : *"`<ID>` référence un fichier introuvable. Rouvrir avec nouveau path, marquer résolu (le pattern n'existe plus), ou archiver ?"*
   - Stale-after : *"`<ID>` est `stale-after-<ID-primaire>` depuis le fix du <YYYY-MM-DD>. Localisation invalidée par le fix. Rouvrir avec nouveau path, marquer résolu, ou archiver ?"*
5. **Vérification de l'invariant cap Resolved** : compter les entrées de `## Resolved` après les moves. Si > 8, appliquer le flux d'archivage automatique (cf. `references/file-formats.md > Cycle de vie d'un finding` étape 5).
6. **Recompute des compteurs d'IDs** : re-scanner `maintainability_findings.md` + `maintainability_resolved_archive.md` (s'il existe), recalculer le max par préfixe, mettre à jour le header `<!-- id_counters: ... -->`. Self-heal contre drift.

### Sortie

Utiliser le template `update:summary`.

### Coût

Cette commande lit potentiellement beaucoup de fichiers (un par pending). Acceptable car invocation rare et explicite — pas appelée à chaque audit.

### Détection intra-session

Indépendamment de la commande `update` explicite, **pendant la conversation qui suit un audit ou un double-check**, si l'utilisateur applique un fix qui résout un finding listé :

1. Le skill **exécute la re-vérification en cascade en lecture seule** (cf. `references/cascade.md`), puis propose la confirmation batchée via le template `resolution:confirm` — primaire + cascadés + stale-after en un seul prompt. Si overlap = 0 (aucun autre pending sur les fichiers du diff) : le template gère la variante simple sans bloc cascade.
2. Si l'utilisateur valide : applique le flux update sur le primaire (move Pending → Resolved, bullet `Resolution`, ligne history) **et** exécute les écritures cascade (cascade-resolved au format compact, stale-after taggés, lignes history complétées, cap Resolved respecté).
3. **Confirmer en chat** via le template `resolution:done` — détaillant les écritures effectuées. Si push-back partiel à l'étape 1 (l'utilisateur a refusé certains items) : la sortie reflète seulement ce qui a été appliqué.

Cette détection est **opportuniste, pas exhaustive**. Pour une re-vérification systématique après plusieurs fixes hors-session, l'utilisateur lance `/maintainability-update`.

## Mode : double-check

Déclenché par `/maintainability-double-check <ID>` (ex. `/maintainability-double-check DUP-007`). Approfondit un finding existant, ne crée pas de nouveau finding.

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
   - **Apport** (uniquement si Verdict GO ou GO-mais-après-X — jamais sur NO-GO) : une seule phrase concrète qui nomme ce qui s'améliore. Une formulation générique type *"améliore la maintenabilité"* reste valable si elle est étoffée par le **comment** (ce qui rend le code plus maintenable, concrètement, dans ce cas précis).
4. **Possibilité de reclasser la sévérité** : si l'analyse montre que HIGH était excessif (effort L mais impact en réalité MED), proposer le changement à l'utilisateur. **Ne pas changer l'ID.**

### Écriture dans le fichier findings

Ajouter une section `Double-check (YYYY-MM-DD) :` dans l'entrée existante du finding, juste après la bullet `Détecté:` ou avant la bullet `Status:`. Format : une bullet unique contenant tous les éléments de la trace (cf. exemple dans `references/file-formats.md > Pending`).

Si la sévérité change : modifier également le titre de l'entrée (`### SIZ-003 — MED — core/api_handler.py`).

### Sortie

1. Récap du verdict via le template `double-check:output`.
2. Proposition d'action via le template `double-check:proposition` (variante filtrée selon verdict GO/GO-mais-après-X vs NO-GO).

### Action selon le choix utilisateur

- **Fix maintenant** (verdict GO / GO-mais-après-X) :
  1. Plan (1-3 lignes : fichiers touchés, ordre, Δ LoC attendu) — réutilise `Reco affinée`.
  2. Plan affiché, OK explicite. Si OK, exécuter.
  3. Avant le marquage `Resolution`, lancer la suite de tests (détectée via marqueurs : `cargo test`, `npm test`, `pytest`, `go test ./...` ; sinon demander la commande). Tests OK → flux résolution intra-session (cf. *Mode : update > Détection intra-session*). Tests KO → arrêt, ne pas marquer.
  4. Cascade re-check automatique (cf. `references/cascade.md`).
  5. Récap final via `resolution:done`.
- **Archiver** (verdict NO-GO) : move Pending → Resolved au format compact, `Resolution: archivé après double-check (NO-GO motivé : <raison>)`. Compléter la ligne history correspondante. Cap Resolved respecté (cf. `references/file-formats.md > Cycle de vie d'un finding` étape 5).
- **Plus tard** / **Garder pending** : terminer sans écriture supplémentaire. Le Double-check (date) est déjà persisté.

## Mode : archive-clear

Déclenché par `/maintainability-archive-clear [--all|--keep N|--older-than <duration>]`. Purge `maintainability_resolved_archive.md` selon les critères. Toujours confirmer avant d'écrire.

### Flux

1. Si l'archive n'existe pas : abort avec *"Pas d'archive sur ce projet, rien à clearer."*
2. Parser les entrées de l'archive : extraire `ID` et la date `(résolu YYYY-MM-DD)` du titre.
3. Calculer `dropped` / `kept` selon les args :
   - **Défaut** (aucun flag) : drop entrées résolues il y a > 6 mois.
   - `--older-than <duration>` : format `<entier><unité>` avec unités `d`/`m`/`y` (`m`=30j, `y`=365j). Ex. `6m`, `1y`, `90d`. Parse échoué → *"Durée `<input>` non reconnue. Format attendu : `6m`, `1y`, `90d`."*
   - `--keep N` : conserver les N entrées les plus récentes (date du titre).
   - `--all` : drop tout.
4. **Recompute des compteurs d'IDs** : scanner findings + archive complète **avant** la suppression, mettre à jour le header `<!-- id_counters: ... -->`. Garantit que les IDs futurs continuent de monter monotonement.
5. **Confirmation utilisateur** : utiliser le template `archive-clear:confirm-all` (cas `--all`) ou `archive-clear:confirm-partial` (autres cas).
6. Réécrire l'archive avec les seules entrées `kept`. Si `kept = []` (cas `--all`) : supprimer le fichier (recreation paresseuse au prochain débordement).
7. Annoncer en chat via le template `archive-clear:done`.

### Garde-fous

- Aucune modification sur `maintainability_findings.md` (sauf le header de compteurs) ni sur `maintainability_history.md`. Les références dangling depuis history vers une entrée archivée disparue restent — convention "voir git".
- Confirmation obligatoire dans tous les cas, même par défaut.
- Si le filtre ne capture aucune entrée : *"Filtre `<critère>` ne capture aucune entrée. Archive inchangée."* — pas d'écriture, pas même du header.

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

**Détection des langages** : avant l'audit, identifier les langages via extensions et fichiers de config (`Cargo.toml`, `pyproject.toml`, `package.json`, `go.mod`, `Gemfile`, `pom.xml`, `composer.json`, …). Sur projet multi-langage, évaluer IDM zone par zone selon le langage dominant.

**Périmètre inclus** : patterns structurels avec impact maintenabilité direct — lisibilité par un dev habitué au langage, error-prone-ness évitable, friction avec l'écosystème. Familles à couvrir : gestion d'erreur idiomatique (Rust `Result`/`?`, Go error wrapping, Python `try/except` ciblé), gestion des ressources (context managers Python, `defer` Go, RAII Rust, try-with-resources Java), types et conteneurs adaptés (dataclasses Python, types stricts TS, `Optional` Java), patterns de construction du langage (builder Rust, comprehensions Python). L'agent s'appuie sur sa connaissance des idiomes du langage rencontré, pas sur une liste fermée du skill.

**Périmètre exclu** : tout ce qui est automatisable par un linter ou un formatter — naming style (snake_case vs camelCase), ordre des imports, indentation, choix de quotes, longueur de ligne, espace avant parenthèse. Hors scope du skill.

**Abstention sur méconnaissance** : si l'agent n'a pas une connaissance suffisante des idiomes d'un langage présent dans la zone, il s'abstient sur cette dimension plutôt que d'inventer des règles. Note honnête en chat type *"Je passe IDM sur ce fichier Elixir : idiomes du langage hors zone de confort."*

## Grille de sévérité

Sévérité = **impact × exposition**. Ce n'est pas un goût, c'est une calibration sur l'effet sur la maintenabilité du code.

- **HIGH** — bloque ou alourdit toute évolution future de la zone.
  Exemples : god file dans un hot path, duplication structurante (3+ copies de logique), drift de contrat utilisé partout, tests fondants empêchant tout refactor.
- **MED** — friction notable mais contournable.
  Exemples : incohérence locale de pattern, redondance modérée de tests, sprawl de config sur 2-3 modules, duplication 2× sur fonction utilitaire.
- **LOW** — cosmétique, nettoyage sans impact comportemental.
  Exemples : commentaire stale, var inutilisée, doublon trivial dans helper jamais touché, doc d'une fonction self-explanatory.

**La sévérité est mutable.** Un `double-check` peut révéler que ce qu'on pensait HIGH est en fait MED (ou inversement). Dans ce cas : amender l'attribut sévérité dans l'entrée, **ne pas changer l'ID.**

## Quand ne PAS produire de finding

Le skill est intrinsèquement orienté détection, ce qui crée un biais structurel à sur-produire des findings pour "justifier" l'invocation. Sans contre-poids, l'audit dérive vers du **paperclip maximizing** : on optimise la maintenabilité jusqu'à dégrader d'autres aspects du projet. Cette section est le contrepoids.

### Conscience du biais à sur-produire

Une zone qui produit 0 finding sur toutes les dimensions est un audit **réussi**, pas un audit raté. Corollaires opérationnels :

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

**Règle par défaut** : si le trade-off est significatif, ne pas produire le finding. Si le finding est produit malgré un trade-off identifié, l'annoter dans la bullet `Reco` pour que l'utilisateur puisse trancher en connaissance de cause.

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

**À un double-check :** raffiner l'estimation à la lumière du blast radius et des contraintes découvertes. Format `Δ LoC affiné : ~-35`. Si le raffinement contredit l'estimation initiale (> 50 % d'écart), expliquer brièvement pourquoi.

## Sorties chat — conventions

Les sorties chat des modes suivent des templates normatifs définis dans `references/templates.md`. Lire ce fichier **avant chaque sortie chat** pour garder la forme stable d'une invocation à l'autre.

**Conventions transverses** (résumé) :
- **Header** des modes écrivant : `<Mode> terminé — <scope>`. Mode list utilise `Maintainability board — <projet>`.
- **Trailer** « Files mis à jour : … » : présent à chaque mode qui écrit (audit, update, double-check, archive-clear, résolution intra-session). Absent du mode list (read-only).
- Les blocs de proposition d'action utilisateur (post-audit, post-double-check single, post-double-check batch, post-list) sont distincts du récap — bloc séparé en fin de message.

**Liste des templates disponibles** (cf. `references/templates.md` pour le format de chacun) :

| Template | Quand l'utiliser |
|---|---|
| `selection:proposition` | Annonce de la zone candidate en mode audit auto. |
| `audit:summary` | Audit qui produit ≥ 1 finding. |
| `audit:clean` | Audit qui produit 0 finding (zone propre). |
| `audit:proposition` | Proposition de double-check autonome post-audit (3 options a/b/c). |
| `audit:proposition-min` | Variante post-audit pour 1 ou 2 findings. |
| `list:dashboard` | Tableau de bord en mode list. |
| `update:summary` | Récap en mode update. |
| `double-check:output` | Sortie standard d'un double-check. |
| `double-check:autonomous-batch` | Sortie agrégée d'un panel quick-wins ou batch fix. |
| `double-check:proposition` | Proposition d'action après un double-check simple (filtrée selon verdict). |
| `double-check:autonomous-batch-proposition` | Proposition d'action après un batch double-check (filtrée selon mix de verdicts). |
| `resolution:confirm` | Confirmation intra-session (variante simple ou avec cascade). |
| `resolution:done` | Confirmation finale après résolution intra-session. |
| `cascade:recap-batch` | Récap final d'un `fix B<n>` (mode list). |
| `archive-clear:confirm-all` | Confirmation purge totale (cas `--all`). |
| `archive-clear:confirm-partial` | Confirmation purge partielle (autres cas). |
| `archive-clear:done` | Récap après purge. |

## Invariants de fin de mode

Avant de rendre la main à l'utilisateur, l'agent **doit** valider que toutes les écritures attendues du mode courant ont eu lieu. Garde-fou cognitif contre le drift sur les flux multi-écritures (résolution intra-session, update batch, cascade) — une étape secondaire peut être silencieusement omise après l'étape principale.

Une case **non applicable** au cas courant (ex. cap Resolved pas dépassé donc pas d'archivage, pas de reclassification donc pas de titre amendé) est considérée cochée — la liste cible les omissions silencieuses, pas les opérations toujours requises.

### Audit (auto ou forcé)

- Findings appendés dans `## Pending` de `maintainability_findings.md` — un par finding produit (ou aucun si zone propre).
- Header `<!-- id_counters: ... -->` incrémenté pour chaque préfixe utilisé.
- Ligne préfixée en tête de `maintainability_history.md`. **Pas de trim** — history est append-only.
- Si bootstrap a eu lieu : fichiers `.claude/maintainability_*.md` créés avec le contenu initial.

### Double-check

- Section `Double-check (YYYY-MM-DD) :` ajoutée à l'entrée du finding ciblé.
- Si reclassification de sévérité validée : titre `### <ID> — <NEW-SEV> — …` modifié.
- Si l'utilisateur a choisi *Fix maintenant* à la proposition : invariants de *Résolution intra-session* applicables (cf. ci-dessous).
- Si l'utilisateur a choisi *Archiver* (NO-GO) : entrée déplacée Pending → Resolved au format compact, `Resolution: archivé après double-check (NO-GO motivé : <raison>)`, ligne history correspondante complétée, cap Resolved respecté.

### Update

- Chaque pending re-vérifié.
- Résolus détectés déplacés vers `## Resolved` au format compact.
- Stales détectés taggés `Status: stale` ; `stale-after-<ID>` existants préservés (pas écrasés).
- Lignes history correspondantes complétées (`(résolus <ID>+...)`).
- Cap Resolved appliqué (archivage automatique si > 8).
- Header `<!-- id_counters: ... -->` recomputed (self-heal en re-scannant findings + archive).

### Résolution intra-session

- Entrée déplacée Pending → Resolved au format compact.
- Bullet `Resolution :` complète (description + Δ LoC mesuré + Commit).
- `(résolu YYYY-MM-DD)` ajouté au titre.
- Ligne history correspondante mise à jour.
- Cascade re-check déclenchée si fix avec diff (cf. `references/cascade.md`).
- Cap Resolved respecté.

### Archive-clear

- Archive réécrite avec les seules entrées `kept` (ou supprimée si `kept = []`, cas `--all`).
- Header `<!-- id_counters: ... -->` recomputed **avant** la suppression.
- Pas d'écriture sur history ni sur findings (sauf le header de compteurs).

### List

Aucune écriture attendue — vérifier qu'aucun fichier projet n'a été modifié pendant le mode (read-only strict).

### Si une case n'a pas pu être cochée

Si une condition empêche une écriture attendue (tests KO, fichier en lecture seule, conflit de merge dans le findings file) : **annoncer en chat** ce qui n'a pas pu être fait et pourquoi, plutôt que rendre la main silencieusement. L'utilisateur doit savoir qu'un état partiel existe.

## Edge cases

### Reclassification

Si un finding s'avère mal catégorisé (e.g. `DUP-007` est en réalité un problème de complexité, pas de duplication) :

- **Garder l'ID.** `DUP-007` reste `DUP-007`.
- Ajouter une bullet `Note: Reclassifié sémantiquement vers CPX, ID conservé pour traçabilité`.
- Optionnel : ajuster la dimension dans la bullet `Dimension`.

### Fichier déplacé / refactoré entre audits

La logique stale du *Mode : update* (étape 2.b et étape 4) s'applique aussi en `double-check` quand l'ID référencé pointe vers un fichier disparu.

### Doublons potentiels

Si un audit produit un finding qui ressemble fortement à un finding pending existant (même fichier, même pattern) :

- Ne pas créer de doublon. Référencer l'ID existant dans le résumé chat : *"DUP-007 toujours présent — pas re-comptabilisé."*
- Rafraîchir éventuellement la date de détection sur l'entrée existante.

### Conflit de prefix

Si l'utilisateur a manuellement utilisé un préfixe inhabituel (e.g. `XXX-001`) dans le findings file, le skill le respecte et continue à incrémenter dans cette série si pertinent. Aucun "rebasage" automatique.
