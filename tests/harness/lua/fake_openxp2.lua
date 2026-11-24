-- Fake OpenXP 2.x (2.0.3) for the OXP-FUI skin seam.
--
-- OpenXP 2.0 keeps its addon table private; other addons see only its
-- named frames and the fields it hangs on them. This mirrors exactly that
-- surface, with the real geometry and call order (UI/Card.lua,
-- UI/StepNavigator.lua, UI/ActionButtons.lua, UI/Style.lua of 2.0.3):
--   * HARNESS.OXP2.Refresh()       Card.Refresh: SetSize, LayoutHeader
--     (texts, then header:SetHeight), blocks, view:SetVerticalScroll last
--   * HARNESS.OXP2.Repaint()       Style.Repaint after a skin change:
--     PaintBackdrop (SetBackdropColor/BorderColor) and every tinted piece
--   * HARNESS.OXP2.OpenSteps()     Nav.Show (builds OpenXPSteps the first time)
--   * HARNESS.OXP2.RefreshTargets(n)  Buttons.Refresh with n targets
--   * HARNESS.OXP2.OpenMenu()      GuidePicker (builds OpenXPMenu)

HARNESS.addonMetadata["OpenXP"] = { Title = "OpenXP", Version = HARNESS.openxp2Version or "2.0.3" }
HARNESS.OXP2 = { calls = {} }
local X = HARNESS.OXP2
local function bump(k) X.calls[k] = (X.calls[k] or 0) + 1 end

local WHITE = "Interface\\Buttons\\WHITE8X8"
local TEX = "Interface\\AddOns\\OpenXP\\Media\\Card\\"
local C = {
  bg = { 13 / 255, 15 / 255, 20 / 255, 0.92 }, border = { 1, 1, 1, 0.10 },
  text = { 0.93, 0.94, 0.96 }, dim = { 0.63, 0.66, 0.72 }, faint = { 0.47, 0.50, 0.56 },
  blue = { 90 / 255, 184 / 255, 1 }, gold = { 242 / 255, 195 / 255, 92 / 255 },
}
X.C = C
local PAD, HEADER_H = 12, 44

-- Style.Backdrop / PaintBackdrop
local backdrops = {}
local function Backdrop(f)
  f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 } })
  backdrops[#backdrops + 1] = f
  f:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], C.bg[4])
  f:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], C.border[4])
end

-- Style.IconButton
local function IconButton(parent, icon, label)
  local btn = CreateFrame("Button", nil, parent)
  btn:SetSize(label and 116 or 40, 30)
  btn.bg = btn:CreateTexture(nil, "BACKGROUND")
  btn.bg:SetAllPoints()
  btn.bg:SetTexture(WHITE)
  btn.icon = btn:CreateTexture(nil, "ARTWORK")
  btn.icon:SetTexture(TEX .. icon)
  btn.icon:SetSize(16, 16)
  if label then
    btn.icon:SetPoint("LEFT", 10, 0)
    btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    btn.label:SetPoint("LEFT", btn.icon, "RIGHT", 6, 0)
    btn.label:SetText(label)
  else
    btn.icon:SetPoint("CENTER")
    btn.icon:SetVertexColor(0.80, 0.82, 0.88, 1)
  end
  btn:SetScript("OnEnter", function(self)
    self.bg:SetVertexColor(1, 1, 1, 0.08)
    self.icon:SetVertexColor(1, 1, 1, 1)
  end)
  btn:SetScript("OnLeave", function(self)
    self.bg:SetVertexColor(1, 1, 1, 0)
    self.icon:SetVertexColor(0.80, 0.82, 0.88, 1)
  end)
  return btn
end

-- Style.Badge
local function Badge(parent, size)
  local b = CreateFrame("Frame", nil, parent)
  b:SetSize(size, size)
  b.fill = b:CreateTexture(nil, "BACKGROUND")
  b.ring = b:CreateTexture(nil, "BORDER")
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.glyph = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  return b
end

-- ---------------------------------------------------------------------------
-- The card (UI/Card.lua)
-- ---------------------------------------------------------------------------

