-- OXP-FUI · OpenXP2Targets: Quest Targets and the quest item button on
-- OpenXP 2.x.
--
-- OpenXP 2.0 (UI/ActionButtons.lua) shows the step's targets in a box
-- (OpenXPTargets): a title ("TARGETS" / "TALK TO") and a 26px row per
-- target (OpenXPTargetButton, OpenXPTargetRow2..5: secure buttons with a
-- portrait or map icon, the name and a 2px enemy/friend bar). The step's
-- quest item has its own square button (OpenXPItemButton). OpenXP places
-- both left of the card, against UIParent (anchoring a secure button to the
-- card would make the game protect the card).
--
-- Layout exception 13 (Core.lua, README):
--   Icons (setting targetsIcons, default on): like RestedXP's target frame,
--   a row of icon squares, the item first, then one per target: the box's
--   frame, title and names go (the names stay in each icon's tooltip), each
--   icon gets FlareUI's bronze square, the enemy/friend bar runs along its
--   foot, and the key bound to the first target shows on its icon.
--   Full: the box keeps its rows, with the title strip (rows 14px lower).
--   Pin (setting pinTargets: below / beside the guide): the item and the
--   targets sit with the card: under it, or top-aligned beside it on the
--   side away from the screen edge; under the step list while that is open.
--   Positioned against UIParent like OpenXP does, out of combat only.

local ADDON_NAME, OXPFUI = ...

local theme = OXPFUI.theme
local C = theme.C
local A = theme.ART
local V2 = OXPFUI.OpenXP2

local T = {}
V2.Targets = T

local WHITE = "Interface\\Buttons\\WHITE8X8"
local ICON, SPACE = 30, 4
local ROW_TOP, ROW_H, ROW_W, SHIFT = 18, 26, 190, 14
local GAP, SIDE_GAP, LIST_LEFT = 8, 6, 320

local state = { pinned = false, where = nil, pending = false, saved = {}, placing = false }
T.state = state

local function inCombat() return InCombatLockdown and InCombatLockdown() end
local function icons() return (OXPFUI.db or {}).targetsIcons ~= false end
local function box() return rawget(_G, "OpenXPTargets") end
local function item() return rawget(_G, "OpenXPItemButton") end
local function card() return rawget(_G, "OpenXPCard") end
local function steps() return rawget(_G, "OpenXPSteps") end

local function rows()
  local out = {}
  local first = rawget(_G, "OpenXPTargetButton")
  if first then out[1] = first end
  for i = 2, 20 do
    local r = rawget(_G, "OpenXPTargetRow" .. i)
    if not r then break end
    out[i] = r
  end
  return out
end

local function shownRows()
  local n = 0
  for _, r in ipairs(rows()) do if r:IsShown() then n = n + 1 end end
  return n
end

-- ---------------------------------------------------------------------------
-- FlareUI icon squares
-- ---------------------------------------------------------------------------

-- A bronze 1px rim on a near-black square behind a button (FlareUI's
-- tracker buttons), lit under the mouse.
local function rim(b)
  local r = b.oxpfuiRim
  if not r then
    r = CreateFrame("Frame", nil, b, "BackdropTemplate")
    r:SetAllPoints(b)
    r:SetFrameLevel(math.max(0, (b:GetFrameLevel() or 1) - 1))
    if r.EnableMouse then r:EnableMouse(false) end
    r:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    function r.paint(lit)
      local c = lit and C.BOX_LIT or C.BOX
      r:SetBackdropColor(0, 0, 0, 0.6)
      r:SetBackdropBorderColor(c[1], c[2], c[3], 1)
    end
    b:HookScript("OnEnter", function() r.paint(true) end)
    b:HookScript("OnLeave", function() r.paint(false) end)
    b.oxpfuiRim = r
  end
  r.paint(false)
  r:Show()
  return r
end

-- OpenXP's item button has its own backdrop (the skin's panel with an
-- accent edge, repainted on every skin change): FlareUI's square instead.
local painting = false
local function itemSquare(it)
  local function paint()
    painting = true
    it:SetBackdropColor(0, 0, 0, 0.6)
    local c = C.BOX
    it:SetBackdropBorderColor(c[1], c[2], c[3], 1)
    painting = false
  end
  paint()
  if not it.oxpfuiSquare then
    it.oxpfuiSquare = true
    local function back() if not painting then paint() end end
    pcall(hooksecurefunc, it, "SetBackdropColor", back)
    pcall(hooksecurefunc, it, "SetBackdropBorderColor", back)
  end
  if it.hotkey then theme.ApplyText(it.hotkey, "counter", "DIM") end
  if it.count then theme.ApplyTextColor(it.count, "OBJECTIVE") end
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

local inLayout = false

