# Deviations

## Purpose

This document records the intentional differences carried by EyrWSL relative to [Omarchy](https://github.com/omacom/omarchy), and defines the boundary between this repo and its siblings.

Omarchy tag `v4.0.0` at commit `f0020448ca87329199de7cb12f2015ebc4a3e5e7` is the reproducible upstream comparison baseline. The lightweight tag names the release, while the commit ID records the exact reviewed source. Reference clones and the tag are maintenance inputs only; setup, Stow deployment, and verification do not use them.

## Deviation Policy

Omarchy is an opinionated Arch Linux distribution targeting a full desktop environment with Hyprland, systemd user services, GUI applications, and hardware-specific integrations. This repo extracts the terminal-layer configuration that remains useful inside WSL and restructures it into GNU Stow packages.

**Guiding principles:**

1. **Follow Omarchy conventions by default.** Aliases, keybindings, and tool choices should stay close to Omarchy unless a documented workflow, WSL or non-desktop constraint requires a change.
2. **Adapt only what breaks or does not apply.** Desktop-bound behavior, GUI launchers, and hardware workflows are omitted because they do not fit WSL.
3. **Keep Windows-specific behavior explicit.** Anything that depends on `clip.exe`, `powershell.exe`, or Windows Terminal should be documented as a Windows interop concern.
4. **Use GNU Stow for dotfile management.** Omarchy uses direct file copies and packaged assets. This repo uses symlink-based package ownership for clearer separation and reuse.
5. **Single theme, no switching.** This repo uses Gruvbox only, so Omarchy's theme switching and hot-reload infrastructure is intentionally omitted.
6. **Pacman-first package ownership.** System packages, `mise` included, come from official Arch repositories. Claude Code, Codex, OpenCode, and Hermes Agent are installed and updated through mise, as on Omarchy, so they track upstream releases directly. Herdr uses its canonical standalone installer only while an official package is unavailable. The baseline depends on no AUR packages and installs no AUR helper.

## Reference Sources

- [omacom/omarchy](https://github.com/omacom/omarchy) - main repo for bash, native Herdr conventions, starship, git, fastfetch, btop, and editorconfig references; copied desktop launch recipes remain out of scope
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
- [LazyVim Docs](https://www.lazyvim.org/) - installation, extras, and plugin conventions
- [Neovim Docs](https://neovim.io/doc/) - options, API, and Lua reference
- [lazy.nvim Docs](https://lazy.folke.io/) - plugin manager configuration
- [Git Docs](https://git-scm.com/docs) - config options and behavior
- [btop](https://github.com/aristocratos/btop) - config options and themes
- [fastfetch Wiki](https://github.com/fastfetch-cli/fastfetch/wiki) - modules and JSON config

Gruvbox follows Omarchy's behavior on each owned surface. Windows Terminal and btop use the semantic palette from `themes/gruvbox/colors.toml`; Neovim selects `ellisonleao/gruvbox.nvim`; Yazi uses ANSI names resolved through Windows Terminal. OpenCode's `system` theme is selected by EyrAgents and inherits the same terminal palette.

## Intentional Deviations

### Environment Target

- Arch Linux inside WSL2 with active Windows interop, not WSL1 or a full Omarchy desktop.
- Desktop services, GUI launchers, display manager integration, and Hyprland-specific behavior are intentionally excluded.
- Nerd Font rendering is a Windows-side concern. Windows Terminal uses the Windows-installed JetBrainsMono Nerd Font; WSL needs no Linux font package.

### Dotfile Management

- GNU Stow with symlinked package ownership replaces Omarchy's file-copy and package-install model.
- `make clean` derives active owned paths from package files and carries exact retired mappings independently of Git and `PACKAGES`: `.config/bash/functions/{tdw,tmux,herdr}`, `.config/tmux/tmux.conf`, and the former `.config/tmux` fold. The `~/.config/bash/functions/herdr` endpoint maps only to this clone's former `bash/.config/bash/functions/herdr`. It classifies all endpoints and parents before changing anything and never traverses a queued fold. It removes only owned folds, recognized dangling active-package links, and exact retired links into this clone; other live leaf links stay for Stow. Retired paths do not use a broader stale-clone heuristic. Real directories and user data/state stay; regular files, foreign links, and special files at owned endpoints abort untouched. Use guarded clean, preview, then restow; restow itself does not retire links. Verification is read-only after pull and pending known source deletions, without exempting unrelated missing sources.
- Every host-writing Make target checks host and deployed-clone ownership before mutation; direct `scripts/wt-diff.sh --push` does so before destination discovery. The host guard requires WSL2, enabled `binfmt_misc`, an enabled `WSLInterop` or `WSLInterop-late` handler, resolving `clip.exe`/`powershell.exe`, and a successful five-second, no-profile PowerShell probe. `.NOTPARALLEL` serializes one Make invocation, not independent deployments or disk failures. Complete cleanup preflight is preservation-safe refusal, not a rollback transaction.
- `make verify` first checks the active WSL2/interoperability host contract, then runs `lint`, `check`, and `twins`, followed by the full verifier's command baseline, AI tools installed by and resolving through a paranoid-mode mise, deployed package ownership with real managed parents, GitHub no-reply Git identity, and owned config parsers and runtimes. `make check` runs the parser, runtime, and fixture parts anywhere.
- Retirement additionally refuses any still-present exact mapped source entry, including a dangling symlink; source directories containing unrelated retained data stay allowed. HOME and real retired-path ancestors must be caller-owned, readable/writable/searchable and not group/world-writable. Refusal precedes any unlink or repair; the metadata policy does not extend to unrelated active-package parents.
- Stow runs with `--no-folding`, so every managed parent stays a real directory that tools may write into and only leaf files are links.
- `/omasync` owns reference-clone maintenance and upstream comparison; `docs/maintenance.md` owns unresolved decisions, deferred work, active limitations, and dated evidence.
- `make refs` reports and keeps stale clones; listed default branches must reach exact fetched upstream parity by fast-forward. Atomic, non-forced fetches preserve existing local tags and annotations, import new tags, and prune only origin tracking branches. Checkout/merge use `--no-overwrite-ignore` so ignored files in listed clones are not overwritten. Ahead-only/divergent branches and tag/file conflicts refuse; resolution and any stale-clone disposal need separate review, including all refs, stashes, and ignored/untracked content before disposal.
- Local `make twins` checks worktree copies and can skip a missing sibling. `twins-pair` compares committed blobs at full `SELF_COMMIT` and `PEER_COMMIT` IDs without executing peer code. Those IDs and `SIBLING` travel as literal data, not Make expressions or shell source. CI normally uses the peer default branch; manual dispatch accepts an explicit full `peer_commit` only with `peer_reviewed=true` and records both actual commits. Publication evidence must validate the final published pair; operator attestation is not authorization to publish.
- Agent-tool verification approvals are handled by session or shared EyrAgents policy rather than repo-root project allowlists.

### Theme

- Gruvbox is configured on Windows Terminal, btop, and Neovim; ANSI-aware applications inherit the terminal palette. Omarchy's multi-theme plugin set and theme hot-reload infrastructure are omitted.

### Terminal

- Windows Terminal replaces Ghostty from the Omarchy desktop.
- Gruvbox colors, JetBrainsMono Nerd Font at size 9, and padding 14 mirror Omarchy's terminal appearance in `windows-terminal/settings.json`.
- The Gruvbox color scheme maps Omarchy's semantic terminal palette to all 16 ANSI colors, cursor, selection, foreground, and background.
- `defaultProfile` uses the dynamic profile name `archlinux`; host-specific profile entries are omitted, and the `Windows.Terminal.Wsl` generator is disabled so the current `Microsoft.WSL` profile is unambiguous.
- Windows Terminal settings are never stowed. `make wt-push` resolves the active Windows account through PowerShell, validates both files, creates a timestamped adjacent backup only when they differ, and atomically deploys the tracked file; `make wt-diff` reports normalized drift without changing either side.
- `alt+enter` remains unbound in `windows-terminal/settings.json` (`"id": null`) so Windows Terminal's fullscreen default does not swallow it. Omarchy's Herdr map also uses `Alt+Enter`; local tmux retirement does not change or deploy Terminal settings.

### Bash

- Config location is `~/.config/bash/` using an XDG-style layout instead of Omarchy's internal default path.
- Modular shell functions live in `~/.config/bash/functions/` and are sourced via a loop in `.bashrc`.
- Optional Bash overlays are sourced from `~/.config/bash-overlays/*` after the shared init. The directory is untracked and reserved for machine-local additions.
- Dropped aliases: `open` (GUI-only), `d='docker'`, and `r='rails'`.
- The kitty-conditional `ff` image-preview variant is omitted; Windows Terminal is not kitty, so the conditional would always take the plain `bat` branch kept here.
- `y()` is added for Yazi cd-on-exit support. Yazi is not part of Omarchy.
- `hdw <cc|cx|oc|ha> [-c]` creates and focuses a new workspace inside an already-running Herdr using the caller's current physical directory, not an inferred Git root. A populated tab or inactive source workspace is allowed with valid pane identity and selected-tab context; repeated calls and generated bottom-right-shell chaining each create another workspace. AI stays full-height left, Neovim above a shell equally stacked right, with equal columns and AI focus. Commands are `claude`, `codex`, `opencode`, or `hermes`; `-c` uses `claude -c`, `codex resume --last`, `opencode -c`, or `hermes -c`. This geometry intentionally differs from Omarchy's `hdl` recipe.
- Existing names/layouts remain untouched apart from normal global workspace focus. New naming stays with Herdr, with no `--label` or rename/metadata writes; the new default tab displays positional `1`. Bare `hdw` is usage. There is no workspace reuse, server startup, client attachment or roots registry. Old state/recovery files, including `${XDG_STATE_HOME:-$HOME/.local/state}/hdw/roots`, remain untouched and unused. Native Herdr controls own workspace/tab navigation.
- Cooperating calls are serialized; caller identity, pre-creation workspace inventory, the new root's opaque terminal identity, exact membership and complete geometry are checked before input. Cleanup may close only proven new split panes before possible input, never any workspace/tab/root/caller. A new workspace/root always remains on failure; possible input or uncertain ownership preserves remaining state with original/new recovery context. These are failure-preserving multi-call workflows, not server-side atomic transactions.
- `hdw` and its declared tests/fixture are byte-identical twins with EyrArcHy. Native Herdr binary/configuration/keymap remain; open it with `herdr`. EyrWSL does not carry copied Omarchy `hdl`/`hdlm`/`hsl`/`hds` recipes or `h`/`t` aliases, and sync must not import desktop launch helpers.
- Omarchy's SSH port-forwarding and dropped-connection recovery helpers are adopted; the reconnect helper's remote-tmux context remains valid without local tmux. `rsw <source> <destination>` keeps its interface but uses persistent inotify monitoring and event consumption during transfers, coalesces bursts, retries transfer failures after five seconds, and checks for reconciliation between transfers, 60 seconds after the last successful completion. It never adds `--delete`, so destination-only files remain. Startup reports readiness/PID/log path, not sync success; monitor/transfer failures are logged under `${XDG_STATE_HOME:-$HOME/.local/state}/rsw`. `lsw`/`dsw` manage only watchers started by this implementation via checked readiness/process records. SSH sockets use `XDG_RUNTIME_DIR/rsw-sockets`, falling back to `rsw-sockets` under the rsw state directory, not the credential-store tree. Runtime packages remain official `rsync` and `inotify-tools` plus the existing core utilities.
- `ga <branch>` creates beside the actual checkout root even from a subdirectory and checks branch/add/navigation failures. `gd` takes no arguments and uses Git worktree metadata, not a directory-name guess; it confirms the real path/branch, rechecks HEAD/branch, and refuses dirty work or commits not contained in the primary worktree's current HEAD before ordinary `git worktree remove` and `git branch -d`. Directory changes use `builtin cd` so the interactive zoxide alias cannot reinterpret reviewed paths. A failed navigation preserves the created checkout; failed branch deletion retains the branch and reports the partial outcome. Force is a separate manual decision, not a helper option.
- Interactive Bash exports `OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1` and `OPENCODE_ENABLE_EXA=1` so terminal-launched OpenCode skips the Claude Code skill copies, reads `.agents/skills` natively, and exposes its configured web-search tool. EyrAgents owns OpenCode configuration; this repo owns the WSL host environment. Shell initialization removes inherited `$HOME/.opencode/bin` entries and appends the user-level directories after existing system entries, so system binaries retain precedence: `/usr/local/bin`, then the mise shims and `~/.local/bin` in the order Omarchy's `env-bootstrap` uses.
- The AI tools load applicable EyrAgents settings. EyrWSL carries no Omarchy AI launch aliases (`c`, `cx`, `cy`, `ic`, `ix`, `icx`); `hdw` sends full `claude`, `codex`, `opencode`, or `hermes` commands with only the selected continuation form. Its `cc`/`cx`/`oc`/`ha` arguments are not aliases or an isolated harness profile. ArcHy's stock shortcut flags apply only to those stock launches, not `hdw`.
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

### Native Herdr Only

- EyrWSL omits local tmux from the baseline package list, Stow configuration, Bash helpers (`tdw`, `tdl`, `tdlm`, `tsl`) and `t` alias. Copied Herdr recipes and alias `h` are also omitted, not the native Herdr application. The 42 baseline packages stay. Omarchy's desktop tmux remains upstream-owned, outside EyrWSL.
- Source retirement does not uninstall an existing host package or kill sessions. Actual WSL retirement follows the guarded [host procedure](docs/maintenance.md#wsl-host-pass), preserving sessions, real directories and user state; inspect installed package ownership and reverse dependencies before exact package-removal approval. Do not force dependencies, use blanket `-Rns`/orphan cleanup, or overwrite Terminal settings for this migration.

### Neovim

- `lua/config/options.lua` keeps Omarchy's `vim.opt.relativenumber = false` and `vim.g.autoformat = false` baseline and adds a WSL/`powershell.exe`-guarded clipboard provider for both `+` and `*`. Argv arrays use `-NoLogo -NoProfile -NonInteractive`, explicit UTF-8 without BOM on both pipes, and terminating errors. Copy uses `Set-Clipboard` and clears empty input; paste uses `Get-Clipboard -Raw`, casts null to empty, and strips CR. `clip.exe` is not this provider's dependency. Windows PowerShell behavior still needs the live host pass; Unicode mocks do not prove it.
- The `nvim/` package owns the complete LazyVim bootstrap, static configuration, and generated `lazy-lock.json`; setup requires no separate Neovim configuration clone.
- `all-themes.lua` and `omarchy-theme-hotreload.lua` are omitted because Neovim uses a fixed Gruvbox configuration.
- Kept verbatim from `omarchy-nvim`: `disable-news-alert.lua`, `snacks-animated-scrolling-off.lua`, `vim.opt.relativenumber = false`, and `vim.g.autoformat = false`.
- `transparency.lua` content is verbatim from `omarchy-nvim` but lives at `after/plugin/` instead of upstream's `plugin/after/` to use Neovim's actual after-load mechanism. Upstream `omarchy-nvim` uses the incorrect path.
- Owned Lua files use 2-space indentation per the shared `.editorconfig` in this repo. Upstream `omarchy-nvim` uses tabs. Contents are otherwise unchanged.
- The vault plugin specs are `obsidian.lua` (obsidian.nvim against the vault at `~/Projects/vault`, override with `OBSIDIAN_VAULT`) and `render-markdown.lua` (visual markdown rendering companion). `python` is in the baseline package list because the vault keybindings shell out to the vault's `normalize.py`.
- `git-review.lua` overrides only Snacks `gd`, `gD`, and `gs` review mappings, choosing the current file/directory or Neo-tree selection's Git root on each invocation, resolving symlink targets and supporting linked worktrees. Empty/special non-explorer buffers use window cwd; a known non-Git target warns without falling back to an unrelated repository. No global/window directory change is introduced. The spec and mocked regression suite are byte-identical twins with EyrArcHy.
- The spec's `open.func` routes `obsidian://` and web URIs through Windows interop (`powershell.exe Start-Process`) when running under WSL, so `:Obsidian open` and link-following reach the Windows apps without `wsl-open`, which is not in official Arch repos. The override is guarded by `vim.fn.has("wsl")` and inert elsewhere. Both repos track byte-identical copies of the spec.

### Mise

- The `mise/` package stows four AI wrappers into `~/.local/bin`. Claude Code, Codex and OpenCode retain the `omarchy-mise-install` form minus its cooldown override. Hermes uses the same mise/PyPI ownership as Omarchy's specialised installer, with uv installed first and Python 3.13 options persisted in host configuration so `mise up` retains them. It does not import desktop takeover/removal, zero cooldown or forced repair. Omarchy regenerates its wrappers; EyrWSL deploys its wrappers with Stow. `~/.config/mise/config.toml` and `~/.local/share/mise` remain host state.
- The release cooldown stays at mise's 24-hour `minimum_release_age` default in the wrappers and `mup`. Omarchy sets it to zero in exactly two places, its generated wrappers and `omarchy-update-mise`, so an AI tool release is usable the hour it ships, while every other tool it installs through mise (the default agent, Node, the dev-env runtimes) waits out the default; this repo keeps the default everywhere and accepts the day's delay as the supply-chain guard mise documents it as.
- Paranoid mode is on through the stowed `~/.config/mise/conf.d/eyrwsl.toml`. Omarchy runs mise with default trust and trusts `~/Work/.mise.toml` and every worktree automatically; here global configs stay implicitly trusted and every project-level config needs an explicit `mise trust`, prompted again when the file changes.
- `mise` comes from the official `extra` repository instead of Omarchy's `mise-bin` package.
- The four AI tools and Hermes's uv dependency go through mise. Omarchy's other mise-managed tools are omitted: the wrappers for `gh`, `crush`, `gemini`, `copilot`, `playwright`, `pi`, `omp`, `grok`, `ghui`, and `hunk` at the pin (`agy` replacing `gemini`, `hey`, and `ori` since), the global Node runtime, and the language runtimes `omarchy-install-dev-env` adds on request; `gh` comes from the official `github-cli` package.
- Omarchy's `~/Work/.mise.toml` and global Node.js install (`mise-work.sh`) are omitted. Claude Code, Codex and OpenCode use prebuilt binaries; Hermes has its own Python 3.13 environment managed through uv/mise. Node.js belongs to optional EyrAgents verification and Hermes modern-TUI prerequisites, not EyrWSL's terminal baseline.
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
- The README separates Windows/PowerShell, Arch root bootstrap, and normal-user setup. It documents current stable WSL, official Arch `wsl --install archlinux` with a verified official-image fallback, Windows Terminal and Nerd Font installation, preserved `/etc/wsl.conf` sections, UTF-8 locale, no-reply Git identity, preview-first Stow, and preservation-first upgrades. Optional EyrAgents remains a separate deployment; live installation assumptions stay pending in the host-pass ledger.
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

- Shared AI agent runtime configuration (belongs in EyrAgents)
- Omarchy desktop customizations such as Hyprland bindings (belong in EyrArcHy)
