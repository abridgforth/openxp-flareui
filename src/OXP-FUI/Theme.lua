-- OXP-FUI · Theme: the FlareUI Quest Tracker look, re-implemented.
--
-- Constants and recipes come from FlareUI's objective-tracker module
-- (FlareUI by Malkkav, MIT; art and fonts bundled under Media/ and Licenses-ThirdParty/,
-- see Licenses-ThirdParty/FlareUI-LICENSE.txt). No FlareUI code is copied — this file is
-- a new implementation of the same API calls.

local ADDON_NAME, OXPFUI = ...

local theme = {}

-- Palette (RGB triples, 0..1). FlareUI ObjectiveTracker constants.
theme.C = {
  ZONE = { 0.80, 0.60, 0.34 },      -- #CC9957 amber/bronze accent, zone headers
  TITLE = { 1, 0.82, 0 },           -- gold: quest and step titles
  TITLE_DONE = { 0.13, 1, 0.13 },   -- green: completed / arrived
  TITLE_FOCUS = { 0.40, 0.80, 1 },  -- light blue: focused / current
  OBJECTIVE = { 0.85, 0.85, 0.85 }, -- body text, light grey
  OBJECTIVE_DONE = { 0.55, 0.55, 0.55 },
  DIM = { 0.55, 0.55, 0.55 },       -- counters and hints
  URGENT = { 1, 0.25, 0.25 },       -- red: urgent / warning
  BOX = { 0.50, 0.38, 0.21 },       -- bronze square buttons at rest
  BOX_LIT = { 0.65, 0.49, 0.27 },   -- bronze square buttons hovered
  BORDER = { 0.65, 0.49, 0.27, 1 }, -- #A67D45 frame border tint
  FILL = { 0.10, 0.08, 0.06 },      -- warm near-black: solid form of the
                                     -- tracker fill's lighter top colour,
                                     -- used where a plain texture is tinted
  ACCENT = { 0.80, 0.60, 0.34 },    -- #CC9957 bronze for tinted chrome (dots,
                                     -- washes, arrow); never follows a scheme
}

-- Colour schemes (FlareUI ObjectiveTracker.lua OT.ApplyColorScheme, MIT):
-- with "Follow FlareUI tracker style" on, the text colours follow the
-- tracker's scheme. The C tables change in place, so every holder of one
-- (skins keep `local C = theme.C`) follows. nil = OXP-FUI's own palette.
local SCHEME_KEYS = { "ZONE", "TITLE", "TITLE_DONE", "TITLE_FOCUS", "OBJECTIVE",
                      "OBJECTIVE_DONE", "DIM", "URGENT" }
theme.BASE = {}
for _, k in ipairs(SCHEME_KEYS) do theme.BASE[k] = { theme.C[k][1], theme.C[k][2], theme.C[k][3] } end

-- Blizzard's tracker colours, as FlareUI's C table holds them.
local BLIZZARD = {
  ZONE = { 1, 0.82, 0 }, TITLE = { 1, 0.82, 0 }, TITLE_DONE = { 0.13, 1, 0.13 },
  TITLE_FOCUS = { 0.40, 0.80, 1 }, OBJECTIVE = { 0.85, 0.85, 0.85 },
  OBJECTIVE_DONE = { 0.55, 0.55, 0.55 }, DIM = { 0.55, 0.55, 0.55 }, URGENT = { 1, 0.25, 0.25 },
}
-- FlareUI's scheme: zone headings in palette bronze5, titles in bronze4,
-- every other colour in FlareUI's softer tone of Blizzard's (ns.SoftColor:
-- 35% less saturated, a quarter of the way to a warm light bronze).
local FLARE_BRONZE = { ZONE = { 0.85, 0.68, 0.47 }, TITLE = { 0.80, 0.60, 0.34 } }
function theme.SoftColor(r, g, b)
  local avg = (r + g + b) / 3
  r, g, b = r + (avg - r) * 0.35, g + (avg - g) * 0.35, b + (avg - b) * 0.35
  return r * 0.75 + 0.85 * 0.25, g * 0.75 + 0.70 * 0.25, b * 0.75 + 0.50 * 0.25
end

