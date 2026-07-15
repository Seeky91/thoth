---
name: performance
argument-hint: "[<path> | feature <description> | list | update | double-check <PERF-ID>]"
description: "Measure, audit, track, deep-check, and resolve software performance bottlenecks with reproducible workloads and before/after evidence. Use for targeted paths or product features, automatic performance audits, latency/throughput/CPU/memory/I/O/contention/scalability investigations, performance regression triage, persistent PERF findings, board/update workflows, and measured optimization fixes. Excludes speculative optimization, unrelated correctness or security audits, accessibility, and stack selection."
---

# Performance skill

## Frontière

Mesurer, diagnostiquer, suivre et résoudre les problèmes de performance sans transformer des intuitions statiques en conclusions. **Le skill mesure d'abord** : aucun finding persistant sans workload explicite, baseline chiffrée et preuve localisée. Il ne modifie pas le code audité pendant l'audit ou le double-check ; un fix n'arrive qu'après verdict et confirmation explicite, puis doit être validé par tests et mesure avant/après comparable.

Inclure la latence, le throughput, CPU, mémoire/allocations, I/O, contention/concurrence et scalabilité sous charge mesurée. Exclure les audits généraux de maintenabilité, sécurité, accessibilité et choix de stack ; vérifier la correction et la maintenabilité comme garde-fous du changement, sans en faire des axes d'audit autonomes.

**Exception d'orchestration :** une invocation explicite du skill `performance-cycle` vaut confirmation bornée en amont pour sélectionner un workload local sûr et non ambigu, double-checker un finding, appliquer le fix d'un verdict GO, persister sa résolution si toutes les preuves avant/après sont satisfaites et archiver un verdict NO-GO sans scénario crédible de réévaluation. Dans ce cadre seulement, les propositions de sélection, de fix, de résolution et d'archivage deviennent des annonces d'avancement ; les limites de charge externe, de comparabilité, de validation et de Git restent inchangées.

## Références

Ce `SKILL.md` est un **routeur mince**. Lire les références requises par le mode courant, sans charger les autres :

- `references/doctrine.md` — contrat de workload, hiérarchie de preuve, fiabilité des mesures, axes, sévérité, anti-bruit et garde-fou de maintenabilité. **Lire avant tout audit, double-check, update ou fix.**
- `references/mode-audit.md` — bootstrap, inventaire et sélection automatique, audit ciblé par path ou feature, mesure, profiling et production des findings.
- `references/mode-list.md` — tableau de bord lecture seule.
- `references/mode-update.md` — re-mesure des pendings et gestion des workloads ou scopes devenus stales.
- `references/mode-double-check.md` — reproduction approfondie, blast radius, verdict et résolution mesurée.
- `references/file-formats.md` — formats normatifs des trois fichiers d'état et cycle de vie d'un finding.
- `references/templates.md` — formats normatifs des sorties chat. **Lire avant chaque sortie d'un mode.**

## Dispatch des modes

Déduire le mode de l'intention utilisateur, indépendamment de la syntaxe propre à l'agent :

| Intention | Mode | Playbook | Entrée |
|---|---|---|---|
| Afficher le tableau de bord | **list** | `references/mode-list.md` | Aucune |
| Re-mesurer les pendings | **update** | `references/mode-update.md` | Aucune |
| Approfondir un finding | **double-check** | `references/mode-double-check.md` | ID `PERF-NNN` |
| Auditer un chemin | **audit path** | `references/mode-audit.md` | Path existant |
| Auditer une feature | **audit feature** | `references/mode-audit.md` | `feature <description>` ou description fonctionnelle non ambiguë |
| Chercher automatiquement la cible la plus pertinente | **audit auto** | `references/mode-audit.md` | Aucune |

Accepter les formulations compatibles `/performance`, `/performance list`, `/performance update`, `/performance double-check PERF-001`, `/performance src/api` et `/performance feature checkout`. Avec Codex, utiliser le texte qui accompagne `$performance` pour choisir le même mode.

Règles de parsing :

