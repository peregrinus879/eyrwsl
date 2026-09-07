# Deviations

## Purpose

This document records the intentional differences carried by EyrWSL relative to [Omarchy](https://github.com/omacom/omarchy), and defines the boundary between this repo and its siblings.

Omarchy tag `v4.0.0` at commit `f0020448ca87329199de7cb12f2015ebc4a3e5e7` is the reproducible upstream comparison baseline. The lightweight tag names the release, while the commit ID records the exact reviewed source. Reference clones and the tag are maintenance inputs only; setup, Stow deployment, and verification do not use them.

## Deviation Policy

Omarchy is an opinionated Arch Linux distribution targeting a full desktop environment with Hyprland, systemd user services, GUI applications, and hardware-specific integrations. This repo extracts the terminal-layer configuration that remains useful inside WSL and restructures it into GNU Stow packages.

**Guiding principles:**

1. **Follow Omarchy conventions by default.** Aliases, keybindings, tmux layout ratios, and tool choices should stay close to Omarchy unless a WSL or non-desktop constraint requires a change.
2. **Adapt only what breaks or does not apply.** Desktop-bound behavior, GUI launchers, and hardware workflows are omitted because they do not fit WSL.
3. **Keep Windows-specific behavior explicit.** Anything that depends on `clip.exe`, `powershell.exe`, or Windows Terminal should be documented as a Windows interop concern.
4. **Use GNU Stow for dotfile management.** Omarchy uses direct file copies and packaged assets. This repo uses symlink-based package ownership for clearer separation and reuse.
5. **Single theme, no switching.** This repo uses Gruvbox only, so Omarchy's theme switching and hot-reload infrastructure is intentionally omitted.
6. **Pacman-first package ownership.** System packages, `mise` included, come from official Arch repositories. Claude Code, Codex, and OpenCode are installed and updated through mise, as on Omarchy, so they track upstream releases directly. Herdr uses its canonical standalone installer only while an official package is unavailable. The baseline depends on no AUR packages and installs no AUR helper.

## Reference Sources

- [omacom/omarchy](https://github.com/omacom/omarchy) - main repo for bash, tmux, starship, git, fastfetch, btop, and editorconfig references
- [omacom/omarchy-pkgs](https://github.com/omacom/omarchy-pkgs) - package builds, including the Omarchy Neovim package
- [mise](https://mise.jdx.dev/) and the [Arch `mise` package](https://archlinux.org/packages/extra/x86_64/mise/) - tool manager upstream and signed Arch package; its registry names the backend each AI tool installs from
- [Claude Code](https://code.claude.com/docs) - terminal agent upstream; installed through mise's `claude` registry entry
- [OpenAI Codex](https://github.com/openai/codex) - official terminal CLI upstream; installed through mise's `codex` registry entry
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
- [Tmux Wiki](https://github.com/tmux/tmux/wiki) - usage and recipes
- [LazyVim Docs](https://www.lazyvim.org/) - installation, extras, and plugin conventions
- [Neovim Docs](https://neovim.io/doc/) - options, API, and Lua reference
- [lazy.nvim Docs](https://lazy.folke.io/) - plugin manager configuration
- [Git Docs](https://git-scm.com/docs) - config options and behavior
- [btop](https://github.com/aristocratos/btop) - config options and themes
- [fastfetch Wiki](https://github.com/fastfetch-cli/fastfetch/wiki) - modules and JSON config

Gruvbox follows Omarchy's behavior on each owned surface. Windows Terminal and btop use the semantic palette from `themes/gruvbox/colors.toml`; Neovim selects `ellisonleao/gruvbox.nvim`; tmux and Yazi use ANSI names resolved through Windows Terminal. OpenCode's `system` theme is selected by EyrAgents and inherits the same terminal palette.

## Intentional Deviations

### Environment Target

- Arch Linux inside WSL2 with active Windows interop, not WSL1 or a full Omarchy desktop.
- Desktop services, GUI launchers, display manager integration, and Hyprland-specific behavior are intentionally excluded.
- Nerd Font rendering is a Windows-side concern. Windows Terminal uses the Windows-installed JetBrainsMono Nerd Font; WSL needs no Linux font package.

### Dotfile Management

- GNU Stow with symlinked package ownership replaces Omarchy's file-copy and package-install model.
- `make clean` derives the owned paths from the package files, classifies every one before changing anything, and removes only folded directory links left by a folding deployment and dangling links from a moved or deleted clone; live leaf links stay for Stow. Regular files, foreign links, and special files at owned paths abort untouched.
- Every host-writing Make target checks host and deployed-clone ownership before mutation; direct `scripts/wt-diff.sh --push` does so before destination discovery. The host guard requires WSL2, enabled `binfmt_misc`, an enabled `WSLInterop` or `WSLInterop-late` handler, resolving `clip.exe`/`powershell.exe`, and a successful five-second, no-profile PowerShell probe. `.NOTPARALLEL` serializes one Make invocation, not independent deployments or disk failures. Complete cleanup preflight is preservation-safe refusal, not a rollback transaction.
- `make verify` first checks the active WSL2/interoperability host contract, then runs `lint`, `check`, and `twins`, followed by the full verifier's command baseline, AI tools installed by and resolving through a paranoid-mode mise, deployed package ownership with real managed parents, GitHub no-reply Git identity, and owned config parsers and runtimes. `make check` runs the parser, runtime, and fixture parts anywhere.
- Stow runs with `--no-folding`, so every managed parent stays a real directory that tools may write into and only leaf files are links.
- `/omasync` owns reference-clone maintenance and upstream comparison; `docs/maintenance.md` owns unresolved decisions, deferred work, active limitations, and dated evidence.
- Agent-tool verification approvals are handled by session or shared EyrAgents policy rather than repo-root project allowlists.
- `make refs` reports and keeps stale clones; listed default branches must reach exact fetched upstream parity by fast-forward. Atomic, non-forced fetches preserve existing local tags and annotations, import new tags, and prune only origin tracking branches. Checkout/merge use `--no-overwrite-ignore` so ignored files in listed clones are not overwritten. Ahead-only/divergent branches and tag/file conflicts refuse; resolution and any stale-clone disposal need separate review, including all refs, stashes, and ignored/untracked content before disposal.
- Local `make twins` checks worktree copies and can skip a missing sibling. `twins-pair` compares committed blobs at full `SELF_COMMIT` and `PEER_COMMIT` IDs without executing peer code. Those IDs and `SIBLING` travel as literal data, not Make expressions or shell source. CI normally uses the peer default branch; manual dispatch accepts an explicit full `peer_commit` only with `peer_reviewed=true` and records both actual commits. Publication evidence must validate the final published pair; operator attestation is not authorization to publish.

### Theme

- Gruvbox is configured on Windows Terminal, btop, and Neovim; ANSI-aware applications inherit the terminal palette. Omarchy's multi-theme plugin set and theme hot-reload infrastructure are omitted.

### Terminal

- Windows Terminal replaces Ghostty from the Omarchy desktop.
- Gruvbox colors, JetBrainsMono Nerd Font at size 9, and padding 14 mirror Omarchy's terminal appearance in `windows-terminal/settings.json`.
- The Gruvbox color scheme maps Omarchy's semantic terminal palette to all 16 ANSI colors, cursor, selection, foreground, and background.
- `defaultProfile` uses the dynamic profile name `archlinux`; host-specific profile entries are omitted, and the `Windows.Terminal.Wsl` generator is disabled so the current `Microsoft.WSL` profile is unambiguous.
- Windows Terminal settings are never stowed. `make wt-push` resolves the active Windows account through PowerShell, validates both files, creates a timestamped adjacent backup only when they differ, and atomically deploys the tracked file; `make wt-diff` reports normalized drift without changing either side.

### Bash

- Config location is `~/.config/bash/` using an XDG-style layout instead of Omarchy's internal default path.
- Modular shell functions live in `~/.config/bash/functions/` and are sourced via a loop in `.bashrc`.
- Optional Bash overlays are sourced from `~/.config/bash-overlays/*` after the shared init. The directory is untracked and reserved for machine-local additions.
- Dropped aliases: `open` (GUI-only), `d='docker'`, and `r='rails'`.
- The kitty-conditional `ff` image-preview variant is omitted; Windows Terminal is not kitty, so the conditional would always take the plain `bat` branch kept here.
- `y()` is added for Yazi cd-on-exit support. Yazi is not part of Omarchy.
- `tdw` is added: one tmux session per project (Git root, else current directory) holding a dev layout in one window named after the project: the AI agent on the left at full height, and `$EDITOR` above a shell on the right, split 50/50 by height; the columns also split 50/50 instead of Omarchy's 70/30 with its full-width 15% shell strip, and focus lands on the agent, not the editor. Inside tmux, creation uses the full window size, not the calling pane's size. `tdw cc` runs Claude Code, `tdw cx` Codex, `tdw oc` OpenCode; the choice is mandatory at creation so a single agent owns the working tree, and `-c` continues that agent's last conversation in the project (`claude -c`, `codex resume --last`, `opencode -c`). Bare `tdw` re-attaches an existing session without changing its layout; creation checks the selected agent before changing tmux state. Additive alongside Omarchy's `tdl` pane layout. The `t`/`h` prefix follows Omarchy's multiplexer lettering (`tdl`/`hdl`).
- `hdw` is added: the herdr counterpart of `tdw`, one herdr workspace per project with the same one-tab layout, agent choice, `-c` flag, and agent focus, plus a root-collision guard backed by a label-to-root record under `~/.local/state/hdw/roots` (workspace ids recycle across server restarts, so the record keys on the label). Bare `hdw` refocuses; when the herdr server is down, `hdw` starts it headless and attaches, so one invocation works from a cold boot, and if the headless start fails it attaches plain herdr with a hint to rerun `hdw` inside. Additive alongside Omarchy's `hdl` pane layout. `tdw` and `hdw` are byte-identical twins with EyrArcHy.
- Omarchy's Herdr helpers `hdl`, `hdlm`, and `hsl` are adopted. `hds` is omitted because it invokes Hunk, one of the mise-managed Omarchy tools this repo leaves out (see Mise).
- Omarchy's SSH port-forwarding, dropped-connection recovery, and rsync-on-change helpers are adopted. The rsync watcher is backed by the official `rsync` and `inotify-tools` packages.
- Interactive Bash exports `OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1` and `OPENCODE_ENABLE_EXA=1` so terminal-launched OpenCode skips the Claude Code skill copies, reads `.agents/skills` natively, and exposes its configured web-search tool. EyrAgents owns OpenCode configuration; this repo owns the WSL host environment. Shell initialization removes inherited `$HOME/.opencode/bin` entries and appends the user-level directories after existing system entries, so system binaries retain precedence: `/usr/local/bin`, then the mise shims and `~/.local/bin` in the order Omarchy's `env-bootstrap` uses.
- The AI tools run as EyrAgents configures them: `claude`, `codex`, and `opencode` are launched plain and inherit EyrAgents' effort pin and permission rules. Omarchy's launch aliases `c`, `cx`, `cy`, `ic`, `ix`, and `icx` set permission modes, approval flags, and `tdl` targets that EyrAgents and the workspace launchers own, so this repo does not carry them.
- Omarchy's mise shell handling is adopted verbatim: `mise activate bash` opens `init`, `set +h` closes `shell`, and the `mup` alias is carried as plain `mise up`, without Omarchy's `MISE_MINIMUM_RELEASE_AGE=0` prefix (see Mise). Omarchy also sources its PATH bootstrap from `/etc/profile.d` and PAM so login shells and SSH commands find the mise tools; here `envs` is the only source, so shells that skip `.bashrc` (`wsl.exe -e`, SSH commands) see the mise directories only when the system PATH already has them.
- No `pacman` alias and no AUR helper. Omarchy routes updates through `omarchy-update`, which is Hyprland/desktop-bound and runs `mise up` after its package step; this repo uses plain `pacman -Syu` against official repos only, which carries the packaged mise, followed by `mup` for the mise-managed tools.

### Git

- `~/.config/git/config` opens with `[include] path = ~/.config/git/config.local` so the local untracked `[user]` block is loaded first. Omarchy installs identity into the tracked file directly during install.
- `[init] defaultBranch = main` replaces Omarchy's `master`.
- Inline option comments are removed because the same intent is captured in this file. Omarchy keeps inline comments next to each option.
- Private Git identity is intentionally not tracked. WSL uses the untracked local file `~/.config/git/config.local` for `[user]` name and email.

### Starship

- The prompt shows `hostname` only during SSH sessions so remote shells are visually distinct from local ones while keeping the local prompt minimal.
- The `conflicted`, `up_to_date`, and `modified` Git status icons use Material Design Icons codepoints instead of Omarchy's Nerd Font private-use codepoints, matching the same broader-terminal-font compatibility rationale used for Fastfetch.

### Tmux

- Upstream's `M-Enter`, `M-S-Enter`, and `M-Escape` pane bindings are adopted verbatim; `alt+enter` is unbound in `windows-terminal/settings.json` (`"id": null`) because Windows Terminal's default binds it to fullscreen and would swallow `M-Enter` before it reaches tmux.
- The `?` keybindings-popup binding is omitted; it shells out to `omarchy-menu-tmux-keybindings`, which exists only on an Omarchy install.
- Omarchy's binding descriptions, generic clipboard feature, and terminal title settings are adopted. The Kitty-only extended-key feature is omitted because Windows Terminal is the host terminal.

### Tmux Dev Layout

- `tdl`, `tdlm`, and `tsl` retain Omarchy's terminal layouts. `tdl` selects `editor_pane` rather than the upstream baseline's unset `opencode_pane`; Hunk-dependent `tds` is omitted.

### Neovim

- `lua/config/options.lua` keeps Omarchy's `vim.opt.relativenumber = false` and `vim.g.autoformat = false` baseline and adds WSL clipboard integration directly, guarded by `clip.exe` and `powershell.exe` availability so the block is a no-op outside WSL. Copy uses `clip.exe`; paste uses `powershell.exe Get-Clipboard`.
- The `nvim/` package owns the complete LazyVim bootstrap, static configuration, and generated `lazy-lock.json`; setup requires no separate Neovim configuration clone.
- `all-themes.lua` and `omarchy-theme-hotreload.lua` are omitted because Neovim uses a fixed Gruvbox configuration.
- Kept verbatim from `omarchy-nvim`: `disable-news-alert.lua`, `snacks-animated-scrolling-off.lua`, `vim.opt.relativenumber = false`, and `vim.g.autoformat = false`.
- `transparency.lua` content is verbatim from `omarchy-nvim` but lives at `after/plugin/` instead of upstream's `plugin/after/` to use Neovim's actual after-load mechanism. Upstream `omarchy-nvim` uses the incorrect path.
- Owned Lua files use 2-space indentation per the shared `.editorconfig` in this repo. Upstream `omarchy-nvim` uses tabs. Contents are otherwise unchanged.
- Two additive plugin specs are carried: `obsidian.lua` (obsidian.nvim against the vault at `~/Projects/vault`, override with `OBSIDIAN_VAULT`) and `render-markdown.lua` (visual markdown rendering companion). `python` is in the baseline package list because the vault keybindings shell out to the vault's `normalize.py`.
- The spec's `open.func` routes `obsidian://` and web URIs through Windows interop (`powershell.exe Start-Process`) when running under WSL, so `:Obsidian open` and link-following reach the Windows apps without `wsl-open`, which is not in official Arch repos. The override is guarded by `vim.fn.has("wsl")` and inert elsewhere. Both repos track byte-identical copies of the spec.

### Mise

- The `mise/` package stows the three AI tool wrappers into `~/.local/bin`: what `omarchy-mise-install claude`, `codex`, and `opencode` write on Omarchy, minus the `MISE_MINIMUM_RELEASE_AGE=0` export. Omarchy regenerates its wrappers at install and through `omarchy-refresh-applications`; this repo deploys them with Stow and updates them through `make restow`. mise's other files (`~/.config/mise/config.toml`, `~/.local/share/mise`) stay host state the wrappers create.
- The release cooldown stays at mise's 24-hour `minimum_release_age` default in the wrappers and `mup`. Omarchy sets it to zero in exactly two places, its generated wrappers and `omarchy-update-mise`, so an AI tool release is usable the hour it ships, while every other tool it installs through mise (the default agent, Node, the dev-env runtimes) waits out the default; this repo keeps the default everywhere and accepts the day's delay as the supply-chain guard mise documents it as.
- Paranoid mode is on through the stowed `~/.config/mise/conf.d/eyrwsl.toml`. Omarchy runs mise with default trust and trusts `~/Work/.mise.toml` and every worktree automatically; here global configs stay implicitly trusted and every project-level config needs an explicit `mise trust`, prompted again when the file changes.
- `mise` comes from the official `extra` repository instead of Omarchy's `mise-bin` package.
- Only the three AI tools go through mise. Omarchy's other mise-managed tools are omitted: the wrappers for `gh`, `crush`, `gemini`, `copilot`, `playwright`, `pi`, `omp`, `grok`, `ghui`, and `hunk` at the pin (`agy` replacing `gemini`, `hey`, `ori`, and Hermes since), the global Node runtime, and the language runtimes `omarchy-install-dev-env` adds on request; `gh` comes from the official `github-cli` package.
- Omarchy's `~/Work/.mise.toml` and global Node.js install (`mise-work.sh`) are omitted; the AI tools install as prebuilt binaries and need no runtime.
- `omarchy-update-mise` has no counterpart; `mup` is the update path, run by hand.

### OpenCode

- Shared OpenCode runtime and TUI configuration remains owned by EyrAgents. Its `system` theme selection uses ANSI colors and terminal defaults, matching Omarchy's terminal-aware behavior without a custom palette in EyrWSL.
- EyrAgents deploys its own `opencode` package without folding; nothing in EyrWSL touches `~/.config/opencode/`.

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
- Windows-side installation of Windows Terminal, the Nerd Font, and Arch directly through `wsl --install -d archlinux` is documented in this repo's README; WSL2 and a root recovery password are setup gates.
- The WSL baseline includes `inetutils` for the `hostname` host gate, `lua` for EyrWSL's fail-closed syntax verification, `tree-sitter-cli` for LazyVim, and `man-db`/`man-pages` for local documentation. The official `mise` package installs and updates the AI terminal tools through the stowed wrappers.
- Yazi media helpers are optional official packages, not hidden baseline dependencies.

## Skipped From Omarchy

- GUI and desktop components, including Hyprland, Waybar, SDDM, Plymouth, Mako, Walker, Fcitx5, and related user services
- SwayOSD, hardware drivers, Elephant widgets, and other desktop-bound integrations
- `omarchy-fish`, `omarchy-zsh`, and `omarchy-walker`
- `drives` functions such as `iso2sd` and `format-drive`
- `transcoding` functions for video and image conversion
- Hunk-dependent `tds` and `hds` layouts
- Omarchy's `open` and `a` shell helpers, which depend on desktop launchers or `omarchy-agent`
- Hardware-focused tooling and desktop automation
- Theme switching infrastructure not needed for fixed per-surface themes
- Shell or app packages outside the chosen Bash plus terminal-tooling baseline

## Out Of Scope

The following do **not** belong in EyrWSL:

- Shared AI agent runtime configuration (belongs in EyrAgents)
- Omarchy desktop customizations such as Hyprland bindings (belong in EyrArcHy)