-- Every colour a palette key can take (OXP-FUI, Blizzard, FlareUI).
function theme.Variants(key)
  local out = { theme.BASE[key], BLIZZARD[key] }
  if FLARE_BRONZE[key] then out[#out + 1] = FLARE_BRONZE[key]
  elseif BLIZZARD[key] then
    local r, g, b = theme.SoftColor(BLIZZARD[key][1], BLIZZARD[key][2], BLIZZARD[key][3])
    out[#out + 1] = { r, g, b }
  end
  return out
end

theme.scheme = nil
function theme.SetScheme(scheme)
  if scheme ~= "blizzard" and scheme ~= "flareui" then scheme = nil end
  if scheme == theme.scheme then return false end
  theme.scheme = scheme
  for _, k in ipairs(SCHEME_KEYS) do
    local c = theme.C[k]
    local r, g, b
    if scheme == "blizzard" then
      r, g, b = BLIZZARD[k][1], BLIZZARD[k][2], BLIZZARD[k][3]
    elseif scheme == "flareui" then
      local bronze = FLARE_BRONZE[k]
      if bronze then r, g, b = bronze[1], bronze[2], bronze[3]
      else r, g, b = theme.SoftColor(BLIZZARD[k][1], BLIZZARD[k][2], BLIZZARD[k][3]) end
    else
      r, g, b = theme.BASE[k][1], theme.BASE[k][2], theme.BASE[k][3]
    end
    c[1], c[2], c[3] = r, g, b
  end
  return true
end

-- OpenXP's own blue accent (90/255, 184/255, 1 — its COLORS tables and the
-- card art it tints), retinted to FlareUI amber/bronze by the card and the
-- welcome/feedback skins. One shared definition — with one shared
-- near-match tolerance — so every skin agrees what counts as "OpenXP blue".
theme.OXP_BLUE = { 90 / 255, 184 / 255, 1 }

-- Near-match tolerance when comparing a vertex/text colour against a
-- palette triple: the palettes are set as exact constants, so this only
-- absorbs float noise.
local COLOR_EPS = 1 / 64

function theme.NearColor(r, g, b, target)
  return math.abs(r - target[1]) <= COLOR_EPS
    and math.abs(g - target[2]) <= COLOR_EPS
    and math.abs(b - target[3]) <= COLOR_EPS
end

-- Typography: header 13 / title 12 / body 11, no outline, 1px black shadow.
-- The card's header row is smaller than a window header: the zone name is
-- one point under it and the level range / "Step n / n" counter two.
theme.FONT_SIZES = { header = 13, title = 12, body = 11, zone = 12, counter = 11 }

-- Bundled and built-in font choices (order = settings panel cycle order).
local MEDIA = "Interface\\AddOns\\OXP-FUI\\Media\\"
theme.FONTS = {
  { key = "Friz Quadrata",   path = "Fonts\\FRIZQT__.TTF" },
  { key = "Asap Condensed",  path = MEDIA .. "Fonts\\AsapCondensed-Regular.ttf" },
  { key = "Barlow Condensed", path = MEDIA .. "Fonts\\BarlowCondensed-Regular.ttf" },
  { key = "Cabin Condensed", path = MEDIA .. "Fonts\\CabinCondensed-Regular.ttf" },
  { key = "Fira Condensed",  path = MEDIA .. "Fonts\\FiraSansExtraCondensed-Regular.ttf" },
  { key = "Roboto Condensed", path = MEDIA .. "Fonts\\RobotoCondensed-Regular.ttf" },
}
theme.DEFAULT_FONT = "Friz Quadrata"

function theme.FontPath(key)
  for _, f in ipairs(theme.FONTS) do
    if f.key == key then return f.path end
  end
  return theme.FONTS[1].path
end

-- Border styles: bundled FlareUI border art, drawn grey and tinted bronze.
-- Thin is drawn at half the edge size (FlareUI's own rule).
theme.BORDERS = {
  Frames = { file = MEDIA .. "Borders\\FlareUI-Frames.tga", edgeSize = 16 },
  Thick = { file = MEDIA .. "Borders\\FlareUI-Thick.tga", edgeSize = 16 },
  Thin = { file = MEDIA .. "Borders\\FlareUI-Thin.tga", edgeSize = 8 },
  None = { file = nil, edgeSize = 0 }, -- fill only, like FlareUI's "None"
}
theme.BORDER_ORDER = { "Frames", "Thick", "Thin", "None" }
theme.DEFAULT_BORDER = "Frames"

-- With "Follow FlareUI tracker style" on, FlareStyle supplies the tracker's
-- own opacity / border / font; any value it cannot read stays the OXP-FUI
-- setting. nil when not following.
local function flare()
  local fs = OXPFUI.FlareStyle
  if not fs or not fs.Active() then return nil end
  return fs.current or fs.Refresh()
end
theme.FlareOverrides = flare

function theme.BorderKey(db)
  local f = flare()
  local key = (f and f.border) or db.borderStyle
  if theme.BORDERS[key] then return key end
  return theme.DEFAULT_BORDER
end

-- Panel fill opacity from settings; every backdrop recipe shares this
-- default for a missing/non-numeric value.
local DEFAULT_OPACITY = 0.6

local function panelOpacity(db)
  local f = flare()
  if f and type(f.opacity) == "number" then return f.opacity end
  local opacity = db.opacity
  if type(opacity) ~= "number" then opacity = DEFAULT_OPACITY end
  return opacity
end

-- The tracker backdrop recipe: Blizzard's dark dialog fill (a warm near-black
-- vertical gradient), FlareUI border art, insets 3, bronze tint, panel
-- opacity from settings. Appearance only — callers never resize the frame.
function theme.ApplyBackdrop(frame)
  local db = OXPFUI.db or {}
  local border = theme.BORDERS[theme.BorderKey(db)]
  local opacity = panelOpacity(db)
  frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = border.file,
    tile = false, tileSize = 0, edgeSize = border.edgeSize,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  frame:SetBackdropColor(1, 1, 1, opacity)
  local b = theme.C.BORDER
  frame:SetBackdropBorderColor(b[1], b[2], b[3], b[4])
end

-- The header-band variant: FlareUI's tracker header sits on the panel fill
-- with no border of its own (ObjectiveTracker CreateFrames has no separate
-- header background). Used for OpenXP's small title strips that carry their
-- own legacy edge backdrop — the strip blends into the framed panel instead
-- of drawing a second border inside it.
function theme.ApplyPanelFill(frame)
  local db = OXPFUI.db or {}
  local opacity = panelOpacity(db)
  frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = nil,
    tile = false, tileSize = 0, edgeSize = 0,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  frame:SetBackdropColor(1, 1, 1, opacity)
end

-- OpenXP's title strips (the X_title frames): their .text becomes a
-- FlareUI gold header. Nil-safe, like ApplyText. The strip frame itself —
-- border art (ApplyBackdrop), panel fill (ApplyPanelFill) or nothing — is
-- styled by the caller, because the skins differ there.
function theme.ApplyTitleStrip(frame)
  if type(frame) == "table" then
    theme.ApplyText(frame.text, "header", "TITLE")
  end
end

-- Apply the FlareUI typography to a font string: chosen face, size for its
-- kind, no outline, 1px black shadow at (+1, -1).
function theme.ApplyFontString(fs, kind)
  local db = OXPFUI.db or {}
  local f = flare()
  local sizes = (f and f.sizes) or theme.FONT_SIZES
  local size = sizes[kind] or sizes.body or theme.FONT_SIZES.body
  fs:SetFont((f and f.fontPath) or theme.FontPath(db.font), size, "")
  fs:SetShadowColor(0, 0, 0, 1)
  fs:SetShadowOffset(1, -1)
  return fs
end

function theme.ApplyTextColor(fs, colorName)
  local c = theme.C[colorName] or theme.C.OBJECTIVE
  fs:SetTextColor(c[1], c[2], c[3], 1)
end

-- The canonical "typography + colour" pass over a font string:
-- ApplyFontString(fs, kind) + ApplyTextColor(fs, colorName) in one call,
-- nil-safe, so skins can pass OpenXP fields that a version drift may have
-- renamed or removed (a missing font string is skipped quietly).
function theme.ApplyText(fs, kind, colorName)
  if type(fs) == "table" and fs.SetFont then
    theme.ApplyFontString(fs, kind)
    theme.ApplyTextColor(fs, colorName)
  end
  return fs
end

-- FlareUI's bronze box-button paint (CreateBoxButton in the tracker) applied
-- to an existing BackdropTemplate button: hairline bronze border over a
-- near-black fill, bronze-lit while hovered. OpenXP's own white hover swap
-- runs first (HookScript chains), so the bronze wins. Hooking once per
-- button keeps re-applies from stacking handlers.
function theme.ApplyBoxButton(btn)
  btn:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false, tileSize = 0, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  btn:SetBackdropColor(0, 0, 0, 0.85)
  local rest, lit = theme.C.BOX, theme.C.BOX_LIT
  btn:SetBackdropBorderColor(rest[1], rest[2], rest[3], 1)
  if not btn.__oxpfuiBoxHover then
    btn.__oxpfuiBoxHover = true
    btn:HookScript("OnEnter", function(self)
      self:SetBackdropBorderColor(lit[1], lit[2], lit[3], 1)
    end)
    btn:HookScript("OnLeave", function(self)
      self:SetBackdropBorderColor(rest[1], rest[2], rest[3], 1)
    end)
  end
  return btn
end

-- ---------------------------------------------------------------------------
-- Shared FlareUI chrome recipes (procedural, no art files)
-- ---------------------------------------------------------------------------

-- Unwrap an engine-guarded frame to the real frame, so chrome textures are
-- parented and anchored to the frame the client knows (see Engine.lua).
function theme.RealFrame(frame)
  if type(frame) ~= "table" then return nil end
  return frame.__raw or frame
end

-- FlareUI's scrollbar: a 1px faint bronze track down the right margin and a
-- 3px solid bronze thumb, both drawn with colour textures (ObjectiveTracker
-- has no slider art either — its list is mouse-wheel scrolled).
--   frame: the list's frame (guarded or raw)
--   opts.state(): -> fraction (0..1 through the list), visibleRatio
--                 (0..1 of the list that fits), scrollable (bool)
-- Re-applied chrome is reused; nothing is resized except our own textures.
function theme.ApplyScrollBar(frame, opts)
  local rf = theme.RealFrame(frame)
  if not (rf and rf.CreateTexture and rf.SetWidth) then return end
  local chrome = rf.oxpfuiScroll
  if not chrome then
    local track = rf:CreateTexture(nil, "ARTWORK")
    track:SetSnapToPixelGrid(false)
    track:SetTexelSnappingBias(0)
    track:SetWidth(1)
    local thumb = rf:CreateTexture(nil, "OVERLAY")
    thumb:SetSnapToPixelGrid(false)
    thumb:SetTexelSnappingBias(0)
    thumb:SetWidth(3)
    chrome = { track = track, thumb = thumb }
    rf.oxpfuiScroll = chrome
  end
  local box = theme.C.BOX
  chrome.track:SetColorTexture(box[1], box[2], box[3], 0.25)
  chrome.thumb:SetColorTexture(box[1], box[2], box[3], 1)
  chrome.track:ClearAllPoints()
  chrome.track:SetPoint("TOPRIGHT", rf, "TOPRIGHT", -6, -30)
  chrome.track:SetPoint("BOTTOMRIGHT", rf, "BOTTOMRIGHT", -6, 8)

  local fraction, visibleRatio, scrollable = 0, 1, false
  if opts and opts.state then
    local ok, frac, ratio, scroll = pcall(opts.state)
    if ok then
      fraction = frac or 0
      visibleRatio = ratio or 1
      scrollable = scroll and true or false
    end
  end
  if fraction < 0 then fraction = 0 elseif fraction > 1 then fraction = 1 end
  if visibleRatio < 0.05 then visibleRatio = 0.05 elseif visibleRatio > 1 then visibleRatio = 1 end

  -- list body height: the frame minus its title row and bottom padding
  local trackHeight = (rf:GetHeight() or 0) - 38
  if trackHeight < 16 then trackHeight = 16 end
  local thumbHeight = trackHeight * visibleRatio
  if thumbHeight < 16 then thumbHeight = 16 end
  local offset = (trackHeight - thumbHeight) * fraction
  chrome.thumb:ClearAllPoints()
  chrome.thumb:SetPoint("TOPRIGHT", chrome.track, "TOPRIGHT", -1, -offset)
  chrome.thumb:SetHeight(thumbHeight)

  if scrollable then
    chrome.track:Show()
    chrome.thumb:Show()
  else
    chrome.track:Hide()
    chrome.thumb:Hide()
  end
end

-- Sub-panel inset: the warm dark fill at a slightly firmer opacity than the
-- window (OpenXP's own sub-panels are a step lighter than their windows),
-- with a bronze hairline instead of border art — the window already wears
-- the border art.
function theme.ApplyInsetBackdrop(frame)
  local db = OXPFUI.db or {}
  local opacity = panelOpacity(db)
  frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile = false, tileSize = 0, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
  })
  frame:SetBackdropColor(1, 1, 1, math.min(1, opacity + 0.25))
  local c = theme.C.BOX
  frame:SetBackdropBorderColor(c[1], c[2], c[3], 1)
  return frame
