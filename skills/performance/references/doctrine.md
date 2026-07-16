# Doctrine de performance

Référence normative à lire avant tout audit, double-check, update ou fix. Elle définit ce qui mérite un finding `PERF`, comment mesurer et comment empêcher une optimisation de dégrader gratuitement le code.

## Contrat du workload

Toute conclusion porte sur un workload explicite, jamais sur « le programme » en général. Décrire au minimum :

- le scénario ou l'opération exercée ;
- la commande ou procédure reproductible, sanitised si elle contient des paramètres sensibles ;
- la taille et la nature synthétique/réelle des entrées ;
- le mode de build et la configuration influençant la mesure ;
- le warmup, le nombre de répétitions et la statistique retenue ;
- l'environnement utile à la comparaison (OS/architecture, runtime/toolchain, local/CI/conteneur), sans persister de secrets.

Pour une feature, tracer d'abord son point d'entrée, les principaux call sites et le chemin de données. Pour un path, identifier l'opération réellement représentative qui l'exerce. Un microbenchmark isolé n'est valable que si le coût isolé domine réellement le scénario utilisateur ou si le finding porte explicitement sur cette primitive.

## Hiérarchie de preuve

Utiliser les signaux dans cet ordre :

1. **Mesure end-to-end reproductible** : latence, throughput, ressources ou courbe sous charge sur un scénario représentatif.
2. **Profil relié à cette mesure** : CPU samples, allocations, I/O, contention, requêtes ou traces localisant le coût.
3. **Expérience contrôlée** : variante temporaire ou désactivation ciblée confirmant l'hypothèse.
4. **Inspection statique** : complexité algorithmique, copies, appels I/O ou verrous visibles. Sert à formuler une hypothèse, jamais à prouver seule un finding.

Un finding persistant exige au minimum les niveaux 1 et 2, sauf impossibilité intrinsèque de profiler démontrée. Dans ce cas, une expérience contrôlée de niveau 3 peut remplacer le profil si elle attribue clairement le coût. Sans attribution suffisante, écrire un audit `inconclusif`, pas un finding.

## Hypothèses, exposition et matérialité

La preuve de performance habite l'exécution ; le **ciblage**, lui, habite la couche statique. Trois étages épistémiques, du moins cher au plus cher :

1. **Hypothèse** — supposition issue de la lecture du code et du raisonnement d'exposition. Elle porte une localisation, un mécanisme suspecté, une exposition sourcée et l'expérience minimale qui la falsifierait. Elle sert à classer les cibles et à orienter le plan de mesure ; elle n'a pas d'ID, n'entre jamais dans le board et ne se présente jamais comme un problème avéré.
2. **Finding** — hypothèse confirmée par la hiérarchie de preuve (mesure + attribution). Seuil inchangé.
3. **Verdict** — finding re-vérifié par double-check avant tout fix.

### Raisonnement d'exposition

