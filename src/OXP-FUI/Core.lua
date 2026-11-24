-- OXP-FUI · Core: namespace, saved settings, slash commands.
--
-- OXP-FUI restyles OpenXP's windows to the FlareUI Quest Tracker look at
-- runtime. It never modifies OpenXP files, and never touches the world Map,
-- the Minimap, OpenXP's settings windows, the hidden legacy RestedXP window
-- or any Blizzard frame.
--
-- Layout policy (OXP-FUI's own design rule; OpenXP imposes nothing here):
-- skins change appearance (colours, fonts, borders, art) and leave layout to
-- OpenXP, so OpenXP updates keep working, the two addons never fight over a
-- frame's size or place, and switching OXP-FUI off restores OpenXP exactly.
-- Accidental layout calls are blocked by the engine's guard (Engine.lua) and
-- counted in /oxpfui debug. A layout change is allowed only as a listed
-- exception: deliberate (done on the real frame), small, idempotent,
-- re-applied after every OpenXP refresh, and documented here and in the
-- README. The exceptions:
--
--   1. Card dock (Docking.lua): with its switch on and a live FlareUI Quest
--      Tracker, the guide card is anchored to the tracker, optionally at its
--      width.
--   2. Card progress bars (Card.lua): the step progress fill and the XP
--      strip are inset from the border art; the step progress line drops a
--      few px below the title strip when one is drawn.
--   3. "Up next" lines (Card.lua): narrowed by exactly the width the
--      FlareUI label font adds, restoring OpenXP's right edge; the first
--      line is centred on the label instead of top-aligned to it.
--   4. Step list rows (Card.lua): each row's text ends at its status pill or
--      the row's padding (OpenXP leaves pill-less rows without a right edge,
--      so their text ran out of the window); the pill sits 14px in from the
--      row's right edge, clear of the border and scroll bar, and is as wide
--      as its label in the FlareUI font (+ OpenXP's 12px).
--   5. Step list header (Card.lua): the card's title strip; the title and
--      OpenXP's close button sit on it (the button moved onto the strip's
--      right end, 24x24); the rows start 8px lower, under the strip, and the
--      list grows by the same 8px so the bottom keeps OpenXP's own spacing.
--   6. Quest Targets pin (TargetsDock.lua): with its setting on, OpenXP's
--      Quest Targets window is anchored below or beside the guide card, and
--      under the step list while that is open.
--   7. Card header (Card.lua): the zone text starts where OpenXP's accent dot
--      was (the dot is hidden) and is cut with "..." before "Step n / n".
--   8. Card height (CardLayout.lua): the card is never taller than the room
--      between the docked tracker (or its own top) and the screen bottom,
--      one dock gap from each; a dragged height is its maximum. Steps that
--      don't fit scroll inside the card (OpenXP's body in an OXP-FUI scroll
--      frame; Up Next held above the toolbar).
--   9. Step blocks (CardLayout.lua): the /oxpfui mock on the real card: a
--      14px kind icon replaces the 34px badge and "#n"; title, objectives
--      and tips reflow into the freed width; "Along the Way" becomes a
--      section heading; blocks re-stack with their new heights.
--  10. Quest Targets window (SkinTargets.lua): the card's title strip as
--      its header, OpenXP's labels and rows moved 10px down under it (the
--      window 10px taller), and a box button that folds it to its header.
-- OpenXP 2.x (OpenXP2.lua):
--  11. Card header: OpenXP's two rows become one on the title strip,
--      "Darkshore (16–19)" left, "Step n / n" right; the header is the
--      strip's height, so the steps start under it.
--  12. Step list header: the title strip, the guide as the title, the red
--      close button on its right end, OpenXP's back button hidden.
--  13. Quest Targets (OpenXPTargets): rows 14px lower, under the title
--      strip, and the box 14px taller; out of combat only.

local ADDON_NAME, OXPFUI = ...

OXPFUI.name = ADDON_NAME
OXPFUI.version = (GetAddOnMetadata and GetAddOnMetadata(ADDON_NAME, "Version")) or "dev"
-- The OpenXP version this release was tested against (also in the TOC).
OXPFUI.testedOpenXP = "1.3.48"
OXPFUI.testedOpenXP2 = "2.0.3"

-- Exported for skin modules (which are files of this same addon) and tests.
_G.OXPFUI = OXPFUI

-- Per-window switches. Keys are stable identifiers used by skin modules and
-- the settings panel; labels live in Locale.lua.
OXPFUI.WINDOWS = {
  "arrow",      -- waypoint arrow
  "card",       -- guide card + step list
  "targets",    -- Quest Targets list
  "welcome",    -- welcome / what's-new window
  "feedback",   -- feedback window
  "tracker",    -- leveling tracker + level splits
  "talents",    -- talents
  "upgrades",   -- item upgrades
  "inventory",  -- inventory manager
  "activeitems",-- active-item frame
  "tooltips",   -- lines OpenXP adds to mob/NPC tooltips
}

-- Merge saved settings over the defaults in place, so OXPFUIDB always has
-- every key even after new options are introduced. Keys, defaults and
-- reload rules are declared once, in Settings.lua (loaded before any event
-- can call this).
function OXPFUI.InitDB()
  if type(_G.OXPFUIDB) ~= "table" then _G.OXPFUIDB = {} end
  local db = _G.OXPFUIDB
  if type(db.windows) ~= "table" then db.windows = {} end
  -- 0.6 -> 0.7: "Section separators" + border became one Frame Style.
  if db.separators ~= nil then
    if db.frameStyle == nil then
      if db.separators == false then
        db.frameStyle = "custom"
      elseif db.borderStyle == "None" then
        db.frameStyle = "blizzard"
      else
        db.frameStyle = "flareui"
      end
    end
    db.separators = nil
  end
  OXPFUI.Settings.FillMissing(db)
  -- savedDb is the SavedVariables table; OXPFUI.db is what the skins read.
  -- They are the same table except while the settings window previews
  -- unsaved changes (Settings.Preview), so a preview never reaches disk.
  OXPFUI.savedDb = db
  OXPFUI.db = db
  return db
end

-- /oxpfui — open the settings panel (default).
-- /oxpfui debug — print what was skinned, what was skipped and why.
-- /oxpfui mock — toggle the step-readability design mock-up (Mock.lua).
SLASH_OXPFUI1 = "/oxpfui"
SlashCmdList.OXPFUI = function(msg)
  local cmd = msg and msg:lower():match("^%s*(%S*)") or ""
  if cmd == "mock" then
    if OXPFUI.ToggleMock then OXPFUI.ToggleMock() end
  elseif cmd == "debug" then
    print(OXPFUI.DebugReport and OXPFUI.DebugReport() or (ADDON_NAME .. " " .. OXPFUI.version))
  else
    if OXPFUI.OpenPanel then OXPFUI.OpenPanel() end
  end
end
