# Mode : list

Référence chargée en mode **list**. Lecture seule stricte : ne pas mesurer, ne pas re-profiler et ne rien écrire.

## Flux

1. Lire `performance_findings.md` et `performance_history.md` s'ils existent.
2. Compter les Pending par sévérité et résumer pour chacun : ID, axe, scope, métrique/baseline et observation courte.
3. Lister séparément les `stale` et `blocked`, tout en les gardant dans le total Pending.
4. Lister les résolutions des 30 derniers jours depuis la section `## Resolved`. Ne pas charger l'archive ; si les 8 entrées du cap sont toutes dans la fenêtre, signaler que la vue peut être tronquée.
5. Afficher le rolling des N dernières scopes auditées (`N=4`, ou override `<!-- rolling_size: N -->`) ; les lignes `skipped` n'y comptent pas. Mentionner sur une ligne les scopes `skipped (exposure-capped)` présents dans l'history, avec leur calcul.
6. Recommander au plus un prochain geste :
   - finding HIGH/MED sans Double-check, baseline la plus récente d'abord → `double-check <ID>` ;
   - sinon finding GO déjà double-checké → reprendre son fix ;
   - sinon stale/blocked → `update` ou rétablir le workload manquant ;
   - zéro pending → nouvel audit.

Utiliser `list:dashboard` dans `references/templates.md`.

## Projet sans état

Ne pas bootstrapper. Annoncer : `Aucun audit de performance sur ce projet. Invoque performance en audit auto, path ou feature pour commencer.`

## Invariants de fin de mode

- Aucun fichier projet ou état modifié.
- Aucune commande de benchmark/profiling exécutée.
- Stale/blocked distingués des pendings actionnables.
- Recommandation fondée uniquement sur l'état lu, sans nouvelle conclusion technique.
