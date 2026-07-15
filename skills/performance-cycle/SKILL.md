---
name: performance-cycle
argument-hint: "[<N>]"
description: "Orchestrate one or more autonomous, goal-backed performance cycles from safe workload selection or pending PERF findings through mandatory re-measurement, double-check, one attributable optimization, tests, comparable before/after validation, and ledger resolution. Use when the user asks for a complete performance optimization cycle, several automatic measured cycles, autonomous bottleneck resolution, or wants to avoid repeating the audit/double-check/fix/measure prompt. Supports subagents while serializing all measurements and mutations."
---

# Performance cycle

Orchestrer une campagne autonome au-dessus du skill `performance`. Ne redéfinir ni sa doctrine de mesure ni ses formats : charger ses instructions, enchaîner ses modes et préserver tous ses invariants de preuve.

## Dépendance

Avant d'agir :

1. Charger le skill `performance` et les références requises pour chaque opération atomique.
2. Si le runtime ne sait pas activer un skill par son nom, résoudre le skill frère `../performance/SKILL.md` depuis ce dossier.

Le skill atomique reste autoritatif sur le root, les workloads, la comparabilité, les formats d'état, les tests, les dates et les critères de résolution. En cas de contradiction, le présent skill ne remplace que les gates interactives explicitement levées ci-dessous ; toutes les exigences de preuve et de sûreté restent applicables.

## Entrée

- `<N>` : nombre de cycles visé, entier strictement positif ; défaut `1`.
- Un argument inconnu ou un entier invalide exige une clarification. Ne pas deviner.

Accepter les formulations équivalentes indépendamment du runtime, par exemple `/performance-cycle 3` avec Claude Code ou `$performance-cycle lance 3 cycles` avec Codex.

## Goal natif

L'invocation explicite demande et autorise un **goal natif unique** couvrant au maximum `<N>` cycles, avec arrêt anticipé si aucun finding mesurable et actionnable ne subsiste.

- Réutiliser un goal actif qui couvre déjà la demande ; ne pas en imbriquer un second.
- Créer le goal avant le travail si le runtime expose ce mécanisme. Ne fixer un budget que si l'utilisateur en fournit un.
- Sans goal persistant, exécuter la même boucle dans le thread courant.
- Ne terminer le goal qu'après validation, écritures d'état et invariants de campagne. Un audit mesuré clean ou l'absence de GO n'est pas un blocage.
- Sur un arrêt réellement bloquant, laisser le goal actif ou appliquer la politique native du runtime ; ne jamais le déclarer terminé artificiellement.

## Autorisation autonome bornée

L'invocation vaut confirmation en amont pour :

- sélectionner une cible et un workload **local, sûr, court et non ambigu** selon le classement de `performance` ;
- exécuter l'audit, choisir un finding Pending, le double-checker et rejouer sa baseline ;
- appliquer un fix borné après verdict `GO` ;
- persister directement la résolution lorsque tests, acceptation, gain hors variance et garde-fou de maintenabilité sont tous satisfaits ;
- archiver un `NO-GO` — hypothèse réfutée, coût non actionnable ou compromis injustifié — sans scénario crédible de réévaluation.

Dans ce cadre seulement, les propositions de sélection, de fix et de résolution du skill atomique deviennent des annonces d'avancement. Continuer sans demander de nouvel accord tant que l'action reste dans ce périmètre.

Cette autorisation ne couvre jamais :

- un workload de production, distant, facturable, destructif, fondé sur des données réelles ou susceptible de générer une charge externe ;
- une commande anormalement longue ou lourde, l'installation d'une dépendance, un changement de configuration système ou une exigence métier/SLO inventée ;
- `git add`, `commit`, `push`, une opération destructive ou un autre domaine d'audit ;
- un scope ou workload ambigu dont le choix pourrait changer la conclusion.

Demander une autorisation ciblée dans ces cas, ou lorsqu'un fix exige de chevaucher un WIP protégé.

## État initial de campagne

1. Résoudre le root via `performance` et lire le contexte durable du projet (`AGENTS.md`, `CLAUDE.md`, état `.code-quality`, commandes de benchmark et conventions de validation).
2. Si `<STATE_DIR>/performance_campaign.md` existe : annoncer une campagne interrompue et reprendre son état si la demande courante la continue ; sinon demander avant de l'écraser. Ne jamais recapturer sa baseline sale.
3. Capturer `baseline_dirty_source_files` depuis `git status --porcelain=v1 -z`. Protéger ces fichiers : choisir un autre finding ou demander une autorisation ciblée avant tout chevauchement.
4. Lire le board et l'historique performance avant la première sélection.
5. Suivre en mémoire : compteur, scope ou ID courant, phase, `campaign_touched_source_files` (fichiers source réellement édités par les fixes) et IDs non actionnables pendant la campagne.

