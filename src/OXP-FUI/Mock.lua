-- OXP-FUI · Mock: a design mock-up of a more readable guide card body.
--
-- /oxpfui mock toggles a standalone window with sample steps (Darkshore,
-- steps 60-62) drawn the proposed way. It is OXP-FUI's own frame: it never
-- reads or changes OpenXP's card, so it can be judged side by side with the
-- real one. Nothing here is wired into the card yet.
--
-- Proposed changes it shows:
--   1. Header "Darkshore (16–19)" with "Step 61 / 91", no accent dot.
--   2. The 34px step-type badge (and "#61" under it) becomes a 14px icon in
--      front of the title: gold "!" / "?" for accept / turn in (Blizzard's
--      quest-giver marks), OpenXP's own kill / loot / travel / town icons in
--      their kind colours. The title gains ~45px of width.
--   3. Objectives indented under the title, each with its count first and
--      a thin progress bar for kill/loot counts.
--   4. Tips ("Be aware of…", "Care as…", "Getting there") as secondary
--      text: smaller, dimmer, under a light "Tips" heading, so the objective
--      stands out.
--   5. Faint hairline dividers between steps; section headings ("Along the
--      Way", "Up Next") on the tracker's fading heading shade.

local ADDON_NAME, OXPFUI = ...

local theme = OXPFUI.theme

local WIDTH = 300
local PAD = 14
local ICON = 14
local OPENXP_TEX = "Interface\\AddOns\\OpenXP\\Textures\\Card\\"

-- OpenXP's step kinds (OpenXPCard.lua BADGES) and colours.
local KINDS = {
  accept = { glyph = "!", color = { 242 / 255, 195 / 255, 92 / 255 } },
  turnin = { glyph = "?", color = { 242 / 255, 195 / 255, 92 / 255 } },
  kill = { icon = "cross", color = { 1, 112 / 255, 67 / 255 } },
  loot = { icon = "diamond", color = { 38 / 255, 198 / 255, 218 / 255 } },
  travel = { icon = "travel", color = { 90 / 255, 184 / 255, 1 } },
  town = { icon = "house", color = { 179 / 255, 157 / 255, 219 / 255 } },
}

local MOB, ITEM = "|cFFFF6B4D", "|cFF4DD2FF"

-- The sample content: the steps from the in-game screenshots.
local SAMPLE = {
  zone = "Darkshore", range = "16–19", step = 61, total = 91,
  current = {
    kind = "loot",
    title = "Kill " .. MOB .. "Greymist Oracles|r and " .. MOB .. "Greymist Tidehunters|r. Loot them for the "
      .. ITEM .. "Middle of Gelkak's Key|r",
    objectives = { { have = 0, need = 1, text = "Middle of Gelkak's Key" } },
    tips = {
      MOB .. "Greymist Oracles|r cast Lightning Bolt and heal with Healing Wave.",
      MOB .. "Greymist Tidehunters|r poison in melee: 13 damage every 3 sec for 30 sec.",
      "Fight behind the sunken ship to block their bolts.",
    },
  },
  along = {
    kind = "kill", num = 60,
    title = "Kill " .. MOB .. "Raging Reef Crawlers|r and " .. MOB .. "Encrusted Tide Crawlers|r. Loot them for the "
      .. ITEM .. "Bottom of Gelkak's Key|r",
    objectives = { { have = 3, need = 8, text = "Raging Reef Crawler slain" },
                   { have = 0, need = 1, text = "Bottom of Gelkak's Key" } },
  },
  upNext = "Kill Giant Foreststriders. Loot them for the Top of Gelkak's Key",
}

local mock -- built on first open

local function text(parent, kind, colorName, value, width)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  theme.ApplyText(fs, kind, colorName)
  fs:SetJustifyH("LEFT")
  if width then fs:SetWidth(width) end
  fs:SetText(value)
  return fs
end

-- Kind icon: a glyph for accept / turn in, else OpenXP's own icon texture.
local function kindIcon(parent, kind)
  local k = KINDS[kind] or KINDS.travel
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(ICON, ICON)
  if k.glyph then
    local g = text(holder, "title", "TITLE", k.glyph)
    g:SetPoint("CENTER", holder, "CENTER", 0, 0)
    g:SetTextColor(k.color[1], k.color[2], k.color[3], 1)
  else
    local tex = holder:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(holder)
    tex:SetTexture(OPENXP_TEX .. k.icon)
    tex:SetVertexColor(k.color[1], k.color[2], k.color[3], 1)
  end
  return holder
end

local function hairline(parent, y)
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetHeight(1)
  line:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
  line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, y)
  local c = theme.C.ACCENT
  line:SetColorTexture(c[1], c[2], c[3], 0.25)
  return line
end

