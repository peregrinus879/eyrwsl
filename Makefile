# Maintenance automation for EyrWSL. Stow, restow, clean, verify, and wt-push
# run from the repo root on the WSL machine; lint, check, twins, and refs run
# anywhere, including CI. The package list here is the single source of truth
# for the stow command sets, scripts/verify.sh, and scripts/prepare-stow.sh.
# Stow runs without directory folding so every managed parent under $HOME stays
# a real directory and only leaf files are links.

SHELL := /bin/bash
PACKAGES := bash btop editorconfig fastfetch git mise nvim starship tmux yazi
STOW := stow --no-folding -t ~

# Twin files are byte-identical with EyrArcHy and synced manually. When the
# sibling clone is present, twins fails on drift; otherwise it reports a
# skipped check. Paths are repo-relative and identical in both repos.
SIBLING ?= $(HOME)/Projects/eyrie/eyrarchy
TWIN_SPECS := nvim/.config/nvim/lua/plugins/obsidian.lua \
  nvim/.config/nvim/lua/plugins/render-markdown.lua \
  bash/.config/bash/functions/tdw \
  bash/.config/bash/functions/hdw \
  yazi/.config/yazi/yazi.toml \
  scripts/update-references.sh \
  tests/update-references.sh \
  tests/tdw.sh

.PHONY: help require-host require-clone stow unstow dry-run restow lint check twins verify test clean refs wt-diff wt-push

# Deployment goals and their guards must never race, including `make -j clean restow`.
.NOTPARALLEL:

help:
	@echo "Targets:"
	@echo "  stow      Stow all packages into ~"
	@echo "  unstow    Remove all package symlinks"
	@echo "  dry-run   Preview stow actions without making changes"
	@echo "  restow    Re-stow after repo content changes (WSL host, deployed clone only)"
	@echo "  lint      ShellCheck over the bash and mise packages, scripts/, and tests/ (.shellcheckrc holds the disable list)"
	@echo "  check     Repository-only checks: every owned config in repo mode, then the tests/ fixtures (runs in CI)"
	@echo "  twins     Twin-file sync against the EyrArcHy clone at SIBLING (skipped when absent)"
	@echo "  verify    lint, check, and twins, then the WSL host, command baseline, mise tools, deployment, identity, and config checks"
	@echo "  test      Run the fixture suites in fake homes"
	@echo "  clean     Guarded stow preparation: leftover folds and dangling clone links only (scripts/prepare-stow.sh)"
	@echo "  refs      Clone, fast-forward, and prune the reference clones under ~/Projects/quarry to the family's references.txt files"
	@echo "  wt-diff   Diff tracked Windows Terminal settings against the deployed file"
	@echo "  wt-push   Back up changed settings and deploy the tracked Windows Terminal file"

# Host-bound targets refuse elsewhere, and a managed endpoint that is a link
# must resolve into this clone so a reference clone never redeploys the
# packages from itself.
require-host:
	@bash scripts/prepare-stow.sh --require-host

require-clone: require-host
	@EYRWSL_PACKAGES='$(PACKAGES)' bash scripts/prepare-stow.sh --require-clone

stow: require-clone
	$(STOW) -v $(PACKAGES)

unstow: require-clone
	$(STOW) -D -v $(PACKAGES)

dry-run:
	$(STOW) -n -v $(PACKAGES)

restow: require-clone
	$(STOW) -R -v $(PACKAGES)

lint:
	shellcheck -s bash bash/.bashrc bash/.config/bash/envs bash/.config/bash/shell \
	  bash/.config/bash/aliases bash/.config/bash/init bash/.config/bash/functions/* \
	  mise/.local/bin/* scripts/*.sh tests/*.sh
	@echo "ok:   shellcheck clean"

# Repository-only checks: every owned config validates in repo mode, then the
# fixture suites run in fake homes. Needs no WSL host or stowed links.
check:
	@VERIFY_MODE=repo VERIFY_PACKAGES='$(PACKAGES)' bash scripts/verify.sh
	@$(MAKE) --no-print-directory test
	@echo "ok:   check"

twins:
	@command -v cmp > /dev/null || { echo "FAIL: required verifier 'cmp' is missing"; exit 1; }
	@if [[ ! -d "$(SIBLING)" ]]; then \
	  echo "note: EyrArcHy clone not found at $(SIBLING), skipped twin checks"; exit 0; \
	fi; \
	fail=0; \
	for f in $(TWIN_SPECS); do \
	  twin="$(SIBLING)/$$f"; \
	  if [[ ! -e "$$twin" ]]; then echo "FAIL: twin missing in EyrArcHy: $$f"; fail=1; \
	  elif cmp -s "$$f" "$$twin"; then echo "ok:   $$f matches the EyrArcHy twin"; \
	  else echo "FAIL: $$f drifted from the EyrArcHy twin"; fail=1; fi; \
	done; \
	exit $$fail

verify: require-host lint check twins
	@VERIFY_MODE=full VERIFY_REPO='$(CURDIR)' VERIFY_HOME='$(HOME)' \
	  VERIFY_PACKAGES='$(PACKAGES)' bash scripts/verify.sh
	@echo "ok:   verify"

test:
	@set -e; for test in tests/*.sh; do EYRWSL_PACKAGES='$(PACKAGES)' bash "$$test"; done

clean: require-clone
	@EYRWSL_PACKAGES='$(PACKAGES)' bash scripts/prepare-stow.sh

# omasync step 1. Clones what references.txt lists and the quarry lacks,
# repoints moved GitHub remotes, fast-forwards each listed clone, and removes
# unlisted clean clones; anything it cannot settle fails the run.
refs:
	@bash scripts/update-references.sh

wt-diff:
	scripts/wt-diff.sh

wt-push: require-clone
	scripts/wt-diff.sh --push
