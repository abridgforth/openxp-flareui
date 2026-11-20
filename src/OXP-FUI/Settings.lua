-- OXP-FUI · Settings: the one registry of every saved setting.
--
-- Every key in OXPFUIDB is declared here exactly once, with its default and
-- whether changing it needs a UI reload to show. The rest of the addon
-- reads the registry instead of hard-coding keys:
--
--   * Core.InitDB fills missing keys from Settings.Defaults();
--   * the /oxpfui panel edits a draft (Settings.NewDraft). Every change
--     that needs no reload is shown at once (Settings.Preview) on a copy
--     of the saved settings; Cancel drops the copy (Settings.EndPreview).
--   * Save calls Settings.Commit, which writes the saved settings,
--     re-applies them and reloads the UI if — and only if — a changed
--     setting requires it.
--
-- Adding a setting (engineers): add one Define{} entry below. `reload` is
-- REQUIRED and must be either
--   true / false            — the change always / never needs a reload, or
--   function(old, new)      — return true when this particular change does
--                             (e.g. a skin that can be switched on live but
--                             only removed by a reload).
-- Define{} raises at load time if `reload` is missing, so a new setting can
-- never silently skip the decision. tests/test_settings.py also checks that
-- every key the db holds is declared here.

local ADDON_NAME, OXPFUI = ...

local Settings = {}
OXPFUI.Settings = Settings

local defs, byKey = {}, {}
Settings.defs = defs

-- -------------------------------------------------------------------------
-- Dotted key paths ("windows.arrow") into nested tables.
-- -------------------------------------------------------------------------

