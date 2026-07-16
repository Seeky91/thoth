# Mode : audit

Référence chargée en mode **audit auto**, **audit path** ou **audit feature**. Lire d'abord `references/doctrine.md`, puis `references/file-formats.md` avant toute écriture.

## Sommaire

- Bootstrap
- Inventaire, triage de matérialité et sélection automatique
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

## Inventaire, triage de matérialité et sélection automatique

### Construire les cibles candidates

Inventorier sans lire tout le repo indistinctement, en croisant deux directions (cf. `references/doctrine.md > Hypothèses, exposition et matérialité`) :

**Top-down — opérations attendues.** Recenser ce que quelqu'un attend réellement : commandes versionnées (Makefile, scripts, targets Cargo/Gradle, jobs CI), démarrage applicatif, routes/pages du chemin utilisateur, commandes CLI, workers, jobs et batchs dont la durée compte. Sources : manifests, scripts package, docs/README, dossiers `bench`/`benchmark`/`perf`/`load`, configs Lighthouse ou performance budget, documentation de profiling.

**Bottom-up — hypothèses structurelles.** En parcourant les surfaces exécutables et chemins de données (handlers, parsing/sérialisation, requêtes, caches, boucles de traitement), formuler les indices statiques en **hypothèses falsifiables** rattachées aux candidats : boucles imbriquées sur données variables, N+1 I/O, copies/allocations visibles, verrous sur chemin fréquent, appels synchrones dans une boucle, matérialisation de gros jeux de données, travail refait à chaque appel (rechargement, re-parse). Une hypothèse n'est jamais un finding ni présentée comme telle.

Compléter l'inventaire :

1. Repérer les tests fonctionnels ou fixtures capables d'exercer ces surfaces sans trafic externe.
2. Croiser avec l'activité git : une surface modifiée depuis son dernier audit est `chaude`. Exclure du signal les commits identifiables comme fixes performance à partir des hashes stockés dans les résolutions.
3. Exclure vendored, généré, dépendances, fixtures géantes et artefacts de build.

Chaque candidat porte : `<scope>`, paths principaux, **matérialité plausible avec son sourcing d'exposition**, hypothèses éventuelles, workload existant ou proposé, métrique possible et niveau de sécurité d'exécution.

### Triage de matérialité

Classer chaque candidat `forte`, `moyenne`, `capée` ou `indéterminable` selon `references/doctrine.md > Matérialité plausible` :

