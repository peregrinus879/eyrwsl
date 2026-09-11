# Operations

[Overview](../README.md) · [Setup](setup.md) · [Open work](maintenance.md)

Run Make targets from the repository root, on the host required by each target.

## Workflow Cheat Sheet

Open the self-contained [hdw Workflow Guide](hdw.html) in a browser. From Arch Bash, open its Windows path and choose a browser if prompted:

```bash
explorer.exe "$(wslpath -w "$PWD/docs/hdw.html")"
```

Daily and All views cover Herdr, the four AI clients, Neovim/Neo-tree, Git review, vault notes, Bash tools and Yazi. The host profile selects outer-terminal controls and host-specific notes. Search, saved keys, copyable launcher commands and printing work offline; source links open online references when selected.

One keybinding is a shortcut; a keymap is the collection. Both belong in this single guide. Its shared source and [maintenance instructions](cheatsheet/README.md) live under `docs/cheatsheet/`; `make cheatsheet` rebuilds the HTML, `make check` rejects stale output, and `make twins` compares the shared authoring files. Update both companion guides when their shared configuration changes.

Guide reconciliation is part of every in-scope binding or command addition, change and removal. Follow [change-coupled maintenance](cheatsheet/README.md#change-coupled-maintenance), including inherited-default changes after application/plugin updates. `/omasync` owns host/default review; EyrAgents' `/eyrsync` owns AI-client review. The checks verify generated/twin consistency, not the accuracy of live keymaps.

## Native Herdr

Open Herdr independently by running `herdr` in a normal-user Arch shell. In a shell inside that session, navigate to the desired directory, then run `hdw <cc|cx|oc|ha> [-c]` to create and focus a new workspace:

- `cc` sends `claude`; `-c` uses `claude -c`.
- `cx` sends `codex`; `-c` uses `codex resume --last`.
- `oc` sends `opencode`; `-c` uses `opencode -c`.
- `ha` sends `hermes`; `-c` uses `hermes -c`.

Hermes continuation may restore its recorded cwd after launch. EyrAgents owns the Hermes configuration; `hdw` supplies no YOLO flag or separate profile.

`hdw` uses the current physical directory, not an inferred Git root. AI occupies the full-height left column, Neovim the top-right and a shell the bottom-right, with equal columns, equally stacked right panes and AI focus. The caller may be in a populated tab or an inactive workspace, but its pane identity and selected-tab context must be valid. Every call creates a separate workspace, even in the same directory; change directory in a generated bottom-right shell and call again to open the next workspace. Bare `hdw` prints usage; outside-Herdr or invalid-context calls refuse.

Existing workspace/tab names and layouts stay intact, apart from normal global workspace focus moving to the new workspace. New names are Herdr's defaults, with no `--label` or rename/metadata writes; the new default tab displays positional `1` ([Herdr 0.8.2 display-name implementation](https://github.com/herdrdev/herdr/blob/v0.8.2/src/workspace.rs)). There is no workspace reuse, roots registry, server startup or client attachment. Old `hdw` state and recovery files remain unused and untouched. Native controls still own navigation: the shipped `Ctrl+Space` prefix followed by `c` opens a tab and `Shift+C` opens a workspace; in-app help is authoritative for personal keymap changes.

Cooperating calls are serialized. Caller identity, the pre-creation workspace inventory, the new root's opaque terminal identity, exact membership and complete geometry are checked before tool input. Cleanup may close only proven new split panes before input, never any workspace, tab, root or original caller. A newly created workspace/root always remains for inspection on failure; possible input or uncertain ownership preserves remaining state. Inspect the reported original/new recovery context before manual action. This is not an atomic multi-RPC transaction.

The `cc`/`cx`/`oc`/`ha` selectors are arguments, not shell aliases. `hdw` sends full commands and still loads applicable EyrAgents settings; it is not an isolated profile. EyrWSL supplies no Omarchy AI shortcuts, `h`/`t` aliases, copied `hdl`/`hdlm`/`hsl`/`hds`, or tmux recipes. Native Herdr binary/configuration/keymap remain unchanged; do not import desktop launch helpers during sync.

## GitHub Access

After [host-local setup](setup.md#github-login-and-https), open a fresh normal Arch WSL terminal in this clone and check:

```bash
command -v gh
git remote get-url --push --all origin
gh repo view peregrinus879/eyrwsl --json nameWithOwner,viewerPermission
GIT_TERMINAL_PROMPT=0 GH_PROMPT_DISABLED=1 \
  git -c credential.interactive=false ls-remote --exit-code --refs origin refs/heads/main
```

Expect the canonical HTTPS origin, intended repository/access level, and a branch ID without another credential prompt. Public Git refs can be read anonymously; that result alone does not establish authenticated Git writes. H checks helper configuration locally, without displaying credentials, and the next independently approved publication supplies real write-path evidence.

After saving work, at a time H chooses, check `wsl --list --verbose` in **normal Windows PowerShell**. H can then terminate only the intended distribution with `wsl --terminate archlinux`, substituting its actual registered name if different. Reopen it through Windows Terminal and repeat the checks above without refreshing credentials. At the next H-chosen Windows reboot, sign in normally and repeat them from a fresh Arch WSL terminal. Confirm prompt absence explicitly; a manually repaired terminal is not persistence evidence. Launch new AI clients there and record actual versions, source IDs and outcomes in [maintenance](maintenance.md#deferred-work) and the [handoff](handoff.md).

Authentication readiness is separate from EyrAgents' exact commit approval, exact Push selection, agent execution and verification. Codex retains its restrictions and hands publication to a separately launched network-capable primary with fresh approval. Credential access carries the account's permissions, not read-only isolation. A locked store, expired login or wrong account requires H-local recovery through the standard CLI/native UI. Neither TLS/host-trust weakening nor dumping tokens is a recovery step. Follow the setup command's host-local configuration target when refreshing Git helper settings after an update.

## Git Review

After stowing, start a fresh Neovim session once to load `git-review.lua`. `Space g d` shows staged and unstaged hunks, `Space g D` compares against origin, and `Space g s` shows status including untracked files. Each invocation uses the current file/directory's Git repository or the selected Neo-tree item, falling back to the displayed tree root when no item path exists. Symlink targets and linked worktrees are supported; switching files between repositories switches the review target without changing any editor directory.

Empty or special non-explorer buffers use the current window's directory. A known non-Git file or explorer target warns instead of silently reviewing another repository. No recurring `:cd`/`:lcd` is needed for repository files or selected repository folders. Keep the ordinary picker review controls; do not use its stage/restore actions unless intended.

## Git Worktrees

From a repository, `ga branch-name` creates a linked worktree beside the checkout and enters it. From inside a linked worktree, `gd` shows the resolved path and branch and asks before removing them. It refuses dirty work or a HEAD not contained in the primary checkout's HEAD; a failed branch deletion leaves the branch in place.

These helpers act on the actual repository/worktree context, including from a subdirectory. Save and commit work before removal; see [worktree verification](#verify) for disposable checks.

## Synchronization Watches

| Command | Effect |
| --- | --- |
| `rsw source-directory destination` | Start an initial rsync and keep watching the source. Quote paths containing spaces. |
| `lsw` | List active watches created by this helper, with their source and destination. |
| `dsw` | Stop all active watches recognized as belonging to this helper. |

Use only a destination you intend to update. `rsw` prints the watcher PID and log path; readiness means the watcher started, not that the transfer completed. Check that log for failures. Changes during a transfer remain observed, failed transfers retry, and periodic reconciliation catches missed events. Destination-only files are retained because the helper does not use `--delete`. Remote destinations use your normal SSH access and require their own authorization.

## Verify

Layout fixtures use fake agents and a Python-backed Herdr model. They cover new-workspace creation, populated/inactive callers, repeated calls and generated-shell chaining, ownership, failure recovery and concurrency without using running user workspaces or real agents. Real-Herdr, rendered UI and actual-host evidence remain separate; see [active limitations](maintenance.md#active-limitations). Deployment fixtures retire real old Stow deployments after source removal, including the copied Herdr helper; verification neither requires nor invokes tmux.

The rsync fixture uses fake local monitor/transfer commands, not SSH or production endpoints. It checks literal source resolution, complete readiness publication, events during a successful transfer, burst coalescing, failure retry, missed-event reconciliation and watcher management. Normal checks shorten only the fixture's reconciliation interval to 10 seconds; `RSW_FIXTURE_REALTIME=1 bash tests/rsyncing.sh` exercises the unchanged 60-second interval. The Python guard requires Linux child-subreaper support and `/proc`: it owns detached descendants, uses bounded TERM/KILL cleanup, and removes state only after all children are reaped. Unverified cleanup fails and retains its reported diagnostic directory. Killing the guard itself with SIGKILL can leave descendants and state behind.

After stowing or changing owned packages:

- Run `make lint` and `make check` after any change; both are repository-only (ShellCheck; every owned Bash, Lua, TOML, JSON, JSONC, Git, btop, and Fastfetch config in `repo` mode; the `tests/` fixtures). GitHub Actions runs them on pushes to `main` and pull requests, plus an exact committed twin-pair check against EyrArcHy's fetched default branch.
- Run `make verify` from the repo root on the WSL host after stowing or changing owned packages: the active WSL2/interop host guard first, then `lint`, `check`, and `twins`, followed by `scripts/verify.sh` in `full` mode (command baseline, the four AI tools installed by mise and resolving through it, every Git-visible Stow source resolving into this repo with its managed parents real directories, a GitHub no-reply Git identity that is never printed, and every owned config).

Complete these manual fresh-session checks:

- Confirm the core symlinks and local Git identity exist: `test -L ~/.bashrc && test -L ~/.config/starship.toml && test -L ~/.config/nvim/lua/config/options.lua && test -f ~/.config/git/config.local`
- Start a fresh shell and confirm Bash and Starship load without errors; EyrWSL must not supply `tdw`, `tdl`, `tdlm`, `tsl`, `hdl`, `hdlm`, `hsl`, `hds`, or aliases `h`/`t`. A remaining host/user definition needs ownership review, not blanket removal. `command -v herdr` and `type hdw` must still resolve; preserve native Herdr configuration/keymap.
- Confirm `printenv OPENCODE_DISABLE_CLAUDE_CODE_SKILLS` and `printenv OPENCODE_ENABLE_EXA` each print `1`.
- Start a fresh shell and confirm `alias claude c cx cy ic ix icx` reports no alias for any of them: EyrWSL does not supply Omarchy AI shortcuts, and the full tool commands load applicable EyrAgents settings.
- Open a disposable session with `herdr` and check the [Native Herdr](#native-herdr) layout, full agent/continuation commands, native names and AI focus. Repeated calls, including from a populated caller, a valid inactive source workspace and a generated bottom-right shell, must each create a new workspace; existing names/layouts must stay intact apart from global focus. Bare invocation shows usage; outside-Herdr and invalid-context calls refuse without server startup or attachment. Do not experiment in an existing working session.
- On helper failure, inspect the original/new pane/tab/workspace context before manual cleanup. The new workspace/root must remain; only verified new split panes may be removed before possible input, never any workspace/tab/root/caller. Preserve uncertain state and older roots/recovery files. These multi-call operations are not server-side atomic transactions.
- In a disposable Git fixture, check `ga <branch>` from a subdirectory and `gd` from the resulting linked worktree, including the normal shell's `cd` alias. `gd` confirms the actual path/branch, requires its HEAD to be contained in the primary worktree's current HEAD, refuses dirty work and never forces removal; a failed branch deletion reports that the branch was retained. The primary worktree need not be on a branch named `main`. Do not use a real working branch as a removal test.
- With disposable local source/destination directories, start `rsw <source> <destination>`, note its PID/log path, and confirm changes during a transfer eventually arrive. Readiness is not sync success: inspect logs for transfer/monitor failures and retries. Reconciliation is checked between transfers, 60 seconds after the last successful completion. Monitor death stops the watcher after the current transfer returns and requires inspection/restart; a stalled transfer can delay this indefinitely. `lsw` and `dsw` manage only watchers started by this implementation; do not assume an older watcher stopped. No `--delete` is used, so destination-only files remain.
- Confirm `mise ls claude codex opencode pipx:hermes-agent uv` lists an installed version of each tool, and `command -v claude codex opencode hermes` resolves every one under `~/.local/share/mise` (interactive shells, through `mise activate`) or to its `~/.local/bin` wrapper; `make verify` fails when a tool is missing from mise or resolves elsewhere.
- Confirm `mise settings get paranoid` prints `true` and `mise settings get minimum_release_age` reports that the setting is not set, so the 24-hour default applies; `make verify` checks paranoid mode in full mode.
- Run `nvim` once and confirm plugins install successfully and Gruvbox loads.
- Check Git review from files in two repositories and from a selected Neo-tree repository folder while the editor was launched in their non-Git parent; `Space g d` and `Space g s` must target the selection without changing `:pwd`.
- In Neovim, verify both `+` and `*` registers with disposable ASCII, Arabic/CJK, accented and supplementary-plane text through a Windows application, including multiline/CRLF, empty contents, and trailing newlines. Paste strips every CR, normalizing CRLF to LF; this is not byte-for-byte preservation. The provider uses PowerShell with explicit UTF-8 and no profile for both directions, not `clip.exe`. Do not inspect pre-existing clipboard content; mocks are not evidence that this Windows boundary passed.
- If the vault is synced to this machine, open a vault note and confirm obsidian.nvim loads (`<leader>oo` opens the note switcher).
- In OpenCode, run `/theme` and confirm `system` is selected so the TUI inherits Windows Terminal's Gruvbox ANSI palette.
- Confirm Windows Terminal uses JetBrainsMono Nerd Font at size 9 and the Gruvbox color scheme after applying `windows-terminal/settings.json`.
- Keep Windows Terminal `Alt+Enter` unbound (`"id": null`) so it passes through to the terminal application rather than toggling fullscreen. Omarchy's Herdr map uses this key too; tmux retirement does not call for a settings change or deployment.

CI runs `make lint`, `make check`, and `twins-pair` on pushes to `main` and pull requests, using the peer default branch for normal runs. Manual workflow dispatch accepts an explicit full `peer_commit` only with `peer_reviewed=true`; it fetches peer objects without executing peer code and records both actual commits. This attestation is not publication authorization. For coordinated changes, verify the final published pair explicitly after both commits are available; a green check against an earlier peer is not final-pair evidence. Local `make twins` remains a worktree convenience check that can skip a missing sibling.

CI uses the official `archlinux:base` container with a full signed-package upgrade, matching the Arch userspace of both supported hosts. `ubuntu-latest` supplies only GitHub's VM. Checks run as an unprivileged `ci` user with explicit Bash, a private temporary directory and container process reaping; checkout credentials are not persisted. CI does not perform or attest deployment to Omarchy or WSL.

## Maintenance

A repo-root `Makefile` keeps the package list in one place and wraps the routine commands. `stow`, `unstow`, `restow`, `clean`, `verify`, and `wt-push` run on the WSL machine; `lint`, `check`, `twins`, `twins-pair`, and `refs` run anywhere:

- `make stow` / `make unstow` / `make dry-run` / `make restow` - the stow command sets over the package list, without directory folding
- `make lint` - ShellCheck 0.11.0 or newer over the bash package, `scripts/`, and `tests/`; `.shellcheckrc` disables the upstream-derived warnings so new issues stand out
- `make check` - repository-only checks: `scripts/verify.sh` in `repo` mode over every owned config, then every fixture suite (runs in CI)
- `make twins` - twin-file sync against the EyrArcHy clone (`SIBLING`, default `~/Projects/eyrie/eyrarchy`); a missing sibling is reported as a skipped check
- `make twins-pair SELF_COMMIT=<full-sha> PEER_COMMIT=<full-sha> SIBLING=<peer-object-repo>` - read-only twin comparison of two exact full 40-character commit IDs; all three inputs remain literal data, missing objects/files fail, and no peer code executes. Replace the placeholders and quote the peer path; do not type angle brackets
- `make verify` - `lint`, `check`, and `twins`, then `scripts/verify.sh` in `full` mode (host, command baseline, mise-managed AI tools, deployment with real managed parents, no-reply identity, and every owned config); refuses off the WSL host
- `make test` - fake-home deployment, ownership, verifier, Windows Terminal, and reference-clone fixtures; the loop stops on the first failing suite
- `make clean` - WSL-only guarded stow preparation (`scripts/prepare-stow.sh`); owned folds, recognized dangling active-package clone links and exact retired links only, aborts before removing anything otherwise; run before preview/restow when retiring links
- `make refs` - clone and fast-forward listed references to exact fetched upstream parity, repointing moved GitHub remotes; report and keep stale clones, never auto-delete them (`/omasync` step 1)
- `make wt-diff` - diff the tracked Windows Terminal settings against the deployed Windows-side file (normalized with `jq`, since Windows Terminal rewrites key order)
- `make wt-push` - after full-file review/approval, require active WSL2/interop and deployed-clone ownership, validate both settings files, back up a changed deployment, and atomically deploy the tracked file; direct `scripts/wt-diff.sh --push` has the same guard

Every host-writing Make target checks host and deployed-clone ownership before mutation. Deployment goals are serialized within one Make invocation, including `make -j`; this is not rollback against I/O failure or independent concurrent deployments.

Before running `make refs`, preview with `bash scripts/update-references.sh --dry-run` and approve any new clone or remote repointing separately. The preview can query GitHub but does not fetch or establish conflict-free upstream parity. Routine authorized refreshes remain the sync skill's work; atomic fetch does not make the whole family update transactional.

`make refs` refuses ahead-only/divergent listed default branches instead of calling them current. Its atomic, non-forced fetch preserves existing local tags and annotations, imports new tags, and prunes only origin tracking branches. Checkout and merge use `--no-overwrite-ignore`, preserving ignored files in listed clones. Tag/file conflicts refuse that update and require separate review; do not force a tag replacement or delete local files to make it pass. Stale references are informational and require separate review of all refs, stashes, and ignored/untracked files before any manual removal.

Direct `scripts/wt-diff.sh --push` also checks host/clone ownership before discovering or reading the Windows destination. The diff-only mode remains read-only; the full-file replacement still requires explicit review as described in [Setup](setup.md#12-windows-terminal).

Updates run in two steps, as Omarchy's updater does in one: `sudo pacman -Syu` updates the system, mise itself included (the packaged mise cannot self-update and says so when asked), and never touches the mise-managed tools; `mup` then brings Claude Code, Codex, OpenCode, and Hermes Agent current, the `mise up` call Omarchy runs after its package step, here without Omarchy's cooldown override, so a release counts once it is a day old. Under mise, Claude Code's native auto-updater is not in play; the tools change version only through mise.

`nvim/.config/nvim/lazy-lock.json` is generated but tracked. Update it only through an intentional Lazy sync, review the pinned revision changes, verify a clean headless bootstrap, and commit the lockfile with the plugin-spec change that required it.

Periodically, review the local reference repos and official docs for upstream changes to owned packages, sync with `/omasync` or a manual comparison, and confirm every intentional difference is still documented in `DEVIATIONS.md`. Unresolved decisions, deferred work, active limitations, and dated evidence live in [docs/maintenance.md](maintenance.md).
