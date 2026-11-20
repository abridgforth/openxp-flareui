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
--      FlareUI label font adds, restoring OpenXP's right edge.
--   4. Step list rows (Card.lua): each row's text ends at its status pill or
--      the row's padding (OpenXP leaves pill-less rows without a right edge,
--      so their text ran out of the window); the pill sits 14px in from the
--      row's right edge, clear of the border and scroll bar, and is as wide
--      as its label in the FlareUI font (+ OpenXP's 12px).
--   5. Step list top padding (Card.lua): the rows start 8px lower, clear of
--      the title strip's bottom rod, and the list grows by the same 8px so
--      the bottom keeps OpenXP's own spacing.

local ADDON_NAME, OXPFUI = ...

OXPFUI.name = ADDON_NAME
OXPFUI.version = (GetAddOnMetadata and GetAddOnMetadata(ADDON_NAME, "Version")) or "dev"
-- The OpenXP version this release was tested against (also in the TOC).
OXPFUI.testedOpenXP = "1.3.48"

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
SLASH_OXPFUI1 = "/oxpfui"
SlashCmdList.OXPFUI = function(msg)
  local cmd = msg and msg:lower():match("^%s*(%S*)") or ""
  if cmd == "debug" then
    print(OXPFUI.DebugReport and OXPFUI.DebugReport() or (ADDON_NAME .. " " .. OXPFUI.version))
  else
    if OXPFUI.OpenPanel then OXPFUI.OpenPanel() end
  end
end