end


-- ---------------------------------------------------------------------------
-- Section separators: Blizzard's own quest tracker strips, the way FlareUI's
-- tracker draws them in its Blizzard and FlareUI frame styles (same atlases,
-- same measurements: FlareUI ObjectiveTracker.lua "HEADER ART", MIT). Each
-- strip is cut in three so any width keeps the ends at their own size: both
-- ends at 30% of the art's width, a thin slice of the plain middle stretched
-- between them. Sizes come from the game (C_Texture.GetAtlasInfo); with no
-- atlas info the strip is simply not drawn.
-- ---------------------------------------------------------------------------

theme.ART = {
  TITLE = "ui-questtracker-primary-objective-header",   -- window headers
  HEADING = "UI-QuestTracker-Secondary-Objective-Header", -- section headings
  FRAME = 260,        -- Blizzard's header width; strips reach past it
  TEXT = 7,           -- Blizzard's text inset on its headers
  CAP = 0.3,          -- each end of a strip, as a share of its width
  TITLE_RIGHT = 8,    -- the title art sits off centre: right end further out
  TITLE_LEFT = 1,     -- and one pixel left, centred on the border
  TITLE_DOWN = 0.5,   -- with a border: the knobs onto the border's curve
  KNOB_IN = 2,        -- title knobs sit half outside the frame edge
  HEADING_IN = 5,     -- heading strips stay this far inside the frame
  FOOT_BAND = { 31 / 40, 38 / 40 }, -- the title art's bottom line + knobs
  FOOT_Y = 2.5,       -- that line's middle above the frame's bottom edge
  HEADER_INSET = 8,   -- header band from the frame edges
  PAD = 14,           -- text from the frame edges
}