### Fichier de campagne

`<STATE_DIR>/performance_campaign.md` persiste uniquement l'état d'orchestration absent du ledger.

- Pour `<N> > 1`, le créer au démarrage.
- Pour un cycle unique, le créer seulement si le scope le justifie : workload long, nombreux artefacts ou phases, usage de sous-agents, ou risque concret d'interruption. La boucle courte normale n'en crée pas.
- Si un cycle unique sans fichier devient bloqué après une mutation, créer le fichier avant de rendre la main afin de préserver la reprise.
- Ne pas dupliquer les workloads, baselines, double-checks ou preuves déjà stockés dans `performance_findings.md`.
- Ce fichier d'état n'est pas un fichier source : il n'entre jamais dans `baseline_dirty_source_files` ni dans `campaign_touched_source_files`.

Format minimal :

```markdown
# Campagne performance-cycle
- Début : YYYY-MM-DD — cible : <N> cycles — terminés : <k>
- Courant : <scope ou PERF-NNN, ou « aucun »> — phase : <sélection|audit|double-check|fix|validation>
- Baseline sale : <paths relatifs au root, ou « aucun »>
- Fichiers touchés : <paths relatifs au root, ou « aucun »>
- Non actionnables : <ID (verdict), …, ou « aucun »>
- Blocage : <cause précise, ou « aucun »>
```

Mettre ce fichier à jour aux frontières de phase, après chaque mutation et après chaque cycle. Le supprimer à la clôture normale ; le conserver sur un arrêt bloquant.

### Reprise

À la reprise d'une campagne persistée :

1. Relire le ledger et comparer le tree courant à la baseline sale et aux fichiers touchés enregistrés. Traiter toute nouvelle modification extérieure à la campagne comme un WIP protégé.
2. Reprendre `Courant` et `phase` au lieu de sélectionner un nouvel ID. Ne réutiliser aucune preuve dont le code, le workload ou l'environnement pertinent a changé.
3. En phase `sélection`, `audit` ou `double-check`, rejouer proprement la phase atomique inachevée.
4. En phase `fix` ou `validation`, inspecter le diff conservé et les dernières mesures avant toute action. Continuer le même ID seulement si une correction et une validation sûres restent possibles dans le scope autorisé ; sinon conserver le blocage et demander une décision ciblée.
5. Ne jamais supprimer, stasher ou revert automatiquement le diff d'une tentative non validée, et ne jamais passer à un autre finding tant que cette tentative n'est pas résolue.

## Définition d'un cycle

Un cycle traite **une hypothèse de performance attribuable** : un finding Pending existant, ou un finding sélectionné après un nouvel audit. Il ne fixe qu'un seul `PERF-NNN`, même si l'audit en produit plusieurs, afin de préserver l'attribution du gain.

Le cycle est terminé lorsque le finding a été double-checké puis résolu, archivé `NO-GO` ou déclaré non actionnable pour la campagne. Un audit mesuré clean ou inconclusif sans finding compte comme source traitée, puis provoque un arrêt anticipé plutôt que la recherche artificielle d'un fix. Un fix non validé ne termine pas le cycle.

### 1. Choisir la source

1. Prioriser un Pending actionnable dont le workload enregistré est sûr et reproductible.
2. À preuve comparable, classer par sévérité, exposition, fraîcheur de la mesure, scope alphabétique, puis ID croissant. Ne pas inventer une fréquence de production.
3. Exclure les IDs `GO-mais-après-X` ou `INCONCLUSIF` déjà rencontrés pendant la campagne tant que leur condition n'a pas changé. Réévaluer un prérequis devenu satisfait avant de rendre l'ID actionnable.
4. Réutiliser un double-check `GO` seulement après avoir vérifié que code, workload, environnement pertinent et blast radius n'ont pas changé.
5. Sans Pending actionnable, exécuter `performance audit auto`. Retenir automatiquement la cible principale du classement atomique si son workload est local, sûr, court et non ambigu ; annoncer le plan de mesure sans gate.
6. Si l'audit produit plusieurs findings, sélectionner un seul ID pour ce cycle et laisser les autres Pending. S'il est clean ou inconclusif, compter la source traitée puis arrêter tôt.

### 2. Double-checker

Exécuter intégralement `performance double-check <ID>` avant toute édition source : reproduire la baseline, re-profiler, vérifier la comparabilité, le blast radius, les risques et l'acceptation affinée, puis persister le verdict.

