# Templates de sortie chat

Lire avant chaque sortie d'un mode. Respecter la structure ; adapter uniquement les placeholders. Les modes qui écrivent terminent par `Files mis à jour`, contrairement à `list`.

## `selection:proposition`

```text
Je propose : <scope> — <motif>
Workload : <commande/scénario sanitised>
Métrique : <métrique primaire>
Alternatives : <scope-alt-1> — <motif>, <scope-alt-2> — <motif>
```

Ajouter `Information requise : <manque>` si aucun workload représentatif n'est disponible. Attendre validation.

## `audit:summary`

```text
Audit performance terminé — <scope>

Workload : <résumé>
Baseline : <métrique + valeur + dispersion + environnement court>

<N> nouveaux findings (<X> HIGH, <Y> MED, <Z> LOW) :
  <ID> (<SEV>, <axe>) — <observation courte> — <preuve courte>

Files mis à jour : <STATE_DIR>/performance_findings.md (+<N>), <STATE_DIR>/performance_history.md (+1 ligne).
```

Suivre avec `audit:proposition`.

## `audit:clean`

```text
Audit performance terminé — <scope>. Mesure valide, aucun bottleneck actionnable sur ce workload.

Workload : <résumé>
Résultat : <métrique + valeur + dispersion> [budget : <budget respecté>]

Files mis à jour : <STATE_DIR>/performance_history.md (+1 ligne `0 findings (clean)`).
```

## `audit:inconclusive`

```text
Audit performance inconclusif — <scope>

Cause : <workload absent | variance instable | attribution insuffisante | environnement non sûr | autre>
Pour conclure : <information ou condition précise>

Files mis à jour : <STATE_DIR>/performance_history.md (+1 ligne `0 findings (inconclusive: <raison>)`).
```

Ne jamais appeler ce résultat `clean`.

## `audit:proposition`

```text
Prochaine étape proposée : double-check <ID-prioritaire> — <raison : sévérité, exposition ou preuve à confirmer>.
Sinon : double-check un autre ID ou garder les findings pending.
```

## `list:dashboard`

```text
Performance board — <projet>

Pending actionnables (<total>) :
  HIGH (<n>) : <ID> (<scope>, <métrique/baseline>, <observation courte>)
  MED  (<n>) : ...
  LOW  (<n>) : ...

Stale / blocked (<n>) :
  <ID> — <status et cause>

Recently resolved (30 derniers jours) :
  <ID> (<SEV>) — <date> — <gain avant/après>

Rolling (N=<N>) :
  <date> — <scope> — <résultat>

Prochaine étape : <double-check ID | update | nouvel audit> — <raison>.
```

Omettre `Stale / blocked` si vide. Si zéro résolu, écrire `Aucun résolu dans les 30 derniers jours.` Si zéro pending, l'indiquer sans lignes de sévérité.

## `update:summary`

```text
Update performance terminé — <projet>

Re-mesuré <N>/<total> pendings :
  Résolus (<n>) : <IDs avec avant → après>
  Toujours présents (<n>) : <IDs>
  Régressés (<n>) : <IDs avec mesure>
  Non comparables (<n>) : <IDs avec cause>
  Relocalisés (<n>) : <ID old → new>
  Stale (<n>) : <IDs>
  Blocked (<n>) : <IDs>

Files mis à jour : <liste exacte des fichiers d'état modifiés>.
```

Omettre les catégories à zéro. Si certains workloads n'ont pas été lancés, préciser lesquels et pourquoi.

## `double-check:output`

```text
Double-check <ID> — <verdict>

Reproduction : <baseline initiale → mesure actuelle, dispersion, comparabilité>
Attribution : <profil/expérience>
Blast radius : <call sites, tests, surfaces>
Risques : <correction, mémoire/I-O/concurrence, maintenabilité>
Effort : <S|M|L>
Acceptation affinée : <critère>
Plan affiné : <recommandation>
Verdict : <GO|GO-mais-après-X|NO-GO|INCONCLUSIF>

Files mis à jour : <STATE_DIR>/performance_findings.md (Double-check ajouté[, sévérité/localisation amendée]).
```

## `double-check:proposition`

GO / GO-mais-après-X :

```text
Que faire pour <ID> ?
  (a) Fix maintenant — plan, OK explicite, tests, benchmark avant/après et garde-fou maintenabilité.
  (b) Plus tard — le Double-check reste dans le board.
```

NO-GO :

```text
Verdict NO-GO. Archiver <ID> avec le motif, ou le garder pending ?
```

INCONCLUSIF :

```text
Pas de fix proposé : il manque <condition>. <ID> reste pending.
```

## `resolution:confirm`

```text
<ID> satisfait l'acceptation : <avant> → <après> (<gain>, dispersion <valeur>), tests OK, garde-fou maintenabilité OK. Je marque comme résolu ?
```

## `resolution:done`

```text
Résolution performance terminée — <ID> : <avant> → <après> (<gain>).

Files mis à jour : <STATE_DIR>/performance_findings.md (move <ID> → Resolved), <STATE_DIR>/performance_history.md (résolu <ID>)[, <STATE_DIR>/performance_resolved_archive.md].
```

## `resolution:failed`

```text
Fix non validé — <ID> reste pending.

Cause : <tests KO | gain absent | résultat dans la variance | dette de maintenabilité injustifiée>
Mesure : <avant> → <après, dispersion>
Fichiers modifiés : <liste des fichiers touchés par le fix>
Diff conservé dans l'arbre de travail pour review ; aucun statut de résolution écrit.
Pour le mettre de côté : `git stash push -- <fichiers>` (non exécuté).
```