local artInfo = {}
function theme.ArtInfo(atlas)
  local info = artInfo[atlas]
  if info == nil then
    local ok, found = false, nil
    if C_Texture and C_Texture.GetAtlasInfo then
      ok, found = pcall(C_Texture.GetAtlasInfo, atlas)
    end
    info = ok and type(found) == "table" and found.file and (found.width or 0) > 0 and found or false
    artInfo[atlas] = info
  end
  return info or nil
end

function theme.ArtReach(atlas)
  local info = theme.ArtInfo(atlas)
  return info and math.max(0, (info.width - theme.ART.FRAME) / 2) or 0
end

-- Are separators drawn? Following FlareUI: its frame style decides (Blizzard
-- and FlareUI yes, Custom no). Otherwise the "Section separators" setting.
function theme.StripsOn()
  local f = flare()
  if f and f.strips ~= nil then return f.strips end
  local db = OXPFUI.db or {}
  return db.separators ~= false
end

-- The bottom strip with its knobs sits on a border: FlareUI style only.
function theme.FootOn()
  local f = flare()
  return f ~= nil and f.foot == true
end

-- An OXP-FUI-owned band frame on `parent` (created once per key). Strips are
-- drawn on it, never on OpenXP's own frames. It sits at the parent's frame
-- level, under the parent's child frames and their text.
function theme.Band(parent, key)
  parent.oxpfuiBands = parent.oxpfuiBands or {}
  local band = parent.oxpfuiBands[key]
  if not band then
    band = CreateFrame("Frame", nil, parent)
    if band.SetFrameLevel and parent.GetFrameLevel then
      band:SetFrameLevel(parent:GetFrameLevel() or 0)
    end
    if band.EnableMouse then band:EnableMouse(false) end
    parent.oxpfuiBands[key] = band
  end
  return band
