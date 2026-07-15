---
name: maintainability-cycle
argument-hint: "[<N>] [--no-doc-cleanup]"
description: "Orchestrate one or more autonomous, goal-backed maintainability cycles from audit or pending selection through mandatory GO/NO-GO double-checks, bounded fixes, validation, ledger updates, and one final scoped doc-cleanup pass. Use when the user asks for a complete maintainability cycle, several automatic cycles, autonomous technical-debt resolution, or wants to avoid repeating the audit/double-check/fix prompt. Supports subagents without provider- or model-specific names."
---

# Maintainability cycle

Orchestrer une campagne autonome au-dessus des skills `maintainability` et `doc-cleanup`. Ce skill ne redéfinit ni leur doctrine ni leurs formats : il charge leurs instructions, enchaîne leurs modes et conserve leurs invariants.

## Dépendances

Avant d'agir :

1. Charger le skill `maintainability` et les playbooks requis pour chaque opération atomique.
2. Charger `doc-cleanup` uniquement au moment de la clôture, sauf si `--no-doc-cleanup` est présent.
3. Si le runtime ne sait pas activer un skill par son nom, résoudre les skills frères `../maintainability/SKILL.md` et `../doc-cleanup/SKILL.md` depuis ce dossier.

Le skill atomique reste autoritatif sur la détection du root, les formats d'état, les dates, les tests, la cascade et les invariants. En cas de contradiction, le présent skill ne remplace que les gates interactives explicitement levées ci-dessous ; toutes les règles de sûreté restent applicables.

## Entrée

- `<N>` : nombre de cycles visé, entier strictement positif ; défaut `1`.
- `--no-doc-cleanup` : désactiver la clôture documentaire.
- Un argument inconnu ou un entier invalide exige une clarification. Ne pas deviner.

Accepter les formulations équivalentes indépendamment de la syntaxe du runtime, par exemple `/maintainability-cycle 3` avec Claude Code ou `$maintainability-cycle lance 3 cycles` avec Codex.

## Goal natif

L'invocation explicite de ce skill demande et autorise la création d'un **goal natif unique** couvrant toute la campagne : `<N>` cycles maximum, arrêt anticipé si plus aucun finding n'est actionnable, puis clôture doc-cleanup éventuelle.

- Si un goal actif couvre déjà la demande, le réutiliser ; ne pas imbriquer un second goal.
- Si le runtime expose un mécanisme de goal persistant, le créer avant le travail. Ne fixer un budget que si l'utilisateur en a fourni un.
- Si aucun mécanisme de goal n'est disponible, exécuter la même boucle dans le thread courant avec les mêmes conditions d'arrêt.
- Ne marquer le goal terminé qu'après les invariants de campagne et la clôture doc-cleanup demandée. Un audit clean ou l'absence de GO n'est pas un blocage.
- Sur un arrêt réellement bloquant, ne jamais marquer le goal terminé. Le laisser actif/en attente ou utiliser le statut bloqué selon la politique native du runtime ; ne pas inventer un statut ou contourner ses seuils.

## Autorisation autonome bornée

L'invocation vaut confirmation explicite en amont pour :

- choisir une zone d'audit ou une dimension crosscut ;
- sélectionner un batch cohérent de findings ;
- double-checker ce batch ;
- appliquer les fixes des verdicts GO dans le scope annoncé ;
- archiver un NO-GO selon le format atomique lorsqu'aucun scénario crédible de réévaluation ne subsiste ; sinon le laisser Pending avec son verdict persisté et ne pas le retraiter pendant la même campagne.

Les propositions et plans normalement interactifs de `maintainability` deviennent ici des annonces d'avancement, pas des gates. Continuer sans demander un nouveau « OK » tant que l'action reste dans ce périmètre.

Cette autorisation ne couvre jamais `git add`/`commit`/`push`, une opération destructive, un changement de production, un autre domaine d'audit, ni un élargissement matériel du scope. Demander une décision seulement lorsqu'une nouvelle autorité est réellement nécessaire, que le root/scope est ambigu ou qu'une validation échoue sans correction sûre.

## État initial de campagne

