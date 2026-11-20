-- OXP-FUI · SkinTargets: the Quest Targets list in the FlareUI look.
--
-- Ticket #5, spec stories 11-12: restyle OpenXP's target mob/NPC frame and
-- its buttons so they match the FlareUI Quest Tracker / guide card, without
-- ever blocking targeting.
--
-- What gets the FlareUI look (appearance only):
--   * RXPTargetFrame   — bronze border + warm dark fill (theme backdrop)
--   * the title strip  — "Quest Targets" in gold header typography on a
--                        tracker-style header band (shade between two rods),
--                        the keybind hint in dim grey
--   * section labels   — "Kill" / "Talk to" in the zone colour on a heading
--                        shade that fades out to the right
--   * target rows      — name in light grey body text, keybind hint dim,
--                        the 2px class strip recoloured to the bronze accent
--
-- What never changes: icons/portraits, highlight textures, click
-- attributes, scripts and keybindings.
--
-- Layout exception 10 (Core.lua), one window model with the card:
--   * the header is the card's: the tracker's title strip across the top
--     (theme.ApplyWindow, headerStyle "strip"), the title and keybind hint
--     centred on it, and the bottom strip on a bordered frame;
--   * OpenXP's section labels and rows move down by SHIFT so they start
--     under the strip, and the window grows by the same amount;
--   * a FlareUI box button (minus / plus) folds the window to its header
--     (setting targetsCollapsed; rows hide, the height is the header's).
-- All of it runs only out of combat (secure = true), like OpenXP's own
-- rebuilds; a click in combat is saved and shown when combat ends.
--
-- The row buttons are SECURE frames (SecureActionButtonTemplate macro
-- buttons, keybound), so this skin registers with secure = true: the engine
-- applies it only out of combat and defers a requested re-apply to
-- PLAYER_REGEN_ENABLED — the same rule OpenXP follows for its own rebuilds
-- (Targeting.lua bails out of combat too).

local ADDON_NAME, OXPFUI = ...

local theme = OXPFUI.theme

-- FlareUI look for one target row. `raw` is a button taken from OpenXP's own
-- reference lists; ctx.Guard re-applies the engine's rules (name allow/deny,
-- layout blocking) before anything is touched, and missing fields skip
-- quietly (OpenXP updates must never give Lua errors).
local function StyleRow(ctx, raw)
  local btn = ctx.Guard(raw)
  if not btn then return end
  if type(btn.bar) == "table" and btn.bar.SetColorTexture then
    local c = theme.C.ACCENT -- bronze accent, like every FlareUI strip
    btn.bar:SetColorTexture(c[1], c[2], c[3], 1)
  end
  theme.ApplyText(btn.label, "body", "OBJECTIVE")
  theme.ApplyText(btn.key, "body", "DIM")
end

local A = theme.ART
local SHIFT = 10                     -- OpenXP's content starts at 28; the strip ends at 30
local COLLAPSED_H = A.HEADER + 4     -- the strip and 3px under it, as the tracker minimized

-- OpenXP's own geometry (Targeting.lua ResizeTargetsFrame, 1.3.66): first
-- label at OXP_HEAD_H + 4; label 16, rows 24 each, 4 after each section;
-- window height y + 2.
local HEAD_Y, LABEL_H, ROW_H, SECTION_GAP = 24 + 4, 16, 24, 4
local SECTIONS = {
  { key = "enemy", list = "enemyTargetButtons" },
  { key = "friendly", list = "friendlyTargetButtons" },
}