local function layoutIcons(b)
  local list = rows()
  for i, r in ipairs(list) do
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", b, "TOPLEFT", (i - 1) * (ICON + SPACE), 0)
    r:SetSize(ICON, ICON)
    if r.text then r.text:SetAlpha(0) end
    if r.slot then
      r.slot:ClearAllPoints()
      r.slot:SetPoint("CENTER", r, "CENTER", 0, 1)
      r.slot:SetSize(ICON - 8, ICON - 8)
    end
    if r.bar then
      r.bar:ClearAllPoints()
      r.bar:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 2, 2)
      r.bar:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -2, 2)
      r.bar:SetHeight(2)
    end
    if r.hl then
      r.hl:ClearAllPoints()
      r.hl:SetPoint("TOPLEFT", r, "TOPLEFT", 1, -1)
      r.hl:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -1, 1)
    end
    rim(r)
  end
  -- the first target's key, on its icon (OpenXP shows it in the title row)
  local first = list[1]
  if first then
    local k = first.oxpfuiKey
    if not k then
      k = first:CreateFontString(nil, "OVERLAY")
      first.oxpfuiKey = k
    end
    theme.ApplyText(k, "counter", "DIM")
    k:ClearAllPoints()
    k:SetPoint("TOPRIGHT", first, "TOPRIGHT", -2, -2)
    k:SetText(b.key and b.key:GetText() or "")
    k:Show()
  end
  if b.title then b.title:SetAlpha(0) end
  if b.key then b.key:SetAlpha(0) end
  b:SetSize(math.max(1, shownRows()) * (ICON + SPACE) - SPACE, ICON)
end

local function layoutRows(b)
  for i, r in ipairs(rows()) do
    local y = -(ROW_TOP + SHIFT + (i - 1) * ROW_H)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", b, "TOPLEFT", 1, y)
    r:SetPoint("TOPRIGHT", b, "TOPRIGHT", -1, y)
    r:SetHeight(ROW_H)
    if r.text then r.text:SetAlpha(1) end
    if r.slot then
      r.slot:ClearAllPoints()
      r.slot:SetPoint("LEFT", r, "LEFT", 8, 0)
      r.slot:SetSize(20, 20)
    end
    if r.bar then
      r.bar:ClearAllPoints()
      r.bar:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -4)
      r.bar:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 4)
      r.bar:SetWidth(2)
    end
    if r.hl then r.hl:ClearAllPoints(); r.hl:SetAllPoints(r) end
    if r.oxpfuiRim then r.oxpfuiRim:Hide() end
    if r.oxpfuiKey then r.oxpfuiKey:Hide() end
  end
  if b.title then b.title:SetAlpha(1) end
  if b.key then b.key:SetAlpha(1) end
  b:SetSize(ROW_W, 20 + math.max(1, shownRows()) * ROW_H + SHIFT)
end

function T.Layout()
  local b = box()
  if not b or inLayout or inCombat() then return end
  inLayout = true
  local ok, err = pcall(icons() and layoutIcons or layoutRows, b)
  inLayout = false
  if not ok then error(err, 0) end
end

-- ---------------------------------------------------------------------------
-- The skin
-- ---------------------------------------------------------------------------

