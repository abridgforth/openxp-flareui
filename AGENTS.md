## Agent skills

### Issue tracker

Issues are tracked in GitHub Issues (`micfre/openxp-flareui`) via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-label vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.

### Settings and reloads

Every saved setting is declared in `src/OXP-FUI/Settings.lua` with an explicit `reload` rule (`true`, `false`, or `function(old, new)`). Never call `ReloadUI()` directly: saving goes through `Settings.Commit`, which reloads only when a changed setting's rule requires it. See "Adding a setting" in `README.md`.

### Windows

Every window OXP-FUI draws or skins goes through `theme.ApplyWindow` (Theme.lua), which applies FlareUI's frame-style model (Blizzard / FlareUI / Custom) as one unit. See "Adding a window" in `README.md`.

### Versioning

`## Version` in `src/OXP-FUI/OXP-FUI.toc` follows semantic versioning, MAJOR.MINOR.PATCH:

- **PATCH** (0.8.0 → 0.8.1): bug fixes only. Nothing new to see or set; behaviour returns to what was intended.
- **MINOR** (0.7.x → 0.8.0): anything new or changed that a player can see or set: a new setting, a new or changed layout exception, a visual change, a settings migration. Reset PATCH to 0.
- **MAJOR**: stays 0 until the addon is verified in game and its settings are stable. Before 1.0, a MINOR bump may also break things (e.g. migrate or drop a setting); say so in the commit message. From 1.0 on, a breaking change (a setting removed or reinterpreted, saved variables that need migrating) bumps MAJOR.

When a change mixes fixes and features, the highest level wins. Bump the version in the same commit as the change, rebuild (`python tools/build.py --zip`, after clearing `dist/`), and name the version and what kind of bump it is in the first line of the commit message.