end

function theme.HideStrip(band)
  local s = band and band.oxpfuiStrip
  if s then s.L:Hide(); s.M:Hide(); s.R:Hide() end
end

-- Draw `atlas` across band, centred on its height: leftOut / rightOut past
-- its edges; band (optional) = the part of the art's height to draw; dy
-- moves it up (+) or down (-).
function theme.PlaceStrip(band, atlas, leftOut, rightOut, cut, dy)
  local info = theme.ArtInfo(atlas)
  if not info then theme.HideStrip(band) return false end
  local s = band.oxpfuiStrip
  if not s then
    s = {}
    for _, part in ipairs({ "L", "M", "R" }) do
      local tex = band:CreateTexture(nil, "BACKGROUND", nil, -1)
      if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
      if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
      s[part] = tex
    end
    band.oxpfuiStrip = s
  end
  local l, r = info.leftTexCoord or 0, info.rightTexCoord or 1
  local top, bottom = info.topTexCoord or 0, info.bottomTexCoord or 1
  local height = info.height
  if cut then
    local tall = bottom - top
    top, bottom = top + tall * cut[1], top + tall * cut[2]
    height = info.height * (cut[2] - cut[1])
  end
  local span = r - l
  local cap = math.floor(info.width * theme.ART.CAP + 0.5)
  local capSpan = span * cap / info.width
  local mid = l + span / 2
  for _, tex in pairs(s) do
    tex:SetTexture(info.file)
    tex:ClearAllPoints()
    tex:SetHeight(height)
    tex:Show()
  end
  s.L:SetTexCoord(l, l + capSpan, top, bottom)
  s.L:SetWidth(cap)
  s.L:SetPoint("LEFT", band, "LEFT", -leftOut, dy or 0)
  s.R:SetTexCoord(r - capSpan, r, top, bottom)
  s.R:SetWidth(cap)
  s.R:SetPoint("RIGHT", band, "RIGHT", rightOut, dy or 0)
  s.M:SetTexCoord(mid - span * 0.005, mid + span * 0.005, top, bottom)
  s.M:SetPoint("LEFT", s.L, "RIGHT")
  s.M:SetPoint("RIGHT", s.R, "LEFT")
  return true
