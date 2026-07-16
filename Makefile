# Local CLI for installing canonical skills into Claude Code and Codex.
#
# Usage:
#   make list
#   make install-claude [SKILL=foo]
#   make install-codex  [SKILL=foo]
#   make install-all    [SKILL=foo]
#   make install AGENT=claude|codex|all [SKILL=foo]
#   make diff-claude|diff-codex|diff-all [SKILL=foo]
#   make uninstall-claude|uninstall-codex|uninstall-all [SKILL=foo]
#   make validate

# Recipes run in POSIX sh: make deliberately ignores the environment's SHELL
# variable, so the interactive shell (bash, zsh, fish…) has no effect on them.
# Pinned here for deterministic behavior across make implementations. Recipes
# contain no bashisms.
SHELL := /bin/sh

CLAUDE_DIR         := $(HOME)/.claude
CODEX_DIR          := $(HOME)/.agents
SKILLS_SRC         := skills
CLAUDE_SKILLS_DEST := $(CLAUDE_DIR)/skills
CODEX_SKILLS_DEST  := $(CODEX_DIR)/skills

ALL_SKILLS := $(notdir $(wildcard $(SKILLS_SRC)/*))
SKILLS     := $(if $(SKILL),$(SKILL),$(ALL_SKILLS))
AGENT      ?= all

.PHONY: help list check-skill \
	install install-all install-claude install-codex \
	diff diff-all diff-claude diff-codex \
	uninstall uninstall-all uninstall-claude uninstall-codex \
	validate

help:
	@echo "Targets (install/diff/uninstall without a suffix: both agents; -claude/-codex to target one):"
	@echo "  make list                              Installation status by agent"
	@echo "  make install-claude [SKILL=x]          Install into ~/.claude"
	@echo "  make install-codex  [SKILL=x]          Install into ~/.agents"
	@echo "  make install-all    [SKILL=x]          Install into both agents"
	@echo "  make install AGENT=claude|codex|all    Generic variant"
	@echo "  make diff-<agent> [SKILL=x]             Compare repository and installation"
	@echo "  make uninstall-<agent> [SKILL=x]        Uninstall with confirmation"
	@echo "  make validate                           Validate structure and manifests"

list:
	@for s in $(ALL_SKILLS); do \
		if [ -d "$(CLAUDE_SKILLS_DEST)/$$s" ]; then claude="installed"; else claude="absent"; fi; \
		if [ -d "$(CODEX_SKILLS_DEST)/$$s" ]; then codex="installed"; else codex="absent"; fi; \
		printf "  %-20s claude: %-9s codex: %s\n" "$$s" "$$claude" "$$codex"; \
	done

check-skill:
	@for s in $(SKILLS); do \
		if [ ! -d "$(SKILLS_SRC)/$$s" ]; then \
			echo "Unknown skill: $$s (see 'make list')"; exit 1; \
		fi; \
	done

install: install-$(AGENT)

install-all: install-claude install-codex

install-claude: check-skill
	@mkdir -p "$(CLAUDE_SKILLS_DEST)"
	@for s in $(SKILLS); do \
		rsync -a --delete "$(SKILLS_SRC)/$$s/" "$(CLAUDE_SKILLS_DEST)/$$s/"; \
		echo "Installed for Claude: $$s"; \
	done

# Codex: the skill-creator validator accepts only name, description, allowed-tools,
# license, and metadata in frontmatter. The Claude-only `argument-hint` key
# (completion help) is therefore stripped from the installed copy—the Codex
# runtime tolerates the key, but the installation remains validator-compliant.
install-codex: check-skill
	@mkdir -p "$(CODEX_SKILLS_DEST)"
	@for s in $(SKILLS); do \
		rsync -a --delete "$(SKILLS_SRC)/$$s/" "$(CODEX_SKILLS_DEST)/$$s/"; \
		file="$(CODEX_SKILLS_DEST)/$$s/SKILL.md"; \
		grep -v '^argument-hint:' "$$file" > "$$file.tmp" && mv "$$file.tmp" "$$file"; \
		echo "Installed for Codex: $$s (frontmatter without argument-hint)"; \
	done

diff: diff-$(AGENT)

diff-all: diff-claude diff-codex

diff-claude: check-skill
	@for s in $(SKILLS); do \
		echo "=== $$s: skill (repository → ~/.claude) ==="; \
		if [ -d "$(CLAUDE_SKILLS_DEST)/$$s" ]; then \
			if diff -ru "$(SKILLS_SRC)/$$s" "$(CLAUDE_SKILLS_DEST)/$$s"; then echo "  identical."; fi; \
		else \
			echo "  not installed—run 'make install-claude SKILL=$$s'."; \
		fi; \
	done

diff-codex: check-skill
	@for s in $(SKILLS); do \
		echo "=== $$s: skill (repository → ~/.agents, argument-hint stripped on install) ==="; \
		if [ -d "$(CODEX_SKILLS_DEST)/$$s" ]; then \
			rc=0; diff -ru -x SKILL.md "$(SKILLS_SRC)/$$s" "$(CODEX_SKILLS_DEST)/$$s" || rc=1; \
			grep -v '^argument-hint:' "$(SKILLS_SRC)/$$s/SKILL.md" \
				| diff -u - "$(CODEX_SKILLS_DEST)/$$s/SKILL.md" || rc=1; \
			if [ "$$rc" = 0 ]; then echo "  identical (except stripped argument-hint)."; fi; \
		else \
			echo "  not installed—run 'make install-codex SKILL=$$s'."; \
		fi; \
	done

uninstall: uninstall-$(AGENT)

uninstall-all: check-skill
	@printf "Remove from ~/.claude and ~/.agents: $(SKILLS)? [y/N] "; \
	read ans; \
	if [ "$$ans" = "y" ] || [ "$$ans" = "Y" ]; then \
		for s in $(SKILLS); do \
			rm -rf "$(CLAUDE_SKILLS_DEST)/$$s" "$(CODEX_SKILLS_DEST)/$$s"; \
			echo "Uninstalled from both agents: $$s"; \
		done; \
	else \
		echo "Cancelled."; \
	fi

uninstall-claude: check-skill
	@printf "Remove from ~/.claude: $(SKILLS)? [y/N] "; \
	read ans; \
	if [ "$$ans" = "y" ] || [ "$$ans" = "Y" ]; then \
		for s in $(SKILLS); do \
			rm -rf "$(CLAUDE_SKILLS_DEST)/$$s"; \
			echo "Uninstalled from Claude: $$s"; \
		done; \
	else \
		echo "Cancelled."; \
	fi

uninstall-codex: check-skill
	@printf "Remove from ~/.agents: $(SKILLS)? [y/N] "; \
	read ans; \
	if [ "$$ans" = "y" ] || [ "$$ans" = "Y" ]; then \
		for s in $(SKILLS); do \
			rm -rf "$(CODEX_SKILLS_DEST)/$$s"; \
			echo "Uninstalled from Codex: $$s"; \
		done; \
	else \
		echo "Cancelled."; \
	fi

# Frontmatter keys allowed in the canonical source: the Claude/Codex intersection
# plus `argument-hint` (Claude-only, stripped by install-codex—see target comment).
# Any other key would break one of the two ecosystems.
FRONTMATTER_KEYS := name description argument-hint allowed-tools license metadata

validate: check-skill
	@for s in $(ALL_SKILLS); do \
		file="$(SKILLS_SRC)/$$s/SKILL.md"; \
		test -f "$$file" || { echo "Missing SKILL.md: $$s"; exit 1; }; \
		test "$$(sed -n '1p' "$$file")" = "---" || { echo "Invalid frontmatter: $$s"; exit 1; }; \
		grep -Fqx "name: $$s" "$$file" || { echo "Invalid name: $$s"; exit 1; }; \
		grep -Eq '^description: .+' "$$file" || { echo "Missing description: $$s"; exit 1; }; \
		for k in $$(awk '/^---$$/{n++; next} n==1 && /^[A-Za-z][A-Za-z-]*:/{sub(/:.*/,""); print}' "$$file"); do \
			case " $(FRONTMATTER_KEYS) " in \
				*" $$k "*) ;; \
				*) echo "Non-portable frontmatter key in $$s/SKILL.md: $$k (allowed: $(FRONTMATTER_KEYS))"; exit 1 ;; \
			esac; \
		done; \
		test -f "$(SKILLS_SRC)/$$s/agents/openai.yaml" || { echo "Missing agents/openai.yaml: $$s"; exit 1; }; \
		for src in "$$file" $$(ls "$(SKILLS_SRC)/$$s/references/"*.md 2>/dev/null); do \
			for ref in $$(grep -Eo 'references/[a-z0-9-]+\.md' "$$src" | sort -u); do \
				test -f "$(SKILLS_SRC)/$$s/$$ref" || { echo "Missing reference: $$s/$$ref (cited by $$src)"; exit 1; }; \
			done; \
		done; \
		for agent_dir in .claude .agents; do \
			link="$$agent_dir/skills/$$s"; \
			test -L "$$link" || { echo "Missing symlink: $$link"; exit 1; }; \
			test -f "$$link/SKILL.md" || { echo "Broken symlink: $$link"; exit 1; }; \
			test "$$(readlink "$$link")" = "../../skills/$$s" || { echo "Unexpected target: $$link"; exit 1; }; \
		done; \
	done
	@python3 -m json.tool .claude-plugin/plugin.json >/dev/null
	@python3 -m json.tool .codex-plugin/plugin.json >/dev/null
	@if command -v ruby >/dev/null 2>&1; then \
		ruby -ryaml -e 'ARGV.each { |f| text = File.read(f); if f.end_with?("/SKILL.md"); match = text.match(/\A---\n(.*?)\n---/m); raise "frontmatter missing: #{f}" unless match; text = match[1]; end; YAML.parse_stream(text) }' \
			$(addsuffix /SKILL.md,$(addprefix $(SKILLS_SRC)/,$(ALL_SKILLS))) \
			$(addsuffix /agents/openai.yaml,$(addprefix $(SKILLS_SRC)/,$(ALL_SKILLS))); \
	else \
		echo "Ruby absent: full YAML parsing skipped (structural checks completed)."; \
	fi
	@if command -v claude >/dev/null 2>&1; then \
		claude plugin validate . >/dev/null && echo "claude plugin validate : OK"; \
	else \
		echo "claude CLI absent: skipped 'claude plugin validate .'."; \
	fi
	@echo "Local validation OK: $(words $(ALL_SKILLS)) skills, Claude/Codex views, and JSON manifests."