local f = CreateFrame("Frame", "OpenXPCard", UIParent, "BackdropTemplate")
f:SetSize(330, 300)
f:SetPoint("RIGHT", UIParent, "RIGHT", -40, 120)
Backdrop(f)

-- The resize grip (Card.StartSizing / StopSizing / TakeSize): while it is
-- pressed OpenXP takes the frame's size as yours; otherwise every refresh
-- puts the saved one back. X.locked: Settings > Lock frames.
X.width, X.height = 330, 300
local grip = CreateFrame("Button", nil, f)
grip:SetSize(16, 16)
grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
grip:SetScript("OnMouseDown", function()
  if X.locked then return end
  X.sizing = true
  f:StartSizing("BOTTOMRIGHT")
  grip:SetScript("OnUpdate", function() if X.sizing then X.width = f:GetWidth() end end)
end)
grip:SetScript("OnMouseUp", function()
  if not X.sizing then return end
  grip:SetScript("OnUpdate", nil)
  f:StopMovingOrSizing()
  X.sizing = false
  X.width = math.floor(f:GetWidth() + 0.5)
  bump("StopSizing")
  X.Refresh()
end)
grip:SetScript("OnHide", function() end)
X.grip = grip

local header = CreateFrame("Frame", nil, f)
header:SetPoint("TOPLEFT", 1, -1)
header:SetPoint("TOPRIGHT", -1, -1)
header:SetHeight(HEADER_H)
header.bg = header:CreateTexture(nil, "BACKGROUND")
header.bg:SetAllPoints()
header.bg:SetColorTexture(1, 1, 1, 0.03)
header.zone = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
header.zone:SetPoint("TOPLEFT", header, "TOPLEFT", PAD - 1, -7)
header.zone:SetPoint("RIGHT", header, "RIGHT", -PAD + 1, 0)
header.range = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
header.range:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", PAD - 1, 7)
header.step = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
header.step:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -PAD + 1, 7)
header.nav = CreateFrame("Button", nil, header)
header.nav:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 1)
header.nav:SetSize(110, 22)
header.nav.icon = header.nav:CreateTexture(nil, "ARTWORK")
header.nav.icon:SetPoint("RIGHT", header.step, "LEFT", -5, 0)
header.nav:SetScript("OnClick", function() X.ToggleSteps() end)
X.header = header

local progressBg = f:CreateTexture(nil, "ARTWORK")
progressBg:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
progressBg:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)
progressBg:SetHeight(2)
progressBg:SetColorTexture(1, 1, 1, 0.06)
local progress = f:CreateTexture(nil, "OVERLAY")
progress:SetPoint("TOPLEFT", progressBg, "TOPLEFT")
progress:SetHeight(2)
progress:SetColorTexture(C.blue[1], C.blue[2], C.blue[3], 1)
X.progressBg, X.progress = progressBg, progress

local view = CreateFrame("ScrollFrame", nil, f)
view:SetPoint("TOPLEFT", progressBg, "BOTTOMLEFT", 0, 0)
view:SetPoint("TOPRIGHT", progressBg, "BOTTOMRIGHT", 0, 0)
local content = CreateFrame("Frame", nil, view)
view:SetScrollChild(content)
local body = CreateFrame("Frame", nil, content)
X.view, X.body = view, body

local blocks = {}
X.blocks = blocks
local function NewLine(block)
  local line = CreateFrame("Frame", nil, block)
  line.mark = line:CreateTexture(nil, "ARTWORK")
  line.text = line:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  line.barBg = line:CreateTexture(nil, "ARTWORK")
  line.bar = line:CreateTexture(nil, "OVERLAY")
  line.count = line:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  return line
end
local function GetBlock(i)
  if blocks[i] then return blocks[i] end
  local b = CreateFrame("Frame", nil, body)
  b.sep = b:CreateTexture(nil, "ARTWORK")
  b.sep:SetColorTexture(1, 1, 1, 0.07)
  b.badge = Badge(b, 34)
  b.num = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  b.title = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  b.title:SetTextColor(C.text[1], C.text[2], C.text[3])
  b.lines = { NewLine(b), NewLine(b) }
  blocks[i] = b
  return b
