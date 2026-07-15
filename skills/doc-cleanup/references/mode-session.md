# Mode : session (fichiers touchés)

Playbook chargé par SKILL.md en mode **session**, avec l'option éventuelle `--touched` ou `--files <path>...`. Nettoie les fichiers modifiés pendant la session courante, ou une liste explicite fournie par un orchestrateur. Charger `references/doctrine.md` avant d'exécuter. Conventions transverses : cf. SKILL.md.

## A. Sélection des fichiers

### Sélection par défaut

Signal déterministe = les fichiers **changés vs `HEAD`** dans la session (non encore commités), **staged ou non** :

1. `git status --porcelain` → fichiers **modifiés**, **staged** et **non suivis** (untracked). C'est la source **autoritative** : elle voit l'index, contrairement à `git diff` seul (qui rate les changements staged-only).
2. Filtrer sur les fichiers **source** (exclure générés/vendored, non-code, lockfiles, `.md`/`.json`/`.toml`).
3. Set `fichiers_session` = le résultat.

**Fichiers staged / index** : si l'index n'est pas vide, l'**annoncer**. Le skill **ne modifie jamais l'index** (cf. git read-only) : éditer un fichier déjà staged ajoute des changements non-staged par-dessus (état mixte index/worktree — attendu et normal, l'utilisateur re-stagera à sa main). Les fichiers staged sont **inclus** dans le scope session : ils font partie du travail de la session.

**Cas limites** :
- **Aucun changement** (arbre propre) → `session:none` : *"Aucun fichier modifié dans l'arbre de travail. Si ton travail de session est déjà commité, invoque `doc-cleanup` en mode zone avec un chemin explicite."* Et terminer.
- **Repo non-git** → pas de signal de session fiable : l'annoncer et suggérer le mode zone avec un chemin explicite.
- Beaucoup de fichiers (≳ 8) ou très gros → **fan-out** sérialisé si les sous-agents sont disponibles et autorisés, sinon **main-loop segmentée** ; voir `references/orchestration.md`. Pour un petit scope, rester en main-loop.

### Sélection explicite (`--files`)

`--files <path>...` remplace entièrement la sélection par `git status`. Ce mode sert notamment à clore une campagne multi-cycle sans absorber le WIP préexistant :

1. Exiger au moins un path. Résoudre chaque path relativement au root projet, normaliser et dédupliquer en conservant l'ordre.
2. Refuser tout path hors du root. Un path inexistant ou un dossier est invalide : demander une clarification plutôt que l'étendre implicitement.
3. Filtrer sur les fichiers source avec les mêmes exclusions que le mode par défaut.
4. Vérifier que chaque fichier retenu est encore modifié dans le worktree ; ignorer un fichier revenu identique à `HEAD` et l'annoncer.
5. Set `fichiers_session` = cette liste filtrée. Ne jamais y ajouter d'autres fichiers depuis `git status`.

`--files` et `--touched` sont incompatibles : refuser la combinaison. Si aucun fichier ne reste après filtrage, utiliser `session:none` avec une formulation adaptée à la liste explicite et ne pas écrire de couverture.

## B. Scope : fichier entier vs hunks

- **Défaut et `--files`** : nettoyer le **fichier entier** de chaque fichier touché. Justification : un commentaire inutile 5 lignes au-dessus d'une ligne modifiée reste inutile, et un rename est non-local par nature. Le fichier touché est la *sélection* ; le fichier entier est l'*unité de travail*.
- **`--touched`** : restreindre aux **hunks modifiés**, récupérés via `git diff HEAD` (inclut staged **et** non-staged ; **pas** `git diff` seul qui rate les hunks staged). Opt-in étroit. **Fichiers non suivis (untracked)** : `git diff HEAD` ne produit **aucun hunk** pour eux (pas de version de base à differ) — il n'y a rien à restreindre, donc un fichier untracked est traité **en entier** même sous `--touched`, en l'annonçant dans la sortie (le flag ne l'a pas borné, c'est attendu : un fichier neuf est intégralement « touché »). **Avertir** que ce scope est partiel : un rename dont des références sortent des hunks doit quand même propager dans tout le projet (la doctrine de rename prime sur la restriction de scope), et du bruit hors-hunk sera laissé.

## C. Exécution

Appliquer la doctrine (cf. `references/doctrine.md`) sur le scope retenu : SUPPRIMER le bruit, RENOMMER pour supprimer (grep des références dans tout le projet avant chaque rename), GARDER + dé-drifter. En `--touched`, ne pas sortir des hunks **sauf** pour propager un rename.

## D. Validation + sortie

1. **Valider** une fois tous les fichiers traités (cf. `references/orchestration.md > Validation`). KO → reporter, arbitrage utilisateur.
2. **Ligne de couverture** (delta, en tête de `<STATE_DIR>/doccleanup_coverage.md`) : mode `session`, scope = `session (<N> files)`, `session --touched (<N> files)` ou `session --files (<N> files)`. Cf. `references/file-formats.md`.
3. **Sortie** via `session:summary` : fichiers traités, commentaires supprimés, renames, docs dé-driftées, validation, rappel non commité.

## Invariants de fin de mode

- Ligne de couverture écrite (mode `session`).
- Validation lancée et reportée (ou dégradation annoncée).
- Renames listés ; en `--touched`, avertissement de scope partiel émis ; en `--files`, aucun fichier hors liste nettoyé de manière opportuniste (seuls les sites de propagation d'un rename déclaré peuvent être modifiés hors liste).
- Aucun `git add`/`commit`.
- Aucun fichier touché → `session:none`, pas de nettoyage forcé.