end

-- A window's title strip behind `header` (any region or frame with a top
-- and bottom), spanning `frame` like FlareUI's tracker header, plus the
-- bottom strip along the frame's foot in the FlareUI style. Returns whether
-- the title strip is drawn.
function theme.ApplyTitleStrips(frame, header)
  local A = theme.ART
  local band = theme.Band(frame, "title")
  local foot = theme.Band(frame, "foot")
  -- The band is placed even without strips: header controls (the step
  -- list's close button) centre on it either way.
  if header then
    band:ClearAllPoints()
    band:SetPoint("TOP", header, "TOP")
    band:SetPoint("BOTTOM", header, "BOTTOM")
    band:SetPoint("LEFT", frame, "LEFT", A.HEADER_INSET, 0)
    band:SetPoint("RIGHT", frame, "RIGHT", -A.HEADER_INSET, 0)
  end
  if not (header and theme.StripsOn()) then
    theme.HideStrip(band); theme.HideStrip(foot)
    return false
  end
  local reach = theme.ArtReach(A.TITLE)
  local leftOut = reach - A.KNOB_IN + A.TITLE_LEFT
  local rightOut = reach + A.TITLE_RIGHT - A.KNOB_IN - A.TITLE_LEFT
  local bordered = theme.BorderKey(OXPFUI.db or {}) ~= "None"
  local drawn = theme.PlaceStrip(band, A.TITLE, leftOut, rightOut, nil, bordered and A.TITLE_DOWN or nil)
  if drawn and theme.FootOn() then
    foot:ClearAllPoints()
    foot:SetHeight(1)
    foot:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", A.HEADER_INSET, A.FOOT_Y - 0.5)
    foot:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -A.HEADER_INSET, A.FOOT_Y - 0.5)
    theme.PlaceStrip(foot, A.TITLE, leftOut, rightOut, A.FOOT_BAND)
  else
    theme.HideStrip(foot)
  end
  return drawn