-- Lay the sections out the way ResizeTargetsFrame does, SHIFT lower: from
-- what OpenXP shows (its rows in list order), never from where things are
-- now, so any number of re-applies lands in the same place. (Moving the
-- current anchors down "once" broke in game: rows drifted on top of each
-- other.)
local function layoutContent(rf, tf)
  local y = HEAD_Y + SHIFT
  for _, sec in ipairs(SECTIONS) do
    local label = theme.RealFrame(tf.sections and tf.sections[sec.key])
    local shown = {}
    for _, raw in ipairs(type(tf[sec.list]) == "table" and tf[sec.list] or {}) do
      local b = theme.RealFrame(raw)
      if b and b.IsShown and b:IsShown() then shown[#shown + 1] = b end
    end
    if #shown > 0 then
      if label then
        label:ClearAllPoints()
        label:SetPoint("TOPLEFT", rf, "TOPLEFT", 11, -y)
      end
      y = y + LABEL_H
      for _, b in ipairs(shown) do
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", rf, "TOPLEFT", 1, -y)
        y = y + ROW_H
      end
      y = y + SECTION_GAP
    end
  end
  local h = y + 2
  local cur = rf:GetHeight()
  if not cur or math.abs(cur - h) >= 0.5 then rf:SetHeight(h) end
end

local function collapsed() return (OXPFUI.db or {}).targetsCollapsed == true end

local function rows(tf)
  local out = {}
  for _, listName in ipairs({ "enemyTargetButtons", "friendlyTargetButtons" }) do
    if type(tf[listName]) == "table" then
      for _, raw in ipairs(tf[listName]) do out[#out + 1] = theme.RealFrame(raw) end
    end
  end
  return out
end

-- The box button on the header strip's right end.
local function collapseButton(rf, rt)
  local b = rt.oxpfuiCollapse
  if not b then
    b = theme.BoxButton(rt, 12)
    b:SetScript("OnClick", function()
      OXPFUI.Settings.Set("targetsCollapsed", not collapsed(), "quest targets folded")
      if not collapsed() then
        -- OpenXP shows its rows and sizes the window again; the skin's hook
        -- on UpdateTargetFrame moves them under the strip.
        local openxp = OXPFUI.GetOpenXP and OXPFUI.GetOpenXP()
        local t = openxp and openxp.targeting
        if t and t.UpdateTargetFrame and not InCombatLockdown() then
          pcall(t.UpdateTargetFrame, t)
        end
      end
    end)
    b:SetScript("OnEnter", function(self)
      self:Paint(true)
      if GameTooltip then
        GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
        GameTooltip:SetText(collapsed() and OXPFUI.L.targetsExpand or OXPFUI.L.targetsCollapse)
        GameTooltip:Show()
      end
    end)
    b:SetScript("OnLeave", function(self)
      self:Paint(false)
      if GameTooltip then GameTooltip:Hide() end
    end)
    rt.oxpfuiCollapse = b
  end
  b:SetPlus(collapsed())
  b:Show()
  return b
end

-- Exception 10: header, shift, fold. rf/rt: raw window and title frame.
local function layoutWindow(rf, rt, tf)
  local band = theme.Band(rf, "title")
  -- The title frame covers the whole strip (drag handle + button home).
  rt:ClearAllPoints()
  rt:SetPoint("TOPLEFT", rf, "TOPLEFT", 1, -1)
  rt:SetPoint("TOPRIGHT", rf, "TOPRIGHT", -1, -1)
  rt:SetHeight(A.HEADER)
  local btn = collapseButton(rf, rt)
  btn:ClearAllPoints()
  btn:SetPoint("RIGHT", band, "RIGHT", -(A.PAD - A.HEADER_INSET), 0)
  local text = theme.RealFrame(rt.text)
  if text then
    text:ClearAllPoints()
    text:SetPoint("LEFT", band, "LEFT", A.PAD - A.HEADER_INSET, 0)
  end
  local hint = theme.RealFrame(rt.keyHint)
  if hint then
    hint:ClearAllPoints()
    hint:SetPoint("RIGHT", btn, "LEFT", -6, 0)
  end

  -- What OpenXP shows is remembered while folded (it decides which rows
  -- and labels show; a fold only hides them), and given back on unfold.
  local regions = rows(tf)
  for _, fs in pairs(tf.sections or {}) do regions[#regions + 1] = theme.RealFrame(fs) end
  if collapsed() then
    -- Anything showing means OpenXP just rebuilt: its set replaces ours.
    local now = {}
    for _, r in ipairs(regions) do
      if r and r.IsShown and r:IsShown() then now[#now + 1] = r end
    end
    if #now > 0 or not rf.oxpfuiFolded then
      rf.oxpfuiFolded = {}
      for _, r in ipairs(now) do rf.oxpfuiFolded[r] = true; r:Hide() end
    end
    if math.abs((rf:GetHeight() or 0) - COLLAPSED_H) >= 0.5 then rf:SetHeight(COLLAPSED_H) end
    return
  end
  if rf.oxpfuiFolded then
    for r in pairs(rf.oxpfuiFolded) do r:Show() end
    rf.oxpfuiFolded = nil
  end
  layoutContent(rf, tf)
end

OXPFUI.RegisterSkin{
  name = "targets",
  windows = { "targets" },
  secure = true,
  Apply = function(ctx)
    local f = ctx.Frame("RXPTargetFrame")
    if f then theme.ApplyBackdrop(f) end
    local rf = theme.RealFrame(f)

    local title = ctx.Frame("RXPTargetFrame_title")
    if title then
      theme.ApplyTitleStrip(title)
      local rt = theme.RealFrame(title)
      -- OpenXP's faint white wash goes; the tracker-style header band (a
      -- shade between two rods) takes its place. "QUEST TARGETS" becomes
      -- "Quest Targets", like the tracker's headings.
      if rt and rt.SetBackdropColor then pcall(rt.SetBackdropColor, rt, 1, 1, 1, 0) end
      local text = theme.RealFrame(title.text)
      if text and text.GetText then
        local tc = theme.TitleCase(text:GetText())
        if tc ~= text:GetText() then text:SetText(tc) end
      end
      if rf and rt and rf.GetChildren then
        -- One header for every window: the card's title strip.
        theme.ApplyWindow(rf, { header = rt, headerStyle = "strip", foot = not collapsed() })
      end
      if title.keyHint then
        theme.ApplyText(title.keyHint, "body", "DIM")
      end
    end

    -- Rows and section labels are reached through OpenXP's addon table (the
    -- buttons are created on demand and kept in these reference lists).
    local openxp = ctx.OpenXP()
    local tf = openxp and openxp.targeting and openxp.targeting.activeTargetFrame
    if type(tf) ~= "table" then return end
    if type(tf.sections) == "table" then
      local rtf = theme.RealFrame(tf)
      for key, fs in pairs(tf.sections) do
        theme.ApplyText(fs, "title", "ZONE")
        -- "KILL" / "TALK TO" -> "Kill" / "Talk to", on a heading shade.
        local rfs = theme.RealFrame(fs)
        if rfs and rfs.GetText then
          local tc = theme.TitleCase(rfs:GetText())
          if tc ~= rfs:GetText() then rfs:SetText(tc) end
        end
        if rtf and rtf.GetChildren then
          theme.ApplySectionHeading(rtf, rfs, "targetsSection_" .. tostring(key))
        end
      end
    end
    for _, listName in ipairs({ "enemyTargetButtons", "friendlyTargetButtons" }) do
      if type(tf[listName]) == "table" then
        for _, raw in ipairs(tf[listName]) do
          StyleRow(ctx, raw)
        end
      end
    end
    local rt = theme.RealFrame(title)
    if rf and rt and rf.SetHeight then
      local ok, err = pcall(layoutWindow, rf, rt, tf)
      if not ok then ctx.Skip("targets layout: " .. tostring(err)) end
      -- the fold hid the labels: their heading shades go with them
      if type(tf.sections) == "table" then
        for key, fs in pairs(tf.sections) do
          theme.ApplySectionHeading(rf, theme.RealFrame(fs), "targetsSection_" .. tostring(key))
        end
      end
    end
  end,
}
