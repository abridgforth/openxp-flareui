-- OXP-FUI · FlareStyle: follow the FlareUI Quest Tracker's own look.
--
-- With the "Follow FlareUI tracker style" switch on (db.followFlareUI) and
-- FlareUI loaded, the theme takes these from FlareUI instead of the
-- OXP-FUI Font / Border / Opacity settings:
--
--   opacity  FlareUI2_DB.profiles[<profile>].objectivetracker.opacity
--   border   ...objectivetracker.borderTexture  ("None", or a border name)
--   font     the font the live tracker (FlareUI_ObjectiveTracker) draws with
--
-- Read-only: nothing here writes FlareUI's saved variables or frames.
-- Every read is defensive — a FlareUI update that renames a key just means
-- that value falls back to the OXP-FUI setting. Refresh() runs at the start
-- of every re-apply pass (Engine.lua), so a FlareUI change shows on the
-- next OpenXP refresh, settings save or /reload.

local ADDON_NAME, OXPFUI = ...

local FlareStyle = {}
OXPFUI.FlareStyle = FlareStyle

FlareStyle.current = nil -- last Refresh() result, or nil when not following

local function savedVars()
  local db = rawget(_G, "FlareUI2_DB")
  if type(db) ~= "table" then db = rawget(_G, "FlareUI_DB") end
  if type(db) == "table" then return db end
  return nil
end

-- The profile this character uses. FlareUI keys profileKeys by character
-- name (on Forever, first and last name, e.g. "Smiter Sogood"); fall back
-- to the only profile in use, then "Default".
function FlareStyle.ProfileName(db)
  local keys = type(db.profileKeys) == "table" and db.profileKeys or {}
  local name = UnitName and UnitName("player") or nil
  local realm = GetRealmName and GetRealmName() or nil
  local candidates = {}
  if name then
    candidates[#candidates + 1] = name
    if realm then candidates[#candidates + 1] = name .. " - " .. realm end
  end
  for _, c in ipairs(candidates) do
    if type(keys[c]) == "string" then return keys[c] end
  end
  local only
  for _, profile in pairs(keys) do
    if only == nil then only = profile elseif only ~= profile then only = false end
  end
  if type(only) == "string" then return only end
  return "Default"
end

function FlareStyle.TrackerSettings()
  local db = savedVars()
  if not db or type(db.profiles) ~= "table" then return nil end
  local profile = db.profiles[FlareStyle.ProfileName(db)]
  if type(profile) ~= "table" then return nil end
  local ot = profile.objectivetracker or profile.objectiveTracker
  if type(ot) ~= "table" then return nil end
  return ot
end

-- FlareUI border name -> OXP-FUI border key. FlareUI ships the same three
-- border arts OXP-FUI bundles, plus "None".
function FlareStyle.MapBorder(name)
  if type(name) ~= "string" then return nil end
  -- Whole words only ("Something" must not read as "thin").
  local n = " " .. name:lower():gsub("[^%a]", " ") .. " "
  local function has(word) return n:find("%f[%a]" .. word .. "%f[%A]") ~= nil end
  if has("none") or name:match("^%s*$") then return "None" end
  if has("thin") then return "Thin" end
  if has("thick") then return "Thick" end
  if has("frames") or has("frame") then return "Frames" end
  return nil -- unknown art: keep the OXP-FUI setting
end

-- First font the live tracker uses (its header/quest lines). Bounded walk.
function FlareStyle.TrackerFont()
  local tracker = rawget(_G, "FlareUI_ObjectiveTracker")
  if type(tracker) ~= "table" then return nil end
  local visited, budget = 0, 300
  local function fontOf(region)
    if type(region) ~= "table" or type(region.GetObjectType) ~= "function" then return nil end
    local okType, kind = pcall(region.GetObjectType, region)
    if not okType or kind ~= "FontString" or type(region.GetFont) ~= "function" then return nil end
    local ok, path, size = pcall(region.GetFont, region)
    if ok and type(path) == "string" and path ~= "" then return path, size end
    return nil
  end
  local function walk(frame, depth)
    if depth > 4 or visited >= budget or type(frame) ~= "table" then return nil end
    visited = visited + 1
    if type(frame.GetRegions) == "function" then
      local ok, regions = pcall(function() return { frame:GetRegions() } end)
      if ok then
        for _, r in ipairs(regions) do
          local path, size = fontOf(r)
          if path then return path, size end
        end
      end
    end
    if type(frame.GetChildren) == "function" then
      local ok, children = pcall(function() return { frame:GetChildren() } end)
      if ok then
        for _, c in ipairs(children) do
          local path, size = walk(c, depth + 1)
          if path then return path, size end
        end
      end
    end
    return nil
  end
  return walk(tracker, 0)
end

function FlareStyle.Available()
  return savedVars() ~= nil or rawget(_G, "FlareUI_ObjectiveTracker") ~= nil
end

function FlareStyle.Active()
  local db = OXPFUI.db
  return db ~= nil and db.followFlareUI == true and FlareStyle.Available()
end

-- Recompute what FlareUI says; nil fields mean "use the OXP-FUI setting".
function FlareStyle.Refresh()
  if not FlareStyle.Active() then
    FlareStyle.current = nil
    return nil
  end
  local style = {}
  local ot = FlareStyle.TrackerSettings()
  if ot then
    if type(ot.opacity) == "number" then
      style.opacity = math.max(0, math.min(1, ot.opacity))
    end
    style.border = FlareStyle.MapBorder(ot.borderTexture)
    style.borderName = ot.borderTexture
    style.width = type(ot.width) == "number" and ot.width or nil
  end
  local ok, path = pcall(FlareStyle.TrackerFont)
  if ok and path then style.fontPath = path end
  FlareStyle.current = style
  return style
end

-- One line for /oxpfui debug.
function FlareStyle.Describe()
  local L = OXPFUI.L
  local db = OXPFUI.db
  if not db or db.followFlareUI ~= true then return L.flareStyleOff end
  if not FlareStyle.Available() then return L.flareStyleMissing end
  local s = FlareStyle.Refresh() or {}
  return L.flareStyleOn:format(
    s.opacity and (math.floor(s.opacity * 100 + 0.5) .. "%") or L.flareStyleOwn,
    s.border or (s.borderName and (tostring(s.borderName) .. "?")) or L.flareStyleOwn,
    s.fontPath or L.flareStyleOwn)
end
