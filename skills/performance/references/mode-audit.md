# Mode : audit

Référence chargée en mode **audit auto**, **audit path** ou **audit feature**. Lire d'abord `references/doctrine.md`, puis `references/file-formats.md` avant toute écriture.

## Sommaire

- Bootstrap
- Inventaire et sélection automatique
- Audit ciblé par path
- Audit ciblé par feature
- Plan de mesure
- Exécution
- Production et écriture des findings
- Sortie
- Invariants

## Bootstrap

Si l'état performance n'existe pas :

1. Créer `<STATE_DIR>` si nécessaire.
2. Créer `performance_history.md` avec `# Performance audit history\n\n`.
3. Créer `performance_findings.md` avec `# Performance findings\n\n## Pending\n\n## Resolved\n`. Ne pas créer de compteur avant le premier finding.
4. Ne créer `performance_resolved_archive.md` qu'au premier débordement du cap Resolved.
5. Annoncer : `Bootstrap performance sur ce projet, aucun historique préalable.`

## Inventaire et sélection automatique

### Construire les cibles candidates

Inventorier sans lire tout le repo indistinctement :

1. Détecter les commandes déjà prévues pour la performance : dossiers/fichiers `bench`, `benchmark`, `perf`, `load`, manifests, scripts package, targets Make/Cargo/Gradle, configs Lighthouse ou performance budget, jobs CI et documentation de profiling.
2. Repérer les surfaces exécutables et chemins de données : routes, handlers, pages et vues client, commandes CLI, workers, jobs, pipelines, parsing/sérialisation, requêtes, caches, boucles de traitement, démarrage applicatif.
3. Repérer les tests fonctionnels ou fixtures capables d'exercer ces surfaces sans trafic externe.
4. Utiliser les indices statiques uniquement pour classer des candidats : boucles imbriquées sur données variables, N+1 I/O, copies/allocation visibles, verrous sur chemin fréquent, appels synchrones dans une boucle, matérialisation de gros jeux de données. Ne jamais les présenter comme findings.
5. Croiser avec l'activité git : une surface modifiée depuis son dernier audit est `chaude`. Exclure du signal les commits identifiables comme fixes performance à partir des hashes stockés dans les résolutions.
6. Exclure vendored, généré, dépendances, fixtures géantes et artefacts de build.

Chaque candidat porte : `<scope>`, paths principaux, workload existant ou proposé, métrique possible, raison de pertinence et niveau de sécurité d'exécution.

### Sélectionner

Lire `performance_history.md` en entier. Construire :

- `jamais_audité` : scope absent de tout l'historique ;
- `chaud` : code du scope modifié depuis son dernier audit ;
- `froid` : aucun changement depuis ;
- `rolling` : les 4 scopes les plus récents, ou la valeur de `<!-- rolling_size: N -->` si présente.

Comparer les scopes `feature:` par les paths entre crochets, pas par la description libre (cf. `references/file-formats.md`) : une feature reformulée qui couvre matériellement les mêmes paths n'est ni `jamais_audité` ni une nouvelle scope.

Prioriser de façon déterministe :

1. candidat jamais audité avec workload versionné et sûr ;
2. candidat chaud avec workload reproductible ;
3. candidat jamais audité avec test/fixture permettant un workload local crédible ;
4. candidat froid avec workload existant ;
5. candidat statique sans workload, uniquement pour demander à l'utilisateur comment l'exercer.

Écarter le rolling tant qu'un autre candidat existe. À niveau égal, préférer la surface la plus exposée d'après les call sites/tests/configs, puis l'ordre alphabétique du scope. Ne pas inventer de fréquence de production.

Utiliser `selection:proposition` dans `references/templates.md` avec une cible principale, jusqu'à deux alternatives, le workload et la métrique envisagés. **Attendre la validation utilisateur** avant la mesure. Si aucun workload sûr n'est disponible, proposer la meilleure cible en disant explicitement quelle information manque.

### Cas dégénérés

- Aucun code exécutable ou workload identifiable : terminer avec `audit:inconclusive` et mémoriser l'inconclusif dans history.
- Tous les candidats dans le rolling : choisir le moins récemment audité.
- Repo non-git : ignorer le signal chaud/froid et annoncer la dégradation.
- Commande estimée longue, coûteuse ou chargeante : demander confirmation avec coût/durée attendus avant exécution.

## Audit ciblé par path

1. Vérifier que le path existe et appartient au projet.
2. Lire intégralement les fichiers source du scope raisonnable, plus les call sites/tests/benchmarks nécessaires pour savoir comment l'exercer.
3. Si le path dépasse un budget de lecture crédible ou contient plusieurs sous-systèmes indépendants, proposer 2-3 sous-scopes ; continuer sur tout le path seulement si l'utilisateur insiste.
4. Identifier une opération qui exerce réellement le path. Ne pas benchmarker une fonction isolée si son coût n'est pas représentatif de son usage.
5. Si plusieurs workloads sont plausibles et changeraient la conclusion, les présenter et demander lequel retenir.

