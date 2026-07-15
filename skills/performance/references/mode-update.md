# Mode : update

Référence chargée en mode **update**. Lire `references/doctrine.md` et `references/file-formats.md`. Re-mesurer les findings existants ; ne pas chercher de nouveaux bottlenecks.

## Préparer l'update

1. Lire tous les Pending de `performance_findings.md`.
2. Extraire pour chacun scope, workload, métrique, baseline, acceptation, environnement et dernière observation.
3. Construire un plan de commandes, coûts et dépendances. L'invocation autorise les workloads locaux courts déjà enregistrés ; demander confirmation avant toute charge longue, distante, facturable ou potentiellement destructive.
4. Si plusieurs findings partagent exactement workload et protocole, mesurer une fois et réutiliser la même observation avec attribution propre à chaque finding.

## Re-vérifier chaque finding

### 1. Scope

- Path présent : continuer.
- Path absent : rechercher rename ou déplacement via git et recherche de symboles.
  - signal unique/fort : proposer la relocalisation puis continuer si validée ;
  - coût clairement supprimé avec commit identifiable : continuer vers une re-mesure du workload avant toute résolution ;
  - signal ambigu : `Status: stale (date) — scope introuvable : <raison>`.

### 2. Workload

- Commande et fixtures disponibles : continuer.
- Commande renommée avec remplacement évident dans le même manifeste/historique : proposer l'amendement avant exécution.
- Dépendance locale temporairement indisponible : `blocked (date) — mesure sûre impossible sans <condition>`.
- Workload disparu ou non reproductible : `stale (date) — workload non reproductible : <raison>`.
- Ne jamais substituer silencieusement un autre workload : il changerait le sens de la baseline.

### 3. Comparabilité

Comparer build mode, taille d'entrée, concurrence, runtime/toolchain et environnement. Un drift mineur documenté peut rester comparable ; un drift susceptible d'expliquer l'écart impose une nouvelle série de référence. Dans ce dernier cas :

- écrire `Dernière observation (date)` comme nouvelle mesure non comparable ;
- laisser Pending ;
- proposer de rebaseliner explicitement plutôt que conclure résolu/régressé.

### 4. Mesure

1. Lancer le test de correction ciblé.
2. Rejouer warmup et protocole enregistrés.
3. Calculer la métrique et la dispersion avec la même méthode.
4. Comparer à baseline et acceptation :
   - acceptation satisfaite, environnement comparable, correction OK, écart au-delà du bruit → résoudre ;
   - bottleneck toujours présent → laisser Pending et ajouter `Dernière observation (date)` ;
   - résultat significativement pire → laisser Pending, ajouter l'observation et signaler la régression ;
   - variance empêche de conclure → laisser Pending et noter `inconclusif` dans la dernière observation.

Ne pas marquer résolu à partir d'un changement statique seul.

## Écritures de résolution

Pour chaque résolu :

1. Déplacer vers `## Resolved` au format compact.
2. Ajouter `(résolu YYYY-MM-DD)` au titre.
3. Renseigner mesure avant/après, gain, dispersion, tests et garde-fou maintenabilité dans `Validation`.
4. Identifier le commit responsable seulement sans ambiguïté ; sinon `Commit : non commité` ou `Commit : indéterminé` pour un changement externe.
5. Compléter la ligne history d'origine `(résolus <IDs>)` via date + scope.
6. Appliquer le cap Resolved = 8.

Recalculer ensuite le compteur `PERF` depuis findings + archive. Backfiller un `Commit : non commité` uniquement lorsqu'un commit correspondant est identifiable sans ambiguïté.

## Sortie

Utiliser `update:summary`. Signaler séparément résolus, toujours présents, régressés, non comparables, relocalisés, stale et blocked.

## Invariants de fin de mode

- Chaque Pending sûr et exécutable re-mesuré avec son workload enregistré.
- Toute commande non sûre ou coûteuse confirmée avant exécution.
- Aucun workload substitué silencieusement.
- Résolution fondée sur mesure comparable + correction OK.
- Dernières observations écrites en delta pour les findings maintenus.
- Résolus compactés, history complétée, cap appliqué.
- Compteur `PERF` recalculé.
- État partiel et commandes non exécutées annoncés.
