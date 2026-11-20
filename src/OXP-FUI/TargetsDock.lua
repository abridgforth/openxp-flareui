-- OXP-FUI · TargetsDock: pin OpenXP's Quest Targets window to the guide.
--
-- Layout exception 6 (Core.lua). With "Pin Quest Targets" set to Below the
-- guide or Beside the guide, RXPTargetFrame is anchored to the guide card:
--
--   below   under the card, left edges aligned
--   beside  next to the card, on the side away from the screen edge (the
--           side OpenXP opens the step list on: left when the card's left
--           edge is past 320px, like card.ToggleStepList)
--
-- While the step list is open, the pinned window moves under the step list
-- instead, and goes back when the list closes. If there is not enough room
-- under the list, it stays in its pinned spot (the step list has a
-- background, so it reads over it either way).
--
-- Your own spot is kept: while pinned the window carries OpenXP's own
-- savePosition = false flag, so OpenXP's position save (SaveFramePositions)
-- skips it, and unpinning restores it with OpenXP's LoadFramePosition.
-- Dragging the window is suspended while pinned (the pin owns its place).
--
-- The window holds secure target buttons, so the game refuses to move it in
-- combat: a move that comes up in combat waits for PLAYER_REGEN_ENABLED.

local ADDON_NAME, OXPFUI = ...

local TargetsDock = {}
OXPFUI.TargetsDock = TargetsDock

local GAP = 12        -- below: the window's title strip sits 8px above it
local SIDE_GAP = 6    -- beside: between the card and the window
local LIST_LEFT = 320 -- OpenXP's own rule for which side the list opens on

local state = {
  pinned = false,     -- the window is anchored by this module
  where = nil,        -- "card" | "list": what it is anchored to right now
  pending = false,    -- a move waits for combat to end
  list = nil,         -- the step list frame, once seen
}
TargetsDock.state = state

local function targetsFrame() return rawget(_G, "RXPTargetFrame") end
local function cardFrame() return rawget(_G, "OpenXPCard") end

local function mode()
  local db = OXPFUI.db or {}
  if db.enabled ~= true then return "off" end
  local m = db.pinTargets
  if m == "below" or m == "side" then return m end
  return "off"
end

-- Which side of the card the step list (and a "beside" pin) goes on.
local function cardOnRight(card)
  local left = card.GetLeft and card:GetLeft() or 0
  return (left or 0) > LIST_LEFT
end

-- ---------------------------------------------------------------------------
-- Drag suspension (both the window and its title strip start drags)
-- ---------------------------------------------------------------------------

local wrapped = {} -- frame -> original OnMouseDown (false: none)

local function suspendDrag(frame)
  if not frame or wrapped[frame] ~= nil or not frame.GetScript then return end
  local orig = frame:GetScript("OnMouseDown")
  wrapped[frame] = orig or false
  frame:SetScript("OnMouseDown", function(self, ...)
    if state.pinned then return end -- the pin owns the window's place
    if orig then return orig(self, ...) end
  end)
end

local function restoreDrag(frame)
  local orig = frame and wrapped[frame]
  if orig == nil then return end
  frame:SetScript("OnMouseDown", orig or nil)
  wrapped[frame] = nil
end

-- ---------------------------------------------------------------------------
-- Placement
-- ---------------------------------------------------------------------------

local function listOpen()
  local l = state.list
  return l ~= nil and l.IsShown ~= nil and l:IsShown() and l:IsVisible() ~= false
end

-- Room under the open list for the whole window (screen coordinates).
local function roomUnderList(t, l)
  local bottom = l.GetBottom and l:GetBottom()
  local h = t.GetHeight and t:GetHeight()
  if type(bottom) ~= "number" or type(h) ~= "number" then return true end
  local ls = l.GetEffectiveScale and l:GetEffectiveScale() or 1
  local ts = t.GetEffectiveScale and t:GetEffectiveScale() or 1
  return bottom * ls - (h + GAP) * ts >= 0
end

local function place(t, card, m)
  local l = state.list
  t:ClearAllPoints()
  if listOpen() and roomUnderList(t, l) then
    -- Under the step list, aligned with the list's outer edge.
    if cardOnRight(card) then
      t:SetPoint("TOPRIGHT", l, "BOTTOMRIGHT", 0, -GAP)
    else
      t:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -GAP)
    end
    state.where = "list"
  elseif m == "below" then
    t:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 0, -GAP)
    state.where = "card"
  else
    if cardOnRight(card) then
      t:SetPoint("TOPRIGHT", card, "TOPLEFT", -SIDE_GAP, -GAP + 4)
    else
      t:SetPoint("TOPLEFT", card, "TOPRIGHT", SIDE_GAP, -GAP + 4)
    end
    state.where = "card"
  end
end

local function release(t)
  if not state.pinned then return end
  state.pinned, state.where = false, nil
  restoreDrag(t)
  restoreDrag(t and t.title)
  if t then
    t.savePosition = nil
    local openxp = OXPFUI.GetOpenXP and OXPFUI.GetOpenXP() or nil
    local settings = openxp and openxp.settings
    if settings and settings.LoadFramePosition then
      pcall(settings.LoadFramePosition, settings, "activeTargetFrame", t)
    end
  end
end

-- Central evaluation: settings changes, every re-apply pass, the step list
-- opening and closing, and combat ending.
function TargetsDock.Update(reason)
  local t, card = targetsFrame(), cardFrame()
  if not (t and card) then return end
  local m = mode()
  if InCombatLockdown and InCombatLockdown() then
    state.pending = true
    return
  end
  state.pending = false
  if m == "off" then
    release(t)
    return
  end
  if not state.pinned then
    state.pinned = true
    t.savePosition = false -- OpenXP keeps your own saved spot
    suspendDrag(t)
    suspendDrag(t.title)
  end
  place(t, card, m)
end

-- The step list is OpenXP-local; the card skin hands it over once found.
function TargetsDock.WatchList(list)
  if not list or state.list == list then return end
  state.list = list
  if list.HookScript then
    list:HookScript("OnShow", function() TargetsDock.Update("step list opened") end)
    list:HookScript("OnHide", function() TargetsDock.Update("step list closed") end)
  end
end

function TargetsDock.Status()
  local L = OXPFUI.L
  local m = mode()
  if m == "off" then return L.pinOff end
  if state.pending then return L.pinPending end
  if not state.pinned then return L.pinOff end
  return L.pinOn:format(m == "below" and L.pinBelow or L.pinSide,
    state.where == "list" and L.pinUnderList or L.pinAtCard)
end

local events = CreateFrame("Frame", "OXPFUITargetsDockFrame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" or state.pending then
    TargetsDock.Update(event)
  end
end)
