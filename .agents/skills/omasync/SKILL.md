---
name: omasync
description: Sync EyrWSL against Omarchy references and official WSL and Windows Terminal docs. Covers all packages owned by EyrWSL.
---

# Omasync

Source configs from reference repos and official docs, compare against EyrWSL, and apply changes only where they belong in this repo.

## Sources

Local reference clones live under `~/Projects/quarry/`; `references.txt` names this repo's needs and the family union defines the maintained set. `make refs` creates missing entries only from this repo's manifest, updates existing family-listed clones to exact fetched-upstream parity, and reports but preserves unlisted clones:

- `omarchy/` - main repo for bash, native Herdr conventions, starship, git, fastfetch, btop, and editorconfig references, not a source to import desktop launch recipes; `make refs` keeps it on the upstream default branch, which upstream moves between releases, so pin EyrWSL release comparisons to tag `v4.0.0` (`git show v4.0.0:<path>`)
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
- Review the affected workspace guide sections after a binding/command change or a relevant application/plugin update, including inherited defaults that changed without an owned keymap-file diff.
- Use this skill before broad sync-oriented doc updates.

## Workflow

1. Before reference mutation, run `bash scripts/update-references.sh --dry-run` and review its scope. The preview can query GitHub through `gh api`, but does not fetch or prove upstream parity or absence of incoming conflicts. Obtain H's explicit approval for each new clone or remote repointing, and for any separately proposed destructive resolution; routine preservation-safe refreshes of existing declared clones remain the skill's work within shared authorization. Then run `make refs`. Atomic, non-forced fetches preserve existing local tags and annotations, import new tags, and prune only origin tracking branches; this is not a transaction across clones. Checkout/merge use `--no-overwrite-ignore` to preserve ignored files. Ahead/divergent branches and tag/file conflicts refuse that update; do not force or delete to obtain a pass. Unlisted clones are reported and kept. Resolve failed updates before comparing, without assuming earlier successful updates rolled back. If an approved origin move occurs, align its URL in `references.txt` and `DEVIATIONS.md`. Manifest changes define maintenance scope, not permission to create, repoint or delete unreviewed targets. Then confirm Omarchy tag `v4.0.0` resolves (`git rev-parse v4.0.0^{commit}`); retain the pinned release comparison.
2. Compare reference repos against the packages owned by EyrWSL
3. For Omarchy-derived packages, compare against tag `v4.0.0` in `omarchy/`, plus `omarchy-pkgs/` and `gruvbox.nvim/`; never substitute moving-branch contents for the pinned release comparison
4. For non-Omarchy tools, compare Yazi against `yazi/` and official docs, and the vault plugin specs against `obsidian.nvim/` and the render-markdown.nvim README
5. Check the WSL and Windows contract against official WSL, Arch-on-WSL, and Windows Terminal docs: WSL2 with active interop (enabled `binfmt_misc` and `WSLInterop` or `WSLInterop-late`, plus the bounded no-profile PowerShell probe), `clip.exe`/`powershell.exe` resolution, Windows-side font ownership, and `windows-terminal/settings.json` against `terminal/`; run `make wt-diff` when Terminal settings are involved. Neovim's clipboard provider needs PowerShell, not `clip.exe`; both commands remain host-gate requirements
6. Check package ownership at maintenance time: confirm `pacman -Si mise` still reports an official repository and `mise ls claude codex opencode pipx:hermes-agent uv` lists each tool, compare the `mise/.local/bin` wrappers against the heredoc in `git show v4.0.0:bin/omarchy-mise-install` and the tool list in `install/user/mise.sh`, accounting for the documented v4.0.2 `--quiet` adoption and omitted `MISE_MINIMUM_RELEASE_AGE=0` export without silently moving the comparison pin. Re-probe `pacman -Si herdr` before retaining its canonical installer, and keep Yazi media helpers explicitly optional
7. For each difference, classify it:
   - **Intentional deviation**: documented in `DEVIATIONS.md`, should stay different
   - **New upstream addition**: added upstream after the last sync, should be reviewed for inclusion
   - **Upstream change to existing config**: modified upstream, needs review
