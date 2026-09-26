# EyrWSL

An Omarchy-style terminal environment for **Arch Linux on WSL 2**, deployed with [GNU Stow](https://www.gnu.org/software/stow/). It adapts [Omarchy](https://github.com/omacom/omarchy)'s shell, editor and tools to Windows, adds the WSL and Windows integration, and owns the whole baseline rather than layering on an installed Omarchy; every difference and its reason is in [DEVIATIONS.md](DEVIATIONS.md).

## What You Get

| Package | Adds |
| --- | --- |
| `bash/`, `starship/` | Bash and a Starship prompt, `hdw` for [Herdr](https://herdr.dev) workspaces, `wsl-update` for the system, the AI clients and Herdr, Git worktree helpers (`ga`, `gd`) and rsync watches (`rsw`, `lsw`, `dsw`) |
| `herdr/` | Omarchy's Herdr keymap and layout: `Ctrl+Space` prefix, `Alt+Enter` splits, tabs and workspaces as on the desktop |
| `nvim/` | A complete LazyVim configuration with a pinned plugin lockfile, repository-aware Git review, vault plugins, and a UTF-8 clipboard through Windows PowerShell |
| `mise/` | Launchers that install and update Claude Code and OpenCode through [mise](https://mise.jdx.dev), in paranoid mode |
| `git/`, `editorconfig/` | Shared Git and editor defaults; your identity stays in an untracked local file |
| `btop/`, `fastfetch/`, `yazi/` | Terminal application configuration in a consistent Gruvbox palette |
| `windows-terminal/` | Complete Windows Terminal settings, deployed separately with `make wt-push` |

## Requirements

Windows with WSL 2 and Windows Terminal, and an Arch Linux distribution with a normal user. Packages come from the official Arch repositories only; [setup](docs/setup.md) walks through a new installation from Windows, or an existing one, step by step.

## Quick Start

On an Arch WSL installation that already meets the [prerequisites](docs/setup.md#4-prerequisites):

```bash
git clone https://github.com/peregrinus879/eyrwsl.git ~/Projects/eyrie/eyrwsl
cd ~/Projects/eyrie/eyrwsl
make dry-run   # preview; resolve any conflict first
make stow      # deploy
make verify    # repository, deployment, tool and interop checks
```

Keep the clone in the Linux filesystem: it is live configuration. Inside Herdr, `hdw cc` opens Claude Code, Neovim and a shell as a new workspace; [operations](docs/operations.md) covers daily use.

## Documentation

| Need | Read |
| --- | --- |
| Install from Windows, step by step | [Setup: before you begin](docs/setup.md#before-you-begin) |
| Adopt an existing Arch WSL installation | [Setup: existing installations](docs/setup.md#existing-installations) |
| Fix installation, user or deployment problems | [Setup: troubleshooting](docs/setup.md#troubleshooting) |
| Daily use, checks and Make targets | [Operations](docs/operations.md) |
| What differs from Omarchy, and why | [DEVIATIONS.md](DEVIATIONS.md) |
| Keys, commands and workflows, offline | [EyrAgents workspace guide](https://github.com/peregrinus879/eyragents/blob/main/docs/workspace-guide.html) (download the raw file) |
| Open work | [Maintenance ledger](docs/maintenance.md) |
| Reconcile with Omarchy, WSL and Windows Terminal | [omasync](.agents/skills/omasync/SKILL.md) |
| Rules for agents changing this repository | [AGENTS.md](AGENTS.md) |

Companion repositories: [EyrArcHy](https://github.com/peregrinus879/eyrarchy) holds the overrides for an Omarchy desktop, sharing several files byte for byte with this repository, and [EyrAgents](https://github.com/peregrinus879/eyragents) holds the shared AI harness.

## License

[MIT](LICENSE). Adapted from Omarchy.
