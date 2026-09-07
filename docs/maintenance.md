# Maintenance Ledger - EyrWSL

Unresolved decisions, deferred work, active limitations, and the dated evidence behind them. Durable rules live in `AGENTS.md`, `DEVIATIONS.md`, a skill, a script header, or a test; remove an item here once its rule has moved there.

## Active Limitations

- `:Obsidian paste_img` expects `wl-clipboard` or `xclip`, unavailable under WSL.
- Deployment preflight does not roll back disk I/O failure or serialize independent Make processes. `twins-pair` attests exact committed twin blobs, not deployment or publication authorization; CI must name the final published pair. Revalidate these limits before introducing concurrent deployments or changing the CI pair protocol.

## Deferred Work

- Reference maintenance host evidence: fixtures do not establish the state of the shared quarry. On the next authorized reference-dependent maintenance pass, preview with `bash scripts/update-references.sh --dry-run`, obtain approval for new clones/repointing, then run the preservation-first update. Confirm exact fetched parity and preservation of local tags and ignored/stale content without disclosing private values. Keep failures explicit; revalidate after updater or Git transport changes and remove this item when the host pass is complete.
- Coordinated twin CI remains pending: after both final commits are available, validate the explicit reviewed pair using full SHAs and retain both IDs in the hosted evidence. Do not treat a green earlier-peer run as final-pair confirmation or dispatch/publish without H's authorization.
- Complete the [WSL host pass](#wsl-host-pass) on the actual host. Repository fixtures do not attest Windows behavior or the deployed home; stop on refusals rather than bypassing the guards.
- Move the Omarchy comparison pin: `DEVIATIONS.md` and the `/omasync` skill pin `v4.0.0` while the packaged Omarchy is at 4.0.2-1 (2026-09-03). On the WSL host, run `/omasync` comparing the owned packages between `v4.0.0` and the current release tag, adopt or record each difference, then move the pin in the `DEVIATIONS.md` baseline paragraph and the skill's steps 1 and 3 and completion check. The `mise/` wrappers follow v4.0.2's `omarchy-mise-install` form (`mise use -g --quiet`, added after v4.0.0) minus the cooldown export, a documented deviation; the pin move closes the `--quiet` gap rather than opening one.

## WSL Host Pass

Pending on the actual WSL host. H approves package, exact-path cleanup, Windows settings replacement and host-local repair targets separately. Do not inspect credentials or use existing clipboard contents as diagnostics.

1. After H updates the intended clone, confirm WSL2, the normal-user home and deployment owner with `uname -r`, `id -u`, `pwd`, `git status --short --branch`, and `readlink -f ~/.bashrc`. Preserve dirty/untracked work and read the current README. Do not deploy EyrArcHy here.
2. Use README's package list and `pacman -T` to identify missing prerequisites. Establish executable/package ownership before proposing a removal, and preserve only a specifically reviewed conflicting launcher under an unused backup name. Keep versions stores until the replacement is verified; no blanket package, launcher, store, auth or configuration cleanup is a prerequisite.
3. From the deployed EyrWSL clone, run `make require-clone`, `make dry-run`, `make clean`, `make dry-run`, and `make restow` in order. The guard must establish active WSL2/interop, including a standard or late handler and bounded PowerShell probe. Confirm real managed parents, leaf links, mise wrappers and the paranoid-mode fragment. Regular files/foreign links require preservation and review, never a force/adopt option. `~/.config/opencode` stays EyrAgents-owned.
4. Open a fresh normal-user shell. Confirm mise paranoid mode, both OpenCode environment variables from README, and absence of `OPENCODE_DISABLE_EXTERNAL_SKILLS`. Retain the existing release cooldown and authentication. Install missing tools only within the approved installation scope, then check mise inventory/resolution and run `make verify`. Record actual host results, not fixture outcomes.
5. Run `make wt-diff` and review the complete tracked Windows Terminal replacement. Only after explicit approval, run `make wt-push`, then `make wt-diff`; verify the reported backup and intended profile/font. Direct `scripts/wt-diff.sh --push` must have the same host/clone protection. Real Windows deployment and rollback remain unverified until this host pass.
6. If adopting EyrAgents, follow [its deployment and host items](https://github.com/peregrinus879/eyragents/blob/main/docs/maintenance.md#deferred-work) in its own clone. Reference updates are a separate reviewed maintenance operation, not an automatic deployment step. Report safe versions, exact revision, completed checks and remaining limitations; remove this host-pass section only when its checks are complete or each remaining limitation is retained explicitly.

## Revalidation Triggers

- Each Omarchy release (the newest tag in `~/Projects/quarry/omarchy` after `make refs`): rerun `/omasync` against the pin and decide whether to move it, then `make verify` on the WSL host.
