# Operations

[Overview](../README.md) · [Setup](setup.md) · [Deviations](../DEVIATIONS.md) · [Open work](maintenance.md)

Run Make targets from the repository root, on the host each target requires.

## Workspace Guide

The [EyrAgents workspace guide](https://github.com/peregrinus879/eyragents/blob/main/docs/workspace-guide.html) is one offline page of Herdr, AI-client, Neovim, Git-review, vault, Bash and Yazi controls. Open it from Arch Bash and select **Arch WSL** (on GitHub, download the raw file first):

```bash
explorer.exe "$(wslpath -w "$HOME/Projects/eyrie/eyragents/docs/workspace-guide.html")"
```

EyrAgents owns the guide and its [maintenance contract](https://github.com/peregrinus879/eyragents/blob/main/docs/workspace-guide-src/README.md). A key or command change here includes reconciling the guide's `host-reference.json` there; `/omasync` reviews host facts and `/eyrsync` client facts.

## Native Herdr

Start Herdr with `herdr` in a normal-user Arch shell. In a shell inside it, change to the project directory and run `hdw <cc|oc> [-c]`:

| Command | Opens |
| --- | --- |
| `hdw cc` | Claude Code (`claude`) |
| `hdw cc -c` | Claude Code, continuing the last session (`claude -c`) |
| `hdw oc` | OpenCode (`opencode`) |
| `hdw oc -c` | OpenCode, continuing the last session (`opencode -c`) |

Each call creates and focuses a new workspace in the current directory: the AI client full-height on the left, Neovim top-right and a shell bottom-right, with the AI client focused. Call it again from any shell, including the new bottom-right one, to open another workspace; existing workspaces keep their names and layouts. Herdr's own controls handle navigation (`Ctrl+Space`, then `c` for a tab or `Shift+C` for a workspace). [DEVIATIONS.md](../DEVIATIONS.md#bash) holds the full contract, including how a failed call preserves state for inspection.

**Claude Code background sessions.** A session sent to the background with `/bg`, or with *Move to background and exit*, keeps running under Claude Code's own daemon, independently of Herdr. While it runs, `claude -c` refuses with `Your most recent conversation is running in the background (session <uuid>)`. `claude agents` lists such sessions; `claude attach <id>` reopens one with its tasks intact, and `claude stop <id>` followed by `claude -c` continues it in the foreground.

EyrWSL carries no Omarchy AI launch aliases or copied Herdr and tmux recipes; `cc` and `oc` are `hdw` arguments, not aliases.

## Git Review

Start a fresh Neovim session once after stowing. `Space g d` shows staged and unstaged hunks, `Space g D` compares against origin, and `Space g s` shows status including untracked files. Each uses the Git repository of the current file or directory, or of the selected Neo-tree item, without changing Neovim's working directory; a file outside any repository warns instead of reviewing another one. [DEVIATIONS.md](../DEVIATIONS.md#neovim) holds the full contract.

## Git Worktrees

From a repository, `ga branch-name` creates a linked worktree beside the checkout and enters it. From inside a linked worktree, `gd` shows the resolved path and branch and asks before removing them. It refuses dirty work, or a HEAD not contained in the primary checkout's HEAD, and never forces removal; a failed branch deletion leaves the branch in place. Both act on the actual repository, including from a subdirectory.

## Synchronization Watches

| Command | Effect |
| --- | --- |
| `rsw source-directory destination` | Start an initial rsync and keep watching the source. Quote paths containing spaces. |
| `lsw` | List the watches this helper started, with their source and destination. |
| `dsw` | Stop the watches this helper started. |

Use only a destination you intend to update. `rsw` prints the watcher's PID and log path; readiness means the watcher started, not that a transfer succeeded, so check the log. Changes during a transfer are still picked up, failed transfers retry after five seconds, and a reconciliation 60 seconds after the last successful transfer catches missed events. Files that exist only at the destination are kept, since the helper never uses `--delete`. Remote destinations use your normal SSH access.

## GitHub Access

After [setup](setup.md#github-login-and-https), confirm from a fresh Arch terminal in this clone:

```bash
git remote get-url --push --all origin
gh repo view peregrinus879/eyrwsl --json nameWithOwner,viewerPermission
GIT_TERMINAL_PROMPT=0 GH_PROMPT_DISABLED=1 \
  git -c credential.interactive=false ls-remote --exit-code --refs origin refs/heads/main
```

Expect the HTTPS origin, the intended access level, and a branch ID with no credential prompt. Public refs can be read anonymously, so only an approved push proves write access. To confirm access survives a restart, stop only this distribution from Windows PowerShell (`wsl --list --verbose`, then `wsl --terminate archlinux`, using its actual name), reopen it and repeat the check; do the same after the next Windows reboot. A locked store, expired login or wrong account is recovered locally through the GitHub CLI; never weaken TLS or dump tokens.

## Verify

After any change:

```bash
make lint check   # ShellCheck 0.11.0 or newer; every owned Bash, Lua, TOML, JSON, Git, btop and Fastfetch file; the fixture tests
```

On the WSL host, after stowing or changing a package, `make verify` checks WSL 2 and Windows interop, runs `lint`, `check` and `twins`, then checks the deployment: retired links are gone, the command baseline, Claude Code and OpenCode installed through mise and resolving through it, mise in paranoid mode, every link resolving into this clone with real managed parents, a GitHub no-reply Git identity (without printing it), and every owned configuration file. It fails closed.

Then check by hand, in fresh sessions:

- Bash and Starship load without errors; `command -v herdr` and `type hdw` resolve; none of `tdw`, `tdl`, `tdlm`, `tsl`, `hdl`, `hdlm`, `hsl`, `hds` or the aliases `h`, `t`, `claude`, `c`, `cx`, `cy`, `ic`, `ix`, `icx` exist (a remaining definition needs ownership review, not blanket removal);
- in a disposable Herdr session, `hdw` produces the layout above, repeated calls each create a new workspace, bare `hdw` prints usage, and calls outside Herdr refuse;
- in a disposable Git fixture, `ga <branch>` from a subdirectory and `gd` from the new worktree behave as above;
- with disposable local directories, `rsw` delivers changes made during a transfer, and `lsw` and `dsw` manage only its own watchers;
- `mise ls claude opencode` lists both, `command -v claude opencode` resolves under `~/.local/share/mise` or to the `~/.local/bin` wrappers, `mise settings get paranoid` prints `true`, and `minimum_release_age` is unset, so mise's 24-hour default applies;
- `nvim` installs its plugins and loads Gruvbox;
- Git review targets the selected repository when Neovim was started in a non-Git parent directory, without changing `:pwd`;
- the `+` and `*` registers round-trip ASCII, Arabic, CJK, accented and supplementary-plane text, multiline and empty content through a Windows application (paste removes every CR by design); only the real Windows boundary proves this, not the fixtures;
- a vault note loads obsidian.nvim, if the vault is synced here;
- Windows Terminal uses JetBrainsMono Nerd Font at size 9 and the Gruvbox scheme, with `Alt+Enter` unbound so it reaches the terminal application.

The fixture tests model Herdr, Stow, the sync helper's processes and the Windows side in fake homes; they do not replace a check on the real host. `RSW_FIXTURE_REALTIME=1 bash tests/rsyncing.sh` runs the sync fixture at its real 60-second interval. GitHub Actions runs `make lint check` and an exact twin-pair check against EyrArcHy's default branch on every push to `main` and every pull request, in an `archlinux:base` container as an unprivileged user; it does not deploy to a host.

## Make Targets

| Target | Does |
| --- | --- |
| `make dry-run` | Preview Stow's links |
| `make stow`, `make restow`, `make unstow` | Deploy, redeploy or remove the packages (WSL only) |
| `make clean` | Guarded preparation: remove only folded, dangling or retired links this clone owns; refuse on anything else (WSL only) |
| `make lint`, `make check`, `make test` | Repository checks and the fixture tests |
| `make verify` | Repository, deployment, tool and interop checks (WSL only) |
| `make twins` | Compare the twin files with the EyrArcHy clone (`SIBLING`, default `~/Projects/eyrie/eyrarchy`); a missing sibling is skipped |
| `make twins-pair SELF_COMMIT=<sha> PEER_COMMIT=<sha> SIBLING=<path>` | Compare the twin files at two exact full commit IDs, without running the peer's code |
| `make refs-plan`, `make refs` | Preview, then refresh the reference clones in [`references.txt`](../references.txt) |
| `make wt-diff` | Compare the tracked Windows Terminal settings with the deployed file |
| `make wt-push` | Deploy the reviewed settings file, backing up the previous one ([setup](setup.md#12-windows-terminal)) |

Deployment goals in one Make invocation run serially, even under `make -j`; this is not a transaction against disk failure or a second concurrent deployment.

**Twin pairs in CI.** A manual workflow run accepts an explicit `peer_commit` only with `peer_reviewed=true`, fetches the peer's objects without executing its code, and records both commits. For a coordinated change, check the final published pair once both commits are available; a green check against an earlier peer is not evidence for the final pair.

**Reference clones.** Approve a new clone or a remote repointing that `make refs-plan` shows before running `make refs`. The refresh fast-forwards listed default branches to the fetched upstream and refuses branches that are ahead or diverged; its fetch keeps existing local tags, imports new ones and prunes only origin tracking branches, and checkout never overwrites ignored files. It may include the EyrArcHy peer when selected, never arbitrary neighboring repositories. Conflicts refuse for separate review, and stale clones are reported and kept.

## Updates

`sudo pacman -Syu` updates the system, including mise itself. `mup` (`mise up`) then updates Claude Code and OpenCode, once a release is a day old under mise's default cooldown; the tools change version only through mise.

`nvim/.config/nvim/lazy-lock.json` is generated but tracked. Change it only through an intentional Lazy sync, review the pinned revisions, check a clean headless bootstrap, and commit it with the plugin change that required it.

## Upstream Changes

Periodically, and after an Omarchy baseline change, run `/omasync` to compare the owned packages with Omarchy and the WSL and Windows Terminal documentation, confirm every difference is still documented in DEVIATIONS.md, and run `make verify`.
