# EyrWSL

Self-contained Arch Linux dotfiles for WSL, adapted from [Omarchy](https://github.com/omacom/omarchy), managed with [GNU Stow](https://www.gnu.org/software/stow/).

EyrWSL carries the full terminal baseline for Arch Linux running inside WSL, plus the WSL and Windows-specific pieces: Windows Terminal and clipboard integration. It keeps Omarchy's terminal tooling and general feel while dropping desktop-specific components that do not apply inside WSL.

Eyrie is the shared project habitat, reflected locally in `~/Projects/eyrie/`. `Eyr` is its shortened family prefix, used by EyrAgents, EyrArcHy, and EyrWSL.

## Repo Family

Derivation model for this repo family:

```text
AI agent harness                → EyrAgents
Omarchy + personal deviations   → EyrArcHy
Omarchy + WSL deviations        → EyrWSL
```

- [`eyragents`](https://github.com/peregrinus879/eyragents) - AI agent harness: Claude Code, Codex, and OpenCode settings, shared guidance, and commit workflow
- [`eyrarchy`](https://github.com/peregrinus879/eyrarchy) - Personal Omarchy customizations: Bash overrides, Hyprland bindings, Neovim plugins, and Yazi
- [`eyrwsl`](https://github.com/peregrinus879/eyrwsl) - Self-contained WSL Arch environment: terminal baseline plus Windows Terminal and clipboard integration

Local clones live side by side under `~/Projects/eyrie/`.

## Stack

- **Shell**: [Bash](https://www.gnu.org/software/bash/)
- **Prompt**: [Starship](https://github.com/starship/starship)
- **Terminal Workspaces**: [Tmux](https://github.com/tmux/tmux), [Herdr](https://github.com/herdrdev/herdr)
- **AI Tools**: [Claude Code](https://code.claude.com/docs), [Codex](https://github.com/openai/codex), and [OpenCode](https://github.com/anomalyco/opencode), installed and updated through [mise](https://mise.jdx.dev/)
- **Editor**: [Neovim](https://github.com/neovim/neovim) ([LazyVim](https://github.com/LazyVim/LazyVim))
- **Version Control**: [Git](https://git-scm.com/), [GitHub CLI](https://cli.github.com/), [LazyGit](https://github.com/jesseduffield/lazygit)
- **File Manager**: [Yazi](https://github.com/sxyazi/yazi), [eza](https://github.com/eza-community/eza), [zoxide](https://github.com/ajeetdsouza/zoxide)
- **Search and Preview**: [fd](https://github.com/sharkdp/fd), [fzf](https://github.com/junegunn/fzf), [bat](https://github.com/sharkdp/bat), [ripgrep](https://github.com/BurntSushi/ripgrep)
- **System Monitor**: [btop](https://github.com/aristocratos/btop)
- **System Info**: [fastfetch](https://github.com/fastfetch-cli/fastfetch)
- **Dotfile Management**: [GNU Stow](https://www.gnu.org/software/stow/)
- **Terminal**: [Windows Terminal](https://github.com/microsoft/terminal)
- **Theme**: [Gruvbox](https://github.com/ellisonleao/gruvbox.nvim)

## Package Layout

Each top-level directory is a GNU Stow package that symlinks into `$HOME`, except `windows-terminal/`, which is deployed separately:

```text
bash/              Shell config (.bashrc, .inputrc, .config/bash/)
btop/              System monitor config (btop.conf, themes/gruvbox.theme)
editorconfig/      Editor formatting rules (.editorconfig)
fastfetch/         System info config (config.jsonc)
git/               Git config (config, ignore)
mise/              AI tool wrappers (.local/bin/claude, codex, opencode) that install and run each tool through mise, plus the paranoid-mode fragment (.config/mise/conf.d/eyrwsl.toml)
nvim/              Self-contained Neovim config (bootstrap, lock, LazyVim config and plugins)
starship/          Prompt config (starship.toml)
tmux/              Tmux config (tmux.conf)
yazi/              File manager config (yazi.toml)
windows-terminal/  Windows Terminal settings.json, deployed explicitly, not stowed
```

Key ownership rules:

- `nvim/` owns the full Neovim config, including the LazyVim bootstrap and lockfile plus `lua/config/options.lua` with the built-in WSL clipboard integration
- `nvim/` includes the vault plugin specs (`obsidian.lua`, `render-markdown.lua`); the vault is expected at `~/Projects/vault` (override with `OBSIDIAN_VAULT`)
- Bash supports additive machine overlays through `~/.config/bash-overlays/*`; the directory is optional and reserved for untracked machine-local additions
- `mise/` owns the `~/.local/bin` wrappers for Claude Code, Codex, and OpenCode, the files `omarchy-mise-install` writes on Omarchy minus its release-cooldown override, and the `~/.config/mise/conf.d/eyrwsl.toml` fragment that turns on mise's paranoid mode; each wrapper installs its tool through mise on first run, and mise's other files (`~/.config/mise/config.toml`, `~/.local/share/mise`) are host state the wrappers create
- The AI tools run as EyrAgents configures them; Omarchy's launch aliases are not carried
- Interactive Bash exports `OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1` and `OPENCODE_ENABLE_EXA=1`, so OpenCode skips the Claude Code skill copies and reads `.agents/skills` natively; EyrAgents owns OpenCode runtime configuration
- EyrAgents owns shared OpenCode runtime and TUI configuration; its `system` theme selection inherits the Windows Terminal ANSI palette
- `windows-terminal/` stays Windows-side and intentionally tracks the full paste-ready `settings.json`; setup deploys it through idempotent, backup-first `make wt-push`

## Setup

### 1. Windows and WSL

EyrWSL targets current Windows 11 or a supported Windows 10 release with WSL2. Open PowerShell as Administrator, install Windows Terminal and the Nerd Font, and confirm Arch is listed online:

```powershell
winget install --id Microsoft.WindowsTerminal --exact --accept-package-agreements --accept-source-agreements
winget install --id DEVCOM.JetBrainsMonoNerdFont --exact --accept-package-agreements --accept-source-agreements
wsl --list --online
```

Windows Terminal uses the Windows-installed Nerd Font directly. WSL does not need a separate Linux font package for `tmux`, `nvim`, `yazi`, `starship`, or `fastfetch` icons to render correctly.

On a fresh Windows host, this command enables WSL and installs Arch instead of the default Ubuntu distribution:

```powershell
wsl --install -d archlinux
```

Restart Windows if prompted. If WSL is already enabled, update it before installing Arch with the same distro-specific command:

```powershell
wsl --update
wsl --install -d archlinux
```

After installation, require WSL2, make Arch the default distribution, and inspect the result:

```powershell
wsl --update
wsl --set-default-version 2
wsl --set-version archlinux 2
wsl --set-default archlinux
wsl --status
wsl --list --verbose
```

`wsl --list --verbose` must report `archlinux` at version `2` before continuing.

### 2. WSL Initial Setup

Launch Arch. The first shell runs as root. Set a root recovery password before creating the daily user, then update the system and install the bootstrap tools:

```bash
passwd
pacman -Syu
pacman -S --needed git neovim openssh sudo
useradd -m -G wheel -s /bin/bash <username>
passwd <username>
EDITOR=nvim visudo
```

Uncomment this line in `visudo`:

```text
%wheel ALL=(ALL:ALL) ALL
```

Open `nvim /etc/wsl.conf`, then set the default user and keep Windows interop enabled:

```ini
[user]
default = <username>

[interop]
enabled = true
```

Exit the root shell, then terminate only Arch from PowerShell so `/etc/wsl.conf` is applied without stopping unrelated distributions:

```powershell
wsl --terminate archlinux
wsl -d archlinux
```

Confirm the new shell opens as `<username>`, and run `sudo -v` before continuing.

### 3. Locale

Edit `/etc/locale.gen`, uncomment `en_US.UTF-8 UTF-8`, then generate the locale:

```bash
sudo nvim /etc/locale.gen
sudo locale-gen
sudo nvim /etc/locale.conf
```

Set the following value in `/etc/locale.conf`, then start a fresh WSL shell:

```ini
LANG=en_US.UTF-8
```

### 4. Prerequisites

Install the baseline packages required by these dotfiles:

```bash
sudo pacman -S --needed 7zip bash-completion bat btop curl diffutils eza fastfetch fd file findutils \
  fzf gcc git github-cli gum inetutils inotify-tools jq lazygit less lua make man-db man-pages mise \
  neovim openssh procps-ng python ripgrep rsync shellcheck starship \
  stow sudo tmux tree-sitter-cli unzip util-linux which yazi zoxide
```

All baseline packages come from official Arch repositories. `mise` installs and updates the AI terminal tools through the stowed wrappers (section 10), as it does on Omarchy. The local documentation baseline uses `man-db` and `man-pages`, and 7-Zip enables Yazi archive previews and extraction. Windows interoperability handles host integration, so this terminal baseline does not add the desktop-oriented `xdg-utils`. This repo intentionally depends on no AUR packages and installs no AUR helper.

Verify the exact baseline; successful closure prints no output. Resolve every reported package before continuing:

```bash
pacman -T 7zip bash-completion bat btop curl diffutils eza fastfetch fd file findutils \
  fzf gcc git github-cli gum inetutils inotify-tools jq lazygit less lua make man-db man-pages mise \
  neovim openssh procps-ng python ripgrep rsync shellcheck starship \
  stow sudo tmux tree-sitter-cli unzip util-linux which yazi zoxide
```

For Yazi image, video, PDF, SVG, and extended archive previews, optionally install the official media helpers:

```bash
sudo pacman -S --needed ffmpeg imagemagick poppler resvg
```

These helpers are optional and are not required by `make verify`.

Herdr is not packaged in the official Arch repositories; recheck the exact package name first:

```bash
pacman -Si herdr
```

Proceed with its canonical user-level installer only while the probe reports `package not found`:

```bash
curl -fsSL https://herdr.dev/install.sh | sh
```

Package ownership is Pacman-first. Before future reinstalls, recheck the official repositories; if `herdr` becomes packaged, replace the standalone installation with the official package.

Claude Code, Codex, and OpenCode are not installed in this step. The `mise/` package stows one wrapper per tool into `~/.local/bin`, and each wrapper installs its tool through mise the first time it runs (section 10). On an existing installation, identify each executable and its package ownership before proposing changes. Preserve a specifically reviewed conflicting launcher under an unused backup name if needed; keep versions stores until the replacement works. No blanket package removal, native-install deletion, or auth/config cleanup is a prerequisite. Authentication and subscriptions are separate from installation; complete interactive sign-in only after the shell configuration is stowed.

### 5. Clone

Create the parent directory and clone EyrWSL. EyrAgents is optional and recommended when this host will run Claude Code, Codex, or OpenCode with the shared agent harness:

```bash
mkdir -p ~/Projects/eyrie
git clone https://github.com/peregrinus879/eyrwsl.git ~/Projects/eyrie/eyrwsl
git clone https://github.com/peregrinus879/eyragents.git ~/Projects/eyrie/eyragents
```

Skip the EyrAgents clone for an EyrWSL-only installation. EyrWSL can be cloned elsewhere; adjust the commands below to match its location. EyrAgents deploys itself: run `make stow` in its clone after this repository is stowed.

### 6. Neovim Ownership

The `nvim/` package includes the complete LazyVim bootstrap, static configuration, and generated plugin lockfile. Setup requires no separate Neovim configuration clone.

### 7. Private Git Identity

Tracked Git config intentionally excludes `[user]` identity. Create a local untracked file before using Git:

```bash
mkdir -p ~/.config/git
```

Create `~/.config/git/config.local` with your local identity:

```ini
[user]
  name = Your Name
  email = your-email@example.com
```

### 8. Prepare

Checklist before stowing:

- Required packages are installed
- EyrWSL was cloned locally
- `~/.config/git/config.local` exists with your local Git identity
- Any existing conflicting files were reviewed and moved or merged

Preview and run the guarded preparation from the intended normal-user clone:

```bash
cd ~/Projects/eyrie/eyrwsl
make dry-run
make clean
make dry-run
```

Preparation derives the owned paths from the package files and checks every one before changing anything. It removes only folded directory links left by a folding deployment and dangling links left by a moved or deleted clone; live leaf links stay for Stow to manage. A regular file, a foreign or unrecognized link, or a special file at an owned path aborts the entire run without partial removal. Compare and move or merge the reported conflict, then rerun `make clean`.

Preparation requires WSL2 with active Windows interop: enabled `binfmt_misc`, an enabled `WSLInterop` or `WSLInterop-late` handler, `clip.exe` and `powershell.exe` on PATH, and a successful five-second no-profile PowerShell probe. Configuration intent in `wsl.conf` is not enough. Every host-writing target checks the deployed clone and managed parents before mutation; `make clean` is a guarded mutation, not a force/adopt operation.

A fresh Arch user normally has a regular `~/.bashrc` from `/etc/skel`, so expect the first preparation run to report it. Compare any needed local content, move or merge it deliberately, and rerun `make clean`; the script never replaces it automatically.

### 9. Stow

Link every package as the normal user from the intended clone, not through `sudo` (the Makefile owns the package list):

```bash
cd ~/Projects/eyrie/eyrwsl
make stow
```

Stow runs without directory folding, so `~/.config/bash`, `~/.config/nvim`, and the other managed parents stay real directories that tools may write into; Stow reports any conflicting regular file without changing it. When EyrAgents is cloned, run `make stow` in its clone next so its packages are linked. Start a new terminal session, or run `source ~/.bashrc`, for the shell config to take effect.

### Unstow

```bash
cd ~/Projects/eyrie/eyrwsl
make unstow
```

### Dry Run

Preview what stow would do without making changes:

```bash
cd ~/Projects/eyrie/eyrwsl
make dry-run
```

### Re-stow

To update symlinks after the repo content changes (same clone path):

```bash
cd ~/Projects/eyrie/eyrwsl
make restow
```

To migrate from a different clone path, inspect both working trees and preserve dirty/untracked work. Unstow from the clone that currently owns the deployed links before stowing the new one:

```bash
make -C /old/clone/path unstow
cd ~/Projects/eyrie/eyrwsl
make stow
```

If the old clone is no longer available, `make clean` (section 8) removes its dangling links; then run `make stow`.

### 10. First Launch

Open Neovim once to install the revisions recorded in the tracked lockfile:

```bash
nvim
```

Run `:LazyHealth`, confirm Gruvbox loads, then exit and open Neovim again to verify the lock is stable. If the vault is synced to a different path, export `OBSIDIAN_VAULT` before launching Neovim; otherwise the vault workflow expects `~/Projects/vault`. Vault synchronization and the vault's `normalize.py` are user-owned data, not installed by this repo.

Start each AI terminal tool once from a fresh shell and complete its own authentication flow. The stowed wrapper in `~/.local/bin` runs `mise use -g` for its tool, which installs the current release under `~/.local/share/mise` and records the `latest` pin in `~/.config/mise/config.toml`, then starts the tool; interactive shells afterwards resolve the tool through `mise activate` and skip the wrapper:

```bash
claude
codex
opencode
```

These wrappers keep mise's default 24-hour release cooldown (`minimum_release_age`), so a release installs the day after it ships, and the `mup` alias (`mise up`) keeps it too; Omarchy opts its AI tool wrappers and updater out of that cooldown while its other mise-managed tools wait it out, and here nothing opts out. Paranoid mode is on through the stowed `~/.config/mise/conf.d/eyrwsl.toml`: global configs stay implicitly trusted, and a project-level `mise.toml` or `.tool-versions` is refused until `mise trust` accepts it. `mise ls` lists the installed versions.

Authentication failures do not indicate a dotfile deployment failure; resolve account access with the tool provider before testing `tdw` or `hdw`.

### 11. Windows Terminal

Launch Windows Terminal once so its settings file exists, then review `make wt-diff` and the complete tracked replacement. The helper replaces the full file, including unrelated profiles or settings, so obtain explicit approval before `make wt-push`:

```bash
cd ~/Projects/eyrie/eyrwsl
make wt-diff
# Only after reviewing and approving the full-file replacement:
make wt-push
make wt-diff
```

`make wt-push` resolves the active Windows account through PowerShell and validates both JSON files. If they already match, it exits without writing anything. If they differ, it creates a timestamped `settings.json.backup-<timestamp>` beside the deployed file and atomically replaces the deployment with the tracked file. The following `make wt-diff` confirms there is no normalized drift after Windows Terminal's key-order rewrites.

Both `make wt-push` and direct `scripts/wt-diff.sh --push` require the active WSL2/interop and deployed-clone guards before destination discovery. A path override does not bypass those checks.

To roll back, copy the reported backup over the deployed `settings.json`. Delete obsolete backups manually after confirming the replacement is stable. Set `WT_SETTINGS` only when Windows Terminal uses a nonstandard settings path.

If automatic discovery is unavailable, open Windows Terminal settings JSON with `Ctrl+Shift+,`, preserve an exact backup, and review and approve the full tracked replacement before applying it manually. The deployed file normally lives at:

```text
%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json
```

After deployment, confirm the default profile resolves to `archlinux` and the font is JetBrainsMono Nerd Font at size 9. If Windows Terminal warns about a missing default profile, re-select it once in the settings UI. Settings UI saves can serialize the generated `archlinux` profile into the deployed file; review any reported drift with `make wt-diff` before approving another full-file push.

## Verify

Workspace fixtures exercise isolated tmux servers with fake agents and a Python-backed Herdr model. They cover creation, ownership, failure recovery and concurrency without using running user workspaces or real agents; rendered UI and actual-host activation remain separate checks.

The rsync fixture uses fake local monitor/transfer commands, not SSH or production endpoints. It checks literal source resolution, complete readiness publication, events during a successful transfer, burst coalescing, failure retry, missed-event reconciliation and watcher management. Normal checks shorten only the fixture's reconciliation interval to 10 seconds; `RSW_FIXTURE_REALTIME=1 bash tests/rsyncing.sh` exercises the unchanged 60-second interval. The Python guard requires Linux child-subreaper support and `/proc`: it owns detached descendants, uses bounded TERM/KILL cleanup, and removes state only after all children are reaped. Unverified cleanup fails and retains its reported diagnostic directory. Killing the guard itself with SIGKILL can leave descendants and state behind.

After stowing or changing owned packages:

- Run `make lint` and `make check` after any change; both are repository-only (ShellCheck; every owned Bash, Lua, TOML, JSON, JSONC, Git, tmux, btop, and Fastfetch config in `repo` mode; the `tests/` fixtures). GitHub Actions runs them on pushes to `main` and pull requests, plus an exact committed twin-pair check against EyrArcHy's fetched default branch.
- Run `make verify` from the repo root on the WSL host after stowing or changing owned packages: the active WSL2/interop host guard first, then `lint`, `check`, and `twins`, followed by `scripts/verify.sh` in `full` mode (command baseline, the three AI tools installed by mise and resolving through it, every Git-visible Stow source resolving into this repo with its managed parents real directories, a GitHub no-reply Git identity that is never printed, and every owned config).

Complete these manual fresh-session checks:

- With disposable local source/destination directories, start `rsw <source> <destination>`, note its PID/log path, and confirm changes during a transfer eventually arrive. Readiness is not sync success: inspect logs for transfer/monitor failures and retries. Reconciliation is checked between transfers, 60 seconds after the last successful completion. Monitor death stops the watcher after the current transfer returns and requires inspection/restart; a stalled transfer can delay this indefinitely. `lsw` and `dsw` manage only watchers started by this implementation; do not assume an older watcher stopped. No `--delete` is used, so destination-only files remain.
- In a disposable Git fixture, check `ga <branch>` from a subdirectory and `gd` from the resulting linked worktree, including the normal shell's `cd` alias. `gd` confirms the actual path/branch, requires its HEAD to be contained in the primary worktree's current HEAD, refuses dirty work and never forces removal; a failed branch deletion reports that the branch was retained. The primary worktree need not be on a branch named `main`. Do not use a real working branch as a removal test.
- Confirm the core symlinks and local Git identity exist: `test -L ~/.bashrc && test -L ~/.config/starship.toml && test -L ~/.config/nvim/lua/config/options.lua && test -f ~/.config/git/config.local`
- Start a fresh shell and confirm Bash, Starship, and Tmux load without errors.
- Confirm `printenv OPENCODE_DISABLE_CLAUDE_CODE_SKILLS` and `printenv OPENCODE_ENABLE_EXA` each print `1`.
- Start a fresh shell and confirm `alias claude c cx cy ic ix icx` reports no alias for any of them: the AI tools run as EyrAgents configures them.
- Confirm `type tdw` and `type hdw` show the workspace functions. From a project directory, `<tdw|hdw> <cc|cx|oc> [-c]` creates a project-named session/workspace with a new window/tab named `claude`, `codex`, or `opencode`; `-c` continues that agent's last conversation. AI stays full-height left, editor/shell equally stacked right, with equal columns and agent focus. Bare invocation preserves existing workspace names/layouts while attaching or focusing. New tmux titles retain host, project session, and agent window as `#h:#S:#W`.
- Workspace creation is serialized and validates the full layout before sending input; failures stop clearly and cleanup targets only that invocation's creation. Herdr starts headless when needed; failed startup returns failure with manual-start guidance, not a plain-attach success. If rollback is unverified, inspect the reported pending identity and any retained `hdw` roots snapshot before retrying; do not delete unfamiliar workspaces or recovery files.
- Confirm `type hdl`, `type hdlm`, and `type hsl` show the other Herdr workspace functions. `hds` is intentionally unavailable because it requires Hunk.
- Confirm `mise ls claude codex opencode` lists an installed version of each tool, and `command -v claude codex opencode` resolves every one under `~/.local/share/mise` (interactive shells, through `mise activate`) or to its `~/.local/bin` wrapper; `make verify` fails when a tool is missing from mise or resolves elsewhere.
- Confirm `mise settings get paranoid` prints `true` and `mise settings get minimum_release_age` reports that the setting is not set, so the 24-hour default applies; `make verify` checks paranoid mode in full mode.
- Run `nvim` once and confirm plugins install successfully and Gruvbox loads.
- In Neovim, verify both `+` and `*` registers with disposable ASCII, Arabic/CJK, accented and supplementary-plane text through a Windows application, including multiline/CRLF, empty contents, and trailing newlines. Paste strips every CR, normalizing CRLF to LF; this is not byte-for-byte preservation. The provider uses PowerShell with explicit UTF-8 and no profile for both directions, not `clip.exe`. Do not inspect pre-existing clipboard content; mocks are not evidence that this Windows boundary passed.
- If the vault is synced to this machine, open a vault note and confirm obsidian.nvim loads (`<leader>oo` opens the note switcher).
- In OpenCode, run `/theme` and confirm `system` is selected so the TUI inherits Windows Terminal's Gruvbox ANSI palette.
- Confirm Windows Terminal uses JetBrainsMono Nerd Font at size 9 and the Gruvbox color scheme after applying `windows-terminal/settings.json`.

## Troubleshooting

- **WSL or Arch does not start**: Confirm hardware virtualization is enabled in UEFI, run `wsl --update` from elevated PowerShell, and repeat `wsl --status` and `wsl --list --verbose`. Do not continue until `archlinux` launches under WSL2.
- **Preparation reports a conflict**: Compare the reported path, move or merge any needed content, then rerun `make clean`. The script never deletes regular files, foreign links, or special files; the only dangling links it removes name a package path of this repo.
- **Host or clone guard refuses**: Confirm actual WSL2/interop and executable availability, not only `wsl.conf`. Run deployment from the clone owning the current links; preserve local edits before changing clone locations. Do not use fixture overrides or a force/adopt operation on the live home.
- **Neovim clipboard not working**: The provider requires WSL and `powershell.exe`, not `clip.exe`; both executables still belong to the repository's host gate. In a fresh normal-user WSL shell, check `command -v clip.exe powershell.exe` and run `powershell.exe -NoProfile -NonInteractive -Command '$PSVersionTable.PSVersion.ToString()'`. This probes execution, not clipboard correctness, and neither reads nor replaces the clipboard. Check `[interop]` in `/etc/wsl.conf` if resolution fails. Once interop works, use only disposable text for the manual clipboard checks above, never pre-existing clipboard contents.
- **Obsidian image paste unavailable**: `:Obsidian paste_img` expects `wl-clipboard` or `xclip`, which this WSL baseline does not install. Save the image through Windows or the vault's own workflow, then link or embed it from the note.
- **mise refuses a project config**: Paranoid mode is on. Review the file, then `mise trust` it; an edit to a trusted file prompts again.
- **An AI tool wrapper fails or hangs on first run**: The wrapper resolves and downloads the release through mise, which needs network access; rerun it, or run `mise use -g <tool>` directly to see mise's own error. `mise doctor` reports activation and PATH problems.
- **OpenCode does not match Windows Terminal**: Select `system` with `/theme`. When EyrAgents is installed, confirm `~/.config/opencode/tui.json` resolves into its `opencode` package.

## Maintenance

A repo-root `Makefile` keeps the package list in one place and wraps the routine commands. `stow`, `restow`, `clean`, `verify`, and `wt-push` run on the WSL machine; `lint`, `check`, `twins`, and `refs` run anywhere:

Every host-writing Make target checks host and deployed-clone ownership before mutation. Deployment goals are serialized within one Make invocation, including `make -j`; this is not rollback against I/O failure or independent concurrent deployments.

- `make stow` / `make unstow` / `make dry-run` / `make restow` - the stow command sets over the package list, without directory folding
- `make lint` - ShellCheck over the bash package, `scripts/`, and `tests/`; `.shellcheckrc` disables the upstream-derived warnings so new issues stand out
- `make check` - repository-only checks: `scripts/verify.sh` in `repo` mode over every owned config, then every fixture suite (runs in CI)
- `make twins` - twin-file sync against the EyrArcHy clone (`SIBLING`, default `~/Projects/eyrie/eyrarchy`); a missing sibling is reported as a skipped check
- `make twins-pair SELF_COMMIT=<full-sha> PEER_COMMIT=<full-sha> SIBLING=<peer-object-repo>` - read-only twin comparison of two exact full 40-character commit IDs; all three inputs remain literal data, missing objects/files fail, and no peer code executes. Replace the placeholders and quote the peer path; do not type angle brackets
- `make verify` - `lint`, `check`, and `twins`, then `scripts/verify.sh` in `full` mode (host, command baseline, mise-managed AI tools, deployment with real managed parents, no-reply identity, and every owned config); refuses off the WSL host
- `make test` - fake-home deployment, ownership, verifier, Windows Terminal, and reference-clone fixtures; the loop stops on the first failing suite
- `make clean` - WSL-only guarded stow preparation (`scripts/prepare-stow.sh`); leftover folded links and dangling clone links only, aborts before removing anything otherwise
- `make refs` - clone and fast-forward listed references to exact fetched upstream parity, repointing moved GitHub remotes; report and keep stale clones, never auto-delete them (`/omasync` step 1)
- `make wt-diff` - diff the tracked Windows Terminal settings against the deployed Windows-side file (normalized with `jq`, since Windows Terminal rewrites key order)
- `make wt-push` - after full-file review/approval, require active WSL2/interop and deployed-clone ownership, validate both settings files, back up a changed deployment, and atomically deploy the tracked file; direct `scripts/wt-diff.sh --push` has the same guard



Updates run in two steps, as Omarchy's updater does in one: `sudo pacman -Syu` updates the system, mise itself included (the packaged mise cannot self-update and says so when asked), and never touches the mise-managed tools; `mup` then brings Claude Code, Codex, and OpenCode current, the `mise up` call Omarchy runs after its package step, here without Omarchy's cooldown override, so a release counts once it is a day old. Under mise, Claude Code's native auto-updater is not in play; the tools change version only through mise.

`nvim/.config/nvim/lazy-lock.json` is generated but tracked. Update it only through an intentional Lazy sync, review the pinned revision changes, verify a clean headless bootstrap, and commit the lockfile with the plugin-spec change that required it.

Before running `make refs`, preview with `bash scripts/update-references.sh --dry-run` and approve any new clone or remote repointing separately. The preview can query GitHub but does not fetch or establish conflict-free upstream parity. Routine authorized refreshes remain the sync skill's work; atomic fetch does not make the whole family update transactional.

`make refs` refuses ahead-only/divergent listed default branches instead of calling them current. Its atomic, non-forced fetch preserves existing local tags and annotations, imports new tags, and prunes only origin tracking branches. Checkout and merge use `--no-overwrite-ignore`, preserving ignored files in listed clones. Tag/file conflicts refuse that update and require separate review; do not force a tag replacement or delete local files to make it pass. Stale references are informational and require separate review of all refs, stashes, and ignored/untracked files before any manual removal.

CI runs `make lint`, `make check`, and `twins-pair` on pushes to `main` and pull requests, using the peer default branch for normal runs. Manual workflow dispatch accepts an explicit full `peer_commit` only with `peer_reviewed=true`; it fetches peer objects without executing peer code and records both actual commits. This attestation is not publication authorization. For coordinated changes, verify the final published pair explicitly after both commits are available; a green check against an earlier peer is not final-pair evidence. Local `make twins` remains a worktree convenience check that can skip a missing sibling.

Periodically, review the local reference repos and official docs for upstream changes to owned packages, sync with `/omasync` or a manual comparison, and confirm every intentional difference is still documented in `DEVIATIONS.md`. Unresolved decisions, deferred work, active limitations, and dated evidence live in [docs/maintenance.md](docs/maintenance.md).

## Related Repos

Upstream comparison runs through the `/omasync` skill; `make refs` keeps the reference clones listed in `references.txt` current. Upstream URLs and official docs live in [DEVIATIONS.md](DEVIATIONS.md) (Reference Sources).

## Credits

Adapted from [Omarchy](https://github.com/omacom/omarchy). See [DEVIATIONS.md](DEVIATIONS.md) for intentional differences and boundary definitions.

## License

[MIT](LICENSE)
