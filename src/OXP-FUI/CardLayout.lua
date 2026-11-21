-- OXP-FUI · CardLayout: the guide card's step blocks and its height.
--
-- Layout exceptions 8 and 9 (Core.lua). Both run at the end of every card
-- skin pass, i.e. after every OpenXP card.Refresh, on the real frames.
--
-- 9. Step blocks (the /oxpfui mock, built into the card):
--    * OpenXP's 34px step-type badge and the "#61" under it give way to a
--      14px icon in front of the title (the badge's own icon or "!"/"?"
--      glyph, in its kind colour); title, objectives and tips reflow into
--      the width that frees up.
--    * Objectives line up under the title; tips (OpenXP's plain lines) use
--      the smaller counter size.
--    * An "Along the Way" step gets a section heading (the tracker's fading
--      shade) with its step number on the right, instead of the inline
--      "Along the Way:" prefix.
--    * OpenXP's faint white line between steps becomes a faint bronze one.
--    Blocks are re-stacked in OpenXP's body with their new heights.
--
-- 8. Card height (fit): the card is never taller than the room it has:
--    docked under FlareUI's tracker, between the tracker's bottom (the dock
--    gap) and the screen's bottom (the same gap); otherwise between its own
--    top and the screen's bottom. OpenXP makes the card as tall as its
--    content on every refresh (OpenXPCard.lua: max(content, saved height)),
--    and the game then pushes a too-tall card up to keep it on screen - over
--    the tracker. A height you drag the card to is its maximum, as FlareUI's
--    tracker's max height: shorter content shrinks the card to fit. When the card is shorter than its content,
--    the steps scroll inside it (the header, Up Next and the toolbar stay):
--    OpenXP's body moves into an OXP-FUI scroll frame, and Up Next sits
--    above the toolbar. The mouse wheel scrolls the steps; at the top, up
--    opens OpenXP's earlier-steps history as before, and with the history
--    open, down closes it first.

local ADDON_NAME, OXPFUI = ...

local theme = OXPFUI.theme
local C = theme.C

local CardLayout = {}
OXPFUI.CardLayout = CardLayout

local PAD, ICON, ICON_GAP = 14, 14, 6
local MIN_H = 160          -- header + one step line + Up Next + toolbar
local SCROLL_STEP = 24

local function R(x) return theme.RealFrame(x) end

local function shown(x)
  local f = R(x)
  return f ~= nil and f.IsShown ~= nil and f:IsShown()
end

-- ---------------------------------------------------------------------------
-- 9. Step blocks
-- ---------------------------------------------------------------------------

-- The block's small kind icon, copied from OpenXP's badge every pass.
local function kindIcon(b)
  local holder = b.oxpfuiIcon
  if not holder then
    holder = CreateFrame("Frame", nil, b)
    holder:SetSize(ICON, ICON)
    if holder.EnableMouse then holder:EnableMouse(false) end
    holder.tex = holder:CreateTexture(nil, "ARTWORK")
    holder.tex:SetAllPoints(holder)
    holder.glyph = holder:CreateFontString(nil, "OVERLAY")
    theme.ApplyText(holder.glyph, "title", "TITLE")
    holder.glyph:SetPoint("CENTER", holder, "CENTER", 0, 0)
    b.oxpfuiIcon = holder
  end
  local badge = R(b.badge)
  local r, g, bl = 1, 1, 1
  if badge and badge.ring and badge.ring.GetVertexColor then
    local ok, rr, gg, bb = pcall(badge.ring.GetVertexColor, badge.ring)
    if ok and rr then r, g, bl = rr, gg, bb end
  end
  local glyph = badge and badge.glyph
  local glyphText = glyph and glyph.GetText and glyph:GetText()
  local useGlyph = glyph and glyph.IsShown and glyph:IsShown()
    and type(glyphText) == "string" and glyphText ~= ""
    and not (badge.icon and badge.icon.IsShown and badge.icon:IsShown())
  if useGlyph then
    holder.tex:Hide()
    theme.ApplyFontString(holder.glyph, "title")
    holder.glyph:SetText(glyphText)
    holder.glyph:SetTextColor(r, g, bl, 1)
    holder.glyph:Show()
  else
    holder.glyph:Hide()
    local path = badge and badge.icon and badge.icon.GetTexture and badge.icon:GetTexture()
    if path then holder.tex:SetTexture(path) end
    holder.tex:SetVertexColor(r, g, bl, 1)
    holder.tex:Show()
  end
  if badge and badge.Hide then badge:Hide() end
  return holder
end

-- "Along the Way" steps: OpenXP prefixes the title with
-- "|cFF9EA3B3ALONG THE WAY:|r ". The prefix becomes a heading; the title
-- keeps the rest. Re-read whenever OpenXP sets the title again.
local SIDE = "^|c[Ff][Ff]9[Ee][Aa]3[Bb]3([^|]-):|r%s*(.*)$"
local function sideHeading(b)
  local title = R(b.title)
  if not (title and title.GetText) then return nil end
  local text = title:GetText()
  if text ~= b.oxpfuiTitleSet then
    local label, rest = nil, nil
    if type(text) == "string" then label, rest = text:match(SIDE) end
    if label then
      b.oxpfuiSideLabel = theme.TitleCase(label)
      title:SetText(rest)
      b.oxpfuiTitleSet = rest
    else
      b.oxpfuiSideLabel = nil
      b.oxpfuiTitleSet = text
    end
  end
  return b.oxpfuiSideLabel
end

local function headingFor(b, label)
  local fs = b.oxpfuiHeading
  if not fs then
    fs = b:CreateFontString(nil, "OVERLAY")
    theme.ApplyText(fs, "title", "ZONE")
    b.oxpfuiHeading = fs
    b.oxpfuiHeadNum = b:CreateFontString(nil, "OVERLAY")
    theme.ApplyText(b.oxpfuiHeadNum, "counter", "DIM")
  end
  theme.ApplyText(fs, "title", "ZONE")
  theme.ApplyText(b.oxpfuiHeadNum, "counter", "DIM")
  if label then
    fs:SetText(label)
    fs:Show()
    local num = R(b.num)
    b.oxpfuiHeadNum:SetText(num and num.GetText and num:GetText() or "")
    b.oxpfuiHeadNum:Show()
  else
    fs:Hide()
    b.oxpfuiHeadNum:Hide()
  end
  return fs
end

-- Lay one block out; returns its height.
local function layoutBlock(b, width)
  local X0 = PAD + ICON + ICON_GAP
  local TW = math.max(60, width - X0 - PAD)
  local y = 10

  local label = sideHeading(b)
  local heading = headingFor(b, label)
  if label then
    heading:ClearAllPoints()
    heading:SetPoint("TOPLEFT", b, "TOPLEFT", PAD, -y)
    b.oxpfuiHeadNum:ClearAllPoints()
    b.oxpfuiHeadNum:SetPoint("TOPRIGHT", b, "TOPRIGHT", -PAD, -y - 1)
    y = y + (heading:GetStringHeight() or 13) + 8
  end
  theme.ApplySectionHeading(b, heading, "oxpfuiAlong")

  local num = R(b.num)
  if num and num.Hide then num:Hide() end

  local icon = kindIcon(b)
  icon:ClearAllPoints()
  icon:SetPoint("TOPLEFT", b, "TOPLEFT", PAD, -(y + 1))

  local title = R(b.title)
  if title then
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", b, "TOPLEFT", X0, -y)
    title:SetWidth(TW)
    y = y + (title:GetStringHeight() or 14) + 7
  end

  for _, raw in ipairs(b.lines or {}) do
    local line = R(raw)
    if line and line.IsShown and line:IsShown() then
      local plain = not (line.mark and line.mark.IsShown and line.mark:IsShown())
      line:ClearAllPoints()
      line:SetPoint("TOPLEFT", b, "TOPLEFT", X0, -y)
      line:SetPoint("RIGHT", b, "RIGHT", -PAD, 0)
      local text = line.text
      local h = 12
      if text then
        if plain then theme.ApplyFontString(text, "counter") end
        text:SetWidth(TW - (plain and 0 or 20))
        h = text:GetStringHeight() or 12
      end
      if line.barBg and line.barBg.IsShown and line.barBg:IsShown() then h = h + 12 end
      line:SetHeight(h + 2)
      y = y + h + (plain and 4 or 7)
    end
  end

  local warn = R(b.warn)
  if warn and warn.IsShown and warn:IsShown() then
    warn:ClearAllPoints()
    warn:SetPoint("TOPLEFT", b, "TOPLEFT", X0, -y)
    warn:SetPoint("RIGHT", b, "RIGHT", -PAD, 0)
    y = y + (warn:GetHeight() or 0) + 8
  end

  -- OpenXP's faint white line between steps: a faint bronze hairline.
  local sep = R(b.sep)
  if sep and sep.SetColorTexture then
    local c = C.ACCENT
    sep:SetColorTexture(c[1], c[2], c[3], 0.25)
  end

  local height = math.max(y + 4, ICON + 20)
  b:SetHeight(height)
  return height
end

-- Re-stack the shown blocks in OpenXP's body with their new heights.
-- Returns the body, its height.
function CardLayout.Blocks(cardModule, rf)
  local blocks = cardModule and cardModule.blocksForTest
  if type(blocks) ~= "table" then return nil, 0 end
  local body, y = nil, 0
  for _, raw in ipairs(blocks) do
    local b = R(raw)
    if b and b.IsShown and b:IsShown() and b.SetPoint then
      body = body or (b.GetParent and b:GetParent())
      local width = b.GetWidth and b:GetWidth() or 0
      if not width or width <= 0 then width = (rf:GetWidth() or 300) - 2 end
      local h = layoutBlock(b, width)
      if body then
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
        b:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, -y)
      end
      y = y + h
    end
  end
  if body and body.SetHeight then body:SetHeight(math.max(y, 1)) end
  return body, y
