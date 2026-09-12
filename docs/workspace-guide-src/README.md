# Workspace Guide

Open [`../workspace-guide.html`](../workspace-guide.html) in a modern browser. On GitHub, download the raw HTML first. The page works offline without a server, external fonts, libraries, or asset requests. Source links open online references only when selected.

The guide covers the complete `hdw <cc|cx|oc|ha> [-c]` launcher interface and practical controls for Herdr, the four AI clients, Neovim/LazyVim, Neo-tree, contextual Git review, vault notes, Bash tools and Yazi. The outer-terminal section follows the selected host. Application help owns the full evolving command catalogs.

## Use

- **Daily** is the quick-start set. **All** shows every action for this host.
- Press `/` to search names, shortcuts, commands, modes and context. A search from Daily expands to All; layer, task and Saved filters remain explicit.
- Expand **Context & source** for the action's mode, effects, routing notes and evidence.
- **Workspace launcher** generates copyable Bash commands. An optional directory is shell-quoted; `~` and `~/` expand to HOME, while other shell syntax stays literal. Relative paths start with `./` to avoid `CDPATH` searches and Bash's special `-` destination. Copying never executes anything.
- **Workflow & host notes** connects the panes and explains terminal interception, editor selection and helper differences.
- **Sources & live help** records source baselines and the runtime inspection routes.
- Stars and theme use browser-local storage when available. A browser may scope that storage to the file URL; export/import saved keys when moving or renaming a local copy. Storage keys and saved-key format identifiers are stable compatibility identifiers, independent of the guide or launcher name. Export/import saved keys explicitly transfers favorites; imports merge known IDs and retain recognized peer-host favorites. Nothing syncs automatically.
- **Print view** prints the selected view. In the reference view it includes the current filtered actions and expanded context, then restores the screen's disclosure state.

A **keybinding** is one shortcut. A **keymap** is the collection of shortcuts. One guide includes both keys and commands; there is no separate keymap document to maintain.

Counts measure reference entries, not individual shortcuts or a comparable total of application capabilities. An entry can group related actions or alternative keys. The host selector chooses Ghostty/Omarchy or Windows Terminal entries and host-specific helper explanations; the core workspace reference is shared.

## Ownership and rebuild

| File | Owner / purpose |
| --- | --- |
| `reference.json` | Shared curated actions, sources, recipes, workflows and both host profiles. Edit this to change reference content. |
| `template.html` | Shared offline interface, styles and embedded JavaScript. |
| `build.py` | Standard-library generator and structural/staleness checks. |
| `../workspace-guide.html` | Generated, tracked single-file deliverable. Only its embedded profile selector differs between repositories. |

Run from each repository root:

```bash
make workspace-guide
make check
make twins
```

The Makefile supplies the host profile explicitly, so renamed clones still build correctly. `make check` validates reference IDs, sources, host coverage and all four launcher recipes, then compares the HTML without writing. `make twins` protects the four shared authoring files from drift. Rebuild both companion outputs after changing shared source; the generator neither reaches into the sibling nor reads live user configuration.

## Change-coupled maintenance

The author changing a binding or adopting an update owns its guide reconciliation. It is part of the same atomic change, with companion documentation in both host repositories. A change is incomplete while an affected guide is knowingly stale.

Review additions, changes and removals, including commands/arguments, prefixes, modes, clipboard behavior, key interception, enabled/disabled plugins, and inherited defaults. An application or plugin upgrade can change these without modifying any personal keymap file.

| Change owner | Guide responsibility |
| --- | --- |
| EyrArcHy and EyrWSL configuration work | Reconcile affected Herdr, editor/tree/vault, shell, Yazi and outer-terminal entries. |
| Each repository's `/omasync` | Review inherited controls after relevant Omarchy, Herdr, terminal, Neovim/plugin or Yazi updates and configuration refreshes. Preserve the distinction between installed behavior and a newer upstream version. |
| EyrAgents configuration work and `/eyrsync` | Reconcile AI-client shortcuts, slash commands, launch/continuation arguments, skills and modes in both guides. |

For each affected area:

1. Compare the previous guide with the owning configuration, version-matched source and current application help. Check inherited mappings as well as explicit overrides. For host-specific key delivery, use the actual host or retain an explicit verification gap.
2. Add, edit or remove the affected `reference.json` entries. Update related recipes, workflow text, host notes and source records together. Keep a stable action ID when the same action merely changes keys; remove obsolete actions instead of leaving old shortcuts as alternatives.
3. Record the affected component's checked version/ref and evidence scope. Do not advance the whole guide's review date or other components' baselines merely because one component was checked. If behavior is unchanged, record that result in the change review; no cosmetic data edit is needed.
4. Copy the shared authoring changes to the companion repository, regenerate both outputs with `make workspace-guide`, then run each repository's required checks and `make twins`. Inspect the affected rendered entries. Interface changes also use the browser exercise below.
5. If a sibling, source or actual host is unavailable, or a companion edit needs separate authorization, record the exact pending update/check in the owning `docs/maintenance.md` and report the guide reconciliation as incomplete. Preserve current evidence and authorization boundaries rather than claiming a completed cross-host review.

**Automatic-check boundary:** generation/staleness and twin checks verify file consistency. They do not parse live application keymaps, monitor installed-software changes, or prove that a documented shortcut still performs the stated action. Source/live-help review in the owning workflow supplies that assurance. Relevant upstream updates therefore trigger this review even when the checks are green.

Link active limitations to the repository's maintenance owner rather than expanding this directory into a second ledger.

For interface changes, exercise search, filters, disclosures, favorites, import/export, all eight launcher combinations, quoted directory input, clipboard fallback, theme, print and narrow/wide layouts in an isolated browser profile. Browser checks establish guide behavior, not real keystroke delivery through Herdr or Windows Terminal.

The layout adapts H's Keymap dashboard; the curated starting reference comes from H's Keybind Atlas. The maintained files here are self-contained and have no dependency on the original scratch directory.