end

local bar = CreateFrame("Frame", nil, f)
bar:SetHeight(38)
bar:SetPoint("BOTTOMLEFT", 1, 1)
bar:SetPoint("BOTTOMRIGHT", -1, 1)
bar.bg = bar:CreateTexture(nil, "BACKGROUND")
bar.bg:SetAllPoints()
bar.bg:SetColorTexture(1, 1, 1, 0.04)
bar.line = bar:CreateTexture(nil, "ARTWORK")
bar.line:SetPoint("TOPLEFT")
bar.line:SetPoint("TOPRIGHT")
bar.line:SetHeight(1)
bar.line:SetColorTexture(1, 1, 1, 0.07)
local xp = CreateFrame("Frame", nil, bar)
xp.bg = xp:CreateTexture(nil, "ARTWORK")
xp.rested = xp:CreateTexture(nil, "ARTWORK")
xp.rested:SetColorTexture(C.blue[1], C.blue[2], C.blue[3], 0.35)
xp.fill = xp:CreateTexture(nil, "ARTWORK")
bar.prev = IconButton(bar, "prev")
bar.next = IconButton(bar, "next")
bar.find = IconButton(bar, "target", "Find my place")
bar.stop = IconButton(bar, "prev", "Back to guide")
bar.stop:Hide()
bar.resume = IconButton(bar, "next", "Back to step")
bar.resume:Hide()
bar.collapse = IconButton(bar, "up")
bar.settings = IconButton(bar, "gear")
bar.menu = IconButton(bar, "more")
bar.menu:SetScript("OnClick", function() X.OpenMenu() end)
X.bar, X.xp = bar, xp

local more = CreateFrame("Button", nil, f)
more.bg = more:CreateTexture(nil, "BACKGROUND")
more.label = more:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
more.back = more:CreateTexture(nil, "BACKGROUND")
function more:SetLabel(t) self.label:SetText(t) end
more:SetLabel("More")
more:Hide()
X.more = more

local mini = CreateFrame("Frame", nil, f)
mini.badge = Badge(mini, 24)
mini.text = mini:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
mini.expand = IconButton(mini, "down")
mini.count = mini:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
mini:Hide()
X.mini = mini

X.guideName = "16-19 Darkshore"
X.position, X.total = 10, 91

function X.Refresh()
  bump("Refresh")
  f:Show()
  if not X.sizing then f:SetSize(X.width, X.height) end -- "the size is yours"
  -- LayoutHeader
  local zone, range = X.guideName:match("^%d+%-%d+%s+(.+)$"), X.guideName:match("^(%d+%-%d+)")
  header.zone:SetText((zone or X.guideName):upper())
  header.range:SetText(range and ("Levels " .. range:gsub("%-", "–")) or "")
  header.step:SetText(("Step %d / %d"):format(X.position, X.total))
  header:SetHeight(HEADER_H)
  X.headerHeightSeen = header:GetHeight()
  progress:SetWidth(100)
  -- LayoutBlocks
  local y = 0
  for i = 1, 2 do
    local b = GetBlock(i)
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
    b:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, -y)
    b.title:SetText("Kill Moonstalker Sires")
    b.title:SetTextColor(C.text[1], C.text[2], C.text[3])
    b.lines[1].text:SetText("Moonstalker Sire slain: 0/6")
    b:SetHeight(80)
    b:Show()
    y = y + 80
  end
  view:SetHeight(300 - (1 + header:GetHeight() + 2) - 39)
  view:SetVerticalScroll(0)
end

-- Style.Repaint (after a skin or Background change)
function X.Repaint()
  bump("Repaint")
  for _, bf in ipairs(backdrops) do
    bf:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], C.bg[4])
    bf:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], C.border[4])
  end
  header.bg:SetColorTexture(1, 1, 1, 0.03)
  bar.line:SetColorTexture(1, 1, 1, 0.07)
  progress:SetColorTexture(C.blue[1], C.blue[2], C.blue[3], 1)
  for _, b in ipairs(blocks) do b.title:SetTextColor(C.text[1], C.text[2], C.text[3]) end
