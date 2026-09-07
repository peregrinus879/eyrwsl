---
name: omasync
description: Sync EyrWSL against Omarchy references and official WSL and Windows Terminal docs. Covers all packages owned by EyrWSL.
---

# Omasync

Source configs from reference repos and official docs, compare against EyrWSL, and apply changes only where they belong in this repo.

## Sources

Local reference clones live under `~/Projects/quarry/`; `references.txt` names this repo's needs and the family union defines the maintained set. `make refs` creates missing entries only from this repo's manifest, updates existing family-listed clones to exact fetched-upstream parity, and reports but preserves unlisted clones:

- `omarchy/` - main repo for bash, tmux, starship, git, fastfetch, btop, and editorconfig references; `make refs` keeps it on the upstream default branch, which upstream moves between releases, so pin EyrWSL release comparisons to tag `v4.0.0` (`git show v4.0.0:<path>`)
- `omarchy-pkgs/` - package builds, including the Omarchy Neovim package
- `gruvbox.nvim/` - Gruvbox Neovim plugin source selected by Omarchy
- `yazi/` - Yazi reference repo for configuration and feature changes
- `obsidian.nvim/` - obsidian.nvim upstream for the vault plugin spec
- `terminal/` - Windows Terminal reference repo for settings structure and feature changes

Upstream URLs, official docs, and descriptions live in `DEVIATIONS.md` (Reference Sources). Unresolved decisions, deferred work, and dated evidence live in `docs/maintenance.md`.

## When To Use

- Use this skill when Omarchy or a reference repo changed materially, including after an Omarchy release.
- Use this skill when repo scope or behavior changed materially.
- Use this skill when you suspect undocumented drift between this repo and its references.
- Use this skill before broad sync-oriented doc updates.

## Workflow

1. Before reference mutation, run `bash scripts/update-references.sh --dry-run` and review its scope. The preview can query GitHub through `gh api`, but does not fetch or prove upstream parity or absence of incoming conflicts. Obtain H's explicit approval for each new clone or remote repointing, and for any separately proposed destructive resolution; routine preservation-safe refreshes of existing declared clones remain the skill's work within shared authorization. Then run `make refs`. Atomic, non-forced fetches preserve existing local tags and annotations, import new tags, and prune only origin tracking branches; this is not a transaction across clones. Checkout/merge use `--no-overwrite-ignore` to preserve ignored files. Ahead/divergent branches and tag/file conflicts refuse that update; do not force or delete to obtain a pass. Unlisted clones are reported and kept. Resolve failed updates before comparing, without assuming earlier successful updates rolled back. If an approved origin move occurs, align its URL in `references.txt` and `DEVIATIONS.md`. Manifest changes define maintenance scope, not permission to create, repoint or delete unreviewed targets. Then confirm Omarchy tag `v4.0.0` resolves (`git rev-parse v4.0.0^{commit}`); retain the pinned release comparison.
2. Compare reference repos against the packages owned by EyrWSL
3. For Omarchy-derived packages, compare against tag `v4.0.0` in `omarchy/`, plus `omarchy-pkgs/` and `gruvbox.nvim/`; never substitute moving-branch contents for the pinned release comparison
4. For non-Omarchy tools, compare Yazi against `yazi/` and official docs, and the vault plugin specs against `obsidian.nvim/` and the render-markdown.nvim README
5. Check the WSL and Windows contract against official WSL, Arch-on-WSL, and Windows Terminal docs: WSL2 with active interop (enabled `binfmt_misc` and `WSLInterop` or `WSLInterop-late`, plus the bounded no-profile PowerShell probe), `clip.exe`/`powershell.exe` resolution, Windows-side font ownership, and `windows-terminal/settings.json` against `terminal/`; run `make wt-diff` when Terminal settings are involved. Neovim's clipboard provider needs PowerShell, not `clip.exe`; both commands remain host-gate requirements
6. Check package ownership at maintenance time: confirm `pacman -Si mise` still reports an official repository and `mise ls claude codex opencode` lists each tool, compare the `mise/.local/bin` wrappers against the heredoc in `git show v4.0.0:bin/omarchy-mise-install` and the tool list in `install/user/mise.sh`, accounting for the documented v4.0.2 `--quiet` adoption and omitted `MISE_MINIMUM_RELEASE_AGE=0` export without silently moving the comparison pin. Re-probe `pacman -Si herdr` before retaining its canonical installer, and keep Yazi media helpers explicitly optional
7. For each difference, classify it:
   - **Intentional deviation**: documented in `DEVIATIONS.md`, should stay different
   - **New upstream addition**: added upstream after the last sync, should be reviewed for inclusion
   - **Upstream change to existing config**: modified upstream, needs review
8. Check `git log --format="%h %ad %s" --date=short -- <file>` on the relevant reference repo when you need to determine when a difference was introduced
9. Cross-check differences against `DEVIATIONS.md`. If a difference is not documented there, treat it as a likely upstream change that needs review
10. Apply new upstream additions and changes where they belong in this repo
11. Update `README.md`, `AGENTS.md`, `DEVIATIONS.md`, and `docs/maintenance.md` when ownership, setup, workflow, or durable maintenance findings change
12. Summarize which changes were adopted, rejected, or intentionally kept different

## Completion Checks

- `README.md`, `AGENTS.md`, and `DEVIATIONS.md` reflect any ownership, setup, or workflow changes
- `make refs` passed in this run; Omarchy release comparisons still use tag `v4.0.0`
- Every retained difference is still documented in `DEVIATIONS.md`
- For twin changes, `make twins` checks local worktrees; after both commits exist, `twins-pair` checks the exact full `SELF_COMMIT`/`PEER_COMMIT` pair at `SIBLING`. Inputs remain literal data and peer code never executes. Hosted final-pair evidence must name the final published commits; earlier-peer CI is not a substitute or publication authorization
- Official-package probes and WSL/Windows gates reflect current sources, and `make wt-diff` is clean when Terminal settings are involved
- The final summary distinguishes adopted changes, rejected changes, and intentional retained differences

## Rules

- Present proposed changes to the user before editing; a deliberate exception to shared guidance, because a sync pass touches many files on judgment calls and each adopted upstream change is a deviation decision
- Omarchy, official docs, official package docs, and `DEVIATIONS.md` are the source of truth for default behavior and intentional differences
- Always check all relevant sources, not just one
- Never assume a difference is intentional without verifying it is documented in `DEVIATIONS.md`
- Fetch changeable upstream and package facts at maintenance time instead of caching versions in this skill
- Keep Windows Terminal and btop on Omarchy's semantic Gruvbox palette, Neovim on Omarchy's `gruvbox.nvim` selection, and ANSI-aware applications on terminal inheritance
- Keep shared AI agent harness and OpenCode TUI configuration in EyrAgents; this repo carries no custom OpenCode theme
- System packages, `mise` included, come from official Arch repos; Claude Code, Codex, and OpenCode install and update through mise via the stowed wrappers, which keep mise's release cooldown, with paranoid mode on through the stowed `conf.d` fragment; Herdr uses its canonical installer only while an official package is unavailable. No AUR packages or AUR helper.
- Keep Windows-specific behavior explicit. Anything that depends on `clip.exe`, `powershell.exe`, or Windows Terminal should be documented as a Windows interop concern.
