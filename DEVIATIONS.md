# Deviations

## Purpose

This document records the intentional differences carried by EyrWSL relative to [Omarchy](https://github.com/omacom/omarchy), and defines the boundary between this repo and its siblings.

Omarchy tag `v4.0.4` at commit `c668141e9c42b13c80c9ca4ea108e11708c5e8a5` is the reproducible upstream comparison baseline. The lightweight tag names the release, while the commit ID records the exact reviewed source. Reference clones and the tag are maintenance inputs only; setup, Stow deployment, and verification do not use them.

## Deviation Policy

Omarchy is an opinionated Arch Linux distribution targeting a full desktop environment with Hyprland, systemd user services, GUI applications, and hardware-specific integrations. This repo extracts the terminal-layer configuration that remains useful inside WSL and restructures it into GNU Stow packages.

**Guiding principles:**

1. **Follow Omarchy conventions by default.** Aliases, keybindings, and tool choices should stay close to Omarchy unless a documented workflow, WSL or non-desktop constraint requires a change.
2. **Adapt only what breaks or does not apply.** Desktop-bound behavior, GUI launchers, and hardware workflows are omitted because they do not fit WSL.
3. **Keep Windows-specific behavior explicit.** Anything that depends on `clip.exe`, `powershell.exe`, or Windows Terminal should be documented as a Windows interop concern.
4. **Use GNU Stow for dotfile management.** Omarchy uses direct file copies and packaged assets. This repo uses symlink-based package ownership for clearer separation and reuse.
5. **Single theme, no switching.** This repo uses Gruvbox only, so Omarchy's theme switching and hot-reload infrastructure is intentionally omitted.
6. **Pacman-first package ownership.** System packages, `mise` included, come from official Arch repositories. Claude Code and OpenCode are installed and updated through mise, as on Omarchy, so they track upstream releases directly. Herdr uses its canonical standalone installer only while an official package is unavailable. The baseline depends on no AUR packages and installs no AUR helper.

## Reference Sources

- [omacom/omarchy](https://github.com/omacom/omarchy) - main repo for bash, native Herdr conventions, starship, git, fastfetch, btop, and editorconfig references; copied desktop launch recipes remain out of scope
- [omacom/omarchy-pkgs](https://github.com/omacom/omarchy-pkgs) - package builds, including the Omarchy Neovim package
- [mise](https://mise.jdx.dev/) and the [Arch `mise` package](https://archlinux.org/packages/extra/x86_64/mise/) - tool manager upstream and signed Arch package; its registry names the backend each AI tool installs from
- [Claude Code](https://code.claude.com/docs) - terminal agent upstream; installed through mise's `claude` registry entry
- [OpenCode](https://github.com/anomalyco/opencode) - terminal coding agent upstream; installed through mise's `opencode` registry entry
- [Herdr](https://github.com/herdrdev/herdr) - terminal workspace manager; its website provides the canonical installer
- [ellisonleao/gruvbox.nvim](https://github.com/ellisonleao/gruvbox.nvim) - Neovim colorscheme
- [microsoft/terminal](https://github.com/microsoft/terminal) - Windows Terminal settings structure and feature changes
- [sxyazi/yazi](https://github.com/sxyazi/yazi) and the [Yazi docs](https://yazi-rs.github.io/docs/) - file manager upstream and configuration reference
- [obsidian-nvim/obsidian.nvim](https://github.com/obsidian-nvim/obsidian.nvim) - upstream for the vault plugin spec
- [MeanderingProgrammer/render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim) - upstream for the markdown rendering spec
- [The Omarchy Manual](https://learn.omacom.io/2/the-omarchy-manual) - setup guides, keybindings, workflows
- [WSL Docs](https://learn.microsoft.com/en-us/windows/wsl/) - installation, configuration, and interop
- [Install Arch Linux on WSL](https://wiki.archlinux.org/title/Install_Arch_Linux_on_WSL) - Arch Wiki guide
- [Windows Terminal Docs](https://learn.microsoft.com/en-us/windows/terminal/) - settings, profiles, color schemes, and keybindings
- [GNU Stow Manual](https://www.gnu.org/software/stow/manual/stow.html) - symlink management and package structure
- [Bash Reference Manual](https://www.gnu.org/software/bash/manual/bash.html) - builtins, expansion, scripting
- [Starship Configuration](https://starship.rs/config/) - module options and format strings
- [LazyVim Docs](https://www.lazyvim.org/) - installation, extras, and plugin conventions
- [Neovim Docs](https://neovim.io/doc/) - options, API, and Lua reference
- [lazy.nvim Docs](https://lazy.folke.io/) - plugin manager configuration
- [Git Docs](https://git-scm.com/docs) - config options and behavior
- [btop](https://github.com/aristocratos/btop) - config options and themes
- [fastfetch Wiki](https://github.com/fastfetch-cli/fastfetch/wiki) - modules and JSON config

Gruvbox follows Omarchy's behavior on each owned surface. Windows Terminal and btop use the semantic palette from `themes/gruvbox/colors.toml`; Neovim selects `ellisonleao/gruvbox.nvim`; Yazi uses ANSI names resolved through Windows Terminal. AI-client themes are configured independently; terminal-aware themes can inherit the same palette.

## Intentional Deviations

### Environment Target

- Arch Linux inside WSL2 with active Windows interop, not WSL1 or a full Omarchy desktop.
- Desktop services, GUI launchers, display manager integration, and Hyprland-specific behavior are intentionally excluded.
- Nerd Font rendering is a Windows-side concern. Windows Terminal uses the Windows-installed JetBrainsMono Nerd Font; WSL needs no Linux font package.

### Dotfile Management

- GNU Stow with symlinked package ownership replaces Omarchy's file-copy and package-install model, using `--no-folding` so managed parents stay real directories and only files are links. Deployment, cleanup and recovery are guarded against taking over or deleting anything the clone cannot prove it owns ([setup](docs/setup.md)).
- `make clean` derives active owned paths from package files and carries exact retired mappings independently of Git and `PACKAGES`: `.config/bash/functions/{tdw,tmux,herdr}`, `.config/tmux/tmux.conf`, and the former `.config/tmux` fold. The `~/.config/bash/functions/herdr` endpoint maps only to this clone's former `bash/.config/bash/functions/herdr`. It classifies all endpoints and parents before changing anything and never traverses a queued fold. It removes only owned folds, recognized dangling active-package links, and exact retired links into this clone; other live leaf links stay for Stow. Retired paths do not use a broader stale-clone heuristic. Real directories and user data/state stay; regular files, foreign links, and special files at owned endpoints abort untouched. Use guarded clean, preview, then restow; restow does not run the retirement cleanup. Verification is read-only after pull and pending known source deletions, without exempting unrelated missing sources.
- Every host-writing Make target checks host and deployed-clone ownership before mutation; direct `scripts/wt-diff.sh --push` does so before destination discovery. The host guard requires WSL2, enabled `binfmt_misc`, an enabled `WSLInterop` or `WSLInterop-late` handler, resolving `clip.exe`/`powershell.exe`, and a successful five-second, no-profile PowerShell probe.
- Retirement additionally refuses any still-present exact mapped source entry, including a dangling symlink; source directories containing unrelated retained data stay allowed. HOME and real retired-path ancestors must be caller-owned, readable/writable/searchable and not group/world-writable. Refusal precedes any unlink or repair; the metadata policy does not extend to unrelated active-package parents.
- Files shared with EyrArcHy are byte-identical twins, checked locally and in CI ([operations](docs/operations.md#make-targets)). `/omasync` owns reference-clone maintenance and upstream comparison.
- Agent-tool verification approvals are handled by the active agent session rather than repo-root project allowlists.

### Theme

- Gruvbox is configured on Windows Terminal, btop, and Neovim; ANSI-aware applications inherit the terminal palette. Omarchy's multi-theme plugin set and theme hot-reload infrastructure are omitted.

### Terminal

- Windows Terminal replaces Ghostty from the Omarchy desktop.
- Gruvbox colors, JetBrainsMono Nerd Font at size 9, and padding 14 mirror Omarchy's terminal appearance in `windows-terminal/settings.json`.
- The Gruvbox color scheme maps Omarchy's semantic terminal palette to all 16 ANSI colors, cursor, selection, foreground, and background.
- `defaultProfile` uses the profile name `archlinux`. The `archlinux` entry that WSL's `Microsoft.WSL` fragment generates is carried explicitly, in the form Terminal writes, with the GUID WSL derived for this distribution: Terminal hides a previously generated profile that is absent from `settings.json`, treating the absence as a deletion (`DisableDeletedProfiles` in its settings model), which left the profile launchable by name but missing from the tab dropdown and the Settings pages. A reinstalled distribution gets a new GUID, read from WSL's fragment under `%LOCALAPPDATA%\Microsoft\Windows Terminal\Fragments\Microsoft.WSL`. The legacy `Windows.Terminal.Wsl` generator is disabled so the fragment profile is unambiguous.
- Windows Terminal settings are never stowed. `make wt-push` resolves the active Windows account through PowerShell, validates both files, creates a timestamped adjacent backup only when they differ, and atomically deploys the tracked file; `make wt-diff` reports normalized drift without changing either side.
- `alt+enter` remains unbound in `windows-terminal/settings.json` (`"id": null`) so Windows Terminal's fullscreen default does not swallow it. Omarchy's Herdr map also uses `Alt+Enter`; local tmux retirement does not change or deploy Terminal settings.

### Bash

- Config location is `~/.config/bash/` using an XDG-style layout instead of Omarchy's internal default path.
- Modular shell functions live in `~/.config/bash/functions/` and are sourced via a loop in `.bashrc`.
- Optional Bash overlays are sourced from `~/.config/bash-overlays/*` after the shared init. The directory is untracked and reserved for machine-local additions.
- `init` keeps Omarchy's mise activation and Starship prompt but drops the `try` helper and Omarchy's command completions, which need the Omarchy binaries; its Starship guard omits Omarchy's interactive test because `.bashrc` already returns for non-interactive shells. `envs` sets `EDITOR` to `nvim` and no `BROWSER`, where Omarchy points both at its desktop launchers.
- Dropped aliases: `open` (GUI-only), `d='docker'`, and `r='rails'`.
- The kitty-conditional `ff` image-preview variant is omitted; Windows Terminal is not kitty, so the conditional would always take the plain `bat` branch kept here.
- `y()` is added for Yazi cd-on-exit support. Yazi is not part of Omarchy.
- `hdw <cc|oc> [-c]` creates and focuses a new workspace inside an already-running Herdr using the caller's current physical directory, not an inferred Git root. A populated tab or inactive source workspace is allowed with valid pane identity and selected-tab context; repeated calls and generated bottom-right-shell chaining each create another workspace. AI stays full-height left, Neovim above a shell equally stacked right, with equal columns and AI focus. Commands are `claude` or `opencode`; `-c` uses `claude -c` or `opencode -c`. This geometry intentionally differs from Omarchy's `hdl` recipe.
- Existing names/layouts remain untouched apart from normal global workspace focus. New naming stays with Herdr, with no `--label` or rename/metadata writes; the new default tab displays positional `1`. Bare `hdw` is usage. There is no workspace reuse, server startup, client attachment or roots registry. Old state/recovery files, including `${XDG_STATE_HOME:-$HOME/.local/state}/hdw/roots`, remain untouched and unused. Native Herdr controls own workspace/tab navigation.
- Cooperating calls are serialized; caller identity, pre-creation workspace inventory, the new root's opaque terminal identity, exact membership and complete geometry are checked before input. Cleanup may close only proven new split panes before possible input, never any workspace/tab/root/caller. A new workspace/root always remains on failure; possible input or uncertain ownership preserves remaining state with original/new recovery context. These are failure-preserving multi-call workflows, not server-side atomic transactions.
- `hdw` and its declared tests/fixture are byte-identical twins with EyrArcHy. The Herdr binary is native and its configuration is the stowed `herdr/` package ([Native Herdr Only](#native-herdr-only)); open it with `herdr`. EyrWSL does not carry copied Omarchy `hdl`/`hdlm`/`hsl`/`hds` recipes or `h`/`t` aliases, and sync must not import desktop launch helpers.
- Omarchy's SSH port-forwarding and dropped-connection recovery helpers are adopted; the reconnect helper's remote-tmux context remains valid without local tmux. `rsw <source> <destination>` keeps its interface but uses persistent inotify monitoring and event consumption during transfers, coalesces bursts, retries transfer failures after five seconds, and checks for reconciliation between transfers, 60 seconds after the last successful completion. It never adds `--delete`, so destination-only files remain. Startup reports readiness/PID/log path, not sync success; monitor/transfer failures are logged under `${XDG_STATE_HOME:-$HOME/.local/state}/rsw`. `lsw`/`dsw` manage only watchers started by this implementation via checked readiness/process records. SSH sockets use `XDG_RUNTIME_DIR/rsw-sockets`, falling back to `rsw-sockets` under the rsw state directory, not the credential-store tree. Runtime packages remain official `rsync` and `inotify-tools` plus the existing core utilities.
- `ga <branch>` creates beside the actual checkout root even from a subdirectory and checks branch/add/navigation failures. `gd` takes no arguments and uses Git worktree metadata, not a directory-name guess; it confirms the real path/branch, rechecks HEAD/branch, and refuses dirty work or commits not contained in the primary worktree's current HEAD before ordinary `git worktree remove` and `git branch -d`. Directory changes use `builtin cd` so the interactive zoxide alias cannot reinterpret reviewed paths. A failed navigation preserves the created checkout; failed branch deletion retains the branch and reports the partial outcome. Force is a separate manual decision, not a helper option.
- Shell initialization removes inherited `$HOME/.opencode/bin` entries and appends user-level directories after system entries: `/usr/local/bin`, mise shims and `~/.local/bin`.
- AI clients load their normal user configuration. EyrWSL carries no Omarchy AI launch aliases (`c`, `cx`, `cy`, `ic`, `ix`, `icx`); `hdw` sends full `claude` or `opencode` commands with only the selected continuation form, so the clients start with their normal permission prompts, without the stock aliases' auto-approval flags (`opencode --auto`, `claude --permission-mode auto`). Its `cc`/`oc` arguments are not aliases or an isolated harness profile. ArcHy's stock shortcut flags apply only to those stock launches, not `hdw`.
- Omarchy's mise shell handling is adopted verbatim: `mise activate bash` opens `init`, `set +h` closes `shell`, and the `mup` alias is carried as plain `mise up`, without Omarchy's `MISE_MINIMUM_RELEASE_AGE=0` prefix (see Mise). Omarchy also sources its PATH bootstrap from `/etc/profile.d` and PAM so login shells and SSH commands find the mise tools; here `envs` is the only source, so shells that skip `.bashrc` (`wsl.exe -e`, SSH commands) see the mise directories only when the system PATH already has them.
- No `pacman` alias and no AUR helper. Omarchy routes updates through `omarchy-update`, which is Hyprland/desktop-bound and runs `mise up` after its package step; this repo's `wsl-update` function runs plain `pacman -Syu` against official repos only, which carries the packaged mise, then `mise up` for the mise-managed tools and `herdr update` for the installer-managed Herdr, stopping at the first failure and without Omarchy's snapshot, migration, AUR and orphan steps; `mup` runs the mise step alone.

### Git

- `~/.config/git/config` opens with `[include] path = ~/.config/git/config.local` so the local untracked `[user]` block is loaded first. Omarchy installs identity into the tracked file directly during install.
- `[init] defaultBranch = main` replaces Omarchy's `master`.
- Inline option comments are removed because the same intent is captured in this file. Omarchy keeps inline comments next to each option.
- Private Git identity is intentionally not tracked. WSL uses the untracked local file `~/.config/git/config.local` for `[user]` name and email.
- `~/.config/git/ignore` is an EyrWSL addition: it ignores `.claude/settings.local.json`, the per-checkout Claude Code permission file, in every repository; Omarchy configures no global ignore file.

### Starship

- The prompt shows `hostname` only during SSH sessions so remote shells are visually distinct from local ones while keeping the local prompt minimal.
- The `conflicted`, `up_to_date`, and `modified` Git status icons use Material Design Icons codepoints instead of Omarchy's Nerd Font private-use codepoints, matching the same broader-terminal-font compatibility rationale used for Fastfetch.

### Native Herdr Only

- EyrWSL omits local tmux from the baseline package list, Stow configuration, Bash helpers (`tdw`, `tdl`, `tdlm`, `tsl`) and `t` alias. Copied Herdr recipes and alias `h` are also omitted, not the native Herdr application. The 42 baseline packages stay. Omarchy's desktop tmux remains upstream-owned, outside EyrWSL.
- The `herdr/` package stows Omarchy's `config/herdr/config.toml` at the pin verbatim below a header, plus `onboarding = false`, which Herdr writes after its first run and would otherwise write through the link into the clone. Omarchy copies the file with `omarchy-refresh-config`; here it is a link, so Herdr's own writes (`herdr channel set`, `herdr config reset-keys`, the onboarding flag) land in the clone and are reviewed like the tracked Claude settings, never reverted blindly. `herdr server reload-config`, or Prefix then `q`, applies an edit to the running server.
- Source retirement does not uninstall an existing host package or kill sessions. Actual host retirement follows the guarded [existing-installation sequence](docs/setup.md#existing-installations), preserving sessions, real directories and user state; inspect installed package ownership and reverse dependencies before exact package-removal approval. Do not force dependencies, use blanket `-Rns`/orphan cleanup, or overwrite Terminal settings for this migration.

### Neovim

- `lua/config/options.lua` keeps Omarchy's `vim.opt.relativenumber = false` and `vim.g.autoformat = false` baseline and adds a WSL/`powershell.exe`-guarded clipboard provider for both `+` and `*`. Argv arrays use `-NoLogo -NoProfile -NonInteractive`, explicit UTF-8 without BOM on both pipes, and terminating errors. Copy uses `Set-Clipboard` and clears empty input; paste uses `Get-Clipboard -Raw`, casts null to empty, and strips CR. `clip.exe` is not this provider's dependency. Windows PowerShell behavior still needs the live host pass; Unicode mocks do not prove it.
- The `nvim/` package owns the complete LazyVim bootstrap, static configuration, and generated `lazy-lock.json`; setup requires no separate Neovim configuration clone.
- `all-themes.lua` and `omarchy-theme-hotreload.lua` are omitted because Neovim uses a fixed Gruvbox configuration.
- Kept verbatim from `omarchy-nvim`: `disable-news-alert.lua`, `snacks-animated-scrolling-off.lua`, `vim.opt.relativenumber = false`, and `vim.g.autoformat = false`.
- Omarchy's `lua/config/remote_clipboard.lua` (package 2026.9.21), which routes copies through Wayland, tmux or OSC 52 inside tmux, SSH and Herdr sessions, is omitted together with its `options.lua` call: under WSL the PowerShell provider above serves every session, and Wayland and tmux do not apply.
- `transparency.lua` content is verbatim from `omarchy-nvim` but lives at `after/plugin/` instead of upstream's `plugin/after/` to use Neovim's actual after-load mechanism. Upstream `omarchy-nvim` uses the incorrect path.
- Owned Lua files use 2-space indentation per the shared `.editorconfig` in this repo. Upstream `omarchy-nvim` uses tabs. Contents are otherwise unchanged.
- The vault plugin specs are `obsidian.lua` (obsidian.nvim against the vault at `~/Projects/vault`, override with `OBSIDIAN_VAULT`) and `render-markdown.lua` (visual markdown rendering companion). `python` is in the baseline package list because the vault keybindings shell out to the vault's `normalize.py`.
- `git-review.lua` overrides only Snacks `gd`, `gD`, and `gs` review mappings, choosing the current file/directory or Neo-tree selection's Git root on each invocation, resolving symlink targets and supporting linked worktrees. Empty/special non-explorer buffers use window cwd; a known non-Git target warns without falling back to an unrelated repository. No global/window directory change is introduced. The spec and mocked regression suite are byte-identical twins with EyrArcHy.
- The spec's `open.func` routes `obsidian://` and web URIs through Windows interop (`powershell.exe Start-Process`) when running under WSL, so `:Obsidian open` and link-following reach the Windows apps without `wsl-open`, which is not in official Arch repos. The override is guarded by `vim.fn.has("wsl")` and inert elsewhere. Both repos track byte-identical copies of the spec.

### Mise

- The `mise/` package stows two AI wrappers into `~/.local/bin`. Claude Code and OpenCode retain the `omarchy-mise-install` form minus its cooldown override. Omarchy regenerates its wrappers; EyrWSL deploys its wrappers with Stow. `~/.config/mise/config.toml` and `~/.local/share/mise` remain host state.
- The release cooldown stays at mise's 24-hour `minimum_release_age` default in the wrappers and `mup`. Omarchy sets it to zero in exactly two places, its generated wrappers and `omarchy-update-mise`, so an AI tool release is usable the hour it ships, while every other tool it installs through mise (the default agent, Node, the dev-env runtimes) waits out the default; this repo keeps the default everywhere and accepts the day's delay as the supply-chain guard mise documents it as. Omarchy's `upgrade.auto_prune = false`, added in 4.0.4 so `mise up` never prunes the version a running client executes from, is adopted in the stowed fragment.
- Paranoid mode is on through the stowed `~/.config/mise/conf.d/eyrwsl.toml`. Omarchy runs mise with default trust and trusts `~/Work/.mise.toml` and every worktree automatically; here global configs stay implicitly trusted and every project-level config needs an explicit `mise trust`, prompted again when the file changes.
- `mise` comes from the official `extra` repository instead of Omarchy's `mise-bin` package.
- The two AI tools go through mise. Omarchy's other mise-managed tools are omitted: the wrappers for `codex`, `crush`, `gemini`, `gh`, `copilot`, `playwright`, `pi`, `omp`, `grok`, `cursor-agent`, `ghui`, `hunk`, the Hermes CLI and `muse` at the pin, the global Node runtime, and the language runtimes `omarchy-install-dev-env` adds on request; `gh` comes from the official `github-cli` package.
- Omarchy's `~/Work/.mise.toml` and global Node.js install (`mise-work.sh`) are omitted. Claude Code and OpenCode use prebuilt binaries; Node.js is outside this terminal baseline.
- `omarchy-update-mise`'s counterpart is the mise step of `wsl-update`, which keeps the cooldown; `mup` runs that step alone.

### OpenCode

- EyrWSL supplies no OpenCode configuration or theme; [EyrAgents](https://github.com/peregrinus879/eyragents) owns all AI-client configuration.

### Fastfetch

- Fastfetch is rewritten for a terminal-first environment instead of Omarchy's desktop-oriented presentation.
- The same box-drawing structure and section layout are kept: Hardware, Software, and Uptime.
- Desktop modules are omitted: `display`, `wm`, `de`, and `wmtheme`.
- Omarchy-specific helper commands are omitted: `omarchy-version`, `omarchy-version-branch`, `omarchy-version-channel`, `omarchy-version-pkgs`, and `omarchy-theme-current`.
- `OS Age` is omitted.
- Omarchy's ASCII logo is replaced with fastfetch's built-in small logo.
- Icon codepoints use the Material Design Icons range for broader terminal font compatibility.
- Standard modules `shell` and `os` are added.
- `display.disableLinewrap` follows the Omarchy baseline so long values do not disturb the box layout.

### Btop

- `btop.conf` is based on the generated config format produced by `btop`, including lowercase booleans and additional default settings.
- The intentional baseline change is `color_theme = "gruvbox"` instead of Omarchy's `"current"`; `gruvbox.theme` is the stable Omarchy template rendered with the stable semantic palette.

### Yazi

- Added entirely. Yazi is not part of Omarchy.
- `yazi.toml` carries local layout and behavior choices: ratio `[2, 4, 4]`, hidden files shown, directories sorted first, `sort_by = "natural"`, and `linemode = "size"`. Tracked as a byte-identical twin with EyrArcHy.
- Yazi's built-in theme uses named ANSI colors for its primary interface, so Windows Terminal supplies the Gruvbox palette without a local theme override.

### WSL Bootstrap

- `/etc/wsl.conf` carries the default user and keeps Windows interop enabled, which the clipboard integration requires.
- `/etc/binfmt.d/WSLInterop.conf` carries WSL's own `WSLInterop` registration line so `systemd-binfmt.service` runs at every start. Arch ships no `binfmt.d` files, so the service is otherwise skipped, WSL's generated drop-in that re-registers the handler inside it never runs, and terminating a systemd distribution clears the kernel's single `binfmt_misc` table (observed with WSL 2.6.3 and kernel 6.6.87.2).
- The [setup guide](docs/setup.md) separates Windows/PowerShell, Arch root bootstrap, and normal-user setup. It covers stable WSL, official Arch installation and checksum-checked image fallback, Windows Terminal and fonts, preserved host settings, locale, no-reply identity, and preservation-first deployment/upgrades. [Operations](docs/operations.md) owns usage and verification; the README remains the overview. Client configuration is independent, and actual-host evidence stays pending in the maintenance ledger.
- The WSL baseline includes `inetutils` for the `hostname` host gate, `lua` for EyrWSL's fail-closed syntax verification, `tree-sitter-cli` for LazyVim, and `man-db`/`man-pages` for local documentation. The official `mise` package installs and updates the AI terminal tools through the stowed wrappers.
- Yazi media helpers are optional official packages, not hidden baseline dependencies.

## Skipped From Omarchy

- GUI and desktop components, including Hyprland, Waybar, SDDM, Plymouth, Mako, Walker, Fcitx5, and related user services
- SwayOSD, hardware drivers, Elephant widgets, and other desktop-bound integrations
- `omarchy-fish`, `omarchy-zsh`, and `omarchy-walker`
- `drives` functions such as `iso2sd` and `format-drive`
- `transcoding` functions for video and image conversion
- Omarchy Herdr/tmux launch recipes (`hdl`, `hdlm`, `hsl`, `hds`, `tdl`, `tdlm`, `tsl`, `tds`) and AI launch shortcuts
- Omarchy's `open` and `a` shell helpers, which depend on desktop launchers or `omarchy-agent`
- Hardware-focused tooling and desktop automation
- Theme switching infrastructure not needed for fixed per-surface themes
- Shell or app packages outside the chosen Bash plus terminal-tooling baseline

## Out Of Scope

The following do **not** belong in EyrWSL:

- AI-client runtime configuration and agent workflow policy
- Omarchy desktop customizations such as Hyprland bindings (belong in EyrArcHy)
