-- OXP-FUI · OpenXP2: the FlareUI look for OpenXP 2.x.
--
-- OpenXP 2.0 is a rewrite that keeps its addon table private (Core/Init.lua:
-- modules talk "never through globals"), so nothing here can hook its
-- functions the way the 1.x skins hook card.Refresh. What other addons can
-- reach are its named frames and the fields OpenXP hangs on them:
--   OpenXPCard     the guide card (UI/Card.lua): header {bg, zone, range,
--                  step, nav}, a ScrollFrame of step blocks, the button bar
--   OpenXPSteps    the step list (UI/StepNavigator.lua), built on first open
--   OpenXPTargets  the Quest Targets box (UI/ActionButtons.lua)
--   OpenXPMenu, OpenXPDropdownList, OpenXPConfirm   pop-ups (built lazily)
-- Re-apply points are post-hooks on frame methods OpenXP calls at the end
-- of its own passes:
--   view:SetVerticalScroll   last thing Card.Refresh does (and the wheel)
--   header:SetHeight         LayoutHeader, after it set the header's texts
--   frame:SetBackdropColor   Style.PaintBackdrop: a skin or opacity change
--                            repaints everything in OpenXP's colours
--   box:SetHeight            Buttons.Refresh, after the rows are set
--   steps.guide:SetText      Nav.Refresh
-- Layout exceptions for 2.x (Core.lua, README): 11 card header on the
-- title strip, 12 step list header, 13 Quest Targets rows under the strip.
--
-- Everything else OXP-FUI does for 1.x (the mock step layout, card height
-- fitting, Quest Targets pin and fold, width matching) waits for a public
-- OpenXP API: OpenXP 2.0 keeps the card's size and scroll state private and
-- puts its own size back whenever another addon changes it.

local ADDON_NAME, OXPFUI = ...

local theme = OXPFUI.theme
local C = theme.C
local A = theme.ART

local V2 = {}
OXPFUI.OpenXP2 = V2

local function R(x) return theme.RealFrame(x) end
local function inCombat() return InCombatLockdown and InCombatLockdown() end

