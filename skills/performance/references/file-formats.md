# Format des fichiers projet

Référence normative pour l'état performance sous `<STATE_DIR>`. Conserver le Markdown : lisible, diffable et éditable à la main. Relire chaque fichier juste avant écriture et appliquer uniquement le delta ciblé.

## Sommaire

- `performance_history.md`
- `performance_findings.md`
- `performance_resolved_archive.md`
- Compteur d'IDs
- Cycle de vie

## `performance_history.md`

Journal append-only, nouvelle ligne préfixée en tête :

```markdown
<!-- rolling_size: 4 -->
# Performance audit history

- 2026-07-15 — feature:checkout [src/checkout, src/db/orders] — 2 findings (1 HIGH, 1 MED) (pending) — metric: p95 latency — workload: `make bench-checkout`
- 2026-07-10 — src/serializer/ — 0 findings (clean) — metric: throughput — workload: `cargo bench serializer`
- 2026-07-02 — feature:search [src/search] — 0 findings (inconclusive: variance instable) — workload: `pytest tests/test_search.py`
```

Règles :

- Format : `- YYYY-MM-DD — <scope> — <résultat> — metric: <métrique> — workload: <commande sanitisée>`.
- `<scope>` = path ou `feature:<description-courte> [paths principaux]`.
- L'identité d'une scope `feature:` est portée par les paths entre crochets, pas par le texte libre : deux lignes dont les paths se recouvrent matériellement désignent la même scope même si la description diffère. Avant d'écrire une nouvelle ligne feature, réutiliser la description exacte d'une ligne existante qui matche par les paths.
- Résultat = `N findings (...) (pending|résolus ...)`, `0 findings (clean)` ou `0 findings (inconclusive: <raison>)`.
- Une même scope peut apparaître plusieurs fois ; retrouver l'audit d'origine par la paire exacte date + scope.
- L'historique n'est jamais trimmé. Le rolling est une vue sur les 4 premières scopes, override possible avec `<!-- rolling_size: N -->`. La taille est fixe — contrairement au `N` calculé de `maintainability` — parce que l'inventaire performance compte peu de scopes réellement exerçables ; un calcul proportionnel n'apporterait rien.
- Une ligne inconclusive mémorise la tentative mais ne prouve pas que la scope est propre.

## `performance_findings.md`

Source de vérité :

```markdown
# Performance findings

<!-- id_counter: PERF=7 -->

## Pending

### PERF-007 — HIGH — src/checkout/reprice.ts:88
- **Axe :** latence / I/O
- **Scope :** feature:checkout [src/checkout, src/db/orders]
- **Workload :** `make bench-checkout CASE=standard` ; 200 commandes synthétiques, warmup 3, 15 répétitions, build production
- **Métrique :** latence p95
- **Baseline :** 428 ms p95 ; médiane 391 ms ; dispersion p95 18 ms ; Linux x86_64, Node 24, build production
- **Observation :** 201 lectures séquentielles sont exécutées pour 200 commandes.
- **Preuve :** trace DB : 76 % du temps dans `loadPrice`, appelée une fois par commande depuis l. 88.
- **Hypothèse :** charger les prix distincts en une requête batch supprimera les round-trips séquentiels.
- **Reco :** précharger les IDs distincts puis résoudre les commandes depuis une map locale.
- **Acceptation :** p95 sous le budget existant de 250 ms, mêmes résultats fonctionnels et aucune hausse mémoire > budget projet.
- **Maintenabilité :** conserver le batching dans le repository ; ne pas exposer la map aux couches appelantes.
- **Détecté :** 2026-07-15 (feature:checkout [src/checkout, src/db/orders])
- **Status :** pending
- **Double-check (2026-07-16) :** reproduction 421 ms p95 (écart baseline 1,6 %) ; profil confirmé ; blast radius 3 call sites/8 tests ; effort M ; verdict GO ; plan affiné : `loadPrices(ids)` dans le repository ; gain attendu : suppression de 200 round-trips.

## Resolved

### PERF-003 — MED — src/serializer.rs:44 (résolu 2026-07-12)
- **Axe :** CPU / allocations
- **Resolution :** buffer réutilisé dans la boucle chaude. Commit : non commité.
- **Validation :** avant 82k ops/s, après 119k ops/s (+45 %) ; dispersion 2,8 % ; tests ciblés et suite projet OK ; garde-fou maintenabilité OK.
- **Audit origin :** 2026-07-10 (src/serializer/)
```

### Format Pending

Ordre strict : Axe, Scope, Workload, Métrique, Baseline, Observation, Preuve, Hypothèse, Reco, Acceptation, Maintenabilité, Détecté, Status, puis sections optionnelles `Dernière observation` et `Double-check`.

Status autorisés :

- `pending` ;
- `stale (YYYY-MM-DD) — workload non reproductible : <raison>` ;
- `stale (YYYY-MM-DD) — scope introuvable : <raison>` ;
- `blocked (YYYY-MM-DD) — mesure sûre impossible sans <condition>` uniquement si une dépendance externe précise empêche toute re-mesure.

L'ID est immuable. Sévérité, localisation, workload et acceptation peuvent être amendés après double-check avec trace dans la section correspondante.

### Format Resolved compact

Conserver exactement quatre bullets : Axe, Resolution, Validation, Audit origin. `Resolution` décrit le fix et indique `Commit : <hash>` ou `Commit : non commité`. `Validation` contient mesure avant/après, gain absolu/relatif pertinent, dispersion, tests et verdict du garde-fou de maintenabilité.

Cap `## Resolved` = 8 entrées. Déplacer les plus anciennes vers l'archive après chaque résolution.

## `performance_resolved_archive.md`

Créer paresseusement :

```markdown
# Performance resolved archive

### PERF-001 — MED — src/cache.ts:19 (résolu 2026-06-01)
- **Axe :** latence
- **Resolution :** ...
- **Validation :** ...
- **Audit origin :** ...
```

Ne pas ajouter de sections Pending/Resolved. Déplacer les entrées compactes intactes en fin de fichier. Ne lire l'archive que pour recompute du compteur, update ou demande explicite.

## Compteur d'IDs

Utiliser `<!-- id_counter: PERF=N -->` dans `performance_findings.md`.

- Avant assignation, calculer `max(valeur_header, plus grand PERF-NNN présent dans findings)`, puis incrémenter.
- Header absent : scanner findings et archive, calculer le max, puis écrire le header.
- À chaque update : re-scanner findings + archive et corriger le header.
- Ne jamais réutiliser un ID supprimé ou archivé.
- Format minimal à trois chiffres : `PERF-001`.

## Cycle de vie

1. **Audit** : créer un Pending uniquement avec preuve mesurée.
2. **Double-check** : reproduire, approfondir et ajouter une section datée ; verdict GO, GO-mais-après-X, NO-GO ou INCONCLUSIF.
3. **Fix confirmé** : modifier le code, exécuter tests et benchmark comparable, puis contrôler le diff avec le garde-fou de maintenabilité.
4. **Résolution** : seulement si acceptation satisfaite, correction préservée et gain au-delà de la variance. Déplacer vers Resolved compact et compléter history.
5. **Update** : re-mesurer les pendings ; résoudre ceux qui satisfont désormais l'acceptation dans un environnement comparable, maintenir les présents, tagger les stales.
6. **Archivage** : si Resolved > 8, déplacer les plus anciennes vers l'archive ; tie-break par ordre du fichier.

Un fix sans amélioration mesurable ou avec tests KO reste Pending. Ne jamais marquer résolu parce que le code « semble plus rapide ».
