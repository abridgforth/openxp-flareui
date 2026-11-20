-- OXP-FUI · Core: namespace, saved settings, slash commands.
--
-- OXP-FUI restyles OpenXP's windows to the FlareUI Quest Tracker look at
-- runtime. It never modifies OpenXP files, never touches the world Map,
-- the Minimap, OpenXP's settings windows, the hidden legacy RestedXP window
-- or any Blizzard frame, and the skins never change OpenXP layout, positions
-- or sizes (guarded, see Engine.lua). The one sanctioned exception is the
-- optional card dock (Docking.lua): while its switch is on and a live
-- FlareUI Quest Tracker exists, it re-anchors the guide card to the tracker
-- and can match the card's width to it.

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