1. Résoudre le root via `maintainability` et lire le contexte durable du projet lorsqu'il existe (`AGENTS.md`, `CLAUDE.md`, état `.code-quality`, conventions de validation).
2. Si `<STATE_DIR>/maintainability_campaign.md` existe déjà : campagne interrompue. L'annoncer et reprendre son état (baseline, compteur de cycles, source et phase courantes, fichiers touchés, IDs non actionnables) si la demande courante la continue ; sinon demander avant de l'écraser. Ne jamais recapturer la baseline d'une campagne reprise.
3. Capturer `baseline_dirty_source_files` depuis `git status --porcelain=v1 -z` : fichiers source modifiés, staged ou untracked avant le premier cycle. Traiter ces fichiers comme protégés : choisir un autre batch plutôt que les éditer ; si un finding prioritaire exige un chevauchement impossible à contourner, demander une autorisation ciblée.
4. Initialiser l'état de campagne ; pour `<N> > 1`, le persister dans le fichier de campagne (cf. ci-dessous) :
   - source courante et phase du cycle en cours (`sélection`, `audit`, `double-check`, `fix` ou `clôture`) ;
   - `campaign_touched_source_files` : fichiers source réellement édités par les fixes, y compris propagations de rename ;
   - `campaign_double_checks` : map des IDs vers leur verdict et la preuve courante ;
   - `campaign_non_actionable_findings` : IDs `GO-mais-après-X` et `NO-GO` conservés Pending, à ne pas retraiter pendant cette campagne tant que leur situation reste inchangée.
5. Lire le board maintainability avant de choisir la première source.

### Fichier de campagne

`<STATE_DIR>/maintainability_campaign.md` (le `<STATE_DIR>` résolu par `maintainability`) persiste l'état d'orchestration qui n'existe nulle part ailleurs, pour survivre à une compaction de contexte ou une interruption de session. Requis pour `<N> > 1` ; pour un cycle unique, le créer seulement si le scope le justifie (batch large, nombreux double-checks) — la boucle courte sans sous-agents est peu exposée à la perte de contexte. Si un cycle unique sans fichier devient bloqué après une mutation, créer le fichier avant de rendre la main afin de préserver la reprise. Les verdicts détaillés et leurs preuves restent dans le ledger `maintainability` : ne pas les dupliquer ici. Format minimal :

```markdown
# Campagne maintainability-cycle
- Début : YYYY-MM-DD — cible : <N> cycles — terminés : <k>
- Courant : <zone, dimension ou batch d'IDs, ou « aucun »> — phase : <sélection|audit|double-check|fix|clôture>
- Baseline sale : <paths relatifs au root, ou « aucun »>
- Fichiers touchés : <paths relatifs au root, ou « aucun »>
- Non actionnables : <ID (verdict), …, ou « aucun »>
- Blocage : <cause précise, ou « aucun »>
```

Le mettre à jour aux frontières d'étape : `Courant` et `phase` à chaque changement de phase, compteur après chaque cycle terminé, fichiers touchés après chaque fix, non actionnables après chaque double-check, `Blocage` dès qu'une cause d'arrêt apparaît. Ce fichier d'état n'est pas un fichier source : il n'entre jamais dans `baseline_dirty_source_files` ni `campaign_touched_source_files` et reste hors du scope doc-cleanup. Le supprimer à la clôture normale de la campagne ; le conserver sur un arrêt bloquant comme artefact de diagnostic et de reprise.

### Reprise

À la reprise d'une campagne persistée :

1. Relire le ledger et comparer le tree courant à la baseline sale et aux fichiers touchés enregistrés. Traiter toute nouvelle modification extérieure à la campagne comme un WIP protégé.
2. Reprendre `Courant` et `phase` au lieu de sélectionner une nouvelle source. Reconstruire `campaign_double_checks` depuis le ledger, en revérifiant que code et blast radius n'ont pas changé avant toute réutilisation.
3. En phase `sélection`, `audit` ou `double-check`, rejouer proprement l'étape atomique inachevée.
4. En phase `fix` ou `clôture`, inspecter le diff conservé avant toute action. Continuer le même batch seulement si une correction et une validation sûres restent possibles dans le scope autorisé ; sinon conserver le blocage et demander une décision ciblée.
5. Ne jamais supprimer, stasher ou revert automatiquement le diff d'une tentative non validée, et ne jamais passer à une autre source tant que cette tentative n'est pas résolue.

## Définition d'un cycle

Un cycle traite **une source cohérente** : soit un batch de pendings, soit les findings d'un nouvel audit zonal/crosscut. Il est terminé quand la source sélectionnée a été auditée si nécessaire, double-checkée, résolue dans le batch GO retenu, validée et persistée. Une source clean ou un batch sans GO compte comme cycle traité ; il ne faut jamais inventer un fix pour remplir le quota.

### 1. Choisir la source

