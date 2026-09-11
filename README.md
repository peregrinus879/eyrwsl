# EyrWSL

A self-contained Arch Linux terminal environment for **WSL2**, adapted from [Omarchy](https://github.com/omacom/omarchy), with Windows integration and mise-managed AI tools. [GNU Stow](https://www.gnu.org/software/stow/) deploys Linux configuration; Windows Terminal settings have a separate deployment step.

EyrWSL owns the terminal baseline rather than layering onto an installed Omarchy desktop. It uses official Arch packages, the native Herdr application, and a consistent Gruvbox palette.

## What Is Included

- Bash, Starship, native Herdr workspaces, and command-line navigation/search tools.
- A complete LazyVim-based Neovim configuration, contextual Git review, and vault plugins.
- Mise launchers for Claude Code, Codex, OpenCode, and Hermes Agent.
- Yazi, btop, Fastfetch, and Git configuration.
- Windows Terminal settings and UTF-8 Neovim clipboard integration through PowerShell.

## Package Layout

| Source | Contents |
| --- | --- |
| `bash/`, `starship/` | Shell, prompt, worktree/synchronization helpers, and `hdw`. |
| `mise/` | Four AI launchers, Hermes's uv/Python installation support, and paranoid-mode configuration. |
| `nvim/` | Complete editor bootstrap, configuration, plugins, and lockfile. |
| `git/`, `editorconfig/` | Shared Git and editor defaults; identity remains host-local. |
| `btop/`, `fastfetch/`, `yazi/` | Terminal application configuration. |
| `windows-terminal/` | Full Windows Terminal settings, deployed explicitly rather than stowed. |

The Linux directories above are Stow packages. `scripts/`, `tests/`, and `docs/` support setup and maintenance. [Deviations](DEVIATIONS.md) records the exact ownership boundaries.

## Repository Family

The three repositories share the `Eyr` prefix and normally live under `~/Projects/eyrie/`.

| Repository | Purpose |
| --- | --- |
| [EyrAgents](https://github.com/peregrinus879/eyragents) | Shared guidance, skills, and reviewed Git workflows for Claude Code, Codex, OpenCode, and Hermes Agent. |
| [EyrArcHy](https://github.com/peregrinus879/eyrarchy) | Personal shell, desktop, and editor customizations for an existing Omarchy installation. |
| [EyrWSL](https://github.com/peregrinus879/eyrwsl) | A self-contained Arch WSL terminal environment with Windows integration and mise-managed AI tools. |

EyrAgents is optional. EyrArcHy is for the Omarchy desktop and is not deployed on WSL.

## Setup

Choose the appropriate entry point in the [setup guide](docs/setup.md):

- [New Windows/Arch WSL installation](docs/setup.md#before-you-begin), with explicit Windows, root, and normal-user steps.
- [Existing installation](docs/setup.md#existing-installations), preserving your distribution, user, projects, and configuration.
- [GitHub access](docs/setup.md#github-access), including host-local login and prompt-free restart/reboot verification.
- [Troubleshooting and recovery](docs/setup.md#troubleshooting).
- [Windows Terminal deployment](docs/setup.md#12-windows-terminal), a reviewed full-file replacement with backup and rollback.

**Keep the deployed clone in the Linux filesystem.** Its linked files are live configuration. The guide covers conflict preservation and the separate installation, authentication, and verification steps.

## Usage

Open `herdr`, navigate to a project, then run `hdw ha` for a new Hermes/Neovim/shell workspace. `hdw ha -c` continues Hermes; `cc`, `cx`, and `oc` select the other clients.

The [operations guide](docs/operations.md) covers workspaces, Git review and worktrees, synchronization helpers, updates, and verification.

Open the [hdw Workflow Guide](docs/hdw.html) in a browser for searchable keys, commands, launch recipes and host notes across the whole workspace. It is a self-contained offline file; on GitHub, download the raw HTML first.

[GitHub setup](docs/setup.md#github-access) uses the baseline GitHub CLI and HTTPS. [Operations](docs/operations.md#github-access) covers fresh-client and restart/reboot checks. EyrAgents owns exact commit approval, Push selection, agent execution and verification.

## Verify

`make lint check` runs repository checks on either host. `make verify` requires the real WSL2 host with active Windows interop. Hosted CI and mocks do not establish Windows clipboard or deployment behavior; see the [verification checklist](docs/operations.md#verify).

## Documentation

| Need | Read |
| --- | --- |
| Install, migrate, or recover the environment | [Setup](docs/setup.md) |
| Use helpers, update tools, or verify changes | [Operations](docs/operations.md) |
| Find hdw workspace keys, commands and everyday workflows | [Offline workflow guide](docs/hdw.html) |
| Understand the terminal baseline and Windows differences | [Deviations](DEVIATIONS.md) |
| Find unresolved issues or remaining host work | [Maintenance ledger](docs/maintenance.md) |
| Complete the current cross-host migration | [WSL handoff](docs/handoff.md) |
| Reconcile with upstream Omarchy and Windows | [omasync](.agents/skills/omasync/SKILL.md) |
| Change the repository with an agent | [AGENTS.md](AGENTS.md) |

## License

[MIT](LICENSE). Adapted from Omarchy.
