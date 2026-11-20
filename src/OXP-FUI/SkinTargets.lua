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
-- What never changes: positions and sizes, icons/portraits, highlight
-- textures, click attributes, scripts and keybindings.
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
        theme.ApplyWindow(rf, { header = rt, headerStyle = "band", key = "targetsHeader" })
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
  end,
}
