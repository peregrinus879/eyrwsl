# Setup

[Overview](../README.md) · [Operations](operations.md) · [Deviations](../DEVIATIONS.md) · [Open work](maintenance.md)

Install EyrWSL on a new machine by following the numbered steps in order. Adopting an existing Arch WSL installation starts at [Existing Installations](#existing-installations); [Troubleshooting](#troubleshooting) covers recovery.

## Installation

### Before You Begin

You need a supported Windows release, preferably current Windows 11, on an x86-64 PC with hardware virtualization enabled. [Microsoft's WSL installation](https://learn.microsoft.com/en-us/windows/wsl/install) needs at least Windows 10 version 2004 (build 19041); the official Arch image needs **WSL 2**. The guide uses stable WSL and the official Arch image, with no preview releases, community launchers, Arch ISO or AUR helper.

| Starting point | Start at |
| --- | --- |
| Windows without WSL | [Step 1](#1-windows-and-wsl), in order |
| WSL with other distributions, but no Arch | Step 1, skipping `wsl --install --no-distribution`; other distributions stay untouched |
| Arch, or EyrWSL, already installed | [Existing Installations](#existing-installations); never reinstall the distribution, recreate its user or reclone over an existing directory |

EyrWSL owns the WSL terminal environment. [EyrArcHy](https://github.com/peregrinus879/eyrarchy) is never deployed on WSL, and [EyrAgents](https://github.com/peregrinus879/eyragents) owns AI-client configuration; neither is needed to install EyrWSL.

**Conventions.** Run commands one at a time and stop at an unexpected error. Each code block is preceded by where it runs:

| Label | Meaning |
| --- | --- |
| **PowerShell (Admin)** | Windows PowerShell opened with *Run as administrator* |
| **PowerShell** | Windows PowerShell as your normal Windows user |
| **Arch root** | Bash in Arch as the Linux `root` user |
| **Arch user** | Bash in Arch as your normal Linux user; *in the clone* means from `~/Projects/eyrie/eyrwsl` |
| **File** | Content to put in a file with an editor, not a command |

An elevated Windows account is not the Linux `root` account. Do not type prompt prefixes such as `PS C:\>`, `$` or `#`. In Bash, a trailing `\` continues a command on the next line; paste those lines together.

**Placeholders.** `linuxuser` stands for your chosen Linux login, such as `alex`: lowercase, no spaces, used consistently; it need not match your Windows or GitHub name. Other placeholders are written in capitals, such as `YOUR_WINDOWS_USER`, and are replaced whole. In Bash, `~` and `$HOME` mean the Linux home, `/home/linuxuser`, not a Windows folder.

### 1. Windows and WSL

In **Settings > System > About**, check the Windows version and system type. In **Task Manager > Performance > CPU**, check that virtualization is enabled; if not, follow [Microsoft's virtualization guidance](https://support.microsoft.com/windows/c5578302-6e43-4b4b-a449-8ced115f58e1) and your PC maker's UEFI instructions. On a managed PC, ask its administrator.

Install or update **Windows Terminal** (stable) from the Microsoft Store under your daily Windows account, following [Microsoft's guide](https://learn.microsoft.com/en-us/windows/terminal/install), and launch it once. Its tab dropdown opens Windows PowerShell; tab titles can be renamed, so do not rely on them to identify a shell.

Download **JetBrainsMono** from the [Nerd Fonts downloads](https://www.nerdfonts.com/font-downloads), extract it, and install the `JetBrainsMonoNerdFont-*.ttf` files with right-click **Install**. The family is **JetBrainsMono Nerd Font**, not the unpatched JetBrains Mono. Restart Terminal afterwards. Windows Terminal renders the icons, so Arch needs no font package.

On a machine **without WSL**, install it without a default distribution, then restart Windows when asked. **PowerShell (Admin):**

```powershell
wsl --install --no-distribution
```

Update WSL to the current stable release, whether new or existing. Do not add the legacy WSL kernel or WSLg installers. **PowerShell (Admin):**

```powershell
wsl --update
```

Close the elevated window. **PowerShell:**

```powershell
wsl --version
wsl --list --verbose
wsl --list --online
wsl --set-default-version 2
```

**Checkpoint:** WSL reports its component versions and the online list contains `archlinux`. A fresh host has no installed distributions. If `archlinux` is already installed, go to [Existing Installations](#existing-installations). WSL's own version number and a distribution's `VERSION` column (`1` or `2`) are different things.

Install the [official Arch image](https://wiki.archlinux.org/title/Install_Arch_Linux_on_WSL#Automated_installation); `archlinux` is its catalog name. **PowerShell:**

```powershell
wsl --install archlinux
```

Installation may open an Arch root shell; continue step 2 there, or open one with `wsl -d archlinux`. If the catalog or download is unavailable, use the [official image fallback](#wsl-installation-or-startup), never a community distribution. In a separate tab, **PowerShell:**

```powershell
wsl --list --verbose
wsl --status
```

**Checkpoint:** `archlinux` is listed at version `2`, `Running` or `Stopped`. Stop if it shows version `1`. `wsl --set-default archlinux` optionally makes bare `wsl` open Arch; it changes only that default.

### 2. Arch User

The official image starts as root and has no user-creation wizard. **Arch root:**

```bash
whoami
uname -m
```

Expect `root` and `x86_64`. If a daily user already exists, keep it and check its sudo and default-user setup instead of creating another.

Set a root recovery password, then fully update Arch and install the bootstrap tools. **Arch root:**

```bash
passwd
pacman -Syu --needed git neovim openssh sudo
```

`passwd` asks twice and shows nothing while you type; this is a Linux password, not your Windows PIN. Pacman lists the transaction; read it, then answer `y`. Never use `--noconfirm`, disable signature checks, or continue after an incomplete upgrade. For an older image, read [Arch news](https://archlinux.org/news/) for manual interventions first.

To run several systemd-enabled distributions at once, read [Arch's default-user warning](https://wiki.archlinux.org/title/Install_Arch_Linux_on_WSL#Set_default_user) and choose a free UID when creating the user; a host with only Arch uses the default. Create the user, set its password and open the sudo policy. **Arch root:**

```bash
useradd -m -G wheel -s /bin/bash linuxuser
passwd linuxuser
EDITOR=nvim visudo
```

`useradd` is silent on success: `-m` creates the home, `-G wheel` grants administration, `-s` sets Bash. If it reports that the user exists, stop and inspect that account; never delete it.

`visudo` opens the policy in Neovim, which later steps use too: move with the arrow keys, press `i` to edit, then `Esc`, `:wq` and Enter to save, or `Esc`, `:q!` and Enter to abandon. Uncomment the password-required wheel rule, not the `NOPASSWD` one. **File `/etc/sudoers`:**

```text
%wheel ALL=(ALL:ALL) ALL
```

If `visudo` reports a syntax error, choose `e` and fix it; never save invalid policy. Validate it and open WSL's per-distribution configuration. **Arch root:**

```bash
visudo -c
nvim /etc/wsl.conf
```

Expect `parsed OK`. In `/etc/wsl.conf`, keep existing settings, including the image's `[boot]` systemd setting, and add or edit these keys without duplicating section headers. **File `/etc/wsl.conf`:**

```ini
[user]
default = linuxuser

[interop]
enabled = true
appendWindowsPath = true
```

Interop lets Linux run Windows executables, and `appendWindowsPath` makes `powershell.exe` and `clip.exe` resolvable. This is a Linux file, distinct from Windows' `.wslconfig`; [Microsoft's reference](https://learn.microsoft.com/en-us/windows/wsl/wsl-config) documents both.

Type `exit`, then restart Arch to apply it. Termination stops every Arch process and discards unsaved work, but deletes nothing and leaves other distributions running; a new tab alone may reuse the running instance. **PowerShell:**

```powershell
wsl --terminate archlinux
wsl -d archlinux
```

**Arch user:**

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

**Checkpoint:** `whoami` shows your login, `pwd` shows `/home/linuxuser`, the groups include `wheel`, `sudo -v` accepts your Linux password silently and `sudo whoami` shows `root`. Both Windows commands resolve, normally under `/mnt/c/Windows`, and PowerShell prints its version. On failure, see [User and Sudo Recovery](#user-and-sudo-recovery). Never clone or deploy as root.

### 3. Locale

Use a generated UTF-8 locale; these examples use `en_US.UTF-8`. **Arch user:**

```bash
sudo nvim /etc/locale.gen
```

Uncomment `en_US.UTF-8 UTF-8`, keeping any other locale you need, and save. **Arch user:**

```bash
sudo locale-gen
sudo nvim /etc/locale.conf
```

Expect a generation message for `en_US.UTF-8`. Set `LANG`, keeping other intentional settings; never set `LC_ALL` permanently. **File `/etc/locale.conf`:**

```ini
LANG=en_US.UTF-8
```

WSL can otherwise take the locale from Windows. [Arch's WSL locale override](https://wiki.archlinux.org/title/Install_Arch_Linux_on_WSL#Adjust_locale) makes `/etc/default/locale` a link to `/etc/locale.conf`. Inspect it first. **Arch user:**

```bash
ls -ld /etc/default/locale
```

If it already points to `/etc/locale.conf`, skip to the restart. If it is a regular file or another link, review it, then move it aside with `sudo mv -i /etc/default/locale /etc/default/locale.pre-eyrwsl`, answering **no** to any overwrite prompt. Never replace it with `ln -sf`. Once the path is absent, **Arch user:**

```bash
sudo ln -s /etc/locale.conf /etc/default/locale
```

Exit Arch and restart it. **PowerShell:**

```powershell
wsl --terminate archlinux
wsl -d archlinux
```

**Arch user:**

```bash
locale -a
locale
locale charmap
```

**Checkpoint:** the list includes `en_US.utf8`, `LANG` shows your locale, no warnings appear and the character map is `UTF-8`.

### 4. Prerequisites

Every package comes from the official Arch repositories, with its normal dependencies. Define the baseline once, then install it in a full upgrade and confirm it. **Arch user**, in one shell:

```bash
pkgs=(7zip bash-completion bat btop curl diffutils eza fastfetch fd file findutils fzf gcc git
  github-cli gum inetutils inotify-tools jq lazygit less lua make man-db man-pages mise neovim
  openssh procps-ng python ripgrep rsync shellcheck starship stow sudo tree-sitter-cli unzip
  util-linux which yazi zoxide)
sudo pacman -Syu --needed "${pkgs[@]}"
pacman -T "${pkgs[@]}"
```

Read the transaction and any provider or replacement prompt before accepting. `pacman -T` prints nothing when everything is installed; a printed name is a missing package. [Partial upgrades are unsupported](https://wiki.archlinux.org/title/System_maintenance#Partial_upgrades_are_unsupported), so never use `pacman -Sy` followed by selective installs.

The baseline is terminal-only: `inetutils` provides `hostname`, `lua` the Lua syntax check, `tree-sitter-cli` LazyVim's parsers, `python` the repository checks and vault scripts, `man-db` and `man-pages` local manuals, and `7zip` Yazi's archives. It adds no `xdg-utils`, Linux fonts, AUR packages or Node.js; the Claude Code and OpenCode binaries do not need Node.js.

Yazi's image, video, PDF and SVG previews optionally use these helpers, which `make verify` does not require. **Arch user:**

```bash
sudo pacman -Syu --needed ffmpeg imagemagick poppler resvg
```

[Herdr](https://herdr.dev) is part of the verified baseline. Check for an official package first. **Arch user:**

```bash
pacman -Si herdr
```

If package details print, install it with `sudo pacman -Syu --needed herdr`. Only when Pacman reports `package 'herdr' was not found` (a network or database error proves nothing), review the [Herdr installer](https://herdr.dev/install.sh) and run it as your user, never with `sudo`. **Arch user:**

```bash
curl -fsSL https://herdr.dev/install.sh | sh
```

It installs `~/.local/bin/herdr`; a warning that this directory is not yet on `PATH` is expected until EyrWSL is deployed. When a package appears later, review the move to it rather than installing a second copy.

Claude Code and OpenCode are installed in [step 8](#8-ai-clients) by EyrWSL's mise wrappers, so do not install their Pacman, native or npm versions.

### 5. Clone

Keep the clone in the Linux filesystem, not under `/mnt/c` or a Windows-synced folder. After deployment it is live configuration, so do not delete or casually move it. **Arch user:**

```bash
mkdir -p ~/Projects/eyrie
git clone https://github.com/peregrinus879/eyrwsl.git ~/Projects/eyrie/eyrwsl
cd ~/Projects/eyrie/eyrwsl
git status --short --branch
```

The public clone needs no GitHub login. If the destination exists, stop and follow [Existing Installations](#existing-installations); never delete it or clone into it. **Checkpoint:** status shows `main` tracking `origin/main` with no changes. Read [AGENTS.md](../AGENTS.md), [DEVIATIONS.md](../DEVIATIONS.md) and the [maintenance ledger](maintenance.md) before deploying.

### 6. Git Identity

Tracked Git configuration has no identity; it lives in an untracked host file. Commits must use your **GitHub no-reply address**: in GitHub's **Settings > Emails**, enable **Keep my email addresses private** and copy the exact address shown, usually `ID+USERNAME@users.noreply.github.com` ([GitHub's reference](https://docs.github.com/en/account-and-profile/reference/email-addresses-reference#your-noreply-email-address)). Never use a personal inbox or invent the numeric ID. **Arch user:**

```bash
mkdir -p ~/.config/git
nvim ~/.config/git/config.local
```

Keep other settings in an existing file and set only the identity. **File `~/.config/git/config.local`:**

```ini
[user]
  name = Your Name
  email = 12345678+YOUR_GITHUB_USERNAME@users.noreply.github.com
```

Never put identity in the tracked `git/.config/git/config`. The stowed configuration includes this file after [step 7](#7-deploy), which checks the result.

### 7. Deploy

The `nvim/` package is a complete LazyVim configuration with its plugin lockfile, so do not clone LazyVim's starter into `~/.config/nvim`. An existing configuration there is a conflict to review, like any other.

Preview the links read-only. **Arch user, in the clone:**

```bash
make dry-run
```

A fresh user has a regular `~/.bashrc` from `/etc/skel`, so a conflict on it is expected; Stow can exit nonzero on conflicts. Read the reported paths; a conflict is never permission to overwrite. The preview skips the host check that the writing targets (`clean`, `stow`, `restow`, `unstow`, `verify`) run: WSL 2, an enabled `WSLInterop` or `WSLInterop-late` handler, both Windows commands on `PATH` and a five-second PowerShell probe. A setting in `/etc/wsl.conf` alone does not prove interop works.

For a reported regular `~/.bashrc`, compare it with EyrWSL's. **Arch user, in the clone:**

```bash
ls -ld ~/.bashrc
diff -u ~/.bashrc bash/.bashrc
```

A permission field starting with `-` is a regular file; `l` is a link, which belongs to another clone and needs [its own resolution](#packages-and-deployment). `diff` exits 1 when the files differ. Once you decide to replace the regular file, keep it in a unique backup directory. **Arch user:**

```bash
backup_dir=$(mktemp -d "$HOME/eyrwsl-backup.XXXXXX") &&
  mv -i -- "$HOME/.bashrc" "$backup_dir/bashrc" &&
  printf 'Preserved old Bash config in %s\n' "$backup_dir/bashrc"
```

Keep the backup until the new setup is verified. Carry any still-needed, non-secret machine settings into a file under `~/.config/bash-overlays/`, never by sourcing the old `.bashrc`. Handle any other conflict the same way: compare the exact file and move it to an unused backup name outside the clone. Never move all of `~/.config`, delete an agent directory, use `stow --adopt` or force links.

Then run the guarded preparation and preview again. **Arch user, in the clone:**

```bash
make clean
make dry-run
```

`make clean` is not `git clean` and deletes no project files. It checks every owned path first, then removes only leftover folded links, dangling links into this clone and exact retired links it owns; it refuses regular files, foreign links and special files, and leaves real directories and user state alone ([DEVIATIONS.md](../DEVIATIONS.md#dotfile-management) has the contract). Resolve a refusal and rerun both. **Checkpoint:** preparation finishes, often with `nothing to remove`, and the preview reports no conflict.

Deploy as your user, never with `sudo`. **Arch user, in the clone:**

```bash
make stow
```

Managed parent directories stay real and only files are linked, so generated host state never lands in the clone. From now on, an edit in the clone changes live configuration before any commit. An error means the deployment is incomplete; resolve it and preview again.

Open a **new Arch tab** outside any multiplexer; re-sourcing `.bashrc` in an old shell can keep stale aliases and variables. **Arch user:**

```bash
cd ~
readlink -f ~/.bashrc
command -v mise herdr nvim starship
mise settings get paranoid
```

**Checkpoint:** `.bashrc` resolves to this clone's `bash/.bashrc`, all four commands resolve, paranoid mode prints `true`, and the Starship prompt shows without errors.

Check the effective Git identity without printing it. **Arch user, in the clone:**

```bash
if [[ -n $(git config --get user.name) && $(git config --get user.email) == *@users.noreply.github.com ]]; then
  printf 'OK: Git identity uses a name and GitHub no-reply address\n'
else
  printf 'STOP: correct the effective Git identity before committing\n'
fi
```

Expect `OK`. A legacy `~/.gitconfig` or a repository-local identity overrides the host file; fix that override, never the tracked configuration. Repeat the check in each project before its first commit, and do not set `GIT_AUTHOR_EMAIL` or `GIT_COMMITTER_EMAIL` to another identity.

### 8. AI Clients

The stowed wrappers install Claude Code and OpenCode through mise on first use. Install both without starting a session. **Arch user:**

```bash
cd ~
~/.local/bin/claude --version
~/.local/bin/opencode --version
```

Each downloads on first use, then prints its version. The wrappers run `mise use -g`, which installs under `~/.local/share/mise` and records the `latest` selection in the host-local `~/.config/mise/config.toml`; that file stays out of every package. They keep mise's 24-hour release cooldown, as does `mup` (`mise up`). Never run them with `sudo`. In a fresh tab, **Arch user:**

```bash
mise ls claude opencode
command -v claude opencode
```

**Checkpoint:** mise lists both, and each resolves under `~/.local/share/mise` or to its `~/.local/bin` wrapper, not to an older Pacman, native or Windows copy.

Launch each client once, exiting one before starting the other, and follow its sign-in flow. If no browser opens, open the printed URL in Windows yourself; the baseline omits `xdg-utils`. Keep passwords, codes, tokens and authentication files out of repositories and reports. Sign-in problems are provider issues, not deployment failures. **Arch user:**

```bash
claude
opencode
```

The clients read their normal per-user configuration; [EyrAgents](https://github.com/peregrinus879/eyragents) provides the shared harness for both. Paranoid mode makes mise ask before trusting a project's `mise.toml` or `.tool-versions`: read the file before running `mise trust` in that project, and never turn paranoid mode off.

### 9. Neovim

**Arch user:**

```bash
nvim
```

The first launch installs the plugins pinned by `lazy-lock.json`; let it finish. Run `:LazyHealth` and `:checkhealth`, confirm the Gruvbox theme, then `:qa` and reopen. Missing optional providers are not errors. Do not update plugins just to install the pinned versions. The vault at `~/Projects/vault`, its synchronization and `normalize.py` are yours, not installed here; for another path, set `OBSIDIAN_VAULT` in a Bash overlay.

### 10. Verify

**Arch user, in the clone:**

```bash
make verify
```

**Checkpoint:** the run ends with `ok:   verify` and no `FAIL` line. Without an EyrArcHy clone beside this one, the twin check is reported as skipped; do not deploy EyrArcHy to satisfy it. The manual checks in [Operations](operations.md#verify) follow once Windows Terminal is set up.

### 11. Windows Terminal

This step is a separate, explicit Windows deployment. **The tracked file replaces the whole Terminal settings file; it is not a theme merge.** It sets defaults for every profile, the keybindings, menu visibility (hiding Windows PowerShell) and `archlinux` as the default profile. Save any custom profiles, themes and shortcuts you want to keep, and review them against the tracked file first.

Open Terminal's settings file through **Settings > Open JSON file** (or Shift with **Settings** in the tab dropdown), note its path, and close the editor so it cannot save over the deployment; `defaults.json` is generated and never edited. Compare. **Arch user, in the clone:**

```bash
make wt-diff
```

The helper prints both paths; `+` lines are the current Windows settings. `drift detected` with a nonzero exit is expected before the first deployment; a path or JSON error must be fixed first. Review the whole difference. Once you decide to replace the settings, **Arch user, in the clone:**

```bash
make wt-push
make wt-diff
```

`make wt-push` finds the active Windows account through PowerShell, validates both files as JSON, and writes nothing when they already match. Otherwise it saves `settings.json.backup-TIMESTAMP` beside the destination, replaces the file atomically, and prints both paths. **Checkpoint:** the second diff reports `no drift: tracked and deployed settings match`. Keep the backup until the font, profiles and keys are confirmed in a new Terminal window.

The helper finds the stable Store installation at `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`. For a preview, unpackaged or custom installation, set `WT_SETTINGS` to the path you noted, as a WSL path, and use the same shell for diff and push; `unset WT_SETTINGS` restores discovery. **Arch user, in the clone:**

```bash
export WT_SETTINGS="$(wslpath -u 'C:\Users\YOUR_WINDOWS_USER\AppData\Local\Microsoft\Windows Terminal\settings.json')"
make wt-diff
```

The helper accepts strict JSON, with an optional UTF-8 byte-order mark, but no comments or trailing commas. For a JSONC file, keep a separate backup and convert a working copy deliberately; never discard settings to pass validation.

To roll back, close the settings editor, keep a copy of the current file, and copy the exact backup the helper printed over its neighboring `settings.json` in File Explorer. The rolled-back file then shows drift from the tracked one, as intended.

**Checkpoint:** a new window opens `archlinux` as your normal user, in JetBrainsMono Nerd Font at size 9 with Gruvbox. The file expects current WSL's `Microsoft.WSL` dynamic profile and disables the legacy `Windows.Terminal.Wsl` generator. A save from the Settings UI can write generated profiles into the file; review `make wt-diff` before restoring. Then complete the manual [Verify](operations.md#verify) checks, including the clipboard.

### 12. GitHub

Only for GitHub work. The GitHub CLI (`gh`, from `github-cli`) signs in and serves as Git's HTTPS credential helper, with no SSH keys or Windows services. Complete step 7 first, so the identity file and its include exist.

Check for an existing login. **Arch user:**

```bash
gh auth status --hostname github.com
```

If needed, sign in through the browser or device-code flow, opening the printed URL in Windows if no browser opens, then configure the credential helper. **Arch user:**

```bash
GIT_CONFIG_GLOBAL="$HOME/.config/git/config.local" GH_PATH=gh \
  gh auth login --hostname github.com --git-protocol https --web
GIT_CONFIG_GLOBAL="$HOME/.config/git/config.local" GH_PATH=gh \
  gh auth setup-git --hostname github.com
```

The variables write the helper into the untracked `config.local` as `!gh auth git-credential`, resolved through `PATH` rather than a versioned path. Plain `gh auth setup-git` would write through the stowed global configuration into this clone. The helper replaces the credential chain for `github.com` and `gist.github.com` only, so review an existing custom helper first; other hosts keep theirs.

`gh` uses an operating-system credential store when one is available and otherwise falls back to a plaintext file in your home; on WSL that is not Windows Credential Manager. Check which one it reports and decide whether it fits the host. Keep authentication state out of Git and never print tokens ([login and storage](https://cli.github.com/manual/gh_auth_login), [helper setup](https://cli.github.com/manual/gh_auth_setup-git), [`GH_PATH`](https://cli.github.com/manual/gh_help_environment)).

The clone from step 5 already uses HTTPS. Confirm the remote in both directions. **Arch user, in the clone:**

```bash
git remote get-url --all origin
git remote get-url --push --all origin
```

A clone that still uses SSH for the canonical repository changes only that remote, then rechecks with the same two commands. Convert any other clone as in [Existing Clones over SSH](#existing-clones-over-ssh). **Arch user, in the clone:**

```bash
git remote set-url origin https://github.com/peregrinus879/eyrwsl.git
```

**Checkpoint:** both directions show the HTTPS URL, then the [GitHub access checks](operations.md#github-access) pass in a fresh terminal, after a WSL restart and after a Windows reboot. Signing in authorizes no repository change by itself.

## Existing Installations

**Upgrading is not reinstalling.** Keep the registered distribution, Linux user, clone, projects, Git identity and sign-in state. Before a significant migration, make and test a backup with your own tools; a WSL export holds private files and credentials, so keep it out of repositories and assistants. Never use `wsl --unregister` to troubleshoot: it permanently deletes the distribution.

In **PowerShell**, `wsl --list --verbose` shows the installed name; if it is not `archlinux`, use the actual name in every command and review the Terminal profile before deploying. A WSL 1 or community Arch distribution is a migration: keep it, and follow [Microsoft's conversion reference](https://learn.microsoft.com/en-us/windows/wsl/basic-commands#set-wsl-version-to-1-or-2) before converting. Official Arch supports only WSL 2.

Inspect the deployed clone. **Arch user:**

```bash
git -C ~/Projects/eyrie/eyrwsl status --short --branch
readlink -f ~/.bashrc
```

Work in the clone your live links point to, not a second checkout. Keep uncommitted and untracked work; reconcile local commits or ownership errors first, and never reset, stash automatically or delete to get a clean update. Read the [maintenance ledger](maintenance.md) and any [handoff](handoff.md) for pending host work. With the clone clean, **Arch user, in the clone:**

```bash
git pull --ff-only
```

The pull changes live configuration at once, before any restow. A refused fast-forward needs review, never a forced reset. Install any missing baseline packages with [step 4](#4-prerequisites)'s commands, then look for older AI launchers. **Arch user:**

```bash
type -a claude opencode
pacman -Q opencode
```

Missing commands or packages are normal. For an old executable that shadows mise, find its owner first with `pacman -Qo /ABSOLUTE/PATH`, using the path `type` printed, and have Pacman remove only a confirmed obsolete package after reviewing the transaction. Never delete a Pacman-owned file by hand or copy a removal list from another host. A user-level launcher at a path EyrWSL owns is moved to an unused backup name outside the clone before deployment; keep its version store until the replacement works. Never delete `~/.claude`, OpenCode's configuration or data, mise state, SSH keys or credentials; uninstalling an old native installer is a separate decision, made with its official documentation.

Then redeploy with the guarded sequence, stopping at the first failure. **Arch user, in the clone:**

```bash
make dry-run
make clean
make dry-run
make restow
```

`make clean` also removes links to files the repository has retired, and only this sequence does: restow and verify never clean ([DEVIATIONS.md](../DEVIATIONS.md#dotfile-management) lists the retired paths). A pull uninstalls no package and leaves loaded functions and aliases in running shells. The last preview must be clean. In a fresh tab, repeat the checks from [step 7](#7-deploy) and [step 8](#8-ai-clients), then run `make verify`. Sign-in state should survive; never sign out to test an update. Windows Terminal keeps its separate diff, review, push and diff sequence.

To **move a deployed clone**, keep any local work, remove the links from the old clone while it still exists, then place the clone at its new location and repeat [step 7](#7-deploy) there. **Arch user:**

```bash
make -C /OLD/CLONE/PATH unstow
```

Unstow removes only this repository's links, not the clone, host data or the Windows Terminal deployment; applications lack their configuration until you stow again. If the old clone is gone, `make clean` handles its dangling links; a live link into a different clone is resolved at that clone.

### Existing Clones over SSH

Run this on the host where Git is used, after [step 12](#12-github); remote settings are local Git metadata, so no commit or pull carries them between hosts. It changes transport only, never repository locations, visibility, branches or reference clones.

Find every repository below `~/Projects`, including worktrees (a `.git` file) and nested groups; `git -C REPO_PATH rev-parse --path-format=absolute --git-common-dir` identifies shared metadata so it is edited once. Keep credential stores, session histories, dependency and build trees, and symlinks leading outside out of the search. A directory without remotes needs nothing.

For each repository, record its HEAD, status, remotes and every fetch and push URL from Git's own queries. Treat an explicit `remote.REMOTE.pushurl` separately from the fetch fallback, and account for includes, worktree configuration and URL rewrites. Never print a URL with embedded credentials. SSH URLs in tracked files such as `.gitmodules` are a source change of their own.

Convert GitHub SSH forms such as `git@github.com:OWNER/REPO.git` or `ssh://git@github.com/OWNER/REPO.git` to `https://github.com/OWNER/REPO.git`, keeping the owner and repository exactly, including a fork's owner and its separate upstream. The last argument matches the old URL as a regular expression, so escape special characters in real names. **Arch user:**

```bash
git -C REPO_PATH remote set-url REMOTE https://github.com/OWNER/REPO.git '^git@github[.]com:OWNER/REPO[.]git$'
git -C REPO_PATH remote set-url --push REMOTE https://github.com/OWNER/REPO.git '^git@github[.]com:OWNER/REPO[.]git$'
```

The second line applies only to an existing explicit SSH push URL, which may name a different repository. Re-read the URLs before each change, keep multiple entries in their order, and leave HTTPS URLs, missing push URLs, tracking, refspecs and push defaults as they are. A non-GitHub server or an SSH host alias needs a verified HTTPS endpoint, never a guessed one. Do not add a global `insteadOf` or `pushInsteadOf` rule to hide remaining SSH remotes.

Afterwards, list every remote again in both directions and confirm HEAD, index and worktree are unchanged. `ls-remote` by remote name checks only the fetch URL, so check each distinct changed fetch and push endpoint directly, without prompts. **Arch user:**

```bash
GIT_TERMINAL_PROMPT=0 GH_PROMPT_DISABLED=1 timeout --kill-after=2s 30s \
  git -C REPO_PATH -c credential.interactive=false ls-remote --exit-code -- HTTPS_ENDPOINT HEAD
```

For a private repository, `gh repo view OWNER/REPO --json nameWithOwner,isPrivate,viewerPermission` confirms it is still private and reachable. A successful read proves read access only, since public repositories answer anonymously; write access is proved only by an approved push. Report unsupported endpoints and pending access rather than claiming the migration complete.

## Troubleshooting

### WSL Installation or Startup

- **`wsl` prints help or rejects an option:** check `wsl --version` in PowerShell, run `wsl --update` in PowerShell (Admin) and restart Windows if asked. If installation still prints help on Windows 10, use [Microsoft's explicit form](https://learn.microsoft.com/en-us/windows/wsl/basic-commands#install), `wsl --install -d archlinux`, after `wsl --list --verbose` confirms Arch is not installed.
- **`archlinux` missing from the online list:** update WSL and retry `wsl --list --online`. Never guess another name; use the official image below.
- **Download stuck at 0%:** for an unfinished installation, run `wsl --install --web-download -d archlinux` in PowerShell. A distribution already listed by `wsl --list --verbose` needs diagnosis, not reinstallation.
- **Error `0x80370102` or missing virtualization:** check Task Manager, the UEFI settings and the restart after enabling WSL; inside a virtual machine, nested virtualization is the host administrator's setting. Follow [Microsoft's troubleshooting](https://learn.microsoft.com/en-us/windows/wsl/troubleshooting#installation-issues); never disable security features or unregister a distribution as a generic fix.

**Official image fallback,** for new installations only: download the current `.wsl` file and its `.wsl.SHA256` file from the [image directory ArchWiki links](https://fastly.mirror.pkgbuild.com/wsl/latest/), using the actual file names. Compute the checksum. **PowerShell:**

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath 'C:\Users\YOUR_WINDOWS_USER\Downloads\EXACT_ARCH_IMAGE.wsl' | Format-List
```

The hash in the `.SHA256` file must equal the `Hash` value, ignoring case; stop if it differs. This detects a damaged download, not a compromised source hosting both files. Install by opening the verified file in File Explorer, or **PowerShell:**

```powershell
wsl --install --from-file 'C:\Users\YOUR_WINDOWS_USER\Downloads\EXACT_ARCH_IMAGE.wsl'
```

The image registers as `archlinux`; add `--name` only to choose another name deliberately, and never install the catalog and file versions under the same name. Check `wsl --list --verbose` and continue at [step 2](#2-arch-user). For an unresolved startup error, search the [WSL issue tracker](https://github.com/microsoft/WSL/issues) with the exact error and `wsl --version` before changing host configuration.

### User and Sudo Recovery

If Arch opens as root or with the wrong home, or your user cannot use sudo, open a root shell inside the existing distribution. **PowerShell:**

```powershell
wsl -d archlinux -u root
```

**Arch root:**

```bash
id linuxuser
visudo -c
nvim /etc/wsl.conf
```

Confirm the account exists and `[user] default` names it. If `wheel` is missing from its groups, `usermod -aG wheel linuxuser` adds it while keeping the others. Fix the wheel rule with `EDITOR=nvim visudo` and rerun `visudo -c`. `passwd linuxuser` resets a forgotten password. Never delete and recreate the user or edit the password files. Restart Arch as in [step 2](#2-arch-user), open it without `-u root`, and repeat `whoami`, `pwd` and `sudo -v`. Never fix a deployment permission error by deploying as root or changing ownership of the whole home.

### Packages and Deployment

- **Pacman download, keyring, signature or file conflict:** stop before deploying. Check connectivity, the date and time, [Arch news](https://archlinux.org/news/) and [Pacman troubleshooting](https://wiki.archlinux.org/title/Pacman#Troubleshooting), then retry `sudo pacman -Syu` once the cause is understood. Never bypass signature or dependency checks or use a blanket `--overwrite`.
- **Locale warnings or garbled non-ASCII text:** check `locale -a`, `locale` and `locale charmap`, and compare with [step 3](#3-locale). Never hide the problem with a permanent `LC_ALL=C`.
- **Preview or Stow conflict:** follow [step 7](#7-deploy) for the exact reported path. `make clean` is not a force option; never use `stow --adopt`, `ln -sf` or broad deletion.
- **Another clone owns the links:** `readlink -f ~/.bashrc` shows the deployed clone; work there. Moving a clone needs unstowing from the old one first.
- **Commands or prompt missing after Stow:** open a fresh tab outside any multiplexer and repeat step 7's checks. `wsl -e COMMAND`, non-interactive Bash and running multiplexers may not load the new `.bashrc`; never kill a multiplexer with unsaved work to refresh it.
- **Git identity check fails:** set the exact no-reply address in `~/.config/git/config.local` and look for a legacy or repository-local override privately. Do not paste `git config --list` into a report; unrelated settings can be sensitive.

### AI Tools

- **mise refuses a project configuration:** review the file, then run `mise trust` in that project only if you accept it; a changed file asks again. Never disable paranoid mode or trust a whole tree.
- **First wrapper run fails or stalls:** it needs the network and a release past the cooldown. From `~`, `mise doctor` diagnoses activation, and `mise use -g claude` (or `opencode`) shows the installation error; it installs, so it is not read-only. Never add `sudo`, skip the cooldown or switch package managers.
- **The wrong binary starts:** in a fresh tab, compare `type -a claude opencode` with `mise ls claude opencode`, then follow [Existing Installations](#existing-installations). Never erase provider configuration or sign-in state to replace a launcher.
- **Sign-in cannot open a browser:** open the printed URL in Windows, use only the tool's official flow, and keep codes and tokens private.
- **Application colors differ:** confirm the active Terminal profile uses Gruvbox; applications with their own palette follow their own configuration.

### Windows Integration

For missing clipboard or PowerShell interop, check without touching the clipboard, in a fresh tab. **Arch user:**

```bash
command -v clip.exe powershell.exe
powershell.exe -NoProfile -NonInteractive -Command '$PSVersionTable.PSVersion.ToString()'
```

Expect two paths and a version; the host check needs both, while Neovim's clipboard needs only `powershell.exe`. The probe proves execution, not clipboard correctness. If the commands are missing, check `enabled = true` and `appendWindowsPath = true` under `[interop]` in `/etc/wsl.conf`, make sure no shell overlay drops the Windows `PATH` entries, and restart Arch. Then test Neovim copy and paste with disposable text, including non-ASCII characters and several lines; never use existing clipboard contents.

- **Terminal settings not found:** open the intended Terminal's settings file and use `WT_SETTINGS` as in [step 11](#11-windows-terminal), for both diff and push. Never create a settings file at a guessed path.
- **Settings rejected as invalid JSON:** the helper needs strict JSON although Terminal accepts comments; keep the original and convert a copy. A failed push deploys nothing.
- **Missing `archlinux` profile:** confirm `wsl -d archlinux` works and `wsl --list --verbose` lists that name at version 2, update and reopen WSL and Terminal, then check **Settings > Startup**. A differently named or legacy distribution needs a deliberate profile choice, not repeated `make wt-push`.
- **Boxes instead of icons:** install **JetBrainsMono Nerd Font** in Windows, select it in the active profile and restart Terminal; a Linux font does not help.
- **Obsidian image paste:** the pinned plugin has a WSL PowerShell image path, but its Windows clipboard and destination handling are [still unverified](maintenance.md#limitations-under-watch). Save images through Windows or the vault's own workflow and link them in the note.