local function skin(ctx)
  local b = box()
  if not b then ctx.Skip("OpenXPTargets missing") return false end
  if icons() then
    V2.OwnWindow(b, { bare = true })
  else
    V2.OwnWindow(b, { header = b.title, headerStyle = "strip" })
    local band = b.oxpfuiBands and b.oxpfuiBands.title
    local inset = A.PAD - A.HEADER_INSET
    if b.title then
      local t = b.title:GetText()
      if t ~= b.title.oxpfuiShown then
        local shown = theme.TitleCase(t)
        b.title:SetText(shown)
        b.title.oxpfuiShown = shown
      end
      theme.ApplyText(b.title, "header", "TITLE")
      if band then
        b.title:ClearAllPoints()
        b.title:SetPoint("LEFT", band, "LEFT", inset, 0)
      end
    end
    if b.key then
      theme.ApplyText(b.key, "counter", "DIM")
      if band then
        b.key:ClearAllPoints()
        b.key:SetPoint("RIGHT", band, "RIGHT", -inset, 0)
      end
    end
  end
  T.Layout()
  local it = item()
  if it and it.SetBackdropColor then
    itemSquare(it)
    if not it.oxpfuiSize then it.oxpfuiSize = { it:GetSize() } end
    if icons() then
      it:SetSize(ICON, ICON)
    else
      it:SetSize(it.oxpfuiSize[1], it.oxpfuiSize[2])
    end
  end
  if not b.oxpfuiHooked then
    b.oxpfuiHooked = true
    -- Buttons.Refresh sets the box's height after the rows: lay them out
    -- at once (no frame in OpenXP's look), then a full pass.
    pcall(hooksecurefunc, b, "SetHeight", function()
      if inLayout then return end
      pcall(T.Layout)
      V2.Soon("targets refresh")
    end)
    b:HookScript("OnShow", function() T.Pin("targets shown") end)
  end
end

OXPFUI.RegisterSkin { name = "OpenXP 2 quest targets", gen = 2, windows = { "targets" }, secure = true,
  Apply = skin }

-- ---------------------------------------------------------------------------
-- Pin to the guide
-- ---------------------------------------------------------------------------

local function mode()
  local db = OXPFUI.db or {}
  if db.enabled ~= true or (db.windows and db.windows.targets == false) then return "off" end
  local m = db.pinTargets
  if m == "below" or m == "side" then return m end
  return "off"
end

local function shown(f) return f ~= nil and f:IsShown() end

-- A frame's edges in screen pixels.
local function edges(f)
  if not (f.GetLeft and f.GetRight and f.GetTop and f.GetBottom) then return nil end
  local s = f:GetEffectiveScale() or 1
  local l, r, t, b = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
  if not (l and r and t and b) then return nil end
  return { l = l * s, r = r * s, t = t * s, b = b * s }
end

-- Put f's top-left (or top-right) corner at a screen spot, against UIParent.
local function put(f, corner, x, y)
  local s = f:GetEffectiveScale() or 1
  f:ClearAllPoints()
  f:SetPoint(corner, UIParent, "BOTTOMLEFT", x / s, y / s)
end

local function capture(f)
  if not f or state.saved[f] then return end
  if f:GetNumPoints() > 0 then state.saved[f] = { f:GetPoint(1) } else state.saved[f] = false end
end

local function restore(f)
  local p = f and state.saved[f]
  if p then
    f:ClearAllPoints()
    f:SetPoint(p[1], p[2], p[3], p[4], p[5])
  end
  if f then state.saved[f] = nil end
end

local dragWrapped = {}
local function holdDrag(f)
  if not f or dragWrapped[f] then return end
  dragWrapped[f] = true
  local orig = f:GetScript("OnDragStart")
  f:SetScript("OnDragStart", function(self, ...)
    if state.pinned then return end -- the pin owns the spot
    if orig then return orig(self, ...) end
  end)
end

local function release()
  if not state.pinned then return end
  state.pinned, state.where = false, nil
  restore(box())
  restore(item())
end

-- Place the item and the box together, as a group, at the card.
local function place(m)
  local c, b, it = card(), box(), item()
  local ce = c and edges(c)
  if not ce then return end
  local itemW = shown(it) and ((it:GetWidth() or ICON) * (it:GetEffectiveScale() or 1)) or 0
  local boxW = shown(b) and ((b:GetWidth() or 0) * (b:GetEffectiveScale() or 1)) or 0
  local space = (itemW > 0 and boxW > 0) and SPACE or 0
  local onRight = ce.l / (c:GetEffectiveScale() or 1) > LIST_LEFT -- OpenXP's own side rule
  local x, y, rightAligned
  local list = steps()
  local le = shown(list) and edges(list)
  if le and (m == "side" or m == "below") then
    -- the step list opens beside the card: go under it
    y = le.b - GAP
    if onRight then x, rightAligned = le.r, true else x = le.l end
    state.where = "list"
  elseif m == "below" then
    y = ce.b - GAP
    if onRight then x, rightAligned = ce.r, true else x = ce.l end
    state.where = "card"
  else
    y = ce.t
    if onRight then x, rightAligned = ce.l - SIDE_GAP, true else x = ce.r + SIDE_GAP end
    state.where = "card"
  end
  state.placing = true
  if rightAligned then
    if boxW > 0 then put(b, "TOPRIGHT", x, y) end
    if itemW > 0 then put(it, "TOPRIGHT", x - boxW - space, y) end
  else
    if itemW > 0 then put(it, "TOPLEFT", x, y) end
    if boxW > 0 then put(b, "TOPLEFT", x + itemW + space, y) end
  end
  state.placing = false
end

local hooked = false
local function hookOnce()
  if hooked then return end
  local b, it = box(), item()
  if not b then return end
  hooked = true
  -- OpenXP puts them back next to the card itself (Buttons.Place: on
  -- login, after you drag the card): pin again right after.
  for _, f in ipairs({ b, it }) do
    if f then
      pcall(hooksecurefunc, f, "SetPoint", function()
        if state.pinned and not state.placing then V2.Soon("OpenXP placed targets") end
      end)
      f:HookScript("OnShow", function() if state.pinned then T.Pin("shown") end end)
      f:HookScript("OnHide", function() if state.pinned then T.Pin("hidden") end end)
    end
  end
end

function T.Pin(reason)
  local b = box()
  if not b then return end
  hookOnce()
  if inCombat() then
    state.pending = true
    return
  end
  state.pending = false
  local m = mode()
  if m == "off" then
    release()
    return
  end
  if not state.pinned then
    capture(b)
    capture(item())
    holdDrag(b)
    holdDrag(item())
    state.pinned = true
  end
  place(m)
end

function T.Status()
  local L = OXPFUI.L
  local m = mode()
  if m == "off" then return L.pinOff end
  if state.pending then return L.pinPending end
  if not state.pinned then return L.pinOff end
  return L.pinOn:format(m == "below" and L.pinBelow or L.pinSide,
    state.where == "list" and L.pinUnderList or L.pinAtCard)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function()
  if state.pending and OXPFUI.OpenXPGen and OXPFUI.OpenXPGen() == 2 then T.Pin("combat ended") end
end)
