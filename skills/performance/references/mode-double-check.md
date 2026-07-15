# Mode : double-check

Référence chargée avec un ID `PERF-NNN`. Lire `references/doctrine.md`, `references/file-formats.md` et le fichier source ciblé intégralement. Approfondir un finding existant sans produire de nouveau finding.

## Flux d'analyse

1. Localiser l'entrée dans `## Pending`. ID absent, résolu ou invalide : demander un ID pending valide.
2. Rejouer le workload et protocole enregistrés aussi près que possible de la baseline.
3. Vérifier la comparabilité et la variance. Si la baseline ne se reproduit pas au-delà de la dispersion attendue, chercher la cause avant toute recommandation.
4. Lire tous les paths du scope, les call sites, tests et frontières I/O impliqués.
5. Re-profiler le workload et confirmer que le coût attribué reste dominant.
6. Tester l'hypothèse sans modifier le projet si possible : option runtime, expérience contrôlée, requête isolée ou harness sous `/tmp`. Une modification source appartient au flux de fix après confirmation.
7. Évaluer :
   - reproductibilité de la baseline ;
   - attribution du coût et alternatives plausibles ;
   - blast radius fonctionnel et surfaces publiques ;
   - risque concurrence/mémoire/I/O déplacé ailleurs ;
   - effort `S` (≤2h), `M` (≤1j), `L` (>1j) ;
   - garde-fou de maintenabilité ;
   - protocole avant/après et acceptation affinée.
8. Produire un verdict :
   - `GO` : preuve stable, fix borné, validation crédible ;
   - `GO-mais-après-X` : dépendance préalable explicite ;
   - `NO-GO` : hypothèse réfutée, coût non actionnable ou compromis injustifié ;
   - `INCONCLUSIF` : mesure ou attribution insuffisante.
9. Proposer une reclassification de sévérité si l'impact/exposition mesuré a changé. Conserver l'ID.

## Écriture du Double-check

Ajouter après `Status` une bullet unique :

```markdown
- **Double-check (YYYY-MM-DD) :** reproduction <valeurs> ; comparabilité <état> ; profil <preuve> ; blast radius <résumé> ; risques <résumé> ; effort <S|M|L> ; acceptation affinée <critère> ; verdict <...> ; plan affiné <...>.
```

Amender localisation, workload, acceptation ou sévérité uniquement avec justification dans cette bullet. Utiliser `double-check:output`, puis la proposition adaptée de `double-check:proposition`.

## Action selon le choix utilisateur

### Fix maintenant — GO ou GO-mais-après-X

1. Présenter un plan court : fichiers, ordre, mécanisme attendu, tests, benchmark et risque de maintenabilité.
2. Attendre un OK explicite avant toute modification source.
3. Re-capturer si nécessaire une mesure `avant` immédiate avec le protocole enregistré.
4. Implémenter le plus petit changement crédible sans toucher l'index ou l'historique git.
5. Lancer tests ciblés puis suite/lint appropriés.
6. Rejouer exactement le benchmark comparable et calculer gain + dispersion.
7. Inspecter le diff avec `references/doctrine.md > Garde-fou de maintenabilité`.
8. Issues :
   - tests OK + acceptation satisfaite + gain au-delà du bruit + garde-fou OK → utiliser `resolution:confirm` ; après confirmation, déplacer au format Resolved compact, compléter history et appliquer le cap ;
   - tests KO, gain absent/inconclusif ou dette injustifiée → ne pas marquer résolu, utiliser `resolution:failed`, conserver le diff pour review sans revert automatique, lister les fichiers touchés et proposer `git stash push -- <fichiers>` sans l'exécuter.
9. Repérer les autres pendings partageant le workload ou les paths et recommander `update`. Ne pas les résoudre sans re-mesure.

### NO-GO

Proposer :

- archiver au format Resolved compact avec `Resolution : archivé après double-check (NO-GO : <raison>)`, `Validation : N/A — hypothèse réfutée ou compromis injustifié` ;
- ou garder Pending si une re-évaluation future est crédible.

### INCONCLUSIF

Garder Pending. Expliquer la mesure, donnée ou condition qui manque ; ne pas proposer de fix.

## Invariants de fin de mode

- Baseline rejouée ou impossibilité explicitement documentée.
- Attribution re-vérifiée avec profil ou expérience.
- Section Double-check écrite en delta.
- Verdict cohérent avec la qualité de preuve.
- Aucun code modifié avant OK explicite.
- Après fix : tests + benchmark comparable + garde-fou maintenabilité exécutés.
- Finding résolu seulement après validation complète et confirmation.
- Findings voisins jamais auto-résolus sans mesure.
