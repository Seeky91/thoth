# Sync du skill `maintainability` (et ses slash commands) du repo vers ~/.claude.
#
# Usage :
#   make install   # sync repo → ~/.claude (alias : make sync)
#   make diff      # voir ce qui diffère entre repo et ~/.claude
#   make uninstall # supprime le skill + ses commands de ~/.claude

CLAUDE_DIR     := $(HOME)/.claude
SKILL_NAME     := maintainability
SKILL_SRC      := .claude/skills/$(SKILL_NAME)
SKILL_DEST     := $(CLAUDE_DIR)/skills/$(SKILL_NAME)
COMMANDS_SRC   := .claude/commands
COMMANDS_DEST  := $(CLAUDE_DIR)/commands

.PHONY: help install sync diff uninstall

help:
	@echo "Targets :"
	@echo "  make install    Sync skill + commands du repo vers ~/.claude (alias : sync)"
	@echo "  make diff       Affiche ce qui diffère entre le repo et ~/.claude"
	@echo "  make uninstall  Retire le skill + ses commands de ~/.claude (demande confirmation)"

install: sync

sync:
	@mkdir -p $(SKILL_DEST) $(COMMANDS_DEST)
	@# Skill : --delete pour garantir que ~/.claude reflète exactement le repo
	@# (le dossier skill est "owned" par ce repo).
	@rsync -a --delete $(SKILL_SRC)/ $(SKILL_DEST)/
	@# Commands : le dossier commands est partagé entre skills, donc pas de --delete
	@# global. On purge d'abord les SEULS wrappers de ce skill (même glob scopé que
	@# uninstall) pour qu'un wrapper renommé/retiré ne laisse pas de commande fantôme,
	@# puis on resync — miroir exact sans toucher les commands des autres skills.
	@rm -f $(COMMANDS_DEST)/maintainability*.md
	@rsync -a $(COMMANDS_SRC)/maintainability*.md $(COMMANDS_DEST)/
	@echo "Sync OK :"
	@echo "  $(SKILL_DEST)/{SKILL.md, references/*}"
	@echo "  $(COMMANDS_DEST)/maintainability*.md"

diff:
	@echo "=== Skill (repo → ~/.claude) ==="
	@if [ -d $(SKILL_DEST) ]; then \
		diff -rq $(SKILL_SRC) $(SKILL_DEST) || true; \
	else \
		echo "  $(SKILL_DEST) absent — lance 'make install'."; \
	fi
	@echo ""
	@echo "=== Commands (repo → ~/.claude) ==="
	@for cmd in $(COMMANDS_SRC)/maintainability*.md; do \
		name=$$(basename $$cmd); \
		dest=$(COMMANDS_DEST)/$$name; \
		if [ ! -f "$$dest" ]; then \
			echo "  $$name : absent de ~/.claude"; \
		elif cmp -s "$$cmd" "$$dest"; then \
			echo "  $$name : à jour"; \
		else \
			diff -u "$$cmd" "$$dest" || true; \
		fi; \
	done

uninstall:
	@printf "Supprimer $(SKILL_DEST) et $(COMMANDS_DEST)/maintainability*.md ? [y/N] "; \
	read ans; \
	if [ "$$ans" = "y" ] || [ "$$ans" = "Y" ]; then \
		rm -rf $(SKILL_DEST); \
		rm -f $(COMMANDS_DEST)/maintainability*.md; \
		echo "Désinstallé."; \
	else \
		echo "Annulé."; \
	fi
