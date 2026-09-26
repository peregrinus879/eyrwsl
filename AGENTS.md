# AGENTS.md - EyrWSL

EyrWSL is a self-contained Arch Linux terminal environment for WSL 2, adapted from [Omarchy](https://github.com/omacom/omarchy) and deployed with [GNU Stow](https://www.gnu.org/software/stow/). Unlike [EyrArcHy](https://github.com/peregrinus879/eyrarchy), it owns the whole terminal baseline rather than layering on an installed Omarchy, plus the WSL and Windows integration. Omarchy's pinned baseline, the official documentation and [DEVIATIONS.md](DEVIATIONS.md) define defaults, intentional differences and ownership.

## Loading

Claude Code (2.1.277 or later) and OpenCode read this file natively as the project's `AGENTS.md`; the repository has no `CLAUDE.md`, which would take precedence. The `omasync` skill lives in `.agents/skills`, with a tracked directory link under `.claude/skills` for Claude Code.

## Ownership

| Owner | Holds |
| --- | --- |
| This file | Invariants for agents changing the repository |
| [README](README.md) | Overview and navigation |
| [DEVIATIONS.md](DEVIATIONS.md) | Every intentional difference from Omarchy, its reason, and the behavior contracts of `hdw`, the Git and sync helpers, the clipboard and the launchers |
| [Setup](docs/setup.md) | Windows and WSL installation, deployment, GitHub access and recovery |
| [Operations](docs/operations.md) | Daily use, verification and Make targets |
| [Maintenance ledger](docs/maintenance.md) | Open work only; read it before package, WSL or Windows Terminal changes |
| [`omasync`](.agents/skills/omasync/SKILL.md) | Reconciliation with Omarchy, WSL and Windows Terminal upstreams |
| `Makefile`, script headers, tests | The package list, twin list, local constraints and checked contracts |

State each fact once, at its owner, and link to it. Git history holds provenance. [EyrAgents](https://github.com/peregrinus879/eyragents) owns the offline workspace guide; a change to a key or command here includes reconciling its `host-reference.json` there, or recording the pending reconciliation in this ledger when that repository is out of scope.

## Invariants

- **Target host.** Host-writing targets (`stow`, `unstow`, `restow`, `clean`, `verify`, `wt-push`) refuse anywhere but WSL 2 with working Windows interop, proven by an enabled interop handler, resolvable `clip.exe` and `powershell.exe`, and a successful PowerShell probe; each also checks that the deployed links belong to this clone. `lint`, `check`, `test`, `twins`, `twins-pair` and `refs` run anywhere.
- **Live configuration.** An edit to a stowed file takes effect at the next shell, Git command or Neovim session, before any commit. Work on this repository only in a session H is watching. The stowed Git configuration carries aliases and includes, so editing it is a code-execution change; it stays editable because every change is visible in the diff.
- **Owned baseline.** Packages come from the official Arch repositories, with no AUR helper; Herdr uses its canonical installer while no package exists. Claude Code and OpenCode install and update through mise, in paranoid mode, with mise's default release cooldown. AI-client configuration belongs to EyrAgents, not here.
- **No copied Omarchy desktop recipes.** EyrWSL carries native Herdr and `hdw`, not Omarchy's `hdl`, `hdlm`, `hsl`, `hds`, AI shortcuts, `h`/`t` aliases or a tmux baseline.
- **Twins with EyrArcHy.** The files in the Makefile's `TWIN_SPECS` (Neovim plugin specs, `hdw`, Yazi configuration, the reference updater and their tests) are byte-identical across both repositories; shared concepts use identical wording, with only repository-specific values differing.
- **Host-local state.** Git identity and GitHub helper settings live in the untracked `~/.config/git/config.local`; mise's own configuration and installs are host state its wrappers create. Neither enters a package, and credentials never enter the repository.
- **Windows Terminal.** `windows-terminal/settings.json` is a complete settings file, never stowed: deploy it with `make wt-push`, and run `make wt-diff` before and after changing it.
- **Preservation.** Cleanup, retirement, reference refreshes and recovery never delete or overwrite what they cannot prove they own; they refuse and report instead. `make verify` fails closed. The script headers and [setup](docs/setup.md) state each rule.
- **Documentation together.** Every intentional difference is documented in DEVIATIONS.md, and the overview, this file and the affected guides change together with it.

## Checks

`make lint check` are the repository checks. On the WSL host, `make verify` adds deployment, tool and interop checks, and `make twins` compares the twin files with EyrArcHy. The Windows clipboard and Terminal behavior can only be verified on the real host. [Operations](docs/operations.md#verify) holds the full checklist.