## Audit ciblé par feature

1. Reformuler la feature en scénario observable, sans élargir l'intention.
2. Localiser ses points d'entrée via routes, commandes, UI/API contracts, tests et recherche de symboles.
3. Tracer les principaux call sites et le chemin de données jusqu'aux frontières I/O ; produire une liste de paths explicite.
4. Identifier le test, benchmark ou scénario local qui exerce cette feature.
5. Si le mapping feature → code ou workload reste ambigu, afficher le scope résolu et demander validation avant de mesurer.
6. Conserver comme clé history `feature:<description-courte> [paths principaux]`. Si une ligne history couvre déjà matériellement les mêmes paths, réutiliser sa description exacte plutôt qu'une reformulation.

## Plan de mesure

Avant d'exécuter :

1. Définir le workload selon `references/doctrine.md > Contrat du workload`.
2. Choisir une métrique primaire et au plus deux secondaires utiles.
3. Identifier un budget/SLO existant. S'il n'existe pas, ne pas en inventer ; définir ce qui constituerait une différence à la fois au-delà de la variance et matérielle au regard de l'exposition (l'ordre de grandeur de gain qui justifierait le changement), puis noter que la cible métier reste à préciser. Une acceptation réduite à « mieux que le bruit » ferait résoudre des gains immatériels.
4. Choisir warmup, répétitions et statistique.
5. Capturer une signature d'environnement courte : mode de build, versions runtime/toolchain pertinentes, OS/architecture ou conteneur/CI.
6. Définir la commande de correction minimale à lancer avant/après si elle existe.
7. Sanitiser toute commande destinée à l'état.

Pour un audit auto, le plan fait partie de la proposition de cible. Pour un path/feature explicite, procéder directement si le workload est sûr, local et non ambigu ; sinon demander validation.

## Exécution

1. Vérifier que le scénario fonctionne et que les tests de correction ciblés passent. Une erreur fonctionnelle n'est pas une mesure de performance valide.
2. Exécuter le warmup puis la baseline avec répétitions suffisantes. Conserver valeurs agrégées et dispersion, pas seulement le meilleur run.
3. Refaire un petit échantillon si les résultats sont instables. Si l'instabilité reste trop forte, conclure `inconclusif`.
4. Profiler le même workload avec l'outil le plus pertinent disponible. Éviter que l'overhead du profiler ne soit comparé directement au temps non profilé.
5. Relier les coûts dominants à des fichiers/lignes, requêtes, locks, allocations ou frontières I/O.
6. Formuler une hypothèse falsifiable et une recommandation bornée. Ne pas implémenter pendant l'audit.
7. Appliquer le garde-fou de maintenabilité de `references/doctrine.md`.

## Production et écriture des findings

Produire un finding seulement si toutes les conditions suivantes tiennent :

- workload explicite et reproductible ;
- baseline chiffrée avec contexte de mesure ;
- impact matériel par rapport à la dispersion, au budget ou à l'exposition ;
- preuve localisant ou attribuant le coût ;
- action locale crédible ;
- compromis de maintenabilité/correction évalué.

Pour chaque finding :

1. Calibrer HIGH/MED/LOW via `references/doctrine.md`.
2. Assigner le prochain ID `PERF-NNN` selon `references/file-formats.md`.
3. Écrire le format Pending strict, avec workload et commandes sanitisés.
4. Si un pending existant décrit même scope + métrique + bottleneck, ne pas dupliquer. Ajouter ou rafraîchir une section `Dernière observation (date)` et citer l'ID existant dans la sortie.

Préfixer ensuite une ligne dans `performance_history.md` : findings, clean mesuré ou inconclusif. Ne jamais trimmer l'historique.

## Sortie

- Findings produits : `audit:summary`.
- Mesure valide sans bottleneck actionnable : `audit:clean`.
- Preuve insuffisante ou workload impossible : `audit:inconclusive`.
- Avec findings, proposer un double-check via `audit:proposition`.

## Invariants de fin de mode

- Workload, métrique, baseline et environnement présents pour chaque finding.
- Aucun finding dérivé d'un signal statique seul.
- Findings ajoutés en delta dans `## Pending` et compteur mis à jour, ou aucun si clean/inconclusif.
- Une ligne history préfixée dans tous les cas.
- Commandes persistées sanitisées.
- Code source non modifié.
- Résultat distingué explicitement entre `clean` et `inconclusif`.