end

-- ---------------------------------------------------------------------------
-- The step list (UI/StepNavigator.lua), built on its first open
-- ---------------------------------------------------------------------------

local HEAD_H = 50
local function BuildSteps()
  local s = CreateFrame("Frame", "OpenXPSteps", UIParent, "BackdropTemplate")
  s:SetSize(330, 480)
  Backdrop(s)
  s.head = s:CreateTexture(nil, "BACKGROUND", nil, 1)
  s.head:SetPoint("TOPLEFT", 1, -1)
  s.head:SetPoint("TOPRIGHT", -1, -1)
  s.head:SetHeight(HEAD_H - 1)
  s.accentLine = s:CreateTexture(nil, "ARTWORK")
  s.back = IconButton(s, "prev")
  s.back:SetSize(30, 30)
  s.back:SetPoint("LEFT", s, "TOPLEFT", 8, -HEAD_H / 2)
  s.title = s:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  s.title:SetPoint("TOPLEFT", s.back, "TOPRIGHT", 6, -1)
  s.title:SetText("Steps")
  s.guide = s:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  s.guide:SetPoint("TOPLEFT", s.title, "BOTTOMLEFT", 0, -3)
  s.close = IconButton(s, "cross")
  s.close:SetSize(30, 30)
  s.close:SetPoint("RIGHT", s, "TOPRIGHT", -8, -HEAD_H / 2)
  s.headLine = s:CreateTexture(nil, "ARTWORK")
  s.headLine:SetPoint("TOPLEFT", 1, -HEAD_H)
  s.headLine:SetPoint("TOPRIGHT", -1, -HEAD_H)
  s.headLine:SetHeight(1)
  s.count = s:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  s.stats = s:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  s.here = s:CreateTexture(nil, "OVERLAY")
  s.tabBar = CreateFrame("Frame", nil, s)
  s.underline = s.tabBar:CreateTexture(nil, "OVERLAY")
  s.list = CreateFrame("Frame", nil, s)
  s.bar = CreateFrame("Button", nil, s)
  s.foot = s:CreateTexture(nil, "BACKGROUND", nil, 1)
  -- rows (NewRow): 1 = the "YOU ARE HERE" heading, 2 = the current step
  s.rows = {}
  for i = 1, 3 do
    local row = CreateFrame("Button", nil, s.list)
    row.hl = row:CreateTexture(nil, "BACKGROUND")
    row.accent = row:CreateTexture(nil, "BORDER")
    row.glow = row:CreateTexture(nil, "ARTWORK")
    row.node = row:CreateTexture(nil, "ARTWORK")
    row.pill = CreateFrame("Frame", nil, row)
    row.pill.bg = row.pill:CreateTexture(nil, "BACKGROUND")
    row.pill.text = row.pill:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.header = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    s.rows[i] = row
  end
  s:Hide()
  return s
end

-- Nav.Paint: every row painted in OpenXP's colours, then the scrollbar.
function X.PaintSteps()
  local s = rawget(_G, "OpenXPSteps")
  local blue = C.blue
  local h, cur, todo = s.rows[1], s.rows[2], s.rows[3]
  h.status = nil
  h.header:SetText("YOU ARE HERE")
  h.header:SetTextColor(blue[1], blue[2], blue[3])
  cur.status = "current"
  cur.node:SetVertexColor(blue[1], blue[2], blue[3], 1)
  cur.glow:SetVertexColor(blue[1], blue[2], blue[3], 0.6)
  cur.accent:SetColorTexture(blue[1], blue[2], blue[3], 1)
  cur.pill.text:SetText("YOU'RE HERE")
  cur.pill.text:SetTextColor(blue[1], blue[2], blue[3], 1)
  cur.pill.bg:SetVertexColor(blue[1], blue[2], blue[3], 0.16)
  todo.status = "todo"
  todo.header:SetText("COMING UP")
  todo.header:SetTextColor(C.faint[1], C.faint[2], C.faint[3])
  s.bar:Hide()