local function hex(c)
  return string.format("|cFF%02X%02X%02X", math.floor(c[1] * 255 + 0.5),
    math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

-- "16-19 Darkshore" / "DARKSHORE" + "Levels 16–19" -> "Darkshore (16–19)".
local RANGE = "(%d+)%s*[%-–]+%s*(%d+)"
function V2.FormatTitle(name, rangeText)
  if type(name) ~= "string" then return name end
  local plain = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  local lo, hi, zone
  lo, hi, zone = plain:match("^" .. RANGE .. "%s+(.+)$")
  if not zone then
    zone = plain
    if type(rangeText) == "string" then lo, hi = rangeText:match(RANGE) end
  end
  zone = theme.TitleCase(zone)
  if lo then return zone .. " " .. hex(C.DIM) .. "(" .. lo .. "–" .. hi .. ")|r" end
  return zone
end

-- ---------------------------------------------------------------------------
-- Finding OpenXP's parts (fields on its frames, never globals)
-- ---------------------------------------------------------------------------

local function childWith(parent, ...)
  if not (parent and parent.GetChildren) then return nil end
  local keys = { ... }
  for _, c in ipairs({ parent:GetChildren() }) do
    local ok = true
    for _, k in ipairs(keys) do
      if c[k] == nil then ok = false break end
    end
    if ok then return c end
  end
  return nil
end

local function scrollChild(parent)
  for _, c in ipairs({ parent:GetChildren() }) do
    if c.GetObjectType and c:GetObjectType() == "ScrollFrame" then return c end
  end
  return nil
end

-- The textures OpenXP hangs off the header's bottom: its progress track,
-- and the fill that grows along it.
local function progressParts(f, header)
  local track, fill
  for _, r in ipairs({ f:GetRegions() }) do
    if r.GetPoint and r.GetNumPoints and r:GetNumPoints() > 0 then
      local _, rel = r:GetPoint(1)
      if rel == header and not track then track = r end
    end
  end
  if track then
    for _, r in ipairs({ f:GetRegions() }) do
      if r ~= track and r.GetNumPoints and r:GetNumPoints() > 0 then
        local _, rel = r:GetPoint(1)
        if rel == track then fill = r end
      end
    end
  end
  return track, fill
end

function V2.Card()
  local f = rawget(_G, "OpenXPCard")
  if not f then return nil end
  local p = f.oxpfuiParts
  if p then return p end
  local header = childWith(f, "zone", "step", "nav")
  local view = scrollChild(f)
  if not (header and view) then return nil end
  local content = view.GetScrollChild and view:GetScrollChild()
  local body = content and ({ content:GetChildren() })[1]
  local track, fill = progressParts(f, header)
  p = {
    frame = f, header = header, view = view, content = content, body = body,
    track = track, fill = fill,
    bar = childWith(f, "prev", "next", "menu"),
    mini = childWith(f, "badge", "expand"),
    more = childWith(f, "label", "back", "SetLabel"),
  }
  p.xp = p.bar and childWith(p.bar, "fill", "rested")
  f.oxpfuiParts = p
  return p
end

-- ---------------------------------------------------------------------------
-- Windows: FlareUI's backdrop, kept through OpenXP's repaints
-- ---------------------------------------------------------------------------

local painting = false

-- Draw the window in the FlareUI look, and keep it: OpenXP's
-- Style.PaintBackdrop sets its own colours on the frame on every skin or
-- opacity change; right after it, the FlareUI backdrop goes back on, and a
-- full pass follows a moment later for the rest of what OpenXP repainted.
local function ownWindow(f, opts)
  painting = true
  local ok, drawn = pcall(theme.ApplyWindow, f, opts)
  painting = false
  if not f.oxpfuiOwned then
    f.oxpfuiOwned = opts
    local function back()
      if painting then return end
      painting = true
      pcall(theme.ApplyWindow, f, f.oxpfuiOwned)
      painting = false
      V2.Soon("OpenXP repaint")
    end
    if f.SetBackdropColor then pcall(hooksecurefunc, f, "SetBackdropColor", back) end
    if f.SetBackdropBorderColor then pcall(hooksecurefunc, f, "SetBackdropBorderColor", back) end
  else
    f.oxpfuiOwned = opts
  end
  return ok and drawn
end

-- One full pass after OpenXP's current one (C_Timer.After(0) = next frame).
local soon = false
function V2.Soon(reason)
  if soon then return end
  soon = true
  local function go()
    soon = false
    OXPFUI.Reapply(reason)
  end
  if C_Timer and C_Timer.After then C_Timer.After(0, go) else go() end
end

-- An OpenXP icon button (Style.IconButton) as a FlareUI toolbar box, its
-- icon gold, lit under the mouse (OpenXP tints it white/grey on hover).
local function toolbarButton(b)
  b = R(b)
  if not b then return end
  local wide = b.label ~= nil and b.label.IsShown and b.label:IsShown()
  theme.ApplyToolbarButton(b, { wide = wide })
  if b.label then theme.ApplyText(b.label, "objective", "OBJECTIVE") end
  if not b.oxpfuiTint then
    b.oxpfuiTint = true
    local function tint(lit)
      local c = lit and theme.C.TITLE_FOCUS or theme.C.TITLE
      if b.icon then b.icon:SetVertexColor(c[1], c[2], c[3], 1) end
    end
    b:HookScript("OnEnter", function() tint(true) end)
    b:HookScript("OnLeave", function() tint(false) end)
  end
end

-- Blizzard's red close button art on an OpenXP close button, on the right
-- end of the window's title strip (FlareUI has no close glyph of its own).
local function redClose(b, band)
  b = R(b)
  if not (b and b.CreateTexture) then return end
  local art = b.oxpfuiRed
  if art == nil then
    art = b:CreateTexture(nil, "ARTWORK", nil, 2)
    if art.SetAtlas and art:SetAtlas("RedButton-Exit") then
      b.oxpfuiRed = art
      b:HookScript("OnMouseDown", function() art:SetAtlas("RedButton-exit-pressed") end)
      b:HookScript("OnMouseUp", function() art:SetAtlas("RedButton-Exit") end)
      b:HookScript("OnEnter", function(self) if self.bg then self.bg:SetAlpha(0) end end)
    else
      art:Hide()
      b.oxpfuiRed = false
      art = false
    end
  end
  if not art then return end
  art:ClearAllPoints()
  art:SetAllPoints(b)
  if b.icon then b.icon:SetAlpha(0) end
  if b.bg then b.bg:SetAlpha(0) end
  if band then
    b:ClearAllPoints()
    b:SetPoint("RIGHT", band, "RIGHT", 0, 0)
    b:SetSize(24, 24)
  end
end

-- ---------------------------------------------------------------------------
-- The card
-- ---------------------------------------------------------------------------

local HEADER_H = A.HEADER -- the strip's height: the header is one row on it

-- Layout exception 11: OpenXP's two-row header (ZONE, then "Levels 16-19 ...
-- Step 16 / 52") becomes one row on the title strip, as on the 1.x card:
-- "Darkshore (16–19)" on the left, "Step 16 / 52" and its list icon on the
-- right. Runs right after OpenXP's LayoutHeader (its header:SetHeight), so
-- the card lays its steps out under the new header height.
local inHeader = false
local function layoutHeader(p)
  local f, h = p.frame, p.header
  if inHeader then return end
  inHeader = true
  if math.abs((h:GetHeight() or 0) - HEADER_H) >= 0.5 then h:SetHeight(HEADER_H) end
  inHeader = false
  local band = f.oxpfuiBands and f.oxpfuiBands.title
  local inset = A.PAD - A.HEADER_INSET
  local zone, range, step, nav = h.zone, h.range, h.step, h.nav
  local current = zone:GetText()
  if current ~= zone.oxpfuiShown then
    local shown = V2.FormatTitle(current, range and range:GetText())
    zone:SetText(shown)
    zone.oxpfuiShown = shown
  end
  if range then range:SetAlpha(0) end
  if h.bg then h.bg:SetAlpha(0) end
  theme.ApplyText(zone, "header", "TITLE")
  if zone.SetWordWrap then zone:SetWordWrap(false) end
  theme.ApplyFontString(step, "counter")
  if band then
    step:ClearAllPoints()
    step:SetPoint("RIGHT", band, "RIGHT", -inset, 0)
    if nav then
      nav:ClearAllPoints()
      nav:SetPoint("RIGHT", band, "RIGHT", 0, 0)
    end
    zone:ClearAllPoints()
    zone:SetPoint("LEFT", band, "LEFT", inset, 0)
    local icon = nav and nav.icon
    zone:SetPoint("RIGHT", icon or step, "LEFT", -8, 0)
  end
end

local function paintNav(p)
  local nav, step = p.header.nav, p.header.step
  local c = (nav and nav.lit) and C.TITLE_FOCUS or C.DIM
  step:SetTextColor(c[1], c[2], c[3], 1)
  if nav and nav.icon then nav.icon:SetVertexColor(c[1], c[2], c[3], 1) end
end

local function skinBlocks(p)
  local kids = p.body and { p.body:GetChildren() } or {}
  for _, b in ipairs(kids) do
    if b.title and b.sep then
      local a = C.ACCENT
      b.sep:SetColorTexture(a[1], a[2], a[3], 0.25)
      theme.ApplyTextColor(b.title, "TITLE")
      if b.num then theme.ApplyTextColor(b.num, "DIM") end
      for _, line in ipairs(b.lines or {}) do
        if line.text then theme.ApplyTextColor(line.text, "OBJECTIVE") end
        if line.count then theme.ApplyTextColor(line.count, "DIM") end
      end
    end
  end
end

-- OpenXP's "More" / "Less" (a TextButton over a solid patch in OpenXP's
-- background colour, so cut-off text doesn't show through): a FlareUI box.
local function skinMore(more)
  if not more then return end
  theme.ApplyToolbarButton(more, { wide = true })
  if more.oxpfuiBox then
    more.oxpfuiBox:ClearAllPoints()
    more.oxpfuiBox:SetAllPoints(more)
    more.oxpfuiBox:SetBackdropColor(0, 0, 0, 0.85)
  end
  if more.back then more.back:SetAlpha(0) end
  if more.label then theme.ApplyText(more.label, "counter", "TITLE") end
  if not more.oxpfuiPaint then
    more.oxpfuiPaint = true
    -- OpenXP's Paint brings its wash and colours back on every mouse move
    local function again() if more.bg then more.bg:SetAlpha(0) end
      if more.label then theme.ApplyTextColor(more.label, "TITLE") end end
    more:HookScript("OnEnter", again)
    more:HookScript("OnLeave", again)
    more:HookScript("OnMouseUp", again)
  end
end

local function skinCard(ctx)
  local p = V2.Card()
  if not p then ctx.Skip("OpenXPCard not built") return end
  local f = p.frame
  ownWindow(f, { header = p.header, headerStyle = "strip", foot = false })
  layoutHeader(p)
  paintNav(p)
  -- the progress line: gold on a faint track, under the strip
  if p.track then p.track:SetColorTexture(1, 1, 1, 0.08) end
  if p.fill then
    local c = C.TITLE
    p.fill:SetColorTexture(c[1], c[2], c[3], 1)
  end
  skinBlocks(p)
  local bar = p.bar
  if bar then
    if bar.bg then bar.bg:SetAlpha(0) end
    if bar.line then
      bar.line:SetAlpha(0)
      theme.ApplySectionRule(f, bar.line, "TOP", "toolbar", bar)
    end
    for _, k in ipairs({ "prev", "next", "find", "stop", "resume", "menu", "settings", "collapse" }) do
      if bar[k] then toolbarButton(bar[k]) end
    end
  end
  if p.xp and p.xp.rested then
    local c = C.ACCENT
    p.xp.rested:SetColorTexture(c[1], c[2], c[3], 0.35)
  end
  skinMore(p.more)
  if p.mini then
    if p.mini.text then theme.ApplyText(p.mini.text, "title", "TITLE") end
    if p.mini.count then theme.ApplyTextColor(p.mini.count, "DIM") end
    if p.mini.expand then toolbarButton(p.mini.expand) end
  end
end

-- ---------------------------------------------------------------------------
-- The step list (OpenXPSteps)
-- ---------------------------------------------------------------------------

-- Layout exception 12: the list's header is the card's title strip: the
-- guide as "Darkshore (16–19)" on it (OpenXP: "Steps" over the guide's
-- name), Blizzard's red close button on its right end; OpenXP's back
-- button (it does what close does) goes.
local function skinSteps(ctx)
  local f = rawget(_G, "OpenXPSteps")
  if not f then ctx.Skip("step list not opened yet") return end
  ownWindow(f, { role = "popup", header = f.head, headerStyle = "strip" })
  local band = f.oxpfuiBands and f.oxpfuiBands.title
  if f.head then f.head:SetAlpha(0) end
  if f.foot then f.foot:SetAlpha(0) end
  if f.accentLine then f.accentLine:SetAlpha(0) end
  if f.back then f.back:Hide() end
  if f.headLine then
    f.headLine:SetAlpha(0)
    theme.ApplySectionRule(f, f.headLine, "TOP", "stepsHead")
  end
  if f.title and band then
    local guide = f.guide and f.guide:GetText()
    f.title:SetText(V2.FormatTitle(guide or ""))
    theme.ApplyText(f.title, "header", "TITLE")
    f.title:ClearAllPoints()
    f.title:SetPoint("LEFT", band, "LEFT", A.PAD - A.HEADER_INSET, 0)
    f.title:SetPoint("RIGHT", band, "RIGHT", -30, 0)
    if f.title.SetWordWrap then f.title:SetWordWrap(false) end
    if f.guide then f.guide:SetAlpha(0) end
  end
  redClose(f.close, band)
  local a = C.ACCENT
  if f.underline then f.underline:SetColorTexture(a[1], a[2], a[3], 1) end
  if f.here then f.here:SetVertexColor(a[1], a[2], a[3], 1) end
  if f.count then theme.ApplyTextColor(f.count, "OBJECTIVE") end
  if f.stats then theme.ApplyTextColor(f.stats, "DIM") end
  if f.mine and f.mine.SetBackdrop then
    theme.ApplyToolbarButton(f.mine, { wide = true })
    if f.mine.label then theme.ApplyText(f.mine.label, "objective", "OBJECTIVE") end
  end
  if not f.oxpfuiHooked and f.guide then
    f.oxpfuiHooked = true
    pcall(hooksecurefunc, f.guide, "SetText", function() V2.Soon("step list refresh") end)
    f:HookScript("OnShow", function() OXPFUI.Reapply("step list shown") end)
  end
end

-- ---------------------------------------------------------------------------
-- Quest Targets (OpenXPTargets)
-- ---------------------------------------------------------------------------

-- Layout exception 13: the box's title is the card's title strip, so its
-- rows move SHIFT lower (OpenXP: 18px under the top) and the box grows by
-- the same. Rows are secure buttons: out of combat only, like OpenXP's own
-- Buttons.Refresh (it waits for combat to end too).
local TARGETS_SHIFT = 14
local ROW_TOP, ROW_H = 18, 26

local function targetRows(box)
  local rows = {}
  local first = rawget(_G, "OpenXPTargetButton")
  if first then rows[1] = first end
  for i = 2, 20 do
    local r = rawget(_G, "OpenXPTargetRow" .. i)
    if not r then break end
    rows[i] = r
  end
  return rows
end

local inBox = false
local function layoutTargets(box)
  if inCombat() or inBox then return end
  inBox = true
  for i, r in ipairs(targetRows(box)) do
    local y = -(ROW_TOP + TARGETS_SHIFT + (i - 1) * ROW_H)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", box, "TOPLEFT", 1, y)
    r:SetPoint("TOPRIGHT", box, "TOPRIGHT", -1, y)
  end
  -- OpenXP: 20 + rows * 26; ours: that plus the shift, whatever it was before
  local shown = 0
  for _, r in ipairs(targetRows(box)) do if r:IsShown() then shown = shown + 1 end end
  local want = 20 + math.max(1, shown) * ROW_H + TARGETS_SHIFT
  if math.abs((box:GetHeight() or 0) - want) >= 0.5 then box:SetHeight(want) end
  inBox = false
end

local function skinTargets(ctx)
  local box = rawget(_G, "OpenXPTargets")
  if not box then ctx.Skip("OpenXPTargets missing") return end
  ownWindow(box, { header = box.title, headerStyle = "strip" })
  local band = box.oxpfuiBands and box.oxpfuiBands.title
  if box.title then
    local t = box.title:GetText()
    if t ~= box.title.oxpfuiShown then
      local shown = theme.TitleCase(t)
      box.title:SetText(shown)
      box.title.oxpfuiShown = shown
    end
    theme.ApplyText(box.title, "header", "TITLE")
    if band then
      box.title:ClearAllPoints()
      box.title:SetPoint("LEFT", band, "LEFT", A.PAD - A.HEADER_INSET, 0)
    end
  end
  if box.key then
    theme.ApplyText(box.key, "counter", "DIM")
    if band then
      box.key:ClearAllPoints()
      box.key:SetPoint("RIGHT", band, "RIGHT", -(A.PAD - A.HEADER_INSET), 0)
    end
  end
  layoutTargets(box)
  if not box.oxpfuiHooked then
    box.oxpfuiHooked = true
    pcall(hooksecurefunc, box, "SetHeight", function()
      if not inBox then V2.Soon("targets refresh") end
    end)
  end
end

-- ---------------------------------------------------------------------------
-- Pop-ups: the menu, dropdown lists, the confirm dialog
-- ---------------------------------------------------------------------------

local POPUPS = { "OpenXPMenu", "OpenXPDropdownList", "OpenXPConfirm" }

local function skinPopups(ctx)
  for _, name in ipairs(POPUPS) do
    local f = rawget(_G, name)
    if f and f.SetBackdrop then
      ownWindow(f, { role = "popup" })
      if not f.oxpfuiShowHook then
        f.oxpfuiShowHook = true
        f:HookScript("OnShow", function() V2.Soon(name .. " shown") end)
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- Hooks: re-apply after OpenXP's own passes
-- ---------------------------------------------------------------------------

local hooked = false
function V2.InstallHooks()
  local p = V2.Card()
  if not p or hooked then return end
  hooked = true
  local f, h = p.frame, p.header
  pcall(hooksecurefunc, p.view, "SetVerticalScroll", function()
    if not painting then OXPFUI.Reapply("card refresh") end
  end)
  pcall(hooksecurefunc, h, "SetHeight", function()
    if not inHeader then layoutHeader(p) end
  end)
  f:HookScript("OnShow", function() OXPFUI.Reapply("card shown") end)
  if h.nav then
    h.nav:HookScript("OnEnter", function() paintNav(p) end)
    h.nav:HookScript("OnLeave", function() paintNav(p) end)
    -- the step list is built on its first open
    h.nav:HookScript("OnClick", function() OXPFUI.Reapply("step list toggled") end)
  end
  local bar = p.bar
  if bar and bar.menu then
    bar.menu:HookScript("OnClick", function() OXPFUI.Reapply("menu opened") end)
  end
end

local W = { "card" }
OXPFUI.RegisterSkin { name = "OpenXP 2 card", gen = 2, windows = W, Apply = skinCard }
OXPFUI.RegisterSkin { name = "OpenXP 2 step list", gen = 2, windows = W, Apply = skinSteps }
OXPFUI.RegisterSkin { name = "OpenXP 2 quest targets", gen = 2, windows = { "targets" }, secure = true,
  Apply = skinTargets }
OXPFUI.RegisterSkin { name = "OpenXP 2 pop-ups", gen = 2, windows = W, Apply = skinPopups }