1. Prioriser un batch Pending actionnable et cohérent s'il existe : proximité de fichiers, même cause ou ordre de dépendance raisonnable.
2. Exclure les IDs dans `campaign_non_actionable_findings`, sauf si un fix du cycle courant satisfait leur prérequis ou invalide explicitement leur preuve. Un GO déjà double-checké mais laissé hors du fix reste éligible au cycle suivant.
3. Sans batch Pending actionnable, choisir en autonomie entre audit auto et crosscut selon l'historique, la couverture et les signaux du projet. Par défaut, prendre l'audit auto ; choisir crosscut seulement sur un signal transverse concret, ou lorsque les deux dernières nouvelles sources étaient zonales et que la couverture crosscut éligible est plus ancienne ou absente. À égalité, audit auto. Ne pas demander confirmation sur la sélection.
4. Borner le batch : un audit peut produire plus de findings que le cycle n'en absorbe. Double-checker tous les findings **du batch retenu**, pas nécessairement toute la sortie de l'audit ; laisser explicitement le surplus Pending pour un cycle suivant plutôt que produire un fix trop large.

### 2. Auditer si nécessaire

Exécuter intégralement le mode `audit` ou `crosscut` choisi, y compris doctrine, écritures delta, history et invariants. Pour une source déjà Pending, ne pas créer d'audit artificiel.

Un audit à zéro finding est un résultat réussi. Si aucun autre finding actionnable n'existe, arrêter la campagne après avoir compté ce cycle clean.

### 3. Double-check obligatoire

Avant toute édition de code :

1. Exécuter le playbook `maintainability double-check` sur **chaque** finding du batch qui ne possède pas déjà une preuve courante dans `campaign_double_checks`.
2. Produire un verdict actuel `GO`, `NO-GO` ou `GO-mais-après-X`, fondé sur le tree courant. Une preuve de la campagne peut être réutilisée seulement après avoir vérifié que son code et son blast radius n'ont pas changé ; sinon, refaire et repersister le double-check.
3. Persister chaque nouveau double-check selon le format atomique, puis enregistrer verdict et preuve dans `campaign_double_checks`.
4. Archiver selon le format atomique les `NO-GO` sans scénario crédible de réévaluation ; ajouter les `NO-GO` conservés et les `GO-mais-après-X` à `campaign_non_actionable_findings`. Garder les GO non fixés éligibles au cycle suivant avec leur preuve réutilisable.

Aucun fichier source ne doit être édité avant la fin de cette étape pour l'ensemble du batch retenu.

### 4. Fixer le batch GO

1. Choisir un sous-ensemble GO dont le scope et la validation restent cohérents ; laisser le reste Pending pour un prochain cycle.
2. Annoncer brièvement le plan et l'ordre, puis l'exécuter sans gate supplémentaire.
3. Sérialiser les mutations. Après chaque fix : validation proportionnée, résolution persistée, cap Resolved et cascade selon `maintainability`.
4. Ajouter les fichiers source réellement modifiés à `campaign_touched_source_files`. Ne pas y ajouter les seuls fichiers `.code-quality`.
5. Laisser les `GO-mais-après-X` et les `NO-GO` conservés Pending avec leur preuve ; ne pas les sélectionner à nouveau dans la même campagne.

### 5. Compter et continuer

Après les invariants du cycle, incrémenter le compteur. Continuer jusqu'au premier événement :

- `<N>` cycles terminés ;
- après double-check d'un nouvel audit/crosscut, aucun verdict GO immédiatement exécutable ne subsiste et aucun autre Pending candidat à un double-check ou à un fix ne reste ;
- validation ou autorité réellement bloquante.

Un board vidé par les fixes d'un cycle n'est pas à lui seul une condition d'arrêt : si la cible n'est pas atteinte, lancer un nouvel audit/crosscut pour alimenter le cycle suivant. En revanche, arrêter tôt plutôt que changer artificiellement de zone lorsqu'une nouvelle source auditée est clean ou ne produit que des verdicts non actionnables. Des findings laissés hors batch justifient naturellement le cycle suivant.

## Sous-agents et choix de modèle

Pour `<N> > 1`, utiliser des sous-agents quand le runtime les expose afin de préserver le contexte principal. Pour un seul cycle, les utiliser seulement si le scope le justifie.