end

-- ---------------------------------------------------------------------------
-- 8. Card height
-- ---------------------------------------------------------------------------

-- The dock gap (Docking.lua padding), used above and below the card.
local function gap()
  local p = tonumber((OXPFUI.db or {}).attachPadding)
  if not p then p = 8 end
  return math.max(0, math.min(128, p))
end

-- Room for the card, in the card's own units: from its top (under the
-- docked tracker, one gap below it) to one gap above the screen's bottom.
local function room(rf)
  local scale = rf.GetEffectiveScale and rf:GetEffectiveScale() or 1
  if not scale or scale <= 0 then scale = 1 end
  local top
  local tracker = rawget(_G, "FlareUI_ObjectiveTracker")
  local docked = OXPFUI.Dock and OXPFUI.Dock.IsActive and OXPFUI.Dock.IsActive()
  local db = OXPFUI.db or {}
  if docked and db.attachSide ~= "top" and tracker and tracker.IsVisible and tracker:IsVisible() then
    local tb = tracker.GetBottom and tracker:GetBottom()
    local ts = tracker.GetEffectiveScale and tracker:GetEffectiveScale() or 1
    if type(tb) == "number" then top = tb * ts / scale - gap() end
  end
  if not top then top = rf.GetTop and rf:GetTop() end
  if type(top) ~= "number" then return nil end
  return top - gap()
