---
name: maintainability
description: Use when the user invokes `/maintainability`, asks for a maintainability audit on a codebase, wants to identify duplication / DRY violations / dead code / god files / inconsistent patterns / test redundancy / config sprawl / unnecessary comments in a project, wants to detect cross-zone consistency issues (drift between modules, duplicated helpers across the project, globally dead exports, boundary violations), asks to list or update or double-check existing maintainability findings, or wants a structured code-health review of a specific module or pipeline, or asks in French for « un audit de maintenabilité », « une revue de santé du code », « du code mort », « des fichiers trop gros », « de la duplication » ou « de la dette technique ».
---

# Maintainability skill

## Quand l'invoquer

Famille de slash commands :

- `/maintainability` — audit (auto si pas d'arg, forcé si `<path>` fourni)
- `/maintainability-crosscut` — sweep cross-zone sur une dimension transverse (`DUP`/`INC`/`DRF`/`DED`/`BND`), dimension auto-proposée
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
- `references/dimensions.md` — catalogue des 11 dimensions seed (`DUP`, `CPX`, `SIZ`, `DED`, `INC`, `IDM`, `BND`, `DRF`, `TST`, `CFG`, `DOC`) et cadrage de la dimension `IDM`. **Lire avant la production d'un finding** quand le préfixe ou le cadrage de la dimension n'est pas immédiatement évident.
- `references/quality.md` — grille de sévérité (HIGH/MED/LOW), garde-fous anti-bruit (*"Quand ne PAS produire de finding"*), et convention `Δ LoC`. **Lire avant la production d'un finding** : ces calibrations conditionnent la décision même d'écrire ou pas.

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
| `/maintainability-crosscut` | **crosscut** | (aucun) — sélection autonome d'une dimension cross-zone (`DUP`/`INC`/`DRF`/`DED`/`BND`) avec validation user, puis sweep. |

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

## Conventions transverses (tout mode qui écrit l'état)

Deux règles s'appliquent à **chaque** écriture des fichiers d'état, quel que soit le mode. Elles ne sont pas répétées dans chaque flux — elles sont supposées partout.

1. **Date courante déterministe.** Toute date `YYYY-MM-DD` écrite dans l'état (ligne history, `Détecté:`, `(résolu …)`, section `Double-check (…)`, `Status: stale (…)`) ou comparée à une date stockée (seuil « > 6 mois » d'`archive-clear`) doit être obtenue via `date +%F`, **jamais supposée de mémoire**. Cohérent avec l'usage déjà fait de `git log`/`git diff` pour les autres datations. Si l'environnement ne permet pas d'exécuter `date` : le signaler en chat plutôt que d'inventer une date.

2. **Écritures en delta, jamais de régénération.** Les modes lisent l'état tôt et écrivent tard. Avant d'écrire `maintainability_findings.md` ou `maintainability_history.md`, **relire le fichier juste avant l'écriture**, puis **insérer / déplacer uniquement le(s) bloc(s) ciblé(s)** (le nouveau finding, la ligne history préfixée, le move Pending → Resolved). Ne **jamais** régénérer le fichier entier de mémoire : cela peut perdre des entrées existantes et écraser une édition manuelle faite entre-temps (le skill assume explicitement l'édition humaine de ces fichiers, cf. `references/file-formats.md`). L'écriture en delta réduit aussi la surface d'erreur sur les gros fichiers.

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