- L'exposition s'estime depuis des preuves (configs, cadences, tailles de données, Makefile, docs, qui attend sur l'opération) ; ne jamais fabriquer de chiffres — une exposition sans preuve rend le candidat `indéterminable`, pas `forte`.
- **Capée** : le calcul du plafond doit être explicite et citable (fréquence structurelle × coût plausible majoré). Un scope capé sort de la sélection auto et se consigne en history avant la fin de l'invocation — ligne `skipped (exposure-capped: <calcul court>)`, cf. `references/file-formats.md` — une seule fois : ne pas ré-écrire une ligne skipped existante tant que ni le code du scope ni son exposition n'ont changé. Il reste auditable sur path ou feature explicite.
- Le triage est bon marché et se refait à chaque audit auto ; seules ses conclusions `skipped` se persistent.

### Sélectionner

Lire `performance_history.md` en entier. Construire :

- `jamais_audité` : scope absent de toute ligne d'audit de l'historique (les lignes `skipped` ne sont pas des audits) ;
- `chaud` : code du scope modifié depuis son dernier audit — ou depuis sa ligne `skipped`, ce qui rouvre son triage ;
- `froid` : aucun changement depuis ;
- `rolling` : les 4 scopes audités les plus récents (lignes `skipped` ignorées), ou la valeur de `<!-- rolling_size: N -->` si présente.

Comparer les scopes `feature:` par les paths entre crochets, pas par la description libre (cf. `references/file-formats.md`) : une feature reformulée qui couvre matériellement les mêmes paths n'est ni `jamais_audité` ni une nouvelle scope.

Prioriser de façon déterministe, **matérialité d'abord, disponibilité du workload ensuite** :

1. matérialité forte, jamais audité ou chaud, workload sûr (versionné d'abord, sinon test/fixture/harness local crédible) ;
2. matérialité forte, jamais audité ou chaud, workload long ou coûteux : proposer cette cible avec coût/durée estimés et demander confirmation — ne jamais l'écarter silencieusement au profit d'un candidat plus faible mais plus commode à mesurer ;
3. matérialité forte, jamais audité ou chaud, sans workload connu : proposer la cible en demandant comment l'exercer ;
4. matérialité moyenne, jamais audité ou chaud, workload sûr ;
5. exposition indéterminable : jamais cible principale s'il reste un candidat 1-4 ; sinon proposer en énonçant l'information d'exposition manquante.

Écarter le rolling tant qu'un candidat 1-4 existe hors rolling. À niveau égal, préférer l'exposition sourcée la plus forte, puis l'ordre alphabétique du scope. Estimer l'exposition depuis des preuves ; ne jamais fabriquer une fréquence de production.

Un scope froid inchangé ne se re-sélectionne pas en auto : une mesure ne vieillit pas si ni le code, ni les données, ni l'environnement pertinent n'ont bougé. Il redevient candidat s'il passe `chaud`, sur demande explicite (path/feature), ou si l'utilisateur signale un changement d'environnement ou de dépendances justifiant une re-mesure.

Utiliser `selection:proposition` dans `references/templates.md` avec une cible principale, sa matérialité sourcée, jusqu'à deux alternatives, le workload et la métrique envisagés, et les scopes nouvellement écartés `exposure-capped`. **Attendre la validation utilisateur** avant la mesure.

### Couverture matérielle atteinte

Si aucun candidat 1-5 ne subsiste hors rolling — tout est capé, froid inchangé ou déjà couvert — ne pas auditer un scope immatériel pour occuper l'invocation. Utiliser `selection:coverage-stop` : récapituler les scopes capés avec leurs calculs et les froids inchangés, puis poser la question d'usage — *quelle opération te semble lente ?* — pont vers un audit `feature` ciblé. Écrire les éventuelles nouvelles lignes `skipped` ; ne rien écrire d'autre.

### Cas dégénérés

- Aucun code exécutable ou workload identifiable : terminer avec `audit:inconclusive` et mémoriser l'inconclusif dans history.
- Tous les candidats restants dans le rolling, capés ou froids inchangés : appliquer *Couverture matérielle atteinte*.
- Repo non-git : ignorer le signal chaud/froid et annoncer la dégradation.
- Commande estimée longue, coûteuse ou chargeante : demander confirmation avec coût/durée attendus avant exécution.

## Audit ciblé par path

1. Vérifier que le path existe et appartient au projet.
2. Lire intégralement les fichiers source du scope raisonnable, plus les call sites/tests/benchmarks nécessaires pour savoir comment l'exercer.
3. Si le path dépasse un budget de lecture crédible ou contient plusieurs sous-systèmes indépendants, proposer 2-3 sous-scopes ; continuer sur tout le path seulement si l'utilisateur insiste.
4. Identifier une opération qui exerce réellement le path. Ne pas benchmarker une fonction isolée si son coût n'est pas représentatif de son usage.
5. Si plusieurs workloads sont plausibles et changeraient la conclusion, les présenter et demander lequel retenir.
6. Un path explicitement demandé s'audite même si un triage antérieur l'a classé `exposure-capped` : rappeler le plafond attendu dans le plan de mesure — la mesure documentaire reste légitime sur demande.

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
3. Si le triage a rattaché des hypothèses à la cible, définir pour chacune l'expérience minimale qui la falsifierait — la mesure teste des hypothèses, elle ne « regarde pas ce que ça donne ».
4. Identifier un budget/SLO existant. S'il n'existe pas, ne pas en inventer ; définir ce qui constituerait une différence à la fois au-delà de la variance et matérielle au regard de l'exposition (l'ordre de grandeur de gain qui justifierait le changement), puis noter que la cible métier reste à préciser. Une acceptation réduite à « mieux que le bruit » ferait résoudre des gains immatériels.
5. Choisir warmup, répétitions et statistique.
6. Capturer une signature d'environnement courte : mode de build, versions runtime/toolchain pertinentes, OS/architecture ou conteneur/CI.
7. Définir la commande de correction minimale à lancer avant/après si elle existe.
8. Sanitiser toute commande destinée à l'état.

Pour un audit auto, le plan fait partie de la proposition de cible. Pour un path/feature explicite, procéder directement si le workload est sûr, local et non ambigu ; sinon demander validation.

## Exécution

1. Vérifier que le scénario fonctionne et que les tests de correction ciblés passent. Une erreur fonctionnelle n'est pas une mesure de performance valide.
2. Exécuter le warmup puis la baseline avec répétitions suffisantes. Conserver valeurs agrégées et dispersion, pas seulement le meilleur run.
3. Refaire un petit échantillon si les résultats sont instables. Si l'instabilité reste trop forte, conclure `inconclusif`.
4. Profiler le même workload avec l'outil le plus pertinent disponible. Éviter que l'overhead du profiler ne soit comparé directement au temps non profilé.
5. Relier les coûts dominants à des fichiers/lignes, requêtes, locks, allocations ou frontières I/O.
6. Confronter les hypothèses du triage au profil : confirmées, réfutées ou remplacées par ce que la mesure révèle. Formuler pour chaque piste retenue une hypothèse falsifiable et une recommandation bornée ; ne pas implémenter pendant l'audit. Une hypothèse réfutée se consigne dans la ligne history — résultat à part entière, pas échec.
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

Préfixer ensuite une ligne dans `performance_history.md` : findings, clean mesuré ou inconclusif. La parenthèse de résultat tient en une phrase courte — métrique dominante, raison d'immatérialité et hypothèses réfutées le cas échéant ; le récit détaillé n'appartient pas à history (cf. `references/file-formats.md`). Écrire au même moment les lignes `skipped` des scopes nouvellement capés au triage. Ne jamais trimmer l'historique.

## Sortie

- Findings produits : `audit:summary`.
- Mesure valide sans bottleneck actionnable : `audit:clean`.
- Preuve insuffisante ou workload impossible : `audit:inconclusive`.
- Triage sans cible matérielle restante : `selection:coverage-stop`.
- Avec findings, proposer un double-check via `audit:proposition`.

## Invariants de fin de mode

- Workload, métrique, baseline et environnement présents pour chaque finding.
- Aucun finding dérivé d'un signal statique seul.
- Cible auto sélectionnée par matérialité sourcée ; aucun scope `exposure-capped` choisi en auto.
- Lignes `skipped` écrites pour les scopes nouvellement capés, dédupliquées contre les existantes.
- Findings ajoutés en delta dans `## Pending` et compteur mis à jour, ou aucun si clean/inconclusif.
- Une ligne history préfixée pour chaque audit exécuté ; hypothèses réfutées mentionnées dans la ligne clean.
- Commandes persistées sanitisées.
- Code source non modifié.
- Résultat distingué explicitement entre `clean`, `inconclusif` et arrêt de triage sans audit.
