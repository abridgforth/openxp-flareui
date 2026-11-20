# OXP-FUI

A companion addon for **OpenXP** on the Forever client that restyles
OpenXP's windows to match **FlareUI's Quest Tracker** look — bronze borders,
warm dark fill, gold/amber/green text colours and FlareUI typography.

OpenXP itself is never modified (it keeps receiving upstream updates), the
skins never move or resize any frame, nothing on the world Map or Minimap
is touched, and FlareUI does not need to be installed. The one deliberate
exception is the optional [tracker dock](#tracker-dock), which re-anchors
only the guide card while its switch is on.

## Install

Build the ready-to-copy addon folder, then copy it into your `Interface\AddOns`
(or `_classic_`_) folder yourself — there is no install-to-game step:

    python3 tools/build.py            # writes dist/OXP-FUI/
    python3 tools/build.py --zip      # also writes dist/OXP-FUI-<version>.zip

In game, `/oxpfui` opens the settings window. It is also listed under
**Options → AddOns → OXP-FUI**. `/oxpfui debug` prints a report:
the OpenXP version you run versus the tested one (see the
`## X-Tested-OpenXP` TOC field), the master switch and per-window switches,
whether the FlareUI style is being followed and what was read from it,
how many apply passes ran, and the latest pass's outcome — which skins were
skinned (`Skinned:`), what was skipped and why (`Skipped:`), errors
(`Errors:`, plus `Earlier errors (previous passes):` as labelled history)
and blocked layout attempts.

## Settings window

The window is built from the game's own UI templates, so it looks and
works like Blizzard's settings: check boxes, dropdowns, sliders with `<` `>`
steppers, hover tooltips, and **Defaults / Cancel / Save** buttons.

- **General:** Enable OXP-FUI skin, and *Follow FlareUI tracker style*.
- **Windows:** one check box per OpenXP window.
- **Appearance:** Font, Border style (Frames, Thick, Thin or None), Panel
  opacity. These lock while the FlareUI style is being followed.
- **FlareUI Quest Tracker:** the [tracker dock](#tracker-dock) settings.

**Live changes.** Every change that does not need a reload shows at once
while you adjust it (font, border, opacity, the FlareUI style switch,
turning a window on, the tracker dock). It is only a preview until you
press **Save**: **Cancel**, the close button and Escape put back the saved
look, and an unsaved preview is never written to your saved settings.
**Defaults** resets the window's values (and previews them); press Save
to keep them.

**Automatic reload.** Save reloads the UI by itself only when a change you
made needs a reload to show. Before you save, the button reads
**Save & Reload** and a note lists the settings that need it. A setting's
tooltip also says when it needs a reload. Currently:

| Setting | Needs a reload |
|---|---|
| Enable OXP-FUI skin | always |
| A window switch (except Tooltip lines) | only when turned **off** |
| Everything else | never — applied at once |

## Follow FlareUI tracker style

On by default. With FlareUI installed, OpenXP's windows take the look of
your FlareUI Quest Tracker, read from its saved settings (`FlareUI2_DB`, for
the profile your character uses) with the same rules FlareUI applies:

| FlareUI Frame Style | Background | Border | Separators | Colours |
|---|---|---|---|---|
| Blizzard | none | none | header and section strips | Blizzard's (gold headings and titles) |
| FlareUI | your opacity | FlareUI Thick | strips, plus the bottom strip | FlareUI's bronze scheme |
| Custom | your opacity | your border (or None) | none | FlareUI's scheme, or Blizzard's if chosen |

Text sizes follow the tracker's header, title and objective fonts, and the
font face is read from the tracker on screen. Settings FlareUI never saved
use FlareUI's own defaults. Bronze chrome (dots, the arrow, button washes)
stays bronze in every scheme. FlareUI's saved settings are only read, never
written. The style is re-read on every apply pass (an OpenXP refresh, a
save, or `/reload`).

## Section separators

Like FlareUI's tracker, the guide card draws Blizzard's own quest tracker
strips as separators: the title strip behind the card header and a heading
strip behind the "Up next" and history sections (OpenXP's own thin
separator steps aside meanwhile), plus the bottom strip on bordered
FlareUI-style frames. The step list's title gets the title strip too. When
following FlareUI, its frame style decides; otherwise the **Section
separators** check box does.

## Timer bars

With FlareUI installed, OpenXP's conditional progress bars (the flight
timer and other step timers, shown under the card) are filled with the
texture of FlareUI's unit frame bars ("FlareUI Forever"), keeping the bar's
own colour. FlareUI hardcodes that texture today; if its maintainer adds a
configurable unit frame texture, the bars should follow it. Without
FlareUI the bars keep OpenXP's texture.

## Tracker dock

When FlareUI is installed and its Quest Tracker is on, the settings panel
(`/oxpfui`, "FlareUI Quest Tracker" section) can dock the OpenXP guide
card to it:

- **Attach guide card to tracker** (on by default): the card sits at the
  tracker's bottom edge (default) or top edge, with a configurable padding
  between them (default 8 px), and follows every tracker move or resize by
  anchoring. Minimizing the tracker keeps the card open, docked under the
  header; a hidden tracker (minimized to a lone "+" button, or hidden
  while nothing is tracked) makes the card move into the tracker's spot.
  With FlareUI missing or its Quest Tracker module turned off, the card is
  not moved at all.
- **Match tracker width** (off by default): the card becomes exactly as
  wide as the tracker and follows the tracker's own width setting, so the
  two stack seamlessly.

While docked the card cannot be dragged (the dock owns its place — move
the tracker instead); its resize grip keeps working, and OpenXP's own
saved card position survives, so switching attach off puts the card back
where you left it. Dock changes never need a reload.

## Repository layout

    src/OXP-FUI/        addon source (Lua + bundled FlareUI media and licenses)
    tools/build.py      build script (stages into build/, publishes into dist/)
    tests/              lupa test harness (Seam 1) and build tests (Seam 2)
    build/              ephemeral: staging output and the Python venv (ignored)
    dist/               build output: the ready-to-copy addon folder (ignored)
    prior_art/          local reference copies of OpenXP and FlareUI (ignored,
                        research only — never distributed, never needed to
                        build or test)

## Tests

    python3 tests/run_tests.py

First run creates a venv with `lupa` under `build/venv`. Skin behaviour is
verified against a stubbed WoW API and a fake OpenXP (no game needed); the
build tests verify the produced addon folder. A report is written to
`tests/output/report.txt`.

## Adding a setting

Every saved setting is declared once in `src/OXP-FUI/Settings.lua` with
`Settings.Define { key, kind, default, reload }`. `reload` is required:

- `true` — any change needs a reload (e.g. the change only takes effect at
  login);
- `false` — the setting is re-read on every apply pass;
- `function(old, new) ... end` — return `true` for the changes that need a
  reload (e.g. a skin that can be added live but only removed by a reload).

Missing `reload` is an error at load time, and `tests/test_settings.py`
fails if the saved settings hold a key that is not declared. The window's
window previews every change whose rule says no reload is needed
(`Settings.Preview`, on a copy of the saved settings, so add-on code must
read `OXPFUI.db`, never `OXPFUIDB`). Save (`Settings.Commit`) writes the
draft, re-applies, and calls `Settings.Reload()` if — and only if — a
changed setting's rule says so. Never call `ReloadUI()` directly; go through `Settings.Commit` or
`Settings.Reload`. Add the control in `SettingsPanel.lua` with the
`makeCheckbox` / `makeDropdown` / `makeSlider` helpers, which bind it to the
draft and add its tooltip, including the reload note.

## Known limitations

- OpenXP 1.3.48 exposes no visible inventory-manager window (only an
  invisible keybind button, an input-propagation helper and a hidden
  full-screen click passthrough), so the inventory-manager skin dresses the
  hidden delete-junk helper frame.
- The settings window needs the game's modern UI templates (the Forever
  client has them); it has been checked against the `forever` branch of
  Blizzard's UI source, not in game.
- The dock padding is measured in UI units at the card's own scale; with a
  non-default card scale the on-screen gap scales with it.

## Credits and licenses

- OXP-FUI code: MIT (see `LICENSE`).
- The bundled border art and fonts come from **FlareUI by Malkkav** (MIT) and
  their font licenses; see `src/OXP-FUI/LICENSE` and `src/OXP-FUI/Licenses-ThirdParty/`.
  The FlareUI look is re-implemented in new code. The tracker colour
  schemes, frame-style rules and strip measurements follow FlareUI's
  `ObjectiveTracker.lua` (MIT, credited in `Licenses-ThirdParty/FlareUI-LICENSE.txt`).
- OpenXP (CC BY-NC-SA 4.0) is a runtime dependency, unmodified and
  unredistributed; no OpenXP code is included here.
