# Format des fichiers projet

Référence chargée par SKILL.md quand le skill doit lire ou écrire un fichier d'état. Trois fichiers vivent dans `<projet>/.claude/`. Format strict, à respecter à la lettre.

## `.claude/maintainability_history.md`

**Journal d'audits append-only.** Une ligne par audit, **nouvelle entrée préfixée en tête de fichier** (ordre du plus récent au plus ancien). Le fichier n'est **jamais trimmé** — il accumule sur la durée de vie du projet.

```markdown
<!-- rolling_size: 5 -->        # optionnel : override la taille du rolling actif (cf. plus bas)
# Maintainability audit history

- 2026-05-03 — services/billing/refund/ — 6 findings (3 HIGH, 2 MED, 1 LOW) (résolus DUP-007+SIZ-003)
- 2026-05-01 — pipeline:order-processing [api/ingest.py, validators/order.py, enrichers/customer.py, store/orders.py] — 4 findings (1 HIGH, 3 MED) (pending)
- 2026-04-22 — core/api_handler.py — 8 findings (4 HIGH, 3 MED, 1 LOW) (pending)
- 2026-04-15 — services/auth/ — 3 findings (1 MED, 2 LOW) (résolus tous)
- 2026-03-30 — services/payments/ — 0 findings (clean)
- ... (ligne par audit, jamais tronqué)
```

### Règles de format

- Format ligne : `- YYYY-MM-DD — <zone> — N findings (X HIGH, Y MED, Z LOW) (status)`
- `<zone>` = chemin dossier (`services/billing/refund/`), chemin fichier (`core/api_handler.py`), ou `pipeline:<nom> [fichiers,…]`. Le bracket fichiers n'apparaît QUE pour les pipelines.
- `(status)` : `(pending)`, `(résolus tous)`, ou `(résolus <ID>+<ID>+...)` quand certains seulement sont résolus.
- Zone propre (0 findings) : ligne `- YYYY-MM-DD — <zone> — 0 findings (clean)`. **Écrire quand même cette ligne** — c'est ce qui mémorise que la zone a été examinée.

### Deux usages du fichier (à distinguer)

Le fichier sert à **deux choses** qui n'ont pas le même horizon de mémoire :

1. **Rolling actif** — les `N` audits les plus récents, à exclure des candidats au prochain audit pour éviter le ressassement. `N = clamp(round(Z / 4), 3, 10)` où `Z` = nombre de zones de l'inventaire courant. Override possible via `<!-- rolling_size: M -->` en tête de fichier.
2. **Couverture historique** — l'ensemble des zones **jamais auditées dans la vie du projet**, pour pondérer la sélection ("zones jamais auditées → priorité haute"). Construit en scannant **toutes** les lignes du fichier, pas seulement les `N` dernières.

Le fichier sert les deux usages depuis la même source. Le rolling est une **vue** des `N` premières lignes (les plus récentes, car prepend en tête) ; la couverture est l'**union** des zones de toutes les lignes.

### Pourquoi append-only

Trimmer le fichier à `N` lignes faisait perdre la couverture historique : sur un gros projet (40+ zones), après 11+ audits, des zones réellement auditées sortaient du fichier et redevenaient « jamais auditées » du point de vue de la pondération. Le skill re-proposait alors des zones déjà couvertes. Append-only règle ça sans coût significatif (un audit ≈ une ligne, 100 audits ≈ 100 lignes, lecture instantanée).

### Override `rolling_size`