end

-- A rule between two sections: the title art's bottom line with its end
-- knobs (the same rods FlareUI's tracker draws around its header), across
-- `frame` inside its text padding, centred on `region`'s top or bottom edge.
-- host (default frame): the frame the band belongs to, so the rule shows
-- and hides with that section.
function theme.ApplySectionRule(frame, region, edge, key, host)
  local A = theme.ART
  local band = theme.Band(host or frame, key or "rule")
  if not (region and theme.StripsOn()) then theme.HideStrip(band) return false end
  band:ClearAllPoints()
  band:SetHeight(1)
  band:SetPoint("TOP", region, edge == "BOTTOM" and "BOTTOM" or "TOP")
  band:SetPoint("LEFT", frame, "LEFT", A.PAD, 0)
  band:SetPoint("RIGHT", frame, "RIGHT", -A.PAD, 0)
  local reach = theme.ArtReach(A.TITLE)
  return theme.PlaceStrip(band, A.TITLE, reach, reach, A.FOOT_BAND)
end

-- A section heading's strip behind `label` (a font string or frame),
-- across `frame` inside its text padding, like FlareUI's zone headings.
-- host (default frame): the frame the band belongs to, so the strip shows
-- and hides with that section.
function theme.ApplyHeadingStrip(frame, label, key, host)
  local A = theme.ART
  local band = theme.Band(host or frame, key or "heading")
  if not (label and theme.StripsOn()) then theme.HideStrip(band) return false end
  band:ClearAllPoints()
  band:SetPoint("TOP", label, "TOP")
  band:SetPoint("BOTTOM", label, "BOTTOM")
  band:SetPoint("LEFT", frame, "LEFT", A.PAD, 0)
  band:SetPoint("RIGHT", frame, "RIGHT", -A.PAD, 0)
  local reach = theme.ArtReach(A.HEADING) + A.TEXT - A.HEADING_IN
  return theme.PlaceStrip(band, A.HEADING, reach, reach)
end


-- A toolbar button in the look of FlareUI's tracker header buttons: a dark
-- square with a 1px bronze rim (lit bronze while pointed at) behind a gold
-- icon. Drawn on an own frame under the button's icon; the button keeps its
-- size, place, click and tooltip. OpenXP's own hover wash stays hidden.
-- opts.wide: the button shows a text label too, so the box spans its width.
function theme.ApplyToolbarButton(btn, opts)
  local b = theme.RealFrame(btn)
  if not (b and b.CreateTexture and b.GetFrameLevel) then return end
  local box = b.oxpfuiBox
  if not box then
    box = CreateFrame("Frame", nil, b, "BackdropTemplate")
    box:SetFrameLevel(math.max(0, (b:GetFrameLevel() or 1) - 1))
    if box.EnableMouse then box:EnableMouse(false) end
    box:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8",
      tile = false, tileSize = 0, edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    b.oxpfuiBox = box
    local function paint(lit)
      local c = lit and theme.C.BOX_LIT or theme.C.BOX
      box:SetBackdropBorderColor(c[1], c[2], c[3], 1)
    end
    box.paint = paint
    b:HookScript("OnEnter", function(self)
      paint(true)
      if self.bg then self.bg:SetAlpha(0) end
    end)
    b:HookScript("OnLeave", function(self)
      paint(false)
      if self.bg then self.bg:SetAlpha(0) end
    end)
  end
  box:SetBackdropColor(0, 0, 0, 0.6)
  box.paint(false)
  box:ClearAllPoints()
  if opts and opts.wide then
    box:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
    box:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
  else
    box:SetSize(24, 24)
    box:SetPoint("CENTER", b, "CENTER")
  end
  if b.bg then b.bg:SetAlpha(0) end
  if b.icon and b.icon.SetVertexColor then
    local c = theme.C.TITLE
    b.icon:SetVertexColor(c[1], c[2], c[3], 1)
  end
end


-- ---------------------------------------------------------------------------
-- Pop-up windows (the step list): Blizzard window anatomy rather than the
-- tracker's. A compact title bar the height of Blizzard's close button,
-- with the tracker's rod (end knobs and all) along its bottom edge; and a
-- background and frame whatever the tracker style, since a pop-up opens
-- over other windows and catches clicks across its whole area.
-- ---------------------------------------------------------------------------

theme.TITLE_BAR_H = 24       -- = UIPanelCloseButton's 24px
theme.POPUP_MIN_OPACITY = 0.85

-- Backdrop for a pop-up window: the theme's recipe, but never see-through
-- and never frameless (a "None" border falls back to Thin).
function theme.ApplyPopupBackdrop(frame)
  local db = OXPFUI.db or {}
  local key = theme.BorderKey(db)
  if key == "None" then key = "Thin" end
  local border = theme.BORDERS[key]
  local opacity = math.max(panelOpacity(db), theme.POPUP_MIN_OPACITY)
  frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = border.file,
    tile = false, tileSize = 0, edgeSize = border.edgeSize,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  frame:SetBackdropColor(1, 1, 1, opacity)
  local b = theme.C.BORDER
  frame:SetBackdropBorderColor(b[1], b[2], b[3], b[4])
end

-- The title bar band (own frame across the window's top, TITLE_BAR_H tall):
-- a slightly darker fill and the rod along its bottom. Returns the band, for
-- the caller to centre the title and controls on.
function theme.ApplyWindowTitleBar(frame)
  local A = theme.ART
  local bar = theme.Band(frame, "titlebar")
  bar:ClearAllPoints()
  bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  bar:SetHeight(theme.TITLE_BAR_H)
  if not bar.fill then
    bar.fill = bar:CreateTexture(nil, "BACKGROUND", nil, -2)
    bar.fill:SetPoint("TOPLEFT", bar, "TOPLEFT", 3, -3)
    bar.fill:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -3, 0)
  end
  bar.fill:SetColorTexture(0, 0, 0, 0.35)
  local rule = theme.Band(frame, "titlerule")
  rule:ClearAllPoints()
  rule:SetHeight(1)
  rule:SetPoint("TOP", bar, "BOTTOM")
  rule:SetPoint("LEFT", frame, "LEFT", A.HEADER_INSET, 0)
  rule:SetPoint("RIGHT", frame, "RIGHT", -A.HEADER_INSET, 0)
  local reach = theme.ArtReach(A.TITLE)
  if not theme.PlaceStrip(rule, A.TITLE, reach, reach, A.FOOT_BAND) then
    -- no atlas: a plain bronze hairline
    theme.HideStrip(rule)
    if not rule.line then
      rule.line = rule:CreateTexture(nil, "ARTWORK")
      rule.line:SetAllPoints(rule)
    end
    local c = theme.C.ACCENT
    rule.line:SetColorTexture(c[1], c[2], c[3], 0.5)
    rule.line:Show()
  elseif rule.line then
    rule.line:Hide()
  end
  return bar
end


-- Title case for OpenXP's all-caps labels ("UP NEXT" -> "Up Next", "ALONG
-- THE WAY" -> "Along the Way"), like the tracker's own headings. Small
-- words stay lower case unless first; letters after a hyphen start a word.
-- Text that is not all caps is returned unchanged.
local SMALL = { a = true, an = true, the = true, of = true, to = true, ["and"] = true,
                ["in"] = true, on = true, at = true, ["for"] = true, by = true }
function theme.TitleCase(s)
  if type(s) ~= "string" or s ~= s:upper() or not s:find("%a") then return s end
  local first = true
  return (s:lower():gsub("(%a[%w']*)", function(word)
    local out = word
    if first or not SMALL[word] then out = word:sub(1, 1):upper() .. word:sub(2) end
    first = false
    return out
  end))
end

OXPFUI.theme = theme