end

local function viewport(rf)
  local v = rf.oxpfuiViewport
  if not v then
    v = CreateFrame("ScrollFrame", nil, rf)
    v.child = CreateFrame("Frame", nil, v)
    v.child:SetSize(1, 1)
    v:SetScrollChild(v.child)
    if v.EnableMouse then v:EnableMouse(false) end
    v:Hide()
    rf.oxpfuiViewport = v
  end
  return v
end

local state = setmetatable({}, { __mode = "k" }) -- rf -> { scrolling, max, y }
CardLayout.state = state

local function setScroll(rf, y)
  local s = state[rf]
  local v = rf.oxpfuiViewport
  if not (s and v) then return end
  s.y = math.max(0, math.min(s.max or 0, y))
  v:SetVerticalScroll(s.y)
  theme.ApplyScrollBar(v, { top = 2, bottom = 2, right = 2, state = function()
    if (s.max or 0) <= 0 then return 0, 1, false end
    return s.y / s.max, (s.view or 1) / ((s.view or 1) + s.max), true
  end })
end

-- Option A on the wheel: the steps first, then OpenXP's history.
local function hookWheel(rf, cardModule)
  if rf.oxpfuiWheel then return end
  local orig = rf.GetScript and rf:GetScript("OnMouseWheel")
  rf.oxpfuiWheel = true
  rf:SetScript("OnMouseWheel", function(self, delta, ...)
    local s = state[self]
    if s and s.scrolling then
      if delta > 0 and (s.y or 0) > 0 then
        setScroll(self, (s.y or 0) - SCROLL_STEP)
        return
      end
      if delta < 0 and (cardModule.histOffset or 0) <= 0 and (s.y or 0) < (s.max or 0) then
        setScroll(self, (s.y or 0) + SCROLL_STEP)
        return
      end
    end
    if orig then return orig(self, delta, ...) end
  end)
end