-- One step: icon + title, indented objectives with counts and bars, tips.
-- Returns the y below it.
local function stepBlock(f, step, y)
  local icon = kindIcon(f, step.kind)
  icon:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y - 1)
  local titleW = WIDTH - PAD * 2 - ICON - 6
  local title = text(f, "title", "TITLE", step.title, titleW)
  title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, 1)
  y = y - math.max(ICON, title:GetStringHeight() or 14) - 6
  for _, o in ipairs(step.objectives or {}) do
    local done = o.have >= o.need
    local line = text(f, "body", done and "OBJECTIVE_DONE" or "OBJECTIVE",
      ("%d/%d  %s"):format(o.have, o.need, o.text), titleW)
    line:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + ICON + 6, y)
    y = y - (line:GetStringHeight() or 12) - 3
    if o.need > 1 then
      local track = f:CreateTexture(nil, "ARTWORK")
      track:SetHeight(3)
      track:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + ICON + 6, y)
      track:SetWidth(titleW * 0.6)
      track:SetColorTexture(1, 1, 1, 0.08)
      local fill = f:CreateTexture(nil, "OVERLAY")
      fill:SetHeight(3)
      fill:SetPoint("TOPLEFT", track, "TOPLEFT")
      fill:SetWidth(math.max(1, titleW * 0.6 * o.have / o.need))
      local c = theme.C.ACCENT
      fill:SetColorTexture(c[1], c[2], c[3], 1)
      y = y - 7
    end
  end
  if step.tips then
    y = y - 4
    local head = text(f, "counter", "DIM", "Tips")
    head:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + ICON + 6, y)
    y = y - (head:GetStringHeight() or 11) - 3
    for _, tip in ipairs(step.tips) do
      local fs = text(f, "counter", "DIM", tip, titleW - 8)
      fs:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + ICON + 14, y)
      local dot = f:CreateTexture(nil, "ARTWORK")
      dot:SetSize(3, 3)
      dot:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + ICON + 8, y - 5)
      local c = theme.C.DIM
      dot:SetColorTexture(c[1], c[2], c[3], 1)
      y = y - (fs:GetStringHeight() or 11) - 3
    end
  end
  return y
end

-- A section heading on the tracker's fading shade, with an optional dim
-- note on the right (the step number of an "Along the Way" step).
local function sectionHeading(f, label, note, y, key)
  local fs = text(f, "title", "ZONE", label)
  fs:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
  theme.ApplySectionHeading(f, fs, key)
  if note then
    local n = text(f, "counter", "DIM", note)
    n:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, y - 1)
  end
  return y - (fs:GetStringHeight() or 13) - 10
end

local function build()
  local f = CreateFrame("Frame", "OXPFUIMock", UIParent, "BackdropTemplate")
  f:SetWidth(WIDTH)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  f:SetClampedToScreen(true)
  theme.ApplyPopupBackdrop(f)
  f:Hide()
  tinsert(UISpecialFrames, "OXPFUIMock")

  -- Header: "Darkshore (16–19)" ........ "Step 61 / 91"
  local header = CreateFrame("Frame", nil, f)
  header:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
  header:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
  header:SetHeight(28)
  local c = theme.C.DIM
  local dim = ("|cFF%02X%02X%02X"):format(math.floor(c[1] * 255 + 0.5),
    math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
  f.zone = text(header, "zone", "ZONE", SAMPLE.zone .. " " .. dim .. "(" .. SAMPLE.range .. ")|r")
  f.zone:SetPoint("LEFT", header, "LEFT", PAD, 0)
  f.step = text(header, "counter", "TITLE", ("Step %d / %d"):format(SAMPLE.step, SAMPLE.total))
  f.step:SetPoint("RIGHT", header, "RIGHT", -PAD + 1, 0)
  -- FlareUI's framed style: header strip seated on the top border, bottom
  -- strip on the bottom border (the window has a background and a frame).
  theme.ApplyTitleStrips(f, header, { border = theme.PopupBorderKey() })
  local progress = f:CreateTexture(nil, "OVERLAY")
  progress:SetHeight(2)
  progress:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 3, -3)
  progress:SetWidth((WIDTH - 8) * SAMPLE.step / SAMPLE.total)
  local t = theme.C.TITLE
  progress:SetColorTexture(t[1], t[2], t[3], 1)

  local y = -46
  y = stepBlock(f, SAMPLE.current, y) - 8
  hairline(f, y)
  y = y - 10
  y = sectionHeading(f, "Along the Way", "#" .. SAMPLE.along.num, y, "mockAlong")
  y = stepBlock(f, SAMPLE.along, y) - 8
  hairline(f, y)
  y = y - 10
  y = sectionHeading(f, "Up Next", nil, y, "mockUpNext")
  local nextLine = text(f, "body", "OBJECTIVE", SAMPLE.upNext, WIDTH - PAD * 2)
  nextLine:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
  y = y - (nextLine:GetStringHeight() or 12) - 14
  local note = text(f, "counter", "DIM", "Mock-up only. /oxpfui mock or Escape closes it.", WIDTH - PAD * 2)
  note:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, y)
  y = y - (note:GetStringHeight() or 11) - 16 -- room for the bottom strip
  f:SetHeight(-y)
  return f
end

function OXPFUI.ToggleMock()
  if not mock then mock = build() end
  if mock:IsShown() then mock:Hide() else mock:Show() end
  return mock
end