- Déléguer les inventaires/audits candidats et les traces de double-check en **lecture seule** ; ils rendent des preuves localisées et compactes.
- Les analyses indépendantes peuvent être concurrentes. Les écritures du ledger et du code restent sérialisées.
- Un agent de fix peut éditer le code, mais un seul écrivain agit à la fois et l'orchestrateur vérifie son diff avant de persister la résolution.
- Ne jamais laisser deux agents muter simultanément le même worktree ou les fichiers `.code-quality`.

**Sélection du modèle : rester agnostique du runtime et du temps.** Ne nommer aucun fournisseur, famille, version ou niveau commercial et ne définir aucun sélecteur de modèle par défaut. Décrire seulement la capacité requise dans le briefing (raisonnement de code et blast radius pour audit/double-check ; édition précise et validation pour fix), puis laisser le runtime choisir ou hériter de son modèle. Si le runtime exige un sélecteur, utiliser son choix par défaut ou une classe de capacité native stable, jamais un nom mémorisé. L'absence de choix manuel de modèle n'est pas un blocage.

Chaque sous-agent reçoit le scope, le rôle, les contraintes de mutation, les chemins d'état utiles et le format de retour, mais pas la conclusion attendue. L'orchestrateur vérifie les preuves et reste responsable des écritures normatives.

## Politique anti testing-creep

- Utiliser d'abord les tests, checks, linters ou builds existants qui couvrent raisonnablement le changement.
- Un manque de coverage seul ne bloque pas un fix GO et ne justifie pas mécaniquement de nouveaux tests.
- Ajouter le minimum de tests seulement lorsqu'un comportement modifié ou un contrat non évident resterait autrement sans protection réaliste.
- Quand le scope contient déjà des tests redondants, préférer les comprimer ou les paramétrer si cela reste directement lié au finding ; ne pas lancer une campagne de tests hors scope.
- Distinguer clairement une validation dégradée d'un échec du fix.

## Clôture doc-cleanup multi-cycle

Sauf `--no-doc-cleanup`, exécuter **une seule** clôture après un arrêt normal de la boucle entière, jamais après chaque cycle. Si la campagne s'arrête sur un échec en laissant des edits source non validés, ne pas lancer de nettoyage agressif par-dessus : conserver le diff pour diagnostic, garder le fichier de campagne pour la reprise, signaler la clôture non exécutée et ne pas terminer le goal.

1. Calculer `cleanup_files = campaign_touched_source_files - baseline_dirty_source_files`.
2. Garder seulement les fichiers source existants encore modifiés à la fin. Cette union couvre tous les cycles, y compris les fichiers touchés par propagation de rename.
3. Si `cleanup_files` est vide, annoncer que la clôture est sans objet et ne pas forcer une passe.
4. Sinon, charger `doc-cleanup` et exécuter son mode `session --files <liste explicite>`. Ne jamais retomber silencieusement sur le scope global `git status`.
5. Pendant cette clôture orchestrée, ne pas effectuer un rename dont le blast radius sort de `cleanup_files`, y compris vers `baseline_dirty_source_files` ; garder ou dé-drifter un commentaire court à la place. Le scope final reste ainsi exact et aucun nouveau fichier n'est introduit après son calcul.
6. Laisser `doc-cleanup` appliquer sa doctrine, valider une fois le scope agrégé et écrire une seule ligne de couverture session.

Les fichiers sales avant la campagne restent exclus si l'utilisateur a exceptionnellement autorisé un fix qui les chevauche : préserver le WIP préexistant prime sur l'exhaustivité du nettoyage. Les lister dans le récap comme exclus de la clôture.

## Récap final et invariants

Après une clôture normale — doc-cleanup exécuté, déclaré sans objet ou désactivé par `--no-doc-cleanup` — supprimer `maintainability_campaign.md` s'il existe : un fichier de campagne restant signale toujours une campagne interrompue.

Rendre un récap compact contenant : cycles terminés/cible, sources choisies, IDs et verdicts, GO fixés, NO-GO archivés, validations, clôture doc-cleanup, fichiers exclus car déjà sales, findings actionnables restants et raison d'arrêt.

Avant de terminer, vérifier :

- aucun fix n'a précédé son double-check ;
- toutes les écritures atomiques et cascades attendues sont présentes ;
- un seul écrivain a muté le worktree à chaque instant ;
- aucun `git add`/`commit`/`push` n'a eu lieu ;
- doc-cleanup a tourné au plus une fois, sur la liste explicite agrégée, ou son absence est expliquée ;
- le fichier de campagne est supprimé après une clôture normale, ou conservé et signalé sur un arrêt bloquant ;
- le goal natif n'est terminé que si la campagne et sa clôture demandée sont réellement achevées.