1. Un argument qui résout vers un path existant déclenche `audit path`.
2. Le préfixe `feature` déclenche `audit feature` avec le reste du texte.
3. Un texte libre décrivant clairement un comportement produit déclenche `audit feature`.
4. Une demande de fix direct (`fix PERF-001`, « corrige PERF-001 ») route vers `double-check` sur cet ID : il n'existe volontairement pas de mode fix autonome, la re-baseline et le verdict précèdent toute modification.
5. Un argument ressemblant à un path mais inexistant, un ID invalide ou un flag inconnu exige une clarification ; ne pas réinterpréter silencieusement.
6. Sans précision, choisir `audit auto`.

## Détection du root projet

Avant tout dispatch, confirmer le root à partir de `.git/`, `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `composer.json`, `Gemfile`, `pom.xml`, `build.gradle`, `.hg/` ou `.svn/`.

- Marqueur dans le `cwd` : continuer.
- Marqueur dans un parent : annoncer le root détecté et demander de relancer depuis ce root ou de confirmer l'opération ici.
- Aucun marqueur : arrêter et demander de lancer depuis un projet.
- Path explicite : rattacher l'état au root le plus proche de ce path.

## Répertoire d'état

`<STATE_DIR>` = `<PROJECT_ROOT>/.code-quality`, partagé entre Claude Code et Codex. Le créer seulement dans un mode qui écrit. Les noms non qualifiés désignent toujours :

- `<STATE_DIR>/performance_history.md`
- `<STATE_DIR>/performance_findings.md`
- `<STATE_DIR>/performance_resolved_archive.md`

Le mode `list` ne crée rien.

## Conventions transverses

1. **Date déterministe.** Obtenir chaque date écrite ou comparée avec `date +%F`. Si la commande est indisponible, le signaler au lieu d'inventer.
2. **Écritures en delta.** Lire l'état tôt, le relire juste avant écriture, puis insérer ou déplacer uniquement les blocs ciblés. Ne jamais régénérer un fichier entier de mémoire.
3. **Git sans historique.** Lire librement `git log/diff/show/blame/status`. Éditer l'arbre seulement pendant un fix confirmé. Ne jamais exécuter `git add`, `commit` ou `push`.
4. **Audit source en lecture seule.** L'audit et le double-check peuvent produire des artefacts de build/profiling ou des scripts éphémères sous `/tmp`, mais ne modifient ni le code source ni les benchmarks versionnés.
5. **Pas de charge externe implicite.** Ne jamais lancer de load test contre la production, un service distant, des données réelles ou une opération facturable sans autorisation explicite. Préférer le plus petit workload local représentatif.
6. **Comparabilité avant conclusion.** Comparer uniquement des mesures obtenues avec même workload, configuration, mode de build, taille d'entrée et environnement suffisamment stable. Sinon conclure `inconclusif`.
7. **État sans secrets.** Sanitiser les commandes et workloads persistés : aucun token, secret, header d'authentification, payload personnel ou valeur d'environnement sensible.

## Doctrine d'évaluation

Lire `references/doctrine.md` avant toute décision. Invariants essentiels :

- Un signal statique ou un profiler hit est un candidat, jamais un finding à lui seul.
- Un finding exige une baseline reproductible, une métrique, une exposition et une preuve reliant le coût à une localisation ou relation concrète.
- Un gain inférieur au bruit de mesure n'est pas un gain.
- Une optimisation qui dégrade inutilement correction ou maintenabilité est rejetée ou reformulée.
- Une spécialisation moins abstraite peut être acceptée si son gain est matériel, mesuré, localisé et documenté.

## Sorties chat

Lire `references/templates.md` avant chaque sortie. Les modes qui écrivent terminent par `Files mis à jour : ...`; `list` reste strictement read-only. Séparer le récapitulatif de toute proposition d'action.

## Invariants de fin de mode

Lire et cocher la checklist en fin du playbook courant. Une case non applicable est considérée cochée. Si une mesure, un test ou une écriture attendue n'a pas pu être réalisé, annoncer l'état partiel et sa cause ; ne jamais présenter un résultat incomplet comme validé.