L'exposition s'estime **depuis des preuves**, jamais de mémoire : configs et cadences observables (intervalle de tick, fréquence d'un heartbeat, cron), tailles et bornes des données réelles, commandes versionnées (Makefile, scripts, CI), documentation, et qui attend concrètement sur l'opération (opérateur, utilisateur final, pipeline). Ne jamais fabriquer de chiffres : une exposition sans preuve se déclare indéterminable. Côté coût, la lecture statique ne fournit qu'un **ordre de grandeur plausible** — caches, compilateurs et tailles réelles déjouent l'intuition ; conclure un coût reste le rôle exclusif de la mesure.

### Matérialité plausible

Matérialité plausible d'une cible = exposition sourcée × ordre de grandeur de coût plausible :

- **forte** — opération que quelqu'un attend réellement et souvent, ou coût croissant avec des données non bornées ;
- **moyenne** — exposition réelle mais modérée, ou coût plausible incertain sans plafond démontrable ;
- **capée (exposure-capped)** — un plafond structurel d'exposition borne tout gain plausible sous la matérialité, calcul explicite à l'appui (ex. : migration 1×/lancement × quelques ms majorées ; boucle ~1 Hz × coût ns-µs). Mesurer un scope capé ne pourrait produire aucun finding quel que soit le résultat : il se consigne sans harnais ;
- **indéterminable** — aucune preuve d'exposition disponible ; à déclarer, jamais à deviner.

### La réfutation est un résultat de première classe

Une hypothèse mesurée puis réfutée, ou un scope capé consigné avec son calcul, valent un audit réussi : ils documentent où le temps ne se perd pas. Ne pas produire de finding de consolation, et ne pas relancer un harnais pour re-démontrer un plafond déjà consigné dont ni le code ni l'exposition n'ont changé.

## Mesures comparables

- Faire un warmup adapté aux caches, JIT, pools et connexions.
- Exécuter assez de répétitions pour observer la dispersion ; préférer médiane et percentiles aux meilleurs temps.
- Mesurer avant et après dans le même environnement et aussi près que possible dans le temps.
- Garder identiques données, concurrence, configuration, build mode et dépendances externes.
- Rapporter la variabilité ou un intervalle simple. Si la différence est du même ordre que la dispersion, conclure `inconclusif`.
- Éviter de mélanger temps de compilation/startup et steady-state sauf si le startup est précisément la métrique.
- Pour la scalabilité, mesurer plusieurs niveaux de charge ou tailles d'entrée et observer la courbe, la saturation et le backpressure ; un seul point ne démontre pas une propriété de scaling.

La baseline n'est pas un nombre nu. Format attendu : `<valeur> <unité>, <statistique>, <répétitions>, dispersion <valeur>, environnement/build court`.

## Axes et sévérité

Axes seed, non fermés :

| Axe | Exemples de métriques |
|---|---|
| Latence | médiane, p95/p99, startup, temps par opération |
| Throughput | requêtes/s, jobs/s, lignes/s, octets/s |
| CPU | temps CPU, cycles, samples, utilisation par unité de travail |
| Mémoire | RSS, heap, pic mémoire, allocations/opération, rétention |
| I/O | requêtes DB, lectures/écritures, octets, round-trips réseau |
| Contention | temps bloqué, lock wait, queue wait, saturation de pool |
| Scalabilité | pente coût/taille, débit sous concurrence, point de saturation |

Sévérité = **impact mesuré × exposition réelle** :

- **HIGH** — SLO ou capacité violé sur un chemin central/fréquent, saturation ou croissance non bornée menaçant le fonctionnement, régression majeure confirmée.
- **MED** — coût matériel et répété, marge de capacité sensiblement réduite ou feature perceptiblement lente, sans blocage immédiat.
- **LOW** — coût vérifié mais faible ou peu exposé. Ne pas conserver un LOW dont le gain potentiel est inférieur au bruit ou au coût de complexité.

Ne pas appliquer de seuil universel en millisecondes ou pourcentage. Une milliseconde dans une boucle appelée un million de fois et 100 ms dans une tâche mensuelle n'ont pas la même exposition.

## Quand ne pas produire de finding

Ne pas créer de finding lorsque :

- aucun workload représentatif et sûr n'est disponible ;
- la baseline n'est pas reproductible ;
- l'écart observé est absorbé par la variance ;
- le profiler ne relie pas le coût au code ciblé et aucune expérience ne confirme l'hypothèse ;
- le coût vient principalement d'un service externe hors scope et aucune action locale crédible n'existe ;
- la recommandation repose sur une intuition comme « les allocations sont lentes » sans impact mesuré ;
- l'optimisation proposée échange un gain marginal contre une forte dette de correction ou de maintenabilité ;
- le comportement est déjà dans le budget convenu et aucune contrainte de capacité ne justifie le travail.

Un audit sans finding peut être `clean` seulement si le workload a réellement été mesuré et respecte le budget ou ne montre aucun bottleneck actionnable. Sans mesure suffisante, utiliser `inconclusif`.

## Garde-fou de maintenabilité

Évaluer ce garde-fou lors de la recommandation, puis sur le diff du fix :

- préserver les contrats et tests de correction ;
- éviter duplication, état partagé, branches et indirections sans gain mesuré ;
- confiner toute spécialisation au hot path démontré ;
- nommer les concepts et documenter le **pourquoi performance** lorsque le code devient volontairement non évident ;
- conserver ou ajouter le benchmark qui rend le compromis vérifiable ;
- préférer la variante la plus simple lorsque les résultats sont équivalents dans la variance ;
- expliciter dans le finding toute dette acceptée et pourquoi le gain la justifie.

La propreté n'est pas un DRY mécanique. Dupliquer localement une petite boucle ou éviter une abstraction peut être légitime si cela supprime un coût matériel, mais seulement avec preuve, confinement et benchmark anti-régression.

## Choix des outils

Préférer dans cet ordre :

1. commandes de benchmark/load test déjà versionnées dans le projet ;
2. instrumentation et profiler natifs du langage ou runtime déjà disponibles ;
3. outils système présents (`hyperfine`, `/usr/bin/time`, `perf`, profilers de mémoire/I/O) ;
4. harness éphémère sous `/tmp` si le scénario reste représentatif et ne modifie pas le projet.

Détecter les outils opportunément et s'adapter au langage. Ne pas installer de dépendance ou contacter un service externe sans autorisation. Un outil absent dégrade la profondeur, jamais les exigences de preuve.

## Workloads client et navigateur

Le code exécuté dans un navigateur ou un client graphique s'audite avec la même doctrine ; seul le harness change. Un harness navigateur (Lighthouse, Playwright/Puppeteer avec tracing, profil devtools) est un outil comme un autre dans l'ordre de préférence ci-dessus et suit les mêmes règles d'installation et d'autorisation.

Les métriques web sont des instances des axes existants : LCP, INP, TTI et temps de frame relèvent de la latence ; poids de bundle et octets transférés de l'I/O ; temps de script, layout et paint du CPU. Un performance budget versionné (taille de bundle, seuils Lighthouse) compte comme budget existant.

Exigences spécifiques :

- exercer un build de production servi localement ; un déploiement distant reste soumis à la règle d'autorisation explicite ;
- fixer le throttling CPU/réseau, le mode headless/headed et la version du navigateur, et les persister dans la signature d'environnement ;
- choisir cache froid ou cache chaud comme condition de mesure et l'annoncer ; ne pas mélanger les deux dans une même série ;
- les runs navigateur sont particulièrement bruyants : répétitions, médiane/percentiles et dispersion s'appliquent strictement avant conclusion ;
- le poids de bundle se mesure sur la sortie du build de production, la commande de build servant de workload reproductible.

Sans harness disponible ni moyen sûr d'exercer le client, conclure `inconclusif`, comme pour tout autre workload.
