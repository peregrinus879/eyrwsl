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
- `nvim/` also carries `git-review.lua`, the contextual Snacks diff/status mappings shared with EyrArcHy
- Bash supports additive machine overlays through `~/.config/bash-overlays/*`; the directory is optional and reserved for untracked machine-local additions
- `mise/` owns the `~/.local/bin` wrappers for Claude Code, Codex, and OpenCode, the files `omarchy-mise-install` writes on Omarchy minus its release-cooldown override, and the `~/.config/mise/conf.d/eyrwsl.toml` fragment that turns on mise's paranoid mode; each wrapper installs its tool through mise on first run, and mise's other files (`~/.config/mise/config.toml`, `~/.local/share/mise`) are host state the wrappers create
- The AI tools run as EyrAgents configures them; Omarchy's launch aliases are not carried
- Interactive Bash exports `OPENCODE_DISABLE_CLAUDE_CODE_SKILLS=1` and `OPENCODE_ENABLE_EXA=1`, so OpenCode skips the Claude Code skill copies and reads `.agents/skills` natively; EyrAgents owns OpenCode runtime configuration
- EyrAgents owns shared OpenCode runtime and TUI configuration; its `system` theme selection inherits the Windows Terminal ANSI palette
- `windows-terminal/` stays Windows-side and intentionally tracks the full paste-ready `settings.json`; setup deploys it through idempotent, backup-first `make wt-push`

## Setup

### Before You Begin

