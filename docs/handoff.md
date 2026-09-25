# WSL Host Handoff

[Overview](../README.md) · [Operations](operations.md) · [Open work](maintenance.md)

Everything changed on Omarchy that the WSL host has not yet received, as one ordered procedure. Run it on the actual Arch WSL 2 host as the normal user, after H pulls EyrWSL, EyrArcHy and [EyrAgents](https://github.com/peregrinus879/eyragents). This file transfers no approval: package removals, exact-path cleanup, Windows settings replacement and host-local repairs each need H's approval at the time.

**Rules for the whole pass.** Stop at the first mismatch. Preserve local work, active sessions, foreign files and user state; never delete something to make a check pass. Never read credential or session stores or existing clipboard contents. Record actual versions, full commit IDs and results, never credentials or transcripts.

## 1. Host and Clones

From the deployed EyrWSL clone, check `uname -r` (WSL 2), `whoami`, `pwd`, `git status --short --branch` and `readlink -f ~/.bashrc`, then `make require-clone`. Record the full commit IDs of EyrWSL and EyrArcHy and, when both are available, run `make twins-pair` on them. Never deploy EyrArcHy on WSL.

## 2. Projects Layout

The Omarchy host moved to this layout. If the WSL host already has it, verify it instead of moving anything:

```text
~/Projects/
  eyrie/        every personal repository, including eyragents, eyrarchy, eyrwsl and omasecboot
    scrape/     persistent scratch, formerly ~/Projects/scratch
  quarry/       reference clones (unchanged)
  vault/        notes (unchanged)
```

1. Inventory `eyrie`, `branchers`, `mews`, `scratch`, `quarry` and `vault` by names and metadata only. Record each repository's HEAD (or unborn branch), status, ignored and untracked work, worktrees, directory modes and symlinks. An unborn branch can still hold untracked work.
2. Close terminals, editors and servers using the old paths. Move each repository directly under `eyrie`, keeping its name: `branchers/omarchy`, `mews/shahynmc` and `mews/shahyn-control-lab` are the known moves; review any other entry individually. Relocate linked worktrees and external Git directories with Git's own procedure, not a directory rename.
3. Move the whole `~/Projects/scratch` tree to `~/Projects/eyrie/scrape`, hidden and ignored contents included, preserving modes, with a same-filesystem, no-clobber rename; do not create the destination first. If both paths exist, stop and resolve the collision with H. Remove `mews` and `branchers` only if empty, with `rmdir`.
4. In the ignored `eyrie/shahynmc/.claude/settings.local.json`, move an existing scratch read allowance to the new root, keeping its scope; pull does not carry this file.
5. Confirm the same repositories, branches, staged and untracked work, complete scratch contents and modes, and search maintained configuration for stale paths.

## 3. Deploy EyrWSL

EyrWSL no longer carries local tmux, copied Omarchy Herdr recipes, Codex or Hermes. The guarded cleanup removes the retired tmux and Herdr links; `make restow` then lets Stow prune the orphaned Codex and Hermes wrappers in `~/.local/bin`, a directory the `mise` package still populates.

1. Keep existing tmux and Herdr sessions running; use a new Windows Terminal tab for this work.
2. Run `make dry-run`, `make clean`, `make dry-run` and `make restow`, stopping on errors; the final preview must be clean. Cleanup removes only the retired links it proves this clone owns: `~/.config/bash/functions/{tdw,tmux,herdr}`, `~/.config/tmux/tmux.conf` and a former `~/.config/tmux` fold. Afterwards, `ls ~/.local/bin` shows no `codex` or `hermes` link. Anything else refuses unchanged; resolve only an exact, reviewed conflict, with no `--adopt` or forced links.
3. **Installed tmux.** Inspect read-only: `type -a tmux`, `pacman -Q tmux` and, if installed, `pacman -Qi tmux` and `pacman -Qo` on the reported path. Present the package, its reverse dependencies and any session still using it. Only with H's approval of that exact transaction does H run `sudo pacman -R tmux`; never force, `-Rdd`, `-Rns` or orphan cleanup. A dependency or active session keeps the package, recorded as a blocker.
4. **Codex and Hermes.** H runs `mise unuse -g codex`, `mise unuse -g 'pipx:hermes-agent'` and `mise unuse -g uv`, then `mise uninstall --all <tool>` for any version `mise ls` still lists, and deletes `~/.codex/config.toml`, `~/.codex/AGENTS.md` and `~/.hermes`. Agents must not read or remove these paths; the rest of `~/.codex` is H's decision.

## 4. Tools and Verification

In a fresh normal-user tab outside any multiplexer:

1. Use the setup guide's [package list](setup.md#4-prerequisites) (`pacman -T`) to find missing packages; H installs them in a reviewed full upgrade. Check `mise settings get paranoid` prints `true`, run `claude --version` and `opencode --version` through the `~/.local/bin` wrappers to install them if needed, and confirm `command -v codex hermes uv` prints nothing.
2. Run `make verify` and record the result.
3. Work through the [manual checks](operations.md#verify): shell definitions, `hdw` in a disposable Herdr session, `ga` and `gd` in a disposable repository, `rsw` with disposable local directories, the Neovim clipboard round trip through a Windows application, Git review, and the vault if present. Use only disposable projects and tools for failure checks. In the workspace guide, confirm that exported saved keys keep recognized retired IDs.

## 5. Windows Terminal

Run `make wt-diff`. Confirm the Terminal path, the `archlinux` profile, the normal user, the installed font and the palette, and that `Alt+Enter` still reaches Herdr. Deploy with `make wt-push` only after H reviews the full-file replacement, then run `make wt-diff` again and confirm the reported backup.

## 6. GitHub Access

1. Follow [GitHub login and HTTPS setup](setup.md#12-github); H signs in and checks the credential-storage choice. Helper settings go in the untracked `config.local`, never the stowed Git configuration.
2. Complete the [HTTPS migration](setup.md#existing-clones-over-ssh) for every repository under `~/Projects`, starting with `eyrie/omasecboot` and `eyrie/shahynmc`: convert each GitHub SSH remote and explicit push URL to its HTTPS equivalent, preserving remote roles, order, tracking and push defaults, and review aliases, other hosts and rewrites individually. Report any priority clone that is absent rather than creating it.
3. Confirm the `shahynmc` repository is still private and authenticates over HTTPS through the helper (`gh repo view peregrinus879/shahynmc --json nameWithOwner,isPrivate,viewerPermission`), then complete the [restart and reboot checks](operations.md#github-access) without signing in again.

## 7. EyrAgents

Complete EyrAgents' [WSL host pass](https://github.com/peregrinus879/eyragents/blob/main/docs/maintenance.md#wsl-host-pass): deploy its packages, confirm the renamed `sparrer` and the persistent-scratch grant, and run its permission acceptance and canary.

## 8. Reference Clones

Only when reference-dependent maintenance needs it: preview with `make refs-plan`, get approval for any new clone or repointing, then run `make refs` and confirm exact fetched parity with local tags, ignored files and stale clones preserved.

## Close-Out

Record the host, commit IDs, each section's result and any blocker. When every section succeeds, delete this file in the completion commit, together with every link to it (the README, AGENTS.md, DEVIATIONS.md, setup and the [maintenance ledger](maintenance.md)). A section that cannot finish stays here, and its blocker moves to the ledger.