8. Check `git log --format="%h %ad %s" --date=short -- <file>` on the relevant reference repo when you need to determine when a difference was introduced
9. Cross-check differences against `DEVIATIONS.md`. If a difference is not documented there, treat it as a likely upstream change that needs review
10. Apply new upstream additions and changes where they belong in this repo
11. Update each affected documentation owner: README overview, AGENTS invariants, DEVIATIONS rationale, `docs/setup.md` procedures, and `docs/operations.md` usage/verification. Reconcile the workspace guide through `docs/workspace-guide-src/README.md` (Change-coupled maintenance): review added, changed and removed bindings/commands in the affected host/default layers, including Herdr, the outer terminal, Neovim/Neo-tree/vault plugins, Bash and Yazi. Compare installed/version-matched defaults even when no personal mapping file changed; route AI-client interface changes through EyrAgents' `/eyrsync`. Update affected entries, recipes, routing notes and source evidence together, then regenerate both companion guides. A generator/twin pass does not establish semantic or live-keymap accuracy. Keep only unresolved work and revalidation evidence in `docs/maintenance.md`
12. Summarize which changes were adopted, rejected, or intentionally kept different

## Completion Checks

- Check Hermes separately against Omarchy's `omarchy-install-hermes-cli` and current mise pipx backend documentation. Its uv-first wrapper persists Python 3.13 options for subsequent `mise up`; keep WSL cooldown/paranoid mode and reject wrong-interpreter/foreign launcher state without forced repair. Do not copy Desktop takeover/removal logic. `ha` maps to `hermes` or `hermes -c`, with continuation's native cwd behavior documented.

- The overview, invariants, deviations, and affected setup/operation guides reflect the change without duplicating detailed procedures
- Every affected workspace guide section has been reconciled with the owning configuration/source/help, including additions and removals. Both generated outputs are current and the shared authoring twins agree. Unchanged behavior is stated in the change review; unavailable/unauthorized sibling or actual-host checks remain explicit incomplete work at the maintenance owner, not a fabricated completed guide review
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
- System packages, `mise` included, come from official Arch repos; Claude Code, Codex, OpenCode, and Hermes Agent install and update through mise via the stowed wrappers, which keep mise's release cooldown, with paranoid mode on through the stowed `conf.d` fragment; Herdr uses its canonical installer only while an official package is unavailable. No AUR packages or AUR helper.
- Keep Windows-specific behavior explicit. Anything that depends on `clip.exe`, `powershell.exe`, or Windows Terminal should be documented as a Windows interop concern.
- Keep EyrWSL native-Herdr-only: native binary/configuration/keymap and `hdw` remain; open it with `herdr`. No copied `hdl`/`hdlm`/`hsl`/`hds`, Omarchy AI shortcuts, `h`/`t` aliases, or local tmux package/config/recipes. Never import desktop launch helpers during sync; the SSH reconnect helper's remote-tmux context remains valid. Keep Windows Terminal `Alt+Enter` pass-through for Omarchy's Herdr map, without treating retirement as settings-deployment approval.
- `hdw <cc|cx|oc|ha> [-c]` creates/focuses a new workspace in the current physical cwd inside an already-running Herdr. Valid populated/inactive callers, repeated new workspaces and generated-shell chaining are supported. Preserve existing names/layouts apart from global focus, native new names without `--label`, AI-left/editor-top-right/shell-bottom-right geometry and AI focus. Selectors are arguments sending full commands with optional continuation, not aliases or an isolated EyrAgents profile. No reuse/registry, server startup or outside attachment. Preserve pre-input identity/membership/geometry checks: only proven new split panes may be cleaned before possible input, never any workspace/tab/root/caller; retain the new workspace/root on failure and report original/new context without claiming multi-RPC atomicity.
- Exact retired-link mappings survive source and package removal, including `~/.config/bash/functions/herdr` to this clone's former `bash/.config/bash/functions/herdr` alongside `tdw`, `tmux`, and `tmux.conf`. Use guarded clean then preview/restow, preserving real directories, state and active sessions. Actual installed-package removal needs correct-host inspection, reverse-dependency review and exact approval; the baseline remains 42 packages.