0. **Outil de comptage opportuniste (optionnel, dégradation gracieuse).** Avant la marche manuelle, tester `command -v scc || command -v tokei`. Si présent, l'**exécuter en JSON par fichier** (`scc --by-file -f json` ou `tokei -o json`) et en dériver l'inventaire : les outils donnent les LoC de **code réelles** (hors commentaires/blank), par fichier et par langage, en excluant nativement le vendored — exactement le découpage et la chasse aux god files recherchés ci-dessous, en un appel, sans lire le code (c'est la sortie qui entre en contexte, pas les fichiers). **Si aucun n'est présent** : repli sur la marche manuelle (étapes 1-5). L'outil n'est jamais une dépendance dure ; il remplace seulement l'estimation manuelle quand il est là.
1. **Walk de l'arbo** depuis la racine du projet.
2. **Pour chaque dossier**, mesurer le total LoC source (exclure `.json`, `.toml`, `.lock`, `.md`, dossiers `node_modules`, `.git`, `dist`, `build`, `vendor`, `target`, `.venv`, et tout ce qui ressemble à du généré).
3. **Règles de découpage** :
   - Dossier 200–2000 LoC → zone candidate.
   - Dossier > 2000 LoC → descendre dans ses sous-dossiers, appliquer la règle récursivement.
   - Dossier < 200 LoC → grouper avec son parent (ne pas le proposer seul).
   - **Échelle relative** : les seuils portent sur les LoC de **code** (hors commentaires/blank — naturel si l'inventaire vient de `scc`/`tokei`). Ce sont des défauts volontairement simples, pas une table par langage. Sur **très gros repo / monorepo**, viser un découpage où chaque zone tient dans un budget de lecture raisonnable plutôt que de s'accrocher aux 600/2000 LoC absolus : sous-découper un gros package par sous-module plutôt que de le marquer mécaniquement « trop gros ».
4. **Fichiers ≥ 600 LoC source** (peu importe leur dossier) → zone autonome additionnelle. Chasse les god files même quand ils sont noyés dans un dossier raisonnable.
5. **Mesure LoC source** (marche manuelle uniquement — sauté si l'étape 0 a fourni le compte) : compter les lignes non vides hors lignes-commentaires pures. Approximation acceptable, pas besoin d'AST.
6. **Pipelines candidats** : si en parcourant l'arbo le skill identifie un flux de données traçable (un point d'entrée qui appelle 3-5 fichiers en chaîne), il peut le proposer comme zone `pipeline:<nom>` avec la liste explicite des fichiers. Si le skill n'arrive pas à nommer le pipeline et ses fichiers concrètement, il **n'inclut pas** de pipeline dans les candidats — on n'invente pas de pipeline pour cocher la case. *Optionnel* : si un outil de graphe d'imports est déjà présent dans le repo (`madge --json` JS/TS, `go list -deps`, `pydeps`), s'en servir pour confirmer la fermeture réelle des dépendances autour de l'entry point (capte les imports indirects / l'injection que la lecture à l'œil rate) ; sinon, repli sur le repérage manuel via les imports lus en tête de fichier, l'abstention ci-dessus restant la règle.

`Z` = nombre total de zones candidates issu de cet inventaire.

### C. Sélection (mode auto, args vides)

L'historique sert **trois usages distincts** qui ont des horizons de mémoire différents — la sélection les exploite séparément :

1. **Lire `maintainability_history.md` en entier.** Parser toutes les lignes `- YYYY-MM-DD — <zone> — …` et extraire les zones (les lignes `crosscut:*` sont ignorées pour la sélection zonale).
2. Calculer `N = clamp(round(Z / 4), 3, 10)` (override possible via `<!-- rolling_size: M -->` en tête de history).
3. Construire deux vues sur les zones parsées :
   - **`rolling_actif`** = les `N` zones les plus récentes (les `N` premières lignes du fichier, qui est en ordre prepend = newest-first).
   - **`zones_jamais_auditees`** = `inventaire − {toutes les zones apparaissant dans le fichier, sans limite de date}`.
4. **Calculer le signal d'activité par zone** (cf. *Signal d'activité* ci-dessous). Pour chaque zone de l'inventaire, classer en :
   - **`jamais_auditee`** — zone absente de tout history.
   - **`chaude`** — zone auditée, avec `last_touch_hors_maintainability > last_audit_zone`. Du code utilisateur a bougé depuis le dernier audit.
   - **`froide`** — zone auditée, sans activité hors-maintainability depuis le dernier audit.
5. **Candidats** = `inventaire − rolling_actif`.
6. **Pondération à trois niveaux** :
   - **Top** : candidats `jamais_auditee` → couverture neuve, priorité absolue.
   - **Haute** : candidats `chaude` → la zone vient de bouger, le re-audit a un ROI élevé (nouveau code à examiner).
   - **Basse** : candidats `froide` → re-audit légitime mais marginal (la zone n'a pas changé hors fixes maintainability).
   
   Sélection : prendre le niveau le plus haut non vide, puis **départager de façon déterministe** (reproductible et auditable via l'history) — `last_audit_zone` la plus ancienne d'abord (les `jamais_auditee` n'en ont pas → considérées comme les plus anciennes), puis, à égalité résiduelle, **ordre alphabétique du chemin de zone**. Ce départage étale quand même la couverture (chaque zone finit par devenir la plus ancienne) tout en restant reproductible d'un run à l'autre. Le niveau bas n'est jamais bloqué — il est juste consulté en dernier. Si l'utilisateur veut auditer une zone froide, il passe par `/maintainability <path>`.
7. **Visée pipeline ~30%** : si des candidats `pipeline:` existent et qu'on n'a pas audité de pipeline récemment (rolling), augmenter leur pondération pour atteindre approximativement 30 % des audits sur la durée. La visée pipeline se cumule avec la pondération d'activité — un pipeline chaud reste prioritaire sur un pipeline froid.
8. **Annonce en chat** : utiliser le template `selection:proposition` (cf. `references/templates.md`). Le `<motif>` reflète à la fois la couverture (`jamais auditée`, `god file`, `pipeline traçable`) et le signal d'activité (`chaude — <N> commits depuis le dernier audit`, `froide — auditée le YYYY-MM-DD, aucune activité hors-maintainability depuis`).
9. **Validation utilisateur** : accepter, demander une alternative listée, ou imposer un autre chemin. Attendre avant de lancer l'audit.

**Pourquoi cette séparation** : trimmer history (ancien comportement) faisait perdre la couverture historique. Sur gros projet (40+ zones), après 11+ audits, des zones réellement auditées sortaient du fichier et redevenaient « jamais auditées » du point de vue de la pondération — le skill re-proposait alors des zones déjà couvertes. History est désormais append-only ; le rolling est une vue sur les `N` premières lignes, la couverture est sur le fichier entier, et le signal d'activité prévient le second mode de bouclage (rester collé aux mêmes quelques zones non-rolling sur un gros projet où l'aléatoire pondéré seul ne suffit pas à pousser vers les zones effectivement modifiées).

#### Signal d'activité

Croise les modifications réelles du code (commits utilisateur) avec l'historique des audits, pour pousser la sélection vers les zones où auditer apporte vraiment quelque chose.

**a. Identifier les commits maintainability** (à exclure du calcul d'activité — ils ne reflètent pas un changement utilisateur) :
- Scanner `maintainability_findings.md` (sections Pending **et** Resolved) : extraire tous les hashes après `Commit : ` ou `Commits : ` (un hash, ou plusieurs séparés par `+`).
- Scanner `maintainability_resolved_archive.md` s'il existe : pareil.
- Set `commits_maintainability` = union des hashes extraits (typiquement courts, 7–8 chars).

**b. Calculer `last_touch_hors_maintainability` par zone candidate** :
- Pour une zone simple (dossier ou fichier) : `git log --format=%H %cI -- <path>` puis filtrer les lignes dont le hash **commence par** un des hashes de `commits_maintainability` (matching par préfixe, car le set contient des hashes courts alors que `%H` est long). `last_touch = max(date)` parmi les restants.
- Pour un pipeline (`pipeline:<nom>` avec fichiers explicites) : appliquer le calcul sur l'union des fichiers, `last_touch = max` sur tous.
- Si aucun commit non-maintainability n'existe pour la zone (zone introduite uniquement par des fixes maintainability, cas rare) : `last_touch = epoch`. La zone tombera naturellement en `froide` au point c. — cohérent.
- **Si le repo n'est pas un git repo** (`.git/` absent au root) : sauter le signal d'activité, retomber sur la pondération à deux niveaux historique (jamais auditée = haute, sinon aléatoire). Annoncer *"Repo non-git : signal d'activité indisponible, pondération en mode dégradé."*

**c. Calculer `last_audit_zone` par zone** :
- Scanner les lignes history (hors `crosscut:*`) dont la zone matche exactement (chemin exact, ou `pipeline:<nom>` avec même nom).
- `last_audit_zone = max(date)` parmi ces lignes. Pour une zone dans `zones_jamais_auditees`, ce calcul est inutile (la zone est top de toute façon).

**d. Classement** :
- `jamais_auditee` ssi zone dans `zones_jamais_auditees`.
- Sinon `chaude` ssi `last_touch > last_audit_zone`.
- Sinon `froide`.

**Coût** : un `git log` par zone candidate. Sur Z = 40 zones, ~40 appels — quelques secondes en sélection auto, négligeable face au coût de l'audit lui-même. Sur Z > 80, le coût devient sensible ; à ce stade, le signal reste utile mais le skill peut limiter à un échantillon des top 30 zones par taille LoC (les zones < 200 LoC ont déjà été regroupées en *Inventaire des zones*, donc le filtre par taille est naturel).

#### Cas dégénérés de la sélection

- **Candidats vides** (typiquement petit projet avec un override `rolling_size` qui exclut tout) : relâcher le rolling, choisir la zone la moins récemment auditée parmi **toutes** les zones de l'inventaire. Annoncer *"Toutes les zones sont dans le rolling — j'ai pris la moins récente : `<zone>` (auditée 2026-04-22)."* À égalité, ordre alphabétique du chemin (même départage déterministe que C.6).
- **Toutes les zones candidates sont froides** : le niveau bas est consulté, choisir la `froide` la moins récemment auditée (à égalité, ordre alphabétique du chemin). Annoncer *"Aucune zone modifiée depuis son dernier audit — re-audit d'une zone froide : `<zone>` (auditée le YYYY-MM-DD, sans activité depuis)."* Pas de blocage — l'audit a toujours un sens, ne serait-ce que pour approfondir.
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
1bis. **Indices outillés (optionnel, dégradation gracieuse).** Avant l'examen au jugement, si des outils de détection déterministes sont présents dans l'environnement, les exécuter sur la zone pour obtenir des candidats précis et localisés (duplication, exports morts, complexité, god files). Cf. `references/dimensions.md > Outils de détection opportunistes` pour la cartographie outil↔dimension et la posture (l'outil fournit le **rappel et la localisation** ; l'agent garde le **jugement** — produire ou non le finding, sévérité, trade-off check). **Aucune dépendance dure** : outil absent → repli sur la lecture/jugement de l'étape 2. L'outil ne décide jamais à la place de l'agent.
2. **Examiner systématiquement toutes les dimensions** du catalogue (cf. `references/dimensions.md`). Pour chacune :
   - Chercher des occurrences concrètes du pattern dans la zone.
   - Pour chaque occurrence : observer (fait vérifiable, fichier:ligne, contexte), évaluer la sévérité (impact × exposition, cf. `references/quality.md > Grille de sévérité`), **estimer le Δ LoC** que produirait l'application de la reco (cf. `references/quality.md > Estimation Δ LoC`).
   - **Appliquer le trade-off check** avant de produire (cf. `references/quality.md > Quand ne PAS produire de finding`) — performance, sécurité, scalabilité, lisibilité paradoxale. Si le trade-off est significatif, ne pas produire ; sinon, annoter dans `Reco`.
   - **Ne pas forcer la production de findings.** Une dimension peut très bien produire 0 finding si le code est propre sur cet axe.
3. **Si un problème réel ne colle à aucune dimension** : créer un nouveau préfixe 3 lettres (cf. `references/dimensions.md > Seed des dimensions`). Documenter brièvement dans le finding pourquoi cette nouvelle catégorie.
4. **Assignation des IDs** : suivre le mécanisme de `references/file-formats.md > Compteur d'IDs` (lire le header `<!-- id_counters: ... -->`, **le recaler sur le plus grand NNN réellement présent dans findings avant d'incrémenter** — garde-fou anti-collision si le header a dérivé, mettre à jour la ligne header). Format à 3 chiffres (`DUP-007`).

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

## Mode : crosscut

Déclenché par `/maintainability-crosscut`. Sweep cross-zone sur **une dimension** intrinsèquement transverse — repère les patterns qu'un audit zonal ne voit pas par construction (duplication entre zones, conventions divergentes, types parallèles, dead code global, violations de frontière).

### A. Bootstrap

Même logique que *Mode : audit > A. Bootstrap*. Si `.claude/maintainability_*.md` absent : créer, annoncer *"Bootstrap maintainability sur ce projet, aucun historique préalable."*, puis continuer.

### B. Sélection de la dimension

Une seule dimension par invocation (granularité fine, plus précis qu'un sweep multi-dim). Éligibles : `DUP`, `INC`, `DRF`, `DED` (global), `BND`. Les autres (`CPX`, `SIZ`, `IDM`, `TST`, `CFG`, `DOC`) sont intrinsèquement intra-zone — non éligibles.

Algorithme :

1. **Lire `maintainability_history.md` en entier**. Parser les lignes `- YYYY-MM-DD — crosscut:<DIM> — …` (les lignes zonales sont ignorées pour ce calcul).
2. `Nx = 5` (override possible via `<!-- crosscut_rolling_size: M -->` en tête de history). Avec 5 dimensions éligibles et `Nx = 5`, le rolling actif est plein après 5 invocations consécutives — le système bascule alors naturellement en round-robin via le cas dégénéré ci-dessous (chaque dimension est re-crosscutée à son tour avant de revenir à la première).
3. Vues :
   - `rolling_actif_crosscut` = les `Nx` dimensions les plus récentes parmi les lignes crosscut.
   - `dimensions_jamais_crosscutées` = `{DUP, INC, DRF, DED, BND} − {toutes dimensions vues dans les lignes crosscut}`.
4. **Candidats** = `{DUP, INC, DRF, DED, BND} − rolling_actif_crosscut`.
5. **Pondération** :
   - Candidats dans `dimensions_jamais_crosscutées` → priorité haute.
   - Sinon, **signal préliminaire léger** sur les candidats restants (examen rapide, pas un mini-audit) : exports sans call site visible → `DED` ; symboles voisins / signatures similaires dans plusieurs zones → `DUP` ; imports d'internes inter-zones → `BND` ; types parallèles repérés → `DRF` ; styles multiples d'un même concept (3 paginations, 2 formats d'erreur) → `INC`. Signaux mous → aléatoire pondéré.
6. **Annonce en chat** : template `crosscut:dim-proposition`.
7. **Validation utilisateur** : accepter, demander une alternative parmi les éligibles, ou imposer (y compris une dimension dans le rolling — l'utilisateur sait ce qu'il veut).

**Cas dégénéré** : si toutes les dimensions sont dans le rolling (situation courante dès que ≥ 5 crosscut ont eu lieu, avec `Nx = 5` par défaut), relâcher : proposer la moins récemment crosscutée, annoncer *"Toutes les dimensions sont dans le rolling — j'ai pris la moins récente : `<DIM>` (crosscut le YYYY-MM-DD)."*. C'est le mode round-robin attendu.

### C. Exécution

Pour la dimension validée, scanner **tout le projet** (mêmes exclusions que l'inventaire de l'audit zonal : `node_modules`, `.git`, `dist`, `build`, `vendor`, `target`, `.venv`, généré). L'inventaire des zones (*Mode : audit > B*) sert de carte pour structurer les comparaisons inter-zones — pas de sélection, juste un découpage utile.

**Scalabilité (le crosscut n'a pas le garde-fou des 5000 LoC de l'audit zonal — D.3 — par construction).** Un scan whole-project par lecture intégrale ne passe pas à l'échelle sur un gros repo, surtout `DUP`/`DED` qui comparent toutes les zones entre elles. Donc :
- **Privilégier l'outil** quand il est présent (cf. `references/dimensions.md > Outils de détection opportunistes` — `jscpd` repo-wide pour `DUP`, `knip`/`deadcode`/`cargo-udeps` pour `DED` global, etc.), puis trier les candidats au jugement. C'est le chemin nominal sur un projet de taille réelle.
- **Sinon, fallback borné** : échantillonner les zones les plus pertinentes via la carte d'inventaire (mêmes top-N que le garde-fou de coût du *Signal d'activité*) plutôt que de prétendre tout lire, et **annoncer la couverture partielle** en chat (« couverture : N zones sur M scannées — outil X absent »). Ne jamais laisser croire à une exhaustivité non tenue.

Intent par dimension (jugement, pas algorithme prescriptif) :

- **`DUP`** : fonctions / blocs fonctionnellement équivalents dans plusieurs zones. Privilégier les helpers utilitaires (faciles à factoriser) ; ne pas forcer sur la business logic (souvent légitimement séparée).
- **`INC`** : concepts récurrents (pagination, error handling, logging, config, retries) implémentés différemment dans plusieurs zones.
- **`DRF`** : types / schemas parallèles divergeant accidentellement (`User` côté API + DB + client, `Order` côté service + worker, etc.).
- **`DED` global** : exports publics sans call site dans le projet. Borner aux candidats raisonnables (skip les API publiques de plug-in, hooks de framework, exports re-exposés via barrel files).
- **`BND`** : imports cross-zone qui contournent l'API publique (`_*` Python, `internal/` Go, deep relative imports). Chaque violation = un finding (ou groupe si pattern répété). *Si un outil de graphe d'imports est présent* (`madge --circular`, `go list`, `import-linter`), il peut aussi révéler des **cycles inter-modules / fan-in-out** que la seule lecture des imports rate ; ces problèmes de couplage structurel restent dans l'esprit `BND`, ou justifient un préfixe inédit (`CYC`) si on veut les suivre à part — sans pour autant ajouter `CYC` aux dimensions crosscut-éligibles (le round-robin `Nx = 5` est calé sur les 5 dimensions existantes).

**Conventions de finding multi-fichiers** :
- Title : fichier *primaire* (occurrence majoritaire ou premier alphabétiquement à égalité).
- `Localisation` : énumère tous les fichiers/lignes impliqués (le champ accepte plusieurs lignes).
- Préfixe : standard (`DUP`, `INC`, `DRF`, `DED`, `BND`) — **aucun marqueur "crosscut" dans l'entrée**. La nature transverse se lit de la `Localisation` multi-fichiers et de la ligne history correspondante.

**Edge cases existants applicables** : doublons potentiels (référencer l'ID existant en chat sans créer de doublon), trade-off check (cf. `references/quality.md > Quand ne PAS produire de finding`), reclassification (garder l'ID).

### D. Écritures (append-only)

1. **Append des findings** dans `## Pending` de `maintainability_findings.md`. IDs assignés via le mécanisme normal (mêmes compteurs `<!-- id_counters: ... -->` que les audits zonaux — pas de fork).
2. **Préfixer une nouvelle ligne en tête** de `maintainability_history.md` :
   ```
   - YYYY-MM-DD — crosscut:<DIM> — N findings (X HIGH, Y MED, Z LOW) (pending)
   ```
3. **Pas de trim** — append-only, comme les audits zonaux.

#### Cas dimension propre (0 findings)

- Ligne history : `- YYYY-MM-DD — crosscut:<DIM> — 0 findings (clean)`.
- Aucun append dans le findings file.
- Sortie chat : template `crosscut:clean`.

L'écriture de la ligne history est importante — sans elle, la dimension serait re-proposée trop tôt par le rolling crosscut.

### E. Sortie chat (post-crosscut)

- Findings produits → template `crosscut:summary`.
- 0 finding → template `crosscut:clean`.

### F. Proposition post-crosscut

Si findings ≥ 1, **réutiliser** *Mode : audit > H. Proposition de double-check autonome* tel quel (templates `audit:proposition` ou `audit:proposition-min` selon le nombre de findings) puis *Mode : audit > I. Action post-proposition batch* pour l'exécution. Logique de sélection des panels, critères, et flux d'exécution **identiques** — pas de duplication. Les templates et la mécanique sont génériques sur la nature de l'audit.

## Mode : list

Déclenché par `/maintainability-list`. **Pas d'audit, pas de re-vérification, aucune écriture de fichier.** Lecture seule des deux fichiers projet.

### Flux

1. Lire `maintainability_findings.md` et `maintainability_history.md`.
2. Compter les pending par sévérité. Lister les IDs avec un one-liner descriptif (extrait de l'observation, ~50 chars).
3. **Compter et lister à part les findings stale** (pending dont la bullet `Status` est `stale ...` ou `stale-after-<ID> ...`) — distincts des actifs car ils nécessitent une action utilisateur (relocaliser, marquer résolu, ou archiver) avant de pouvoir être traités. Ils restent inclus dans le total Pending.
4. Lister les résolus des 30 derniers jours (filtrer par la date dans le titre Resolved).
5. Lister les entrées du rolling actif zonal (les `N` premières lignes **non `crosscut:*`** de history, cf. `references/file-formats.md > Lignes crosscut`).
6. **Rolling crosscut** : lister les `Nx` lignes `crosscut:*` les plus récentes de history (`Nx = 5` par défaut, override `<!-- crosscut_rolling_size: M -->`). Même format de ligne que le rolling zonal : `<date> — crosscut:<DIM> — <N findings (status)>`. Omettre la section si aucune ligne crosscut.
7. Détecter les batches groupables parmi les pending **actifs uniquement** (les stale sont exclus du batching, cf. *Batches suggérés*).

### Sortie

Utiliser le template `list:dashboard`. Cas dégénérés :

- Zéro pending actif (peut-être stale) : afficher `Pending actifs (0) : aucun finding actionnable.` La section Stale reste affichée si non vide.
- Zéro stale : omettre entièrement la section Stale (ne pas afficher `Stale (0)`).
- Zéro audit : afficher `Aucun audit dans l'historique. Lance /maintainability pour commencer.`

### Batches suggérés

**Détection** (lecture seule, pas d'analyse de code) :

1. Pour chaque pending, extraire ID, dimension prefix, path (le *primaire* du titre pour les findings multi-fichiers), audit_origin (date `Détecté:`), et contenu de la dernière section `Double-check` si présente.
2. **Signaux explicites** (haute priorité) dans le Double-check, regex insensibles à la casse : `bundle`/`bundler`, `sequencing`/`étape \d+`, `après <ID>`/`avant <ID>`, `couplé avec <ID>`. Chaque mention d'un autre `<ID>` connu crée une arête ; composantes connexes = batches.
3. **Signaux heuristiques** (fallback) : même path exact ; sinon même path parent + même dimension prefix ; sinon même audit_origin. Les findings crosscut du même run partagent l'audit_origin (date du crosscut) — ils peuvent batcher entre eux via cette voie sans cas spécial.
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
   b. **Si le fichier est introuvable** (déplacé, supprimé, renommé) — passer en **investigation self-heal** avant de conclure. Utiliser les outils à disposition selon le contexte (git history, lecture de diffs, recherche du pattern dans la codebase, cross-check avec history) ; pour `stale-after-<ID>`, le commit primaire est connu et fournit un signal direct. Trois issues :
      - **Pattern retrouvé clairement à un nouvel emplacement** (signal fort : rename git ≥50% similarité, ou pattern unique retrouvé à 1 endroit avec match clair sur l'observation) → proposer la relocalisation 1-touch (*"`<ID>` retrouvé à `<new-path>:<line>` (<signal utilisé>). Relocaliser ?"*). Si OK : amender le titre avec le nouveau path, reset du `Status` à `pending`, puis re-vérifier le pattern au nouveau path comme à l'étape 2.c.
      - **Pattern dissout** (suppression nette du pattern dans un commit identifiable, ou aucune trace ailleurs dans la codebase) → proposer marquer résolu (*"`<ID>` dissout par <commit / refactor>. Marquer résolu ?"*). Si OK : flux résolu standard (étape 3), `Resolution` cite le commit responsable si identifiable.
      - **Signaux insuffisants ou ambigus** (pattern trop vague pour scanner, hits multiples non discriminants, fichiers au nom voisin créant un risque de faux positif, observation reposant sur du contexte humain) → marquer `Status: stale` (ou préserver `stale-after-<ID>` déjà posé par la cascade — l'info de cause reste plus précieuse), traité à l'étape 4.
      
      **Seuil de confiance** : conclure seulement si le signal est fort. En cas de doute, retomber sur le tagging stale — l'esprit "pas de faux positif sur fichier au nom voisin" est préservé via cette calibration, pas via une interdiction blanche. Le choix des outils et leur enchaînement reste à la main de l'agent ; le skill spécifie l'intention et les contraintes, pas la procédure.
      
      **Refus utilisateur sur une proposition self-heal** (no à relocaliser ou no à résoudre) → traité comme un stale standard à l'étape 4 (3 options manuelles). Le `Status` reste `stale` (ou `stale-after-<ID>` selon ce qui est applicable).
   c. **Si le fichier existe** : vérifier que le pattern décrit dans l'observation est toujours présent à la localisation indiquée (ou nearby si les lignes ont bougé). Heuristique :
      - Lire les ~20 lignes autour de la localisation.
      - Si le pattern décrit (duplication, god file taille, etc.) est encore reconnaissable → status inchangé.
      - Si le pattern a disparu → bascule en Resolved.
      - **Finding multi-fichiers** (bullet `Localisation` listant plusieurs emplacements, typiquement issu d'un crosscut) : lire chacun, juger le pattern globalement. Pattern dissout sur tous les emplacements → Resolved. Pattern partiellement résolu (1 sur N occurrences clear, mais ≥ 2 restent) → status inchangé. Si seul reste 1 emplacement, traiter selon la dimension : `DUP` n'a plus de sens à 1 copie → Resolved ; `DRF`/`INC` peuvent persister à 1 emplacement si le drift / l'incohérence subsiste → status inchangé.
3. Pour chaque résolu détecté :
   - Déplacer l'entrée de `## Pending` vers `## Resolved` au **format compact** (cf. `references/file-formats.md > Format compact d'une entrée résolue`).
   - Ajouter `(résolu YYYY-MM-DD)` au titre.
   - La bullet `Resolution` indique `détecté résolu lors de update (YYYY-MM-DD). Δ LoC mesuré : <valeur>` (via `git log --since=<date> -- <fichier>` ou comparaison directe ; sinon `indéterminé`). Ajouter `Commit : <hash>` si un commit aval est identifiable.
   - Mettre à jour la ligne history correspondante (l'audit qui a créé ce finding) : ajouter ou compléter le `(résolus <ID>+...)`.
4. Pour chaque stale **non résolu par l'investigation self-heal** (générique ou `stale-after-<ID>` préservé) : laisser dans Pending. Le `Status` a déjà été ajusté à l'étape 2.b. Demander à l'utilisateur en chat — message adapté à la cause, et mentionnant brièvement pourquoi le self-heal n'a pas conclu :
   - Stale générique : *"`<ID>` référence un fichier introuvable, investigation inconclusive (`<raison-courte>`). Rouvrir avec nouveau path, marquer résolu (le pattern n'existe plus), ou archiver ?"*
   - Stale-after : *"`<ID>` est `stale-after-<ID-primaire>` depuis le fix du <YYYY-MM-DD>. Investigation inconclusive (`<raison-courte>`). Rouvrir avec nouveau path, marquer résolu, ou archiver ?"*
   - **Escalade des stales anciens** (borne de terminaison à la boucle d'arbitrage) : comparer la date de pose du `Status: stale (...)` / `stale-after-<ID> (...)` à la date courante (`date +%F`). Si elle dépasse **90 jours**, ne plus re-proposer les trois options à égalité : basculer vers un **défaut explicite d'archivage** — *"`<ID>` est stale depuis le <date-de-pose> (> 90 j sans résolution). J'archive (NO-GO : stale non résolu) sauf objection ?"*. L'utilisateur peut toujours rouvrir/relocaliser ; le but est d'éviter qu'un stale jamais tranché pollue le board indéfiniment. Sans escalade, un stale resterait Pending éternellement.
5. **Vérification de l'invariant cap Resolved** : compter les entrées de `## Resolved` après les moves. Si > 8, appliquer le flux d'archivage automatique (cf. `references/file-formats.md > Cycle de vie d'un finding` étape 5).
6. **Recompute des compteurs d'IDs** : re-scanner `maintainability_findings.md` + `maintainability_resolved_archive.md` (s'il existe), recalculer le max par préfixe, mettre à jour le header `<!-- id_counters: ... -->`. Self-heal contre drift.
7. **Réconciliation history → findings (lecture seule, signalement only).** Les deux fichiers de l'étape 6 sont déjà chargés ; à ce moment, vérifier que chaque ID présent en `## Resolved`/archive apparaît bien dans un `(résolus <ID>+...)` d'une ligne history, et inversement qu'aucune ligne history ne marque résolu un ID encore dans `## Pending`. **Aucune écriture corrective automatique** : en cas d'incohérence (matching date+zone ambigu, `(résolus …)` oublié ou posé sur la mauvaise ligne), le **signaler en chat** (*"history incohérent : `<ID>` est résolu mais aucune ligne history ne le marque — à corriger à la main"*). `(résolus …)` est purement informatif (n'alimente aucune logique de sélection), donc un simple signalement suffit ; la source de vérité reste `findings.md`.

### Sortie

Utiliser le template `update:summary`.

### Coût

Cette commande lit potentiellement beaucoup de fichiers (un par pending), plus les appels d'investigation self-heal sur les pendings dont le fichier est introuvable (git history, grep codebase, lecture de diffs ciblés). Acceptable car invocation rare et explicite — pas appelée à chaque audit. Le coût self-heal est proportionnel au nombre de stales rencontrés, pas au total des pendings.

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
2. **Lire le fichier référencé** intégralement, plus les fichiers voisins / importeurs. **Finding multi-fichiers** (bullet `Localisation` énumérant plusieurs emplacements) : lire **tous** les fichiers listés ; le blast radius devient l'union des call sites / tests / surfaces touchées par chaque emplacement.
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

## Doctrine d'évaluation

Trois cadrages normatifs vivent dans `references/` et **doivent être consultés au moment de produire un finding** :

- `references/dimensions.md` — catalogue des 11 dimensions seed et cadrage strict de `IDM`. Indique aussi le hors-scope du skill (sécurité, performance, accessibilité, choix de stack). Préfixes inédits autorisés (3 lettres) si un problème réel ne colle à aucune dimension.
- `references/quality.md > Grille de sévérité` — HIGH/MED/LOW = impact × exposition. La sévérité est mutable (un double-check peut la reclasser, sans changer l'ID).
- `references/quality.md > Quand ne PAS produire de finding` — contrepoids au biais structurel de sur-production. Une zone à 0 finding est un audit *réussi*. Trade-off check obligatoire en amont (performance, sécurité, scalabilité, lisibilité paradoxale).
- `references/quality.md > Estimation Δ LoC` — convention `~±N`, méthode d'estimation, raffinement au double-check, mesure réelle à la résolution.

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

### Crosscut

- Dimension validée par l'utilisateur (template `crosscut:dim-proposition`) avant l'exécution.
- Findings appendés dans `## Pending` de `maintainability_findings.md` — un par finding produit (ou aucun si dimension propre). Findings multi-fichiers respectent la convention `<localisation>` du titre = primaire + bullet `Localisation` énumérant tous les fichiers.
- Header `<!-- id_counters: ... -->` incrémenté pour chaque préfixe utilisé (mêmes compteurs que les audits zonaux, pas de fork).
- Ligne préfixée en tête de `maintainability_history.md` au format `- YYYY-MM-DD — crosscut:<DIM> — ...`. **Pas de trim** — history est append-only.
- Si bootstrap a eu lieu : fichiers `.claude/maintainability_*.md` créés avec le contenu initial.
- Si proposition post-crosscut choisie : invariants des modes correspondants (*Double-check* pour single, *Résolution intra-session* pour fix) applicables.

### Double-check

- Section `Double-check (YYYY-MM-DD) :` ajoutée à l'entrée du finding ciblé.
- Si reclassification de sévérité validée : titre `### <ID> — <NEW-SEV> — …` modifié.
- Si l'utilisateur a choisi *Fix maintenant* à la proposition : invariants de *Résolution intra-session* applicables (cf. ci-dessous).
- Si l'utilisateur a choisi *Archiver* (NO-GO) : entrée déplacée Pending → Resolved au format compact, `Resolution: archivé après double-check (NO-GO motivé : <raison>)`, ligne history correspondante complétée, cap Resolved respecté.

### Update

- Chaque pending re-vérifié.
- Résolus détectés déplacés vers `## Resolved` au format compact.
- **Investigation self-heal exécutée** sur chaque pending dont le fichier est introuvable (cf. étape 2.b).
- **Stales auto-relocalisés** (signal fort de rename / nouvel emplacement) : titre amendé avec le nouveau path, `Status` reset à `pending`, pattern re-vérifié au nouveau path.
- **Stales auto-résolus** (pattern dissout, fix identifié) : déplacés vers `## Resolved` au format compact, `Resolution` cite le commit responsable si identifiable.
- Stales non résolus par investigation taggés `Status: stale` ; `stale-after-<ID>` existants préservés (pas écrasés). L'utilisateur arbitre à l'étape 4. **Stales > 90 j escaladés** vers un défaut d'archivage proposé (cf. étape 4) plutôt que re-proposés à l'identique.
- Lignes history correspondantes complétées (`(résolus <ID>+...)`).
- Cap Resolved appliqué (archivage automatique si > 8).
- Header `<!-- id_counters: ... -->` recomputed (self-heal en re-scannant findings + archive).
- **Réconciliation history → findings** exécutée en lecture seule (étape 7) ; toute incohérence signalée en chat (pas de correction auto).

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
