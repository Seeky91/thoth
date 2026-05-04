# Claude Skills

Une collection de skills réutilisables pour Claude Code.

## Skills disponibles

### 🛠 maintainability

Audit de maintenabilité ciblé avec :

* suivi des findings via des IDs stables
* état persistant par projet (`.claude/`)
* rotation automatique des zones auditées (rolling coverage)
* re-vérification et approfondissement des problèmes

Permet de détecter et suivre la dette de maintenabilité dans le temps sans repasser toujours sur les mêmes zones.

---

## Installation

Depuis la racine de ce dépôt, copier les fichiers dans votre dossier Claude :

```bash
mkdir -p ~/.claude/skills/maintainability ~/.claude/commands

cp .claude/skills/maintainability/SKILL.md ~/.claude/skills/maintainability/
cp .claude/commands/maintainability.md ~/.claude/commands/
````

---

## Utilisation

Le skill `maintainability` expose une commande principale :

```bash
/maintainability [arguments]
```

### Commandes disponibles

#### 🔍 Audit automatique

```bash
/maintainability
```

* Sélectionne automatiquement une zone à auditer
* Propose des alternatives
* Lance l’audit après validation

---

#### 📁 Audit d’un scope précis

```bash
/maintainability <path>
```

* Audite directement le dossier ou fichier spécifié

---

#### 📊 Afficher le tableau de bord

```bash
/maintainability list
```

* Liste les findings en cours
* Affiche les résolus récents
* Montre le rolling actuel

---

#### 🔄 Mettre à jour les findings

```bash
/maintainability update
```

* Re-vérifie tous les findings `pending`
* Marque ceux qui sont résolus
* Détecte les fichiers déplacés (`stale`)

---

#### 🔎 Approfondir un finding

```bash
/maintainability double-check <ID>
```

* Analyse en profondeur un finding existant
* Évalue le blast radius
* Affine la recommandation et l’effort
* Donne un verdict (GO / NO-GO)

---

## Fichiers générés

Le skill maintient automatiquement plusieurs fichiers dans votre projet :

* `.claude/maintainability_history.md` — historique des audits
* `.claude/maintainability_findings.md` — liste des problèmes détectés (pending + resolved récents)
* `.claude/maintainability_resolved_archive.md` — archive des anciens findings résolus (au-delà de la limite de rétention)

---

## Objectif

Ce skill ne cherche pas à produire un audit ponctuel, mais à :

* couvrir progressivement tout le code
* prioriser les vrais problèmes
* suivre leur résolution dans le temps

---

## Licence

MIT
