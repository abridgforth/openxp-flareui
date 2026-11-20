-- OXP-FUI · FlareStyle: follow the FlareUI Quest Tracker's own look.
--
-- With the "Follow FlareUI tracker style" switch on (db.followFlareUI) and
-- FlareUI loaded, the theme takes the tracker's look from FlareUI's saved
-- settings (FlareUI2_DB.profiles[<profile>].objectivetracker), applying the
-- same rules FlareUI's ObjectiveTracker.lua does (MIT, Malkkav):
--
--   frameStyle  "blizzard": no background, no border, header strips,
--                           Blizzard's colours
--               "flareui":  the Thick border at the chosen opacity, header
--                           strips plus the bottom strip, FlareUI colours
--               "custom":   the chosen border and opacity, no strips,
--                           FlareUI colours (unless colorScheme says so)
--   colorScheme "blizzard" | "flareui" (Blizzard style is always blizzard)
--   fonts       headerFont / titleFont / objectiveFont sizes; the face is
--               read from the live tracker (FlareUI_ObjectiveTracker)
--
-- FlareUI saves only values that differ from its defaults, so a missing key
-- means FlareUI's default (FLARE_DEFAULTS below, from its Core.lua).
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

-- FlareUI's defaults for the keys read here (Core.lua, objectivetracker).
FlareStyle.DEFAULTS = {
  frameStyle = "custom",
  opacity = 0.75,
  borderTexture = "FlareUI Frames",
  headerFont = 12, titleFont = 11, objectiveFont = 10,
}

local function fontSize(ot, key)
  local f = ot[key]
  if type(f) == "table" and type(f.size) == "number" and f.size > 0 then return f.size end
  return FlareStyle.DEFAULTS[key]
end

-- Build.FrameStyle: blizzard and custom as saved, anything else is flareui.
function FlareStyle.FrameStyle(ot)
  local s = ot.frameStyle
  if s == nil then s = FlareStyle.DEFAULTS.frameStyle end
  if s == "blizzard" or s == "custom" then return s end
  return "flareui"
end

-- Recompute what FlareUI says; nil fields mean "use the OXP-FUI setting".
function FlareStyle.Refresh()
  if not FlareStyle.Active() then
    FlareStyle.current = nil
    if OXPFUI.theme and OXPFUI.theme.SetScheme then OXPFUI.theme.SetScheme(nil) end
    return nil
  end
  local style = {}
  local ot = FlareStyle.TrackerSettings()
  if ot then
    local frame = FlareStyle.FrameStyle(ot)
    style.frameStyle = frame
    -- Background (ApplyBackdrop): none in the Blizzard style.
    if frame == "blizzard" then
      style.opacity = 0
    else
      local o = ot.opacity
      if type(o) ~= "number" then o = FlareStyle.DEFAULTS.opacity end
      style.opacity = math.max(0, math.min(1, o))
    end
    -- Border (GetBorderFile): none / Thick / the chosen one.
    if frame == "blizzard" then
      style.border, style.borderName = "None", "None"
    elseif frame == "flareui" then
      style.border, style.borderName = "Thick", "FlareUI Thick"
    else
      local name = ot.borderTexture or FlareStyle.DEFAULTS.borderTexture
      style.borderName = name
      style.border = FlareStyle.MapBorder(name)
    end
    -- Colours (OT.ColorScheme).
    if frame == "blizzard" then
      style.scheme = "blizzard"
    else
      style.scheme = ot.colorScheme == "blizzard" and "blizzard" or "flareui"
    end
    -- Header art (Build.HeaderArtOn) and the bottom strip (FlareUI style).
    style.strips = frame ~= "custom"
    style.foot = frame == "flareui"
    style.sizes = {
      header = fontSize(ot, "headerFont"),
      zone = fontSize(ot, "headerFont"),
      title = fontSize(ot, "titleFont"),
      body = fontSize(ot, "objectiveFont"),
      counter = fontSize(ot, "objectiveFont"),
    }
    style.width = type(ot.width) == "number" and ot.width or nil
  end
  local ok, path = pcall(FlareStyle.TrackerFont)
  if ok and path then style.fontPath = path end
  FlareStyle.current = style
  if OXPFUI.theme and OXPFUI.theme.SetScheme then OXPFUI.theme.SetScheme(style.scheme) end
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
    s.frameStyle or L.flareStyleOwn,
    s.opacity and (math.floor(s.opacity * 100 + 0.5) .. "%") or L.flareStyleOwn,
    s.border or (s.borderName and (tostring(s.borderName) .. "?")) or L.flareStyleOwn,
    s.scheme or L.flareStyleOwn,
    s.strips == nil and L.flareStyleOwn or (s.strips and "on" or "off"),
    s.fontPath or L.flareStyleOwn)
end
