# Maintenance Ledger

[Overview](../README.md) · [Operations](operations.md)

Open work only. Each item states what is open, why, and what closes it; when an item closes, any lasting rule moves to its owner and the item is removed. Read this ledger before package, WSL or Windows Terminal changes.

## Pending on the WSL Host

- **Fresh-image onboarding.** The beginner setup and troubleshooting commands were checked for syntax and against their sources, not run on a fresh Windows and Arch image. Closes when a fresh-image install follows [setup](setup.md) end to end, or on a change to the upstream installation contract.

## Open Decisions

- **Vault note workflows.** Rename and promote do not yet support an explicit target, completion or reference-safe renaming. Closes only on H's request, coordinated across both twins and the vault project's own scripts.

## Limitations Under Watch

| Limitation | Owner | Recheck when |
| --- | --- | --- |
| The clipboard fixtures mock Neovim and the UTF-8 pipes, not Windows PowerShell; the real-host round trip passed on Windows PowerShell 5.1.26100.9444 (ASCII, Arabic, CJK and emoji, and a Notepad exchange), and paste removes every CR by design | [operations](operations.md#verify) | PowerShell, interop or Neovim's provider changes |
| `rsw` checks reconciliation and monitor failure only between transfers, with no transfer timeout, so a stalled transfer can delay exit indefinitely; local WSL inotify delivered a change made during a watch, while remote production endpoints are unverified; killing the fixture's guard with SIGKILL can leave its descendants and state behind | [operations](operations.md#synchronization-watches) | a host check, or a monitor or rsync change |
| Vault image paste: the pinned obsidian.nvim 3.16.6 source has a WSL PowerShell image path, but real Windows clipboard and destination handling are unverified | [setup](setup.md#windows-integration) | a host check, or a change to the plugin's image-paste interface |
| `hdw`'s checks protect cooperating calls, not a server-side atomic transaction; real Herdr 0.8.2 cases passed in private namespaces, and `hdw cc` and `hdw oc` produced the layout on this host with Herdr 0.9.1 | [DEVIATIONS](../DEVIATIONS.md#bash) | the helper, Herdr's CLI or schema, or its layout behavior changes |
| Git review uses per-call file or explorer context (checked on Neovim 0.12.5 and Snacks `882c996`; WSL's pinned Neo-tree `5e076e5` has the same API; H confirmed it on this host; related upstream reports: [Snacks #1639](https://github.com/folke/snacks.nvim/issues/1639), [#2483](https://github.com/folke/snacks.nvim/issues/2483)) | [DEVIATIONS](../DEVIATIONS.md#neovim) | picker working-directory, root detection, Neo-tree state or LazyVim mappings change |
| The paired reference updater follows GitHub's canonical name without a pinned project identity, and can repoint `origin` before its dirty check | [operations](operations.md#make-targets) | fixed together in both twins, with rename, reused-ID and dirty-refusal tests |
| Deployment is serial within one Make invocation, not a transaction; `twins-pair` attests committed twin files, not deployment or publication | [operations](operations.md#make-targets) | before concurrent deployments or a CI pair-protocol change |

## Revalidation Triggers

- **Each Omarchy release** (the newest tag in `~/Projects/quarry/omarchy` after `make refs`): run `/omasync` against the pin, decide whether to move it, then `make verify` on the WSL host.