end

function X.OpenSteps()
  bump("OpenSteps")
  local s = rawget(_G, "OpenXPSteps") or BuildSteps()
  s:Show()
  s.guide:SetText(X.guideName) -- Nav.Refresh
  X.PaintSteps()
end

function X.ToggleSteps()
  local s = rawget(_G, "OpenXPSteps")
  if s and s:IsShown() then s:Hide() else X.OpenSteps() end
end

-- ---------------------------------------------------------------------------
-- Quest Targets (UI/ActionButtons.lua)
-- ---------------------------------------------------------------------------

local ROW_H = 26
local box = CreateFrame("Frame", "OpenXPTargets", UIParent, "BackdropTemplate")
box:SetSize(190, 20 + ROW_H)
Backdrop(box)
box.title = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
box.title:SetPoint("TOPLEFT", 8, -5)
box.key = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
box.key:SetPoint("TOPRIGHT", -8, -5)
box:Hide()

local rows = {}
local function Row(i)
  if rows[i] then return rows[i] end
  local name = i == 1 and "OpenXPTargetButton" or ("OpenXPTargetRow" .. i)
  local b = CreateFrame("Button", name, box, "SecureActionButtonTemplate")
  b:SetHeight(ROW_H)
  b:SetPoint("TOPLEFT", box, "TOPLEFT", 1, -18 - (i - 1) * ROW_H)
  b:SetPoint("TOPRIGHT", box, "TOPRIGHT", -1, -18 - (i - 1) * ROW_H)
  b.hl = b:CreateTexture(nil, "BACKGROUND")
  b.hl:SetAllPoints()
  b.bar = b:CreateTexture(nil, "ARTWORK")
  b.bar:SetPoint("TOPLEFT", 0, -4)
  b.bar:SetPoint("BOTTOMLEFT", 0, 4)
  b.bar:SetWidth(2)
  b.slot = CreateFrame("Frame", nil, b)
  b.slot:SetSize(20, 20)
  b.slot:SetPoint("LEFT", 8, 0)
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  b:Hide()
  rows[i] = b
  return b
end
Row(1)

-- The quest item button (OpenXPItemButton): a square with the skin's
-- panel and an accent edge.
local item = CreateFrame("Button", "OpenXPItemButton", UIParent, "SecureActionButtonTemplate,BackdropTemplate")
item:SetSize(36, 36)
Backdrop(item)
item.icon = item:CreateTexture(nil, "ARTWORK")
item.hotkey = item:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
item.count = item:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
item:SetScript("OnDragStart", function() bump("item drag") end)
box:SetScript("OnDragStart", function() bump("box drag") end)

-- Buttons.Place: left of the card, against UIParent
function X.Place()
  bump("Place")
  item:ClearAllPoints()
  item:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", 592, 700)
  box:ClearAllPoints()
  box:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", 592, 648)
end
X.Place()

function X.RefreshTargets(n)
  bump("RefreshTargets")
  if InCombatLockdown() then return end -- Buttons.Refresh waits for combat to end
  for i = 1, 5 do
    local r = (i <= n) and Row(i) or rows[i]
    if r then
      if i <= n then r:Show() else r:Hide() end
    end
  end
  box.title:SetText("TARGETS")
  box.key:SetText("F")
  box:SetHeight(20 + math.max(1, n) * ROW_H)
  if n > 0 then box:Show() else box:Hide() end
end

-- ---------------------------------------------------------------------------
-- The menu (UI/GuidePicker.lua)
-- ---------------------------------------------------------------------------

function X.OpenMenu()
  local m = rawget(_G, "OpenXPMenu")
  if not m then
    m = CreateFrame("Frame", "OpenXPMenu", UIParent, "BackdropTemplate")
    Backdrop(m)
    m:Hide()
  end
  m:Show()
end

-- OpenXP's PLAYER_LOGIN: the card is laid out once.
HARNESS.OnLogin = HARNESS.OnLogin or {}
X.Refresh()
X.RefreshTargets(2)
