# OXP-FUI

A companion addon for **OpenXP** on the Forever client that restyles
OpenXP's windows to match **FlareUI's Quest Tracker** look — bronze borders,
warm dark fill, gold/amber/green text colours and FlareUI typography.

OpenXP itself is never modified (it keeps receiving upstream updates),
nothing on the world Map or Minimap is touched, and FlareUI does not need
to be installed.

## Layout policy

This is OXP-FUI's own design rule (OpenXP imposes nothing): the skins change
how OpenXP looks (colours, fonts, borders, art) and leave its layout to
OpenXP. That keeps OXP-FUI working across OpenXP updates, stops the two
addons fighting over a window's size or place, and means switching OXP-FUI
off gives you OpenXP's layout back exactly. The engine blocks accidental
layout changes and counts them in `/oxpfui debug` ("Blocked layout
attempts").

A layout change is allowed only as a listed exception. Each one is small,
deliberate, re-applied after every OpenXP refresh, and listed here and in
`src/OXP-FUI/Core.lua`:

1. **Tracker dock**: the guide card anchors to FlareUI's Quest Tracker
   ([details](#tracker-dock)).
2. **Card progress bars**: the step progress fill and XP strip are inset
   from the border art; the step progress line drops 3 px below the title
   separator when one is drawn.
3. **"Up next" lines**: narrowed by exactly the extra width of the FlareUI
   label font, so they end where OpenXP meant them to; the first line is
   centred on the "Up Next" label (OpenXP top-aligns them).
4. **Step list rows**: each row's text ends at its status label or the row's
   padding and is cut off with "…". (OpenXP leaves rows without a status
   label unbounded, so long steps ran out of the window.) Status labels sit
   14 px in from the edge, clear of the border and scroll bar, and their
   plates fit the FlareUI font.
5. **Step list header**: the card's title strip, with the title ("Darkshore
   (16–19)", as on the card) and OpenXP's close button on it; the rows start
   8 px lower so the first row clears the strip, and the list grows by the
   same 8 px so the bottom keeps OpenXP's spacing.
6. **Quest Targets pin**: with **Pin to the guide** on, OpenXP's Quest
   Targets window is anchored to the guide card (see below).
7. **Card header**: the zone text starts where OpenXP's accent dot was (the
   dot is hidden) and is cut off with "…" before "Step n / n".
8. **Card height**: the card never grows past the room it has, keeping the
   dock gap both under the FlareUI tracker and above the screen's bottom
   (undocked: between its own top and the screen's bottom). OpenXP sizes
   the card to its content and the game then pushes a too-tall card up over
   the tracker; OXP-FUI sizes it back down on every refresh and whenever the
   tracker grows or shrinks. A height you drag the card to is its maximum,
   like FlareUI's tracker height: the card is as tall as its steps up to
   that height, so there is no empty space above the toolbar. Steps that don't fit scroll inside
   the card: the mouse wheel scrolls the steps first; at the top, scrolling
   up opens OpenXP's earlier-steps history as before, and with the history
   open, scrolling down closes it first.
9. **Step blocks**: the `/oxpfui mock` layout on the card. A small kind icon
   in front of the title replaces OpenXP's 34px badge and step number;
   title, objectives and tips use the width that frees up, tips in the
   smaller size; an "Along the Way" step gets a section heading with its
   step number; the line between steps is a faint bronze hairline.
10. **Quest Targets window**: the same header as the card (the tracker's
    title strip), with OpenXP's sections moved 10 px down under it and the
    window 10 px taller; a box button on the header folds the window to
    its header and back (saved, no reload). Like OpenXP's own rebuilds,
    this happens only out of combat; a fold clicked in combat shows when
    combat ends.

OpenXP 2.x (see "OpenXP 2.x" below):

11. **Card header**: one row on the title strip, "Darkshore (16–19)" on
    the left and "Step n / n" on the right (OpenXP: two rows); the header
    is the strip's height, so OpenXP lays the steps out under it.
12. **Step list header**: the title strip with the guide as its title and
    Blizzard's red close button on its right end; OpenXP's back button
    (the same as close) is hidden.
13. **Quest Targets and the quest item**: with **Icons only** (default) a
    row of 30 px FlareUI squares like RestedXP's target frame, the quest
    item first, then one per target; the names are in the tooltips and the
    key bound to the first target shows on its icon. Without it, the list
    with its rows 14 px lower under the title strip. **Pin to the guide**
    puts the item and the targets below the card or top-aligned beside it
    (on the side away from the screen edge), under the step list while that
    is open; dragging them is paused while pinned. Out of combat only, like
    OpenXP's own refresh.
14. **Card width**: "Match the tracker's width" resizes the card through
    OpenXP's own resize grip, so OpenXP keeps the width as yours (it puts
    its saved size back after any other change). Not while OpenXP's frames
    are locked.

## OpenXP 2.x

OpenXP 2.0 is a rewrite whose addon table is private, so OXP-FUI reaches it
only through its named frames (`OpenXPCard`, `OpenXPSteps`,
`OpenXPTargets`, `OpenXPMenu`, `OpenXPDropdownList`, `OpenXPConfirm`) and
re-applies after OpenXP's own passes by post-hooking frame methods OpenXP
calls (see `OpenXP2.lua`). OXP-FUI finds out which OpenXP it runs with at
load and uses only the skins for that one.

With 2.x, OXP-FUI gives the card, the step list, Quest Targets and OpenXP's
pop-ups the FlareUI frame, header strip, colours and toolbar, and docks the
card under FlareUI's tracker, at the tracker's width, with Quest Targets
and the quest item pinned to it as icons. Not available on 2.x until
OpenXP offers a public API: the mock step layout and fitting the card's
height under the tracker. OpenXP 2.x
keeps the card's size and scroll state private and puts its own size back
whenever another addon changes it. Text sizes and the font on the card body
come from OpenXP's own font settings, so OpenXP lays its steps out to them.

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
- **Appearance:** Frame style (Blizzard, FlareUI or Custom), Font, Border
  style (Custom only), Panel opacity (FlareUI and Custom). These lock while
  the FlareUI style is being followed.
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

## Frame style

Every window uses one frame-style model, FlareUI's own (its
`ObjectiveTracker.lua`: `Build.FrameStyle`, `GetBorderFile`,
`ApplyBackdrop`, `HeaderArtOn`):

| Frame style | Background | Border | Header strips and separators |
|---|---|---|---|
| Blizzard | none | none | yes |
| FlareUI | your opacity | FlareUI Thick | yes, knobs seated on the border, plus the bottom strip |
| Custom (default, as in FlareUI) | your opacity | your border | none |

When following FlareUI, its tracker's frame style is used; otherwise the
**Frame style** setting. A strip therefore only ever appears with no border
or with the Thick border it is shaped for, never on the rounded Frames or
Thin borders. The header strip uses FlareUI's exact header band (8 px in
from each side, 3 px down, 27 px tall), where its knobs fit the Thick
border's curve.