Si `<!-- rolling_size: N -->` est présent en tête de fichier (avant le `#` header), **respecter cette valeur** au lieu du calcul auto, même si elle tombe hors `[3, 10]`. L'utilisateur sait ce qu'il veut ; le skill ne discute pas la valeur. L'override ne porte que sur la **taille du rolling actif** — il n'affecte ni la taille du fichier (toujours unbounded) ni le calcul de la couverture historique (toujours sur l'ensemble du fichier).

## `.claude/maintainability_findings.md`

Source de vérité des findings. Deux sections (`## Pending`, `## Resolved`) plus un header de compteurs d'IDs.

```markdown
# Maintainability findings

<!-- id_counters: DUP=7, SIZ=3, CPX=2, INC=2, DOC=1 -->

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
- **Double-check (2026-04-25) :** Blast radius : 47 imports, 12 tests touchés. Effort M (~1 jour, 4 commits incrémentaux). Faisabilité OK avec contraintes mineures (transactions à préserver). Δ LoC affiné : ~+85. Verdict : GO, prioriser après TST-009. Apport : chaque responsabilité d'`api_handler` devient testable indépendamment et débloque le refactor de routing prévu plus tard.

## Resolved

### DUP-005 — MED — services/auth/login.py:23 (résolu 2026-04-16)
- **Dimension :** duplication de code
- **Resolution :** Extrait vers `services/auth/_helpers.py`. Δ LoC mesuré : -32. Commit : a7b3d12.
- **Audit origin :** 2026-04-15 (services/auth/)
```

### Règles de format

- En-tête entrée : `### <ID> — <SÉVÉRITÉ> — <localisation>` (avec `(résolu YYYY-MM-DD)` ajouté pour les Resolved).
- `<localisation>` = `path:line` ou `path:start-end` ou juste `path` (pour les god files).
- **Pending** — bullets dans cet ordre : Dimension, Observation, Reco, Δ LoC, Détecté, Status, puis sections optionnelles (Double-check). Valeurs de `Status` :
  - `pending` (initial),
  - `stale (YYYY-MM-DD) — <raison>` (posé par `update` quand le fichier est introuvable **et** l'investigation self-heal est inconclusive ; cf. SKILL.md > Mode update > étape 2.b),
  - `stale-after-<ID> (YYYY-MM-DD) — <raison>` (posé par la cascade quand le fix de `<ID>` invalide la localisation ; peut être résolu ou relocalisé au prochain `update` par self-heal).
- **Resolved** — format compact à 3 bullets : Dimension, Resolution, Audit origin. Voir *Format compact d'une entrée résolue* ci-dessous.
- L'ID est immuable. Tout autre attribut peut être amendé.
- Le header `<!-- id_counters: PREFIX=N, ... -->` cache les compteurs d'IDs pour assignation rapide (cf. *Compteur d'IDs*). Absent dans un fichier fraîchement bootstrappé ; ajouté à la première assignation d'ID.
- **Cap Resolved = 8** (valeur canonique unique du skill). La section `## Resolved` est cappée à 8 entrées ; les plus anciennes sont déplacées vers `maintainability_resolved_archive.md` automatiquement (cf. *Cycle de vie d'un finding* étape 5).

### Format compact d'une entrée résolue

À chaque move vers `## Resolved` (intra-session, update, NO-GO post double-check). **Drop** : Observation, Reco, Δ initial, Status, Double-check. **Conserver** : 3 bullets fixes :

```markdown
### DUP-011 — LOW — crates/bot/src/web.rs (résolu 2026-05-06)
- **Dimension :** duplication scaffolding vault
- **Resolution :** Helper `vault_blocking<F,T>` ajouté, 4 sites migrés. Δ LoC mesuré : -30. Commit : 86518fb.
- **Audit origin :** 2026-05-05 (crates/bot/src/web.rs)
```

`Resolution` doit contenir : description courte du fix + `Δ LoC mesuré : <valeur>` + `Commit : <hash>` (ou `Commits : <h1>+<h2>`). `Audit origin` reprend la date et la zone de l'audit qui a produit le finding.

**Cas NO-GO archivé** (cf. *SKILL.md > Mode audit > H. Proposition de double-check autonome*) : `Resolution` cite la raison du NO-GO en 1-2 phrases ; `Δ LoC : N/A (NO-GO)` remplace le Δ mesuré.

Les entrées Resolved en format verbose **existantes** restent valides — pas de re-écriture rétroactive.

## `.claude/maintainability_resolved_archive.md`

Cold storage pour les entrées de `## Resolved` qui débordent du cap. **Jamais lu par défaut** : le skill ne le charge que pendant `update` (recompute des compteurs d'IDs) et `archive-clear`. Création paresseuse au premier débordement.

```markdown
# Maintainability resolved archive

### DUP-001 — MED — services/auth/login.py:23 (résolu 2026-04-16)
- **Dimension :** duplication de code
- **Observation :** Validation token dupliquée avec `services/auth/refresh.py:18`.
- **Reco :** Helper `_validate_token()`.
- **Δ LoC :** ~-25 (estimation initiale).
- **Resolution :** Extrait vers `services/auth/_helpers.py`. Δ LoC mesuré : -32.

### CPX-002 — HIGH — core/api_handler.py:88 (résolu 2026-04-22)
- ...
```

### Règles de format

- Pas de section `## Pending` / `## Resolved` (le fichier entier est l'équivalent d'un `## Resolved` géant).
- Entrées au format strict identique à celles de `## Resolved` du fichier findings (titre + bullets, déplacées intactes — pas de compaction).
- Append-only en fin de fichier (l'ordre = ordre chronologique des résolutions, du plus ancien au plus récent).
- Les IDs des entrées archivées restent référencés dans `maintainability_history.md` (lignes `(résolus DUP-001+...)`) — pas de mise à jour à faire dans history lors de l'archivage.
- Lecture explicite uniquement par l'utilisateur (`grep`, ouverture éditeur, ou demande conversationnelle "regarde l'archive et …"). Pas de mode dédié dans le skill.

## Compteur d'IDs (header cached)

Le fichier `maintainability_findings.md` porte un header en commentaire HTML qui cache le max assigné par préfixe :

```markdown
<!-- id_counters: DUP=12, CPX=8, SIZ=5, INC=4, DRF=2, BND=1, TST=2, DOC=4, DED=4, CFG=1 -->
```

**Assignation d'un nouvel ID** : lire le compteur pour le préfixe dans le header, incrémenter, écrire le finding avec ce nouvel ID, mettre à jour la ligne header. Coût trivial : le header est déjà chargé, pas besoin de scanner l'archive ni même la totalité du fichier findings.

**Préfixe inédit** (premier finding d'une nouvelle dimension comme `LOG-`, `RAC-`, ou autre invention) : ajouter `<PREFIX>=1` au header.

**Header absent** (cas migration depuis un état pré-archive, ou édition manuelle qui l'a viré) : scan one-shot de `maintainability_findings.md` + `maintainability_resolved_archive.md` (s'il existe), calcul des max par préfixe, écriture du header. Coût ponctuel, jamais répété ensuite.

**Self-healing** : à chaque `update`, recompute des compteurs en re-scannant les deux fichiers. Avec `archive-clear`, ce sont les seuls moments où le skill lit l'archive — coût acceptable car les deux opérations sont rares et explicites.

Format : à 3 chiffres (`DUP-007`), peut grandir au-delà sans souci (`DUP-1042` reste lisible).

**Jamais de réutilisation d'ID**, même après suppression manuelle d'une entrée par l'utilisateur, et même après archivage. Le compteur monte monotonement. Si max trouvé = `DUP-005` mais l'utilisateur a supprimé `DUP-005`, le prochain est `DUP-006` (pas `DUP-005`).

## Cycle de vie d'un finding

1. **Création** lors d'un audit → entrée `## Pending` avec ID, dimension, sévérité, observation, reco, date, `Status: pending`.
2. **Double-check** (`/maintainability-double-check <ID>`) → ajoute une section `Double-check (date)` dans l'entrée existante. Peut amender la reco. Peut révéler un changement de sévérité (proposer à l'utilisateur, valider, puis amender l'attribut).
3. **Résolution intra-session** → quand l'utilisateur applique un fix dans la conversation qui suit un audit ou un double-check, le skill **propose** de marquer résolu :
   - Déplace l'entrée en `## Resolved` au **format compact** — Observation, Reco, Δ initial, Status, Double-check sont droppés.
   - Ajoute `(résolu YYYY-MM-DD)` dans le titre.
   - La bullet `Resolution` contient : description courte du fix + `Δ LoC mesuré : <valeur>` (mesurer via `git diff --stat` ou comptage direct ; faire la mesure dans le tour de conversation si possible) + `Commit : <hash>` du commit qui applique le fix.
   - Met à jour la ligne history correspondante : `(résolus DUP-007)` → `(résolus DUP-007+SIZ-003)` si plus d'un fix.
   - **Déclenche la re-vérification en cascade** sur les pendings dont la localisation chevauche le diff du fix (cf. `references/cascade.md`). Le résultat est intégré dans le **même prompt** de confirmation primaire.
4. **Update** (`/maintainability-update`) → re-vérifie chaque pending :
   - Pattern toujours présent → status inchangé.
   - Pattern absent → bascule en Resolved au format compact ; `Resolution` indique `détecté résolu lors de update (YYYY-MM-DD)` + Δ mesuré + `Commit : <hash>` si identifiable via `git log`.
   - Fichier disparu / déplacé → **investigation self-heal** (cf. SKILL.md > Mode update > étape 2.b). Trois issues : pattern retrouvé ailleurs → relocalisation 1-touch ; pattern dissout → résolu auto avec commit cité ; signaux insuffisants → `Status: stale` (ou préservation de `stale-after-<ID>` posé par la cascade) puis arbitrage utilisateur.
5. **Archivage automatique** → après chaque move vers `## Resolved` (étapes 3, 4, ou *Cas NO-GO en autonomie* du mode audit) :
   - Compter les entrées de la section `## Resolved` du fichier findings.
   - Si > cap (8) : déplacer la (les) plus ancienne(s) vers `maintainability_resolved_archive.md` jusqu'à ramener le compte au cap. Ancienneté déterminée par la date `(résolu YYYY-MM-DD)` dans le titre — la plus petite date part en premier. Tie-break en cas d'égalité de date : ordre dans le fichier (la plus haute dans la section part en premier).
   - Si l'archive n'existe pas, la créer à la volée avec le header `# Maintainability resolved archive\n\n` puis appender l'entrée.
   - Append en fin d'archive (l'ordre d'archivage = ordre chronologique des résolutions).
   - L'entrée est déplacée intacte (la compaction a déjà eu lieu au move vers `## Resolved`).
   - Le header `<!-- id_counters: ... -->` du fichier findings n'est pas affecté (les IDs restent monotonement croissants).