- `GO` : poursuivre vers le fix.
- `GO-mais-après-X` : garder Pending, ajouter aux non actionnables et ne pas fixer avant satisfaction puis nouveau contrôle du prérequis.
- `INCONCLUSIF` : garder Pending, ajouter aux non actionnables et ne proposer aucun fix.
- `NO-GO` : archiver selon le format atomique, quel qu'en soit le motif ; ne garder Pending qu'en présence d'un scénario crédible de réévaluation, en l'ajoutant alors aux non actionnables.

### 3. Fixer et mesurer

1. Annoncer un plan court : fichiers, mécanisme, tests, benchmark et risque de maintenabilité.
2. Recapturer si nécessaire une mesure `avant` immédiate avec le protocole enregistré.
3. Implémenter le plus petit changement crédible sans toucher l'index ni l'historique git.
4. Ajouter les fichiers source réellement modifiés à `campaign_touched_source_files` ; ne pas inclure les seuls fichiers `.code-quality` ou artefacts de build.
5. Lancer les tests ciblés puis les checks projet proportionnés. Ajouter seulement le test ou benchmark minimal nécessaire pour protéger un contrat modifié ou un compromis de performance non évident.
6. Rejouer exactement le benchmark comparable, calculer gain et dispersion, puis contrôler le diff avec le garde-fou de maintenabilité.
7. Si toutes les conditions atomiques sont satisfaites, déplacer directement l'ID vers Resolved, compléter history, appliquer le cap et annoncer la résolution sans confirmation supplémentaire.
8. Si les tests échouent, si le gain est absent ou dans la variance, si la mesure devient non comparable ou si la dette est injustifiée : laisser l'ID Pending, conserver le diff sans revert automatique, créer ou garder le fichier de campagne avec la cause dans `Blocage`, puis arrêter la campagne pour review.
9. Ne jamais auto-résoudre les findings voisins. Signaler ceux qui partagent le workload ou les paths comme candidats à une re-mesure ultérieure.

### 4. Compter et continuer

Après les invariants d'un cycle terminé, incrémenter le compteur. Continuer jusqu'au premier événement :

- `<N>` cycles terminés ;
- une nouvelle source auditée est `clean`, `inconclusif` ou ne laisse aucun finding immédiatement actionnable ;
- aucun Pending actionnable ne subsiste et aucun nouveau workload sûr ne peut être sélectionné ;
- une validation ou une autorité devient réellement bloquante.

Un board vidé par un fix ne suffit pas à arrêter une campagne multi-cycle : lancer un nouvel audit si la cible n'est pas atteinte. Ne jamais inventer un workload, un finding ou une optimisation pour remplir le quota.

## Mesures, sous-agents et mutations

Préserver l'intégrité expérimentale avant la vitesse d'exécution.

- Sérialiser tous les benchmarks, profils, builds et autres travaux CPU, mémoire ou I/O susceptibles de perturber une mesure. Ne jamais comparer des runs obtenus pendant une activité concurrente contrôlable.
- Pour `<N> > 1`, utiliser des sous-agents lorsque le runtime les expose pour les inventaires, call sites, blast radius et revues de diff en lecture seule. Pour un cycle unique, les utiliser seulement si le scope le justifie.
- Suspendre ou attendre tous les sous-agents avant chaque warmup, baseline, profil et mesure après fix. Aucun sous-agent ne lance son propre workload de performance.
- Sérialiser les écritures du ledger et du code. Un seul écrivain agit à la fois, et l'orchestrateur vérifie ses preuves et son diff.
- Rester agnostique du fournisseur et du modèle : décrire la capacité requise, puis laisser le runtime choisir son défaut stable.

## Clôture

Ne pas lancer `doc-cleanup` automatiquement. Un hot path peut nécessiter un commentaire expliquant un compromis volontairement non évident ; le garde-fou de maintenabilité de `performance` reste la clôture documentaire adaptée.

Après un arrêt normal, supprimer `performance_campaign.md` s'il existe. Rendre un récap compact : cycles terminés/cible, scopes mesurés, IDs et verdicts, avant/après, validations, fichiers protégés ou touchés, findings actionnables restants et raison d'arrêt.

Avant de terminer, vérifier :

- aucune modification source n'a précédé le double-check `GO` ;
- chaque résolution repose sur des mesures comparables, un gain hors variance, des tests OK et le garde-fou de maintenabilité ;
- un seul finding a été fixé par cycle et aucun voisin n'a été auto-résolu ;
- aucune mesure potentiellement concurrente n'a tourné ;
- aucun `git add`, `commit`, `push`, workload externe ou opération destructive n'a été exécuté sans autorisation ;
- le fichier de campagne est absent après une clôture normale, ou conservé et signalé sur un arrêt bloquant ;
- le goal natif n'est terminé que si la campagne est réellement achevée.