local function exitScroll(rf, body, anchorTop, upNext)
  local s = state[rf]
  if not (s and s.scrolling) then return end
  s.scrolling = false
  if body and body.SetParent then
    body:SetParent(rf)
    body:ClearAllPoints()
    body:SetPoint("TOPLEFT", anchorTop, "BOTTOMLEFT", 0, 0)
    body:SetPoint("TOPRIGHT", anchorTop, "BOTTOMRIGHT", 0, 0)
  end
  if upNext then
    upNext:ClearAllPoints()
    upNext:SetPoint("TOPLEFT", body, "BOTTOMLEFT", 0, -4)
    upNext:SetPoint("TOPRIGHT", body, "BOTTOMRIGHT", 0, -4)
  end
  if rf.oxpfuiViewport then rf.oxpfuiViewport:Hide() end
end

-- Fit the card into its room; scroll the steps when they don't fit.
function CardLayout.Fit(p)
  local rf, cardModule = p.rf, p.card
  if not (rf and cardModule) or cardModule.sizing then return end
  state[rf] = state[rf] or { scrolling = false, y = 0 }
  local s = state[rf]
  local body, bodyH = p.body, p.bodyH or 0
  local hist = R(cardModule.hist)
  local histShown = hist and hist.IsShown and hist:IsShown()
  local anchorTop = histShown and hist or R(p.track)
  local upNext = R(p.upNext)
  local bar = R(p.bar)
  if not (body and anchorTop and bar) then return end
  local histH = histShown and (hist:GetHeight() or 0) or 0
  local upH = (upNext and upNext.IsShown and upNext:IsShown()) and (upNext:GetHeight() or 0) or 0
  local content = 1 + 28 + 2 + histH + bodyH + 4 + upH + 38 + 1

  -- As FlareUI's tracker: as tall as the content, up to a height you drag
  -- it to (a maximum, not a fixed size) and up to the room it has. A
  -- dragged height taller than the content left empty space above the
  -- toolbar.
  local want = content
  if cardModule.height and cardModule.height < want then want = cardModule.height end
  local avail = room(rf)
  if not avail and not s.scrolling then return end -- not placed yet
  local h = want
  if avail then h = math.min(h, avail) end
  h = math.max(MIN_H, math.floor(h + 0.5))
  local cur = rf:GetHeight()
  if not cur or math.abs(cur - h) >= 0.5 then rf:SetHeight(h) end

  local view = h - (1 + 28 + 2 + histH + 4 + upH + 38 + 1)
  if bodyH <= view + 0.5 then
    exitScroll(rf, body, anchorTop, upNext)
    return
  end

  -- Scroll: the body into the viewport, Up Next above the toolbar.
  local v = viewport(rf)
  if upNext then
    upNext:ClearAllPoints()
    upNext:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 0)
    upNext:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 0)
  end
  v:ClearAllPoints()
  v:SetPoint("TOPLEFT", anchorTop, "BOTTOMLEFT", 0, 0)
  v:SetPoint("TOPRIGHT", anchorTop, "BOTTOMRIGHT", 0, 0)
  if upNext and upH > 0 then
    v:SetPoint("BOTTOMLEFT", upNext, "TOPLEFT", 0, 4)
    v:SetPoint("BOTTOMRIGHT", upNext, "TOPRIGHT", 0, 4)
  else
    v:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 4)
    v:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 4)
  end
  v:Show()
  local width = (rf:GetWidth() or 300) - 2
  v.child:SetSize(width, math.max(bodyH, 1))
  if body:GetParent() ~= v.child then body:SetParent(v.child) end
  body:ClearAllPoints()
  body:SetPoint("TOPLEFT", v.child, "TOPLEFT", 0, 0)
  body:SetWidth(width)
  s.scrolling = true
  s.view = math.max(1, view)
  s.max = math.max(0, bodyH - view)
  hookWheel(rf, cardModule)
  setScroll(rf, s.y or 0)
end

local last = nil

-- One pass: blocks first (their heights feed the fit).
function CardLayout.Apply(p)
  local rf, cardModule = p.rf, p.card
  if not (rf and cardModule) then return end
  local body, bodyH = CardLayout.Blocks(cardModule, rf)
  p.body, p.bodyH = body, bodyH
  last = p
  CardLayout.Fit(p)
end

-- The room changed (the tracker grew or shrank): fit again with the last
-- pass's blocks. Out of combat the card is an ordinary frame, in combat too
-- (OpenXP resizes it itself while fighting), so no deferral.
function CardLayout.Refit()
  if last then pcall(CardLayout.Fit, last) end
end