local function split(key)
  local parts = {}
  for part in key:gmatch("[^%.]+") do parts[#parts + 1] = part end
  return parts
end

function Settings.Read(tbl, key)
  local node = tbl
  for _, part in ipairs(split(key)) do
    if type(node) ~= "table" then return nil end
    node = node[part]
  end
  return node
end

function Settings.Write(tbl, key, value)
  local parts = split(key)
  local node = tbl
  for i = 1, #parts - 1 do
    if type(node[parts[i]]) ~= "table" then node[parts[i]] = {} end
    node = node[parts[i]]
  end
  node[parts[#parts]] = value
end

-- -------------------------------------------------------------------------
-- Declaration
-- -------------------------------------------------------------------------

local VALID_KINDS = { toggle = true, choice = true, range = true }

-- def fields:
--   key      dotted db path (required)
--   kind     "toggle" | "choice" | "range" (required)
--   default  value written for a fresh or missing key (required)
--   reload   true | false | function(old, new) -> bool (required)
--   choices  list of allowed values (choice)
--   min, max, step  bounds (range)
function Settings.Define(def)
  assert(type(def.key) == "string", "OXP-FUI setting needs a key")
  assert(VALID_KINDS[def.kind], "OXP-FUI setting " .. def.key .. ": unknown kind " .. tostring(def.kind))
  assert(def.default ~= nil, "OXP-FUI setting " .. def.key .. " needs a default")
  local r = def.reload
  assert(r == true or r == false or type(r) == "function",
    "OXP-FUI setting " .. def.key .. " must declare reload = true | false | function(old, new)")
  assert(not byKey[def.key], "OXP-FUI setting declared twice: " .. def.key)
  defs[#defs + 1] = def
  byKey[def.key] = def
  return def
end

function Settings.Get(key) return byKey[key] end

-- Does changing `def` from old to new need a reload?
function Settings.NeedsReload(def, old, new)
  if old == new then return false end
  local r = def.reload
  if type(r) == "function" then return r(old, new) == true end
  return r == true
end

-- -------------------------------------------------------------------------
-- The settings
-- -------------------------------------------------------------------------

-- Master switch: the engine installs its OpenXP hooks only at login when
-- the skin is on, and never un-skins frames it already styled, so both
-- directions need a reload.
Settings.Define { key = "enabled", kind = "toggle", default = true, reload = true }

-- Follow the FlareUI Quest Tracker's own style (FlareStyle.lua). Applied on
-- the next re-apply pass, both ways.
Settings.Define { key = "followFlareUI", kind = "toggle", default = true, reload = false }

-- Appearance: every skin re-reads these on each re-apply pass.
Settings.Define { key = "font", kind = "choice", default = "Friz Quadrata", reload = false }
Settings.Define { key = "opacity", kind = "range", default = 0.6, min = 0, max = 1, step = 0.05, reload = false }
Settings.Define { key = "borderStyle", kind = "choice", default = "Frames",
                  choices = { "Frames", "Thick", "Thin", "None" }, reload = false }
-- Blizzard's tracker strips between sections (when not following FlareUI,
-- whose frame style decides instead).
Settings.Define { key = "separators", kind = "toggle", default = true, reload = false }

-- Per-window switches. Switching a skin ON applies it on the next pass;
-- switching it OFF stops future passes but cannot restore OpenXP's own look
-- on frames that were already styled — that takes a reload. The tooltip
-- skin re-checks its switch on every tooltip, so it is live both ways.
local LIVE_BOTH_WAYS = { tooltips = true }
local function offNeedsReload(_, new) return new == false end
for _, w in ipairs(OXPFUI.WINDOWS) do
  local reload = offNeedsReload
  if LIVE_BOTH_WAYS[w] then reload = false end
  Settings.Define { key = "windows." .. w, kind = "toggle", default = true, reload = reload }
end

-- FlareUI Quest Tracker dock (Docking.lua): re-anchors live, both ways.
Settings.Define { key = "attachTracker", kind = "toggle", default = true, reload = false }
Settings.Define { key = "attachSide", kind = "choice", default = "bottom",
                  choices = { "bottom", "top" }, reload = false }
Settings.Define { key = "attachPadding", kind = "range", default = 8, min = 0, max = 40, step = 1, reload = false }
Settings.Define { key = "matchTrackerWidth", kind = "toggle", default = false, reload = false }

-- -------------------------------------------------------------------------
-- Defaults, drafts, commit
-- -------------------------------------------------------------------------

function Settings.Defaults()
  local t = {}
  for _, def in ipairs(defs) do Settings.Write(t, def.key, def.default) end
  return t
end

-- Fill every declared key the db lacks (new options after an update).
function Settings.FillMissing(db)
  for _, def in ipairs(defs) do
    if Settings.Read(db, def.key) == nil then Settings.Write(db, def.key, def.default) end
  end
  return db
end

-- A flat key -> value copy of the saved settings for the panel to edit.
function Settings.NewDraft(db)
  db = db or Settings.Saved()
  local draft = {}
  for _, def in ipairs(defs) do
    local v = Settings.Read(db, def.key)
    if v == nil then v = def.default end
    draft[def.key] = v
  end
  return draft
end

-- Draft values for every declared key reset to defaults.
function Settings.DefaultDraft()
  local draft = {}
  for _, def in ipairs(defs) do draft[def.key] = def.default end
  return draft
end

-- What a draft would change: list of { def, old, new, reload }.
function Settings.Changes(draft, db)
  db = db or Settings.Saved()
  local out = {}
  for _, def in ipairs(defs) do
    local new = draft[def.key]
    local old = Settings.Read(db, def.key)
    if old == nil then old = def.default end
    if new ~= nil and new ~= old then
      out[#out + 1] = { def = def, old = old, new = new,
                        reload = Settings.NeedsReload(def, old, new) }
    end
  end
  return out
end

function Settings.ChangesNeedReload(changes)
  for _, c in ipairs(changes) do
    if c.reload then return true end
  end
  return false
end

-- The one place that reloads the UI. Kept as a seam so tests (and any
-- future confirmation step) see every reload the addon asks for.
function Settings.Reload()
  if ReloadUI then ReloadUI() end
end

-- Re-run the skins and the dock with whatever OXPFUI.db now holds.
function Settings.ApplyLive(reason)
  if OXPFUI.Reapply then OXPFUI.Reapply(reason) end
  -- Reapply already updates the dock when the engine is ready; this covers
  -- the dock before login or with OpenXP missing.
  if OXPFUI.Dock and OXPFUI.Dock.Update then OXPFUI.Dock.Update(reason) end
end

-- -------------------------------------------------------------------------
-- Live preview: unsaved changes that need no reload, shown at once.
-- -------------------------------------------------------------------------

local function deepCopy(v)
  if type(v) ~= "table" then return v end
  local out = {}
  for k, x in pairs(v) do out[k] = deepCopy(x) end
  return out
end

-- The SavedVariables table (OXPFUI.db is a preview copy while previewing).
function Settings.Saved()
  return OXPFUI.savedDb or OXPFUI.db or {}
end

function Settings.IsPreviewing()
  return OXPFUI.savedDb ~= nil and OXPFUI.db ~= OXPFUI.savedDb
end

-- Show every draft change that needs no reload, without saving anything:
-- the skins read a copy of the saved settings with those changes applied.
-- Changes that need a reload wait for Save.
function Settings.Preview(draft)
  local saved = Settings.Saved()
  local view = deepCopy(saved)
  for _, def in ipairs(defs) do
    local new = draft[def.key]
    local old = Settings.Read(saved, def.key)
    if old == nil then old = def.default end
    if new ~= nil and new ~= old and not Settings.NeedsReload(def, old, new) then
      Settings.Write(view, def.key, new)
    end
  end
  OXPFUI.db = view
  Settings.ApplyLive("settings preview")
end

-- Drop the preview and show the saved settings again (Cancel / close).
function Settings.EndPreview()
  if not Settings.IsPreviewing() then return false end
  OXPFUI.db = OXPFUI.savedDb
  Settings.ApplyLive("settings preview cancelled")
  return true
end

-- Write the draft into the saved settings; re-apply them; reload the UI if
-- and only if a changed setting requires it. Returns changes, reloaded.
function Settings.Commit(draft, db)
  db = db or Settings.Saved()
  local wasPreviewing = Settings.IsPreviewing()
  if OXPFUI.savedDb then OXPFUI.db = OXPFUI.savedDb end
  local changes = Settings.Changes(draft, db)
  for _, c in ipairs(changes) do Settings.Write(db, c.def.key, c.new) end

  if Settings.ChangesNeedReload(changes) then
    Settings.Reload()
    return changes, true
  end
  if #changes > 0 or wasPreviewing then Settings.ApplyLive("settings saved") end
  return changes, false
end