The separators are Blizzard's own quest tracker art: the title strip behind
the card header, and the tracker's rod with its end knobs between card
sections, on the line where OpenXP draws its own faint separator above
"Up next" and under the history band (OpenXP's line steps aside
meanwhile). The step progress line is repainted in the title colour (gold
in the Blizzard scheme).

Dividers inside a window (above Up Next, above the toolbar, under the
history) follow FlareUI's zone heading strips: centred, 14 px in from each
side, with their end knobs reaching out toward the border. Only the header
strip and the bottom strip sit on the border itself.

Separators are drawn on the window itself, above its background, so an
opaque background never covers them. On a framed window they follow
FlareUI's framed style: the header strip's end knobs sit on the top border,
and the window gets the bottom strip on its bottom border (except the guide
card, whose bottom edge carries OpenXP's XP bar). Pop-up windows with no
border of their own (a borderless tracker style) use FlareUI's Thick frame.

The step list uses the same window model as the card and Quest Targets:
the tracker's title strip as its header, the title in the card's form
("Darkshore (16–19)"), and Blizzard's red close button (24×24) on the
strip's right end, where Quest Targets has its fold button. FlareUI has no
close glyph of its own (its windows use Blizzard's close button). As a
pop-up it always has a background (at least 85%)
and a frame, even when following a borderless tracker style: it opens over
other windows, and its whole area takes clicks. It keeps the FlareUI font
while scrolling.

Headings use title case like the tracker's ("Up Next", "Along the Way").
The card header reads **Darkshore (16–19)**: zone and level range, taken
from the selected guide's name on every refresh (the way OpenXP itself
splits it), so it always matches the guide; the range is dimmed, and there
is no accent dot. During a quest-chain detour it reads "Quest Chain".

Quest Targets uses the tracker's container look: its header sits on a
shaded band between two rods ("Quest Targets"), and its "Kill" / "Talk to"
headings on a shade that fades out to the right, like the tracker's zone
headings.

`/oxpfui mock` opens a design mock-up of a more readable card body (small
step-type icons instead of the large badge, indented objectives with counts,
tips as secondary text, faint dividers between steps, faded section
headings). It is a separate window with sample steps; it does not change
the real card.

The card's toolbar takes the look of FlareUI's tracker header buttons: each
button is a dark square with a bronze rim (lit while pointed at) behind a
gold icon; buttons with a text label get a box across their width. OpenXP's
white wash behind the toolbar goes, and its top line becomes the section
rule. The XP strip along the bottom is gold, with rested XP in bronze.

## Timer bars

With FlareUI installed, OpenXP's conditional progress bars (the flight
timer and other step timers, shown under the card) are filled with the
texture of FlareUI's unit frame bars ("FlareUI Forever"), keeping the bar's
own colour. FlareUI hardcodes that texture today; if its maintainer adds a
configurable unit frame texture, the bars should follow it. Without
FlareUI the bars keep OpenXP's texture.

## Quest Targets pin

**Settings → Quest Targets → Pin to the guide** keeps OpenXP's Quest Targets
window with the guide card:

- **Off** (default): the window stays where you put it; the step list opens
  over it.
- **Below the guide**: under the card, left edges aligned.
- **Beside the guide**: next to the card, on the side the step list opens
  on (away from the screen edge).

While the step list is open, a pinned window moves under it, and goes back
when the list closes. If there is no room under the list, it stays put.
While pinned it can't be dragged, and OpenXP does not save its position
(OpenXP's own `savePosition = false`), so switching the pin off puts it
back exactly where you had it. The window contains secure target buttons,
which the game does not let addons move during combat: a move then waits
until combat ends.

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

## Adding a window

Every window OXP-FUI draws or skins goes through one component,
`theme.ApplyWindow(frame, opts)` in `Theme.lua`: it applies the frame style
as one unit (background, border, header art, bottom strip), so all windows
behave the same and a combination FlareUI never draws cannot happen. Pass
`role = "popup"` for a pop-up (always a background and a frame), a `header`
region and its `headerStyle` (`"strip"`, `"band"` or `"titlebar"`), and
`foot = false` if the window's bottom edge is taken. Section headings use
`theme.ApplySectionHeading`, dividers `theme.ApplySectionRule`. Don't call
the backdrop or strip helpers directly from a skin.

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
