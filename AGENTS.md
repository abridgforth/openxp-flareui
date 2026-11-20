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