Use a supported Windows release, preferably current Windows 11, on an x86-64 PC with hardware virtualization enabled. [Microsoft's command-based WSL installation](https://learn.microsoft.com/en-us/windows/wsl/install) requires Windows 11 or Windows 10 version 2004/build 19041 or later; that technical minimum is not a promise that an old Windows release is still supported. Arch's official image requires **WSL2**, not WSL1. This guide uses current stable WSL, not preview releases, community Arch launchers, an Arch ISO, or an AUR helper.

- **Fresh Windows machine:** follow the numbered steps in order.
- **WSL installed, but no Arch distribution:** keep your other distributions; skip only WSL's initial installation command, then install Arch under your normal Windows account.
- **Arch or EyrWSL already installed:** read [Existing Installations](#existing-installations) first. Do not reinstall the distribution, recreate its user, reclone over an existing directory, or remove configuration/authentication directories to resolve conflicts.
- **Ownership:** EyrWSL owns this WSL terminal environment; optional EyrAgents owns the shared AI harness; EyrArcHy owns the Omarchy desktop and is not deployed on WSL. No sibling or reference clone is required to install EyrWSL.

Run commands one at a time and stop on an unexpected error. A code block's label names the machine, shell, user, and working directory where relevant. PowerShell commands are not Bash commands. An elevated Windows account is not the Linux `root` account. Do not type prompt prefixes such as `PS C:\>`, `$`, or `#`. In Bash, a trailing `\` continues a command onto the next line; paste those lines together, with nothing after the backslash.

`linuxuser` below is a placeholder for your chosen Linux login, for example `alex`: use lowercase letters without spaces and replace it consistently. It need not match your Windows or GitHub username. `~` and `$HOME` in Bash mean that Linux user's home, normally `/home/linuxuser`, not a Windows folder. Other placeholders are called out beside their examples; never type angle brackets as shell arguments.

### 1. Windows and WSL

In **Windows Settings > System > About**, check the system type and Windows version. In **Task Manager > Performance > CPU**, check that virtualization is enabled; if not, follow [Microsoft's virtualization guidance](https://support.microsoft.com/windows/c5578302-6e43-4b4b-a449-8ced115f58e1) and your PC manufacturer's UEFI instructions. On a managed PC, ask its administrator rather than bypassing policy.

Install or update **Windows Terminal (stable)** through the Microsoft Store under the Windows account you will use daily, following [Microsoft's Terminal installation guide](https://learn.microsoft.com/en-us/windows/terminal/install). Launch it once. Use its tab dropdown to select Windows PowerShell; tab titles can be customized, so do not rely on the title alone to identify the shell.

On the **Windows side**, download **JetBrainsMono** from the [Nerd Fonts downloads page](https://www.nerdfonts.com/font-downloads), extract the archive, and install the `JetBrainsMonoNerdFont-*.ttf` faces through the fonts' right-click **Install** action. Choose the family named **JetBrainsMono Nerd Font**, not the unpatched JetBrains Mono font. Restart Terminal after installing fonts. Linux font packages are unnecessary for icons rendered by Windows Terminal.

For a machine **without WSL**, open **Windows PowerShell as Administrator** from Start's right-click **Run as administrator** action. Accept the Windows elevation prompt, then run:

```powershell
wsl --install --no-distribution
```

This installs WSL and its required Windows features without also installing Ubuntu. Restart Windows when requested before continuing. Do not manually add legacy WSL kernel/WSLg MSI packages to a current WSL installation.

For both new and existing WSL installations, use **Windows PowerShell, Administrator** to update the WSL engine to stable:

```powershell
wsl --update
```

Close the elevated window. In **Windows PowerShell, normal Windows user**, inspect WSL and the official distribution catalog:

```powershell
wsl --version
wsl --list --verbose
wsl --list --online
wsl --set-default-version 2
```

**Checkpoint:** WSL component versions are reported and the online catalog contains `archlinux`. On a fresh host, "no installed distributions" is expected for the installed list. If `archlinux` already appears there, do not install it again. WSL's own release number from `--version` and each distribution's `VERSION` column (`1` or `2`) are different things.

Only when Arch is **not already installed**, run the official [Arch WSL installation command](https://wiki.archlinux.org/title/Install_Arch_Linux_on_WSL#Automated_installation) in **Windows PowerShell, normal Windows user**:

```powershell
wsl --install archlinux
```

`archlinux` is the official catalog name, not a guessed Store product name. Wait for download and extraction. Installation may open an Arch root shell; continue with step 2 there. If it does not, launch it with `wsl -d archlinux` from normal-user PowerShell. If the catalog/download is unavailable, use the [official image fallback](#wsl-installation-or-startup) rather than substituting a community distribution.

In a separate **Windows PowerShell tab, normal Windows user**, check registration:

```powershell
wsl --list --verbose
wsl --status
```

**Checkpoint:** `archlinux` is listed at version `2`; `Running` or `Stopped` is acceptable. Stop if it reports version `1`. Optionally run `wsl --set-default archlinux` in this same PowerShell tab if you want bare `wsl` to launch Arch instead of another distribution. This changes the Windows account's WSL default, not the other distribution's files.

### 2. WSL Initial Setup

This step is for a **new Arch installation**. The official image defaults to root; do not assume it has Ubuntu's username-creation wizard. In **Arch Bash, root**, check:

```bash
whoami
uname -m
```

Expect `root` and `x86_64`. If a daily user was already created, use it and check its sudo/default-user setup instead of recreating it.

In **Arch Bash, root**, set a root recovery password, then fully update Arch and install the bootstrap tools:

```bash
passwd
pacman -Syu --needed git neovim openssh sudo
```

`passwd` asks for the new password twice. Password entry displays no characters, not even asterisks. This is a Linux password, not your Windows PIN. Pacman shows the proposed packages and download/install sizes; read them, then answer `y` at `Proceed with installation? [Y/n]` to approve. Do not use `--noconfirm`, disable signature checking, or continue after an incomplete upgrade. For an older image, read [Arch's news](https://archlinux.org/news/) for required manual interventions first.

If you intend to run multiple systemd-enabled WSL distributions concurrently, read [Arch's current default-user/UID warning](https://wiki.archlinux.org/title/Install_Arch_Linux_on_WSL#Set_default_user) before creating another UID 1000 account. Choose a distinct unused UID at user creation where required, rather than renumbering an existing populated account later. A fresh host with only Arch can use the default below.

In **Arch Bash, root**, replace `linuxuser` with your chosen login before running:

```bash
useradd -m -G wheel -s /bin/bash linuxuser
passwd linuxuser
EDITOR=nvim visudo
```

`useradd` is normally silent: `-m` creates the home directory, `-G wheel` adds the administration group, and `-s` chooses Bash. `passwd linuxuser` sets the daily user's own Linux password. If `useradd` says the user exists, stop and inspect the existing account; do not delete it.

`visudo` opens the sudo policy safely in Neovim. Move with the arrow keys, press `i` to edit, then `Esc`, type `:wq`, and press Enter to save and exit. `Esc`, `:q!`, Enter abandons an edit. Use these same editor keys in later setup steps. Uncomment the password-required wheel rule, not the `NOPASSWD` variant.

**File content in `/etc/sudoers`, edited through `visudo` as Arch root, not a Bash command:**

```text
%wheel ALL=(ALL:ALL) ALL
```

If `visudo` reports a syntax error, choose `e` to edit again; do not force it to save invalid policy. In **Arch Bash, root**, validate the policy and open WSL's per-distribution configuration:

```bash
visudo -c
nvim /etc/wsl.conf
```

Expect `parsed OK` from `visudo -c`. In `/etc/wsl.conf`, preserve existing settings, including the image's `[boot]`/systemd settings. Add missing sections or edit their existing keys, without duplicating section headers. Keep automount/network defaults unless you already need a deliberate override.

**File content to merge into `/etc/wsl.conf` as Arch root; replace `linuxuser`:**

```ini
[user]
default = linuxuser

[interop]
enabled = true
appendWindowsPath = true
```

Interop permits Windows executables to run from Linux; `appendWindowsPath` makes `powershell.exe` and `clip.exe` discoverable. `/etc/wsl.conf` is a Linux file; it is not Windows' global `.wslconfig`. [Microsoft's WSL configuration reference](https://learn.microsoft.com/en-us/windows/wsl/wsl-config) documents these keys and restart behavior.

Save any work in Arch and type `exit` in its root Bash shell. In **Windows PowerShell, normal Windows user**, stop only Arch and reopen it:

```powershell
wsl --terminate archlinux
wsl -d archlinux
```

Termination stops **all processes in Arch**, not just one tab, and discards unsaved work. It does not delete the distribution or stop unrelated distributions. It is needed here to apply `/etc/wsl.conf`; simply opening another tab may reuse the running instance.

In the reopened **Arch Bash, normal Linux user**, check:

```bash
whoami
cd ~
pwd
id -nG
sudo -v
sudo whoami
command -v powershell.exe clip.exe
powershell.exe -NoProfile -NonInteractive -Command '$PSVersionTable.PSVersion.ToString()'
```

**Checkpoint:** `whoami` reports your login, `pwd` is `/home/linuxuser` with your replacement, the groups include `wheel`, and `sudo whoami` reports `root`. `sudo -v` asks for **your daily user's Linux password** and returns silently on success. Both Windows commands resolve, normally under `/mnt/c/Windows`, and PowerShell prints a version. Do not clone or run Stow as root. See [User and Sudo Recovery](#user-and-sudo-recovery) if these checks fail.

### 3. Locale

Use a generated UTF-8 locale. These examples choose `en_US.UTF-8`; substitute another UTF-8 locale consistently if preferred. In **Arch Bash, normal Linux user**, open the generator list:

```bash
sudo nvim /etc/locale.gen
```

Uncomment `en_US.UTF-8 UTF-8` by removing its leading `#`; preserve any other locales you need. Save and exit. In **Arch Bash, normal Linux user**:

```bash
sudo locale-gen
sudo nvim /etc/locale.conf
```

Expect a successful generation message for `en_US.UTF-8`. Set `LANG` in the file, preserving intentional other settings. Do not set `LC_ALL` permanently.

**File content in `/etc/locale.conf`, edited from Arch through `sudo nvim`, not a Bash command:**

```ini
LANG=en_US.UTF-8
```

WSL can otherwise choose a locale from Windows. Follow [Arch's WSL locale override](https://wiki.archlinux.org/title/Install_Arch_Linux_on_WSL#Adjust_locale): make `/etc/default/locale` a symlink to `/etc/locale.conf`. First inspect the path in **Arch Bash, normal Linux user**:

```bash
ls -ld /etc/default/locale
```

If it already points to `/etc/locale.conf`, leave it alone. If it is absent, continue below. If it is a regular file or a different link, review its non-secret locale settings first, then move only that path to an unused backup name with `sudo mv -i /etc/default/locale /etc/default/locale.pre-eyrwsl` in this same Bash shell. Answer **no** to any overwrite prompt and choose a different backup name. Do not overwrite it with `ln -sf`.

Only once `/etc/default/locale` is absent, run in **Arch Bash, normal Linux user**:

```bash
sudo ln -s /etc/locale.conf /etc/default/locale
```

Save work, exit Arch, then restart it in **Windows PowerShell, normal Windows user**:

```powershell
wsl --terminate archlinux
wsl -d archlinux
```

In the new **Arch Bash, normal Linux user**, verify:

```bash
locale -a
locale
locale charmap
```

**Checkpoint:** the available list includes `en_US.utf8`, `LANG` uses your selected locale, there are no locale warnings, and the character map is `UTF-8`.

### 4. Prerequisites

Install the baseline packages in **Arch Bash, normal Linux user**:

```bash
sudo pacman -Syu --needed 7zip bash-completion bat btop curl diffutils eza fastfetch fd file findutils \
  fzf gcc git github-cli gum inetutils inotify-tools jq lazygit less lua make man-db man-pages mise \
  neovim openssh procps-ng python ripgrep rsync shellcheck starship \
  stow sudo tmux tree-sitter-cli unzip util-linux which yazi zoxide
```

All packages in this command come from official Arch repositories; their normal dependencies are installed automatically. `--needed` skips already-current packages, while `-Syu` completes a full system upgrade. Read Pacman's transaction and any provider/replacement prompts before accepting. [Partial upgrades are unsupported](https://wiki.archlinux.org/title/System_maintenance#Partial_upgrades_are_unsupported): do not replace this with `pacman -Sy` followed by selective installs.

The baseline stays terminal-only: `inetutils` supplies `hostname`, `lua` supplies the Lua syntax verifier, `tree-sitter-cli` supports LazyVim, `python` supports repository checks and user-owned vault scripts, `man-db`/`man-pages` supply local documentation, and 7-Zip supports Yazi archives. No desktop `xdg-utils`, Linux font package, AUR package/helper, or Node runtime is added here. **Node.js is a separate prerequisite for optional EyrAgents**, not for these prebuilt AI tool binaries.

Verify the package list in **Arch Bash, normal Linux user**. Success prints nothing and returns to the prompt; every printed package name is an unmet dependency to resolve:

```bash
pacman -T 7zip bash-completion bat btop curl diffutils eza fastfetch fd file findutils \
  fzf gcc git github-cli gum inetutils inotify-tools jq lazygit less lua make man-db man-pages mise \
  neovim openssh procps-ng python ripgrep rsync shellcheck starship \
  stow sudo tmux tree-sitter-cli unzip util-linux which yazi zoxide
```

For Yazi image, video, PDF, and SVG previews, optionally install the official media helpers in **Arch Bash, normal Linux user**:

```bash
sudo pacman -Syu --needed ffmpeg imagemagick poppler resvg
```

These helpers are optional and are not required by `make verify`.

Herdr is also required by the full `make verify` command baseline. It uses its standalone installer only while no official Arch package is available. Recheck the package in **Arch Bash, normal Linux user**:

```bash
pacman -Si herdr
```

If the probe reports package metadata, use the official package (`sudo pacman -Syu --needed herdr` in this same Bash shell). Only if it reports `package 'herdr' was not found`, use the [canonical Herdr installer](https://herdr.dev/install.sh) below. A network or database failure is not evidence of package absence.

This command downloads and executes upstream code as your user, never with `sudo`; review the linked installer before choosing to run it. In **Arch Bash, normal Linux user**:

```bash
curl -fsSL https://herdr.dev/install.sh | sh
```

Expect installation under `~/.local/bin/herdr`. A warning that this directory is not yet on `PATH` is expected before EyrWSL is stowed; the fresh-shell check below confirms it later. Package ownership remains Pacman-first: recheck before a future standalone reinstall, and review any ownership migration rather than installing one copy over another.

Claude Code, Codex, and OpenCode are installed later by EyrWSL's mise wrappers. **Fresh installs should not also install their Pacman/native/npm versions.** Existing installations use the [migration guidance](#existing-installations), not blanket removal commands. Authentication and subscriptions are separate from binary installation.

### 5. Clone

Keep the clone in the Linux filesystem, not `/mnt/c`, a Windows Downloads folder, or a Windows-synced directory. It supplies live symlink targets after deployment, so do not delete or casually move it. In **Arch Bash, normal Linux user, from any directory**:

```bash
mkdir -p ~/Projects/eyrie
git clone https://github.com/peregrinus879/eyrwsl.git ~/Projects/eyrie/eyrwsl
```

The public HTTPS clone requires no GitHub login or token. If Git says the destination already exists, stop and use the existing-installation checks; do not delete the directory or clone into it again. In **Arch Bash, normal Linux user**:

```bash
cd ~/Projects/eyrie/eyrwsl
pwd
git status --short --branch
```

**Checkpoint:** the path is `/home/linuxuser/Projects/eyrie/eyrwsl` with your login, and status reports `main` tracking `origin/main` with no changed files on a fresh clone. Read `AGENTS.md`, `DEVIATIONS.md`, and `docs/maintenance.md` before deployment. EyrAgents is cloned separately in its optional step; EyrArcHy and `make refs` are not bootstrap requirements.

### 6. Neovim Ownership

The `nvim/` package includes the complete LazyVim bootstrap, static configuration, and generated plugin lockfile. **Do not clone LazyVim's starter or another Neovim config into `~/.config/nvim`.** If that directory already holds your own configuration, review the conflicts and preserve it before stowing. Do not delete plugin data or caches as a routine setup step.

### 7. Private Git Identity

Tracked Git config intentionally excludes `[user]` identity. **A GitHub no-reply address is mandatory**, not a personal/work inbox and not `your-email@example.com`. In GitHub's web UI, open **Settings > Emails**, enable **Keep my email addresses private**, and use the exact no-reply address GitHub displays. Its usual form is `ID+USERNAME@users.noreply.github.com`; some older accounts have `USERNAME@users.noreply.github.com`. Do not invent the numeric ID. See [GitHub's email reference](https://docs.github.com/en/account-and-profile/reference/email-addresses-reference#your-noreply-email-address).

In **Arch Bash, normal Linux user**, open the host-local file. If it already exists, preserve other settings and edit only the necessary identity fields:

```bash
mkdir -p ~/.config/git
nvim ~/.config/git/config.local
```

**File content in `~/.config/git/config.local`, edited as the normal Linux user, not a Bash command. Replace both example values with your name and GitHub-provided address:**

```ini
[user]
  name = Your Name
  email = 12345678+YOUR_GITHUB_USERNAME@users.noreply.github.com
```

This untracked host file belongs outside the repository. Do not put identity into `git/.config/git/config` or commit it. Read-only cloning does not require identity, but commits do. The include takes effect after Stow; the post-Stow check below verifies the effective identity without printing it.

### 8. Prepare

Start with a **read-only preview**, not cleanup. In **Arch Bash, normal Linux user, EyrWSL repository root**:

```bash
cd ~/Projects/eyrie/eyrwsl
make dry-run
```

This previews package links without creating them. A fresh Arch user normally has a regular `~/.bashrc` from `/etc/skel`, so an initial conflict is expected. Stow conflict output can return a nonzero status; read the reported paths rather than treating it as permission to overwrite them. Existing folded or dangling links may also prevent this first preview until guarded preparation. The preview does not run the deployment host guard: `make clean`, Stow's host-writing targets, and `make verify` require WSL2, enabled `binfmt_misc`, an enabled `WSLInterop` or `WSLInterop-late` handler, both Windows commands on `PATH`, and a successful five-second, no-profile PowerShell probe. A setting in `/etc/wsl.conf` alone does not establish active interop.

For a **reported regular `~/.bashrc` conflict only**, compare it in **Arch Bash, normal Linux user, EyrWSL repository root**:

```bash
ls -ld ~/.bashrc
diff -u ~/.bashrc bash/.bashrc
```

The `ls` permission field starts with `-` for a regular file; a symlink starts with `l` and shows `->` and its target. Do not use the regular-file example below for a link owned by another clone. `diff` returns status 1 when files differ, which is expected. Review local customizations privately; do not paste sensitive shell settings into reports. Once you have decided to replace this specific regular file, preserve it in a unique backup directory in **Arch Bash, normal Linux user**:

```bash
backup_dir=$(mktemp -d "$HOME/eyrwsl-backup.XXXXXX") &&
  mv -i -- "$HOME/.bashrc" "$backup_dir/bashrc" &&
  printf 'Preserved old Bash config in %s\n' "$backup_dir/bashrc"
```

Retain that backup until the new setup is verified. Add only still-needed, non-secret machine customizations to files under `~/.config/bash-overlays/`; do not source the entire old `.bashrc` from the new one. For other conflicts, compare the exact owned file and preserve it under an unused backup name outside the repository. Never move all of `~/.config`, delete an agent directory, use `stow --adopt`, or force symlinks to make the preview pass.

After reviewing all conflicts, run guarded preparation in **Arch Bash, normal Linux user, EyrWSL repository root**:

```bash
make clean
make dry-run
```

Despite its name, `make clean` is **not** a project-file deletion command. It classifies owned paths before changing them and removes only leftover folded links into this repo or recognized dangling links from an old clone. It refuses regular files, foreign links, and special files rather than replacing them. It is a mutation, unlike `make dry-run`; do not confuse it with `git clean`. Resolve a refusal, then rerun this pair in order. **Checkpoint:** preparation finishes, often with `nothing to remove`, and the final dry run has no conflict or ownership failure.

### 9. Stow

After the successful preview, link every package in **Arch Bash, normal Linux user, EyrWSL repository root**. Never use `sudo make stow`:

```bash
cd ~/Projects/eyrie/eyrwsl
make stow
```

Stow keeps managed parent directories real and links only their files; this protects the repository from generated host state. Once linked, edits in the clone affect live configuration before any commit. An error is not a completed deployment; resolve it and rerun the preview before retrying.

Open a **new Arch tab in Windows Terminal as the normal Linux user**, outside any existing tmux/Herdr session. A new tab is preferable to repeatedly sourcing `.bashrc`, which may retain old aliases and environment values. In that fresh **Arch Bash, normal Linux user**:

```bash
cd ~
readlink -f ~/.bashrc
command -v mise herdr nvim starship
mise settings get paranoid
printenv OPENCODE_DISABLE_CLAUDE_CODE_SKILLS
printenv OPENCODE_ENABLE_EXA
```

**Checkpoint:** `.bashrc` resolves into this EyrWSL clone's `bash/.bashrc`, all four commands resolve, paranoid mode prints `true`, and both environment checks print `1`. A fresh shell should show Starship without errors.

Check the **resolved Git identity configuration** in **Arch Bash, normal Linux user, EyrWSL repository root**, without displaying either value:

```bash
cd ~/Projects/eyrie/eyrwsl
if [[ -n $(git config --get user.name) && $(git config --get user.email) == *@users.noreply.github.com ]]; then
  printf 'OK: Git identity uses a name and GitHub no-reply address\n'
else
  printf 'STOP: correct the effective Git identity before committing\n'
fi
```

Expect `OK`. A legacy `~/.gitconfig` or repository-local identity can supersede the host file; fix the specific override instead of editing tracked configuration or publishing your inbox. Repeat this check inside a project before its first commit. This checks Git configuration, not commit-time environment overrides: do not set `GIT_AUTHOR_EMAIL` or `GIT_COMMITTER_EMAIL` to a different identity.

In **Arch Bash, normal Linux user, from your home directory in a fresh tab**, explicitly invoke the stowed wrappers to install the AI binaries without beginning an interactive session:

```bash
cd ~
~/.local/bin/claude --version
~/.local/bin/codex --version
~/.local/bin/opencode --version
```

Expect a download on first use followed by each tool's version. The wrappers run `mise use -g`, install under `~/.local/share/mise`, and record the tool's `latest` selection in host-local `~/.config/mise/config.toml`. Do not run them with `sudo` or place that generated config in a Stow package. They keep mise's default 24-hour release cooldown; `mup` (`mise up`) keeps it too.

In a **fresh Arch Bash, normal Linux user**, check installation and resolution:

```bash
mise ls claude codex opencode
command -v claude codex opencode
```

**Checkpoint:** mise lists an installed version of all three tools, and each command resolves under `~/.local/share/mise` or to its `~/.local/bin` wrapper, not an old Pacman/native/Windows install. Full EyrWSL verification requires these binaries even if you skip the optional EyrAgents harness; sign-in is needed only when using each provider.

### 10. Optional EyrAgents

Skip this step for an EyrWSL-only installation. It is recommended for the shared Claude Code, Codex, and OpenCode policies and workflows, but EyrWSL does not deploy it for you. Review [EyrAgents' README](https://github.com/peregrinus879/eyragents#setup) and its local `AGENTS.md`/maintenance ledger before adopting its personal guidance and permissions. No EyrArcHy deployment belongs here.

Before optional harness deployment, check the daily account in **Arch Bash, normal Linux user**:

```bash
id -u
```

EyrAgents' current committed WSL procedure assumes UID `1000` so its literal session-root deny matches. If this prints anything other than `1000`, stop this optional step for a harness-policy review. Do not renumber a populated account or modify permissions to continue. **EyrWSL itself has no UID 1000 restriction.**

**EyrAgents needs Node.js for its JavaScript checks. EyrWSL's package baseline does not supply it.** If a suitable Linux `node` runtime is already installed, keep its current owner rather than adding a competing one. Otherwise install the official [Arch `nodejs` package](https://archlinux.org/packages/extra/x86_64/nodejs/) in **Arch Bash, normal Linux user**:

```bash
sudo pacman -Syu --needed nodejs
node --version
```

Expect a `v...` version string. `npm` and a global mise Node pin are not prerequisites for this setup. The remaining EyrAgents prerequisites, including Git, Stow, jq, Python, ShellCheck, and util-linux, are already in the WSL baseline.

Only if the destination does not already exist, clone in **Arch Bash, normal Linux user**:

```bash
git clone https://github.com/peregrinus879/eyragents.git ~/Projects/eyrie/eyragents
```

In **Arch Bash, normal Linux user, EyrAgents repository root**, preview its links:

```bash
cd ~/Projects/eyrie/eyragents
make dry-run
```

Resolve reported configuration conflicts using EyrAgents' own instructions, then run in **Arch Bash, normal Linux user, EyrAgents repository root**:

```bash
make stow
```

This deploys the harness, installs its commit gate, and reconciles host-local Codex configuration. The Stow preview is not a preview of every reconciliation side effect. On an existing host, close agent sessions first and preserve host-owned settings; do not replace the entire `~/.claude`, `~/.codex`, or OpenCode directory or inspect/copy authentication files to make Stow pass. EyrAgents owns those rules, not EyrWSL. Start new agent processes after deployment, especially OpenCode.

### 11. First Launch

Launch the tools **one at a time** in **Arch Bash, normal Linux user**, exiting one before starting the next:

```bash
claude
codex
opencode
```

Follow each provider's current interactive sign-in flow. If it prints a browser URL instead of opening Windows' browser, open that URL yourself on Windows; the terminal-only baseline intentionally omits `xdg-utils`. Keep passwords, tokens, one-time codes, and auth files out of the repository and assistant reports. Existing sign-in state should remain in place through a launcher migration. Authentication failures do not indicate a dotfile deployment failure; resolve account access before testing workspace helpers.

Paranoid mode requires explicit trust for project-level `mise.toml`/`.tool-versions` files; read a project's config before running `mise trust` in that project. Never turn paranoid mode off to finish setup. Global mise configuration is implicitly trusted.

Open Neovim as the **normal Linux user in Arch Bash**:

```bash
nvim
```

First launch downloads the plugins pinned by `lazy-lock.json`; allow the network operations to finish. In Neovim, run `:LazyHealth` and `:checkhealth`, confirm Gruvbox loads, then `:qa` to exit and open it again. Distinguish missing optional providers from required runtime errors. Do not run a plugin update merely to install the locked versions. The vault at `~/Projects/vault`, its synchronization, and `normalize.py` are user-owned and not installed here; set `OBSIDIAN_VAULT` in a machine-local Bash overlay if using another path.

In **Arch Bash, normal Linux user, EyrWSL repository root**, run the full check:

```bash
cd ~/Projects/eyrie/eyrwsl
make verify
```

Expect successful checks ending in `ok:   verify`, with no `FAIL` lines. A missing EyrArcHy sibling produces an explicitly skipped twin check; it is not a reason to deploy EyrArcHy on WSL. If you installed the optional harness, run `make verify` separately in **Arch Bash, normal Linux user, EyrAgents repository root**:

```bash
cd ~/Projects/eyrie/eyragents
make verify
```

### 12. Windows Terminal

This is a separate, explicit Windows-side deployment, not part of Stow. **The tracked file replaces the entire active Terminal settings file; it is not a theme merge.** It changes defaults across profiles, keybindings, menu visibility (including hiding Windows PowerShell), and the default profile to `archlinux`. Save custom profiles, themes, and shortcuts before opting in. If you need to retain a different Terminal layout, do not push this full file until you have reviewed that difference.

Launch stable Windows Terminal once and open its settings JSON through **Settings > Open JSON file**, or hold Shift while selecting **Settings** in the tab dropdown. Note the actual file path; do not edit the generated `defaults.json`. Close the settings editor before deployment to avoid competing saves.

First inspect the differences in **Arch Bash, normal Linux user, EyrWSL repository root**:

```bash
cd ~/Projects/eyrie/eyrwsl
make wt-diff
```

The helper prints tracked and deployed paths. `+` diff lines are the **current Windows-side** settings. `drift detected` and a nonzero result are expected before first deployment; an invalid-file/path error must be resolved first. Review the full difference, not only colors.

Only after deciding to replace those settings, run in **Arch Bash, normal Linux user, EyrWSL repository root**:

```bash
make wt-push
make wt-diff
```

`make wt-push` resolves the active Windows account through PowerShell and validates both files as JSON. Equal files produce `no changes` without a write. Changed settings are backed up beside the destination as `settings.json.backup-TIMESTAMP` before atomic replacement; the command prints both paths. **Checkpoint:** the following diff ends with `no drift: tracked and deployed settings match`. Keep the backup until font, profiles, and keybindings are confirmed in a new Terminal window.

Automatic discovery targets the stable Store installation at `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`. Preview/unpackaged installations or a custom path need `WT_SETTINGS`, expressed as an absolute **WSL path**. For example, replace the entire quoted Windows path below with the path you noted in the UI, including your actual Windows username. In **Arch Bash, normal Linux user, EyrWSL repository root**:

```bash
export WT_SETTINGS="$(wslpath -u 'C:\Users\YOUR_WINDOWS_USER\AppData\Local\Microsoft\Windows Terminal\settings.json')"
make wt-diff
```

Review first, then use the same shell/variable for `make wt-push` and `make wt-diff`. The variable lasts only in this shell; `unset WT_SETTINGS` returns to automatic discovery. The helper accepts JSON with an optional UTF-8 BOM, not JSON comments or trailing commas. For a JSONC file, preserve a separate backup and deliberately convert a working copy to strict JSON; do not erase custom settings to get past validation.

To roll back, close the settings editor and use Windows File Explorer to locate the **exact backup path printed by the helper**. Preserve the current settings separately, then copy that chosen backup over its adjacent `settings.json`, confirming replacement only for that file. Reopen Terminal to check it. Rollback restores your previous whole configuration and will intentionally show drift from the tracked file.

After deployment, confirm the default profile opens `archlinux` as your normal Linux user, the font is JetBrainsMono Nerd Font at size 9, and Gruvbox is active. The config expects current WSL's `Microsoft.WSL` dynamic profile and disables the older `Windows.Terminal.Wsl` generator. Do not repeatedly push away an unresolved missing-profile warning. Settings UI saves can serialize a generated profile into the deployed file; review `make wt-diff` before choosing whether to restore canonical settings. Finish the manual [Verify](#verify) checks, including clipboard behavior.

### Existing Installations

**Upgrading is not reinstalling.** Keep the registered distribution, Linux user, clone, projects, local Git identity, and authentication state. Before significant host migrations, make and test a backup using your own trusted backup workflow; a WSL export contains private files and credentials, so do not place it in a repository or send it to an assistant. Never use `wsl --unregister` as troubleshooting cleanup: Microsoft documents that it permanently deletes that distribution's data.

In **Windows PowerShell, normal Windows user**, use `wsl --list --verbose` to identify the actual installed name. If it differs from `archlinux`, substitute that exact name in launch/terminate commands and review the tracked Terminal profile assumption before deployment. An existing WSL1 or community Arch distribution is a migration, not this fresh-install path: preserve it and follow the [Microsoft backup/conversion reference](https://learn.microsoft.com/en-us/windows/wsl/basic-commands#set-wsl-version-to-1-or-2) before any conversion. Official Arch supports only WSL2.

For an existing EyrWSL clone, inspect it in **Arch Bash, normal Linux user, from any directory**:

```bash
git -C ~/Projects/eyrie/eyrwsl status --short --branch
readlink -f ~/.bashrc
```

Use the clone supplying your live links, not an unrelated second clone. Preserve dirty/untracked work and stop to reconcile local commits or another-clone ownership errors. Do not reset, auto-stash, or delete anything to get a clean update. Read this clone's maintenance ledger for pending host migrations.

Once you have confirmed the intended clone/branch is clean and the update is wanted, run in **Arch Bash, normal Linux user, EyrWSL repository root**:

```bash
cd ~/Projects/eyrie/eyrwsl
git pull --ff-only
```

This updates live Stow sources immediately, even before restowing. A fast-forward refusal needs review, not a forced reset. Recheck the updated README and ledger, install any missing baseline packages using step 4's full-upgrade command, then inspect existing AI launchers in **Arch Bash, normal Linux user**:

```bash
type -a claude codex opencode
pacman -Q openai-codex opencode
```

Missing commands/packages are legitimate results for a host that never installed them. If an old executable shadows mise, determine its exact owner first: `pacman -Qo /absolute/path/to/executable` in this same Bash shell, replacing the path with the one reported by `type`. Have Pacman remove only a confirmed obsolete package, reviewing the transaction before accepting; never manually delete a file Pacman owns. Do not run a blanket `pacman -Rns` list copied from a different host.

For a confirmed user-level standalone launcher at an EyrWSL-owned path, preserve that **specific launcher** under an unused backup name outside the repository before linking the wrapper. Keep its versions store until the replacement is verified. Do not delete `~/.claude`, `~/.codex`, OpenCode's config/data, mise state, SSH keys, or credential files. Native-installer cleanup and auth migration are separate decisions, not prerequisites to replacing a launcher. Follow the old installer's current official uninstall documentation only if removal is actually needed, checking its data impact first.

After conflict/launcher review, use **Arch Bash, normal Linux user, the deployed EyrWSL repository root**, stopping at the first failure:

```bash
make dry-run
make clean
make dry-run
make restow
```

An initial preview may identify old links that `make clean` is designed to repair; do not bypass an unfamiliar ownership refusal. The last preview must be conflict-free. Open a fresh Arch tab, repeat the mise/bootstrap checks in [Stow](#9-stow), and run `make verify`. Existing authentication should still be present; do not sign out or erase auth merely to test the update. Handle optional EyrAgents upgrades in its own deployed clone, using its README/ledger and confirming Node is available. Windows Terminal changes always retain the separate diff/review/push/diff sequence.

To **move a deployed clone**, first preserve any local work and run `make unstow` from the old, still-existing clone, as the normal Linux user on WSL. Then put the clone at the intended location and repeat the preview/preparation/Stow sequence there. `/old/clone/path` below is a placeholder for that exact reviewed old location, not a literal directory. In **Arch Bash, normal Linux user**:

```bash
make -C /old/clone/path unstow
```

Unstow removes this repository's links, not the clone or your generated host data; applications may lack their configuration until you stow again. It does not undo Windows Terminal deployment or remove optional EyrAgents. If the old clone is unavailable, recognized dangling links can be handled by `make clean`; a live link into a different clone must be resolved at its owner rather than forced away.

## Git Review

After stowing, start a fresh Neovim session once to load `git-review.lua`. `Space g d` shows staged and unstaged hunks, `Space g D` compares against origin, and `Space g s` shows status including untracked files. Each invocation uses the current file/directory's Git repository or the selected Neo-tree item, falling back to the displayed tree root when no item path exists. Symlink targets and linked worktrees are supported; switching files between repositories switches the review target without changing any editor directory.

Empty or special non-explorer buffers use the current window's directory. A known non-Git file or explorer target warns instead of silently reviewing another repository. No recurring `:cd`/`:lcd` is needed for repository files or selected repository folders. Keep the ordinary picker review controls; do not use its stage/restore actions unless intended.

## Verify

Workspace fixtures exercise isolated tmux servers with fake agents and a Python-backed Herdr model. They cover creation, ownership, failure recovery and concurrency without using running user workspaces or real agents; rendered UI and actual-host activation remain separate checks.

The rsync fixture uses fake local monitor/transfer commands, not SSH or production endpoints. It checks literal source resolution, complete readiness publication, events during a successful transfer, burst coalescing, failure retry, missed-event reconciliation and watcher management. Normal checks shorten only the fixture's reconciliation interval to 10 seconds; `RSW_FIXTURE_REALTIME=1 bash tests/rsyncing.sh` exercises the unchanged 60-second interval. The Python guard requires Linux child-subreaper support and `/proc`: it owns detached descendants, uses bounded TERM/KILL cleanup, and removes state only after all children are reaped. Unverified cleanup fails and retains its reported diagnostic directory. Killing the guard itself with SIGKILL can leave descendants and state behind.

After stowing or changing owned packages:

- Run `make lint` and `make check` after any change; both are repository-only (ShellCheck; every owned Bash, Lua, TOML, JSON, JSONC, Git, tmux, btop, and Fastfetch config in `repo` mode; the `tests/` fixtures). GitHub Actions runs them on pushes to `main` and pull requests, plus an exact committed twin-pair check against EyrArcHy's fetched default branch.
- Run `make verify` from the repo root on the WSL host after stowing or changing owned packages: the active WSL2/interop host guard first, then `lint`, `check`, and `twins`, followed by `scripts/verify.sh` in `full` mode (command baseline, the three AI tools installed by mise and resolving through it, every Git-visible Stow source resolving into this repo with its managed parents real directories, a GitHub no-reply Git identity that is never printed, and every owned config).

Complete these manual fresh-session checks:

- Confirm the core symlinks and local Git identity exist: `test -L ~/.bashrc && test -L ~/.config/starship.toml && test -L ~/.config/nvim/lua/config/options.lua && test -f ~/.config/git/config.local`
- Start a fresh shell and confirm Bash, Starship, and Tmux load without errors.
- Confirm `printenv OPENCODE_DISABLE_CLAUDE_CODE_SKILLS` and `printenv OPENCODE_ENABLE_EXA` each print `1`.
- Start a fresh shell and confirm `alias claude c cx cy ic ix icx` reports no alias for any of them: the AI tools run as EyrAgents configures them.
- Confirm `type tdw` and `type hdw` show the workspace functions. From a project directory, `<tdw|hdw> <cc|cx|oc> [-c]` creates a project-named session/workspace with a new window/tab named `claude`, `codex`, or `opencode`; `-c` continues that agent's last conversation. AI stays full-height left, editor/shell equally stacked right, with equal columns and agent focus. Bare invocation preserves existing workspace names/layouts while attaching or focusing. New tmux titles retain host, project session, and agent window as `#h:#S:#W`.
- Workspace creation is serialized and validates the full layout before sending input; failures stop clearly and cleanup targets only that invocation's creation. Herdr starts headless when needed; failed startup returns failure with manual-start guidance, not a plain-attach success. If rollback is unverified, inspect the reported pending identity and any retained `hdw` roots snapshot before retrying; do not delete unfamiliar workspaces or recovery files.
- Confirm `type hdl`, `type hdlm`, and `type hsl` show the other Herdr workspace functions. `hds` is intentionally unavailable because it requires Hunk.
- In a disposable Git fixture, check `ga <branch>` from a subdirectory and `gd` from the resulting linked worktree, including the normal shell's `cd` alias. `gd` confirms the actual path/branch, requires its HEAD to be contained in the primary worktree's current HEAD, refuses dirty work and never forces removal; a failed branch deletion reports that the branch was retained. The primary worktree need not be on a branch named `main`. Do not use a real working branch as a removal test.
- With disposable local source/destination directories, start `rsw <source> <destination>`, note its PID/log path, and confirm changes during a transfer eventually arrive. Readiness is not sync success: inspect logs for transfer/monitor failures and retries. Reconciliation is checked between transfers, 60 seconds after the last successful completion. Monitor death stops the watcher after the current transfer returns and requires inspection/restart; a stalled transfer can delay this indefinitely. `lsw` and `dsw` manage only watchers started by this implementation; do not assume an older watcher stopped. No `--delete` is used, so destination-only files remain.
- Confirm `mise ls claude codex opencode` lists an installed version of each tool, and `command -v claude codex opencode` resolves every one under `~/.local/share/mise` (interactive shells, through `mise activate`) or to its `~/.local/bin` wrapper; `make verify` fails when a tool is missing from mise or resolves elsewhere.
- Confirm `mise settings get paranoid` prints `true` and `mise settings get minimum_release_age` reports that the setting is not set, so the 24-hour default applies; `make verify` checks paranoid mode in full mode.
- Run `nvim` once and confirm plugins install successfully and Gruvbox loads.
- Check Git review from files in two repositories and from a selected Neo-tree repository folder while the editor was launched in their non-Git parent; `Space g d` and `Space g s` must target the selection without changing `:pwd`.
- In Neovim, verify both `+` and `*` registers with disposable ASCII, Arabic/CJK, accented and supplementary-plane text through a Windows application, including multiline/CRLF, empty contents, and trailing newlines. Paste strips every CR, normalizing CRLF to LF; this is not byte-for-byte preservation. The provider uses PowerShell with explicit UTF-8 and no profile for both directions, not `clip.exe`. Do not inspect pre-existing clipboard content; mocks are not evidence that this Windows boundary passed.
- If the vault is synced to this machine, open a vault note and confirm obsidian.nvim loads (`<leader>oo` opens the note switcher).
- In OpenCode, run `/theme` and confirm `system` is selected so the TUI inherits Windows Terminal's Gruvbox ANSI palette.
- Confirm Windows Terminal uses JetBrainsMono Nerd Font at size 9 and the Gruvbox color scheme after applying `windows-terminal/settings.json`.

## Troubleshooting

### WSL Installation or Startup

- **`wsl` shows help or does not recognize an option:** check `wsl --version` in normal-user Windows PowerShell, update with `wsl --update` in Administrator PowerShell, and complete any requested Windows restart. Use current stable WSL rather than layering old kernel installers onto it. If installation still shows help on Windows 10, [Microsoft documents the explicit distribution flag](https://learn.microsoft.com/en-us/windows/wsl/basic-commands#install): use `wsl --install -d archlinux` in normal-user Windows PowerShell, only after `wsl --list --verbose` confirms Arch is not already registered.
- **`archlinux` is missing from the online catalog:** update WSL and retry `wsl --list --online` in normal-user Windows PowerShell. Do not guess a different Arch distribution name. If catalog delivery is still unavailable, use Arch's official image below.
- **Download is stuck at 0%:** for an installation that has not completed, Microsoft's documented retry is `wsl --install --web-download -d archlinux` in normal-user Windows PowerShell. Check `wsl --list --verbose` first; an already-registered distribution needs diagnosis, not deletion and reinstall.
- **Error `0x80370102`/required virtualization feature missing:** check Task Manager's virtualization status, your PC's UEFI settings, and the restart after enabling WSL. If Windows itself runs in a VM, nested virtualization requires the host administrator. Follow [Microsoft's installation troubleshooting](https://learn.microsoft.com/en-us/windows/wsl/troubleshooting#installation-issues); do not disable security features or unregister a distribution as a generic fix.

**Official image fallback, new installations only:** download the current `.wsl` file and its matching `.wsl.SHA256` file from the [image directory linked by ArchWiki](https://fastly.mirror.pkgbuild.com/wsl/latest/). Use the actual downloaded filename, not a dated filename from an old tutorial. In **Windows PowerShell, normal Windows user**, replace the entire quoted example path and compute its checksum:

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath 'C:\Users\YOUR_WINDOWS_USER\Downloads\EXACT_ARCH_IMAGE.wsl' | Format-List
```

Open the downloaded `.SHA256` text file in Notepad. Its hexadecimal hash must match the `Hash` value exactly, ignoring letter case; stop if it differs. This detects a damaged/mismatched download, not a compromise of the source hosting both files. With current WSL installed, either double-click the verified `.wsl` file in Windows File Explorer or use **Windows PowerShell, normal Windows user**, with the same actual path:

```powershell
wsl --install --from-file 'C:\Users\YOUR_WINDOWS_USER\Downloads\EXACT_ARCH_IMAGE.wsl'
```

The image's default registered name is `archlinux`; do not add `--name` unless you intentionally want a different profile name. Recheck `wsl --list --verbose` in normal-user PowerShell and return to [WSL Initial Setup](#2-wsl-initial-setup). Do not install both the catalog and file versions on top of the same name. For an unresolved startup error, search the [WSL issue tracker](https://github.com/microsoft/WSL/issues) using the exact error and your `wsl --version` output before changing host configuration.

### User and Sudo Recovery

If Arch still opens as root, opens with the wrong home, or the daily user cannot use sudo, recover through **Windows PowerShell, normal Windows user**:

```powershell
wsl -d archlinux -u root
```

This is a root recovery shell inside the existing distribution; it does not recreate it. Replace `linuxuser` below, then inspect in **Arch Bash, root**:

```bash
id linuxuser
visudo -c
nvim /etc/wsl.conf
```

Confirm the account exists and `[user] default` names it. If `wheel` is absent from `id`'s groups, run `usermod -aG wheel linuxuser` in this root Bash shell; the `-a` preserves other groups. Use `EDITOR=nvim visudo` here to correct the password-required wheel rule and rerun `visudo -c`. For a forgotten daily-user password, `passwd linuxuser` here resets that password without exposing the old one. Do not remove/recreate the user or edit password database files.

Save work before terminating Arch from normal-user PowerShell using the step 2 commands. Relaunch without `-u root`, then repeat `whoami`, `pwd`, and `sudo -v` as the normal Linux user. Never solve a Stow permission error by running deployment as root or recursively changing ownership of the entire home.

### Packages and Deployment

- **Pacman download, keyring, signature, or file-conflict failure:** stop before Stow. Check Windows connectivity, date/time, Arch news, and the relevant [Pacman troubleshooting](https://wiki.archlinux.org/title/Pacman#Troubleshooting). Retry a full `sudo pacman -Syu` only after diagnosing the cause, in normal-user Arch Bash. Do not bypass signature/dependency checks or use a blanket `--overwrite`.
- **Locale warnings or mangled non-ASCII text:** in normal-user Arch Bash, check `locale -a`, `locale`, and `locale charmap`. Generate the selected UTF-8 locale and check `/etc/default/locale` against [step 3](#3-locale). Restart Arch after saving work; do not conceal the problem with a permanent `LC_ALL=C` override.
- **Preparation/Stow conflict:** follow [Prepare](#8-prepare), comparing only the reported owned path and preserving its needed content. `make clean` is not a force option. Never use `stow --adopt`, `ln -sf`, or broad file deletion to bypass a refusal.
- **Another-clone ownership error:** inspect `readlink -f ~/.bashrc` in normal-user Arch Bash and use that deployed clone. A move requires unstowing from the old clone first; do not repoint live links from an unrelated checkout.
- **Commands/prompt missing after Stow:** open a fresh normal-user Arch tab outside existing tmux/Herdr sessions and repeat the step 9 checks. `wsl -e COMMAND`, noninteractive Bash, and already-running multiplexers do not necessarily load the new `.bashrc` environment. Do not kill a multiplexer with unsaved work just to refresh its shell.
- **EyrAgents reports `node: command not found`:** Node is not part of the WSL baseline. Complete [Optional EyrAgents](#10-optional-eyragents) and confirm `node --version` in normal-user Arch Bash before rerunning its gates.
- **Git identity fails:** use the exact no-reply address from GitHub Settings > Emails in `~/.config/git/config.local`. Check legacy/repository overrides privately. Do not print `git config --list` into a support report, since unrelated settings may contain sensitive values.

### AI Tools

- **mise refuses a project config:** in normal-user Arch Bash, review that project's config, then run `mise trust` from the project only if you accept it. Paranoid mode prompts again when a trusted file changes. Do not disable it or trust a whole directory tree to fix one refusal.
- **First-run wrapper fails or appears stalled:** downloads require working network access and a release eligible under the cooldown. In normal-user Arch Bash from `~`, use `mise doctor` for activation problems or `mise use -g claude` for Claude's direct installation error; substitute `codex` or `opencode` for the other tools. This latter command installs/updates host state, it is not a read-only diagnostic. Do not add `sudo`, bypass cooldowns, or reinstall with a different package manager.
- **Wrong binary starts:** in a fresh normal-user Arch Bash, use `type -a claude codex opencode` and `mise ls claude codex opencode`. Follow the ownership checks under [Existing Installations](#existing-installations); do not erase provider configuration or auth to replace a launcher.
- **Sign-in cannot open a browser:** open the tool's displayed URL in Windows yourself. Use only the tool's official flow and keep codes/tokens private. Account access and an expired session are provider issues, not reasons to delete dotfiles.
- **OpenCode colors differ:** select `system` with OpenCode's `/theme`. If using EyrAgents, its `~/.config/opencode/tui.json` should resolve into that clone. Restart OpenCode after changing its configuration; EyrWSL does not own an OpenCode theme file.

### Windows Integration

For missing clipboard/PowerShell interop, test **Arch Bash, normal Linux user, fresh tab** without reading or replacing the Windows clipboard:

```bash
command -v clip.exe powershell.exe
powershell.exe -NoProfile -NonInteractive -Command '$PSVersionTable.PSVersion.ToString()'
```

Expect two executable paths and a PowerShell version for the repository's host gate; Neovim's provider itself requires only WSL and `powershell.exe`, not `clip.exe`. The version probe checks execution, not clipboard correctness. If commands are absent, check both `enabled = true` and `appendWindowsPath = true` under `[interop]` in `/etc/wsl.conf`. A machine-local shell overlay must preserve existing Windows PATH entries. Save work, terminate only Arch from normal-user Windows PowerShell, then relaunch. Once interop works, manually test Neovim copy/paste with disposable non-sensitive text, including non-ASCII characters and multiple lines; never use existing clipboard contents as a diagnostic artifact.

- **Windows Terminal settings not found:** launch the intended Terminal edition and open its actual settings JSON. Default discovery covers stable Store Terminal only; use the `WT_SETTINGS` example in [step 12](#12-windows-terminal) for another path/account. Keep that variable set for both diff and push. Do not create an empty settings file at a guessed path.
- **Terminal settings rejected as invalid JSON:** the helper requires strict JSON even though Terminal itself accepts comments. Preserve the original before converting it, and do not skip validation. A failed push is not a deployment.
- **Missing `archlinux` default profile:** in normal-user PowerShell confirm `wsl -d archlinux` works and `wsl --list --verbose` lists that exact name at version 2. Update/reopen WSL and stable Terminal, then inspect profile selection in Terminal's Settings > Startup. A differently named or legacy distribution needs an explicit profile decision, not repeated `make wt-push` calls. Review any resulting drift before replacing the settings again.
- **Boxes instead of icons:** confirm Windows has **JetBrainsMono Nerd Font** installed and the active Terminal profile selects that family, then restart Terminal. Installing a Linux font will not fix Windows Terminal's rendering.
- **Obsidian image paste unavailable:** `:Obsidian paste_img` expects `wl-clipboard` or `xclip`, which this WSL baseline does not install. Save the image through Windows or the vault's own workflow, then link/embed it in the note. The repo does not install or synchronize your vault.

## Maintenance

A repo-root `Makefile` keeps the package list in one place and wraps the routine commands. `stow`, `unstow`, `restow`, `clean`, `verify`, and `wt-push` run on the WSL machine; `lint`, `check`, `twins`, `twins-pair`, and `refs` run anywhere:

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

Every host-writing Make target checks host and deployed-clone ownership before mutation. Deployment goals are serialized within one Make invocation, including `make -j`; this is not rollback against I/O failure or independent concurrent deployments.

Before running `make refs`, preview with `bash scripts/update-references.sh --dry-run` and approve any new clone or remote repointing separately. The preview can query GitHub but does not fetch or establish conflict-free upstream parity. Routine authorized refreshes remain the sync skill's work; atomic fetch does not make the whole family update transactional.

`make refs` refuses ahead-only/divergent listed default branches instead of calling them current. Its atomic, non-forced fetch preserves existing local tags and annotations, imports new tags, and prunes only origin tracking branches. Checkout and merge use `--no-overwrite-ignore`, preserving ignored files in listed clones. Tag/file conflicts refuse that update and require separate review; do not force a tag replacement or delete local files to make it pass. Stale references are informational and require separate review of all refs, stashes, and ignored/untracked files before any manual removal.

Direct `scripts/wt-diff.sh --push` also checks host/clone ownership before discovering or reading the Windows destination. The diff-only mode remains read-only; the full-file replacement still requires explicit review as described in Setup.

CI runs `make lint`, `make check`, and `twins-pair` on pushes to `main` and pull requests, using the peer default branch for normal runs. Manual workflow dispatch accepts an explicit full `peer_commit` only with `peer_reviewed=true`; it fetches peer objects without executing peer code and records both actual commits. This attestation is not publication authorization. For coordinated changes, verify the final published pair explicitly after both commits are available; a green check against an earlier peer is not final-pair evidence. Local `make twins` remains a worktree convenience check that can skip a missing sibling.

Updates run in two steps, as Omarchy's updater does in one: `sudo pacman -Syu` updates the system, mise itself included (the packaged mise cannot self-update and says so when asked), and never touches the mise-managed tools; `mup` then brings Claude Code, Codex, and OpenCode current, the `mise up` call Omarchy runs after its package step, here without Omarchy's cooldown override, so a release counts once it is a day old. Under mise, Claude Code's native auto-updater is not in play; the tools change version only through mise.

`nvim/.config/nvim/lazy-lock.json` is generated but tracked. Update it only through an intentional Lazy sync, review the pinned revision changes, verify a clean headless bootstrap, and commit the lockfile with the plugin-spec change that required it.

Periodically, review the local reference repos and official docs for upstream changes to owned packages, sync with `/omasync` or a manual comparison, and confirm every intentional difference is still documented in `DEVIATIONS.md`. Unresolved decisions, deferred work, active limitations, and dated evidence live in [docs/maintenance.md](docs/maintenance.md).

## Related Repos

Upstream comparison runs through the `/omasync` skill; `make refs` keeps the reference clones listed in `references.txt` current. Upstream URLs and official docs live in [DEVIATIONS.md](DEVIATIONS.md) (Reference Sources).

## Credits

Adapted from [Omarchy](https://github.com/omacom/omarchy). See [DEVIATIONS.md](DEVIATIONS.md) for intentional differences and boundary definitions.

## License

[MIT](LICENSE)
