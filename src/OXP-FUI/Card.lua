-- OXP-FUI · Card: the guide card and step list, in the FlareUI Quest
-- Tracker look (ticket #4: bronze border, warm dark fill, gold titles,
-- grey objectives, green completed, blue current and a bronze scrollbar;
-- OpenXP's own borderless icon buttons are left as they are).
--
-- Appearance only, except the layout exceptions listed in Core.lua's layout
-- policy (2-5: progress bars, "Up next" lines, step list rows and bottom
-- padding), which work on the real frames on purpose. The engine's guarded
-- frames refuse every other layout call.
-- OpenXP's card children are unnamed; they are found by walking the card
-- frame's children and matching OpenXP's own field shapes, and anything
-- missing (a renamed frame in a new OpenXP) is skipped quietly.

local ADDON_NAME, OXPFUI = ...

local theme = OXPFUI.theme
local C = theme.C

local function fields(obj, ...)
  if type(obj) ~= "table" then return false end
  for i = 1, select("#", ...) do
    if obj[(select(i, ...))] == nil then return false end
  end
  return true
end

-- OpenXP's blue label accent (a lighter blue it uses on button icons) also
-- becomes amber; the main accent blue itself is theme.OXP_BLUE.
local OXP_BLUE_LABEL = { 159 / 255, 212 / 255, 1 }

local function matches(tex, triple)
  local ok, r, g, b = pcall(tex.GetVertexColor, tex)
  if not ok or r == nil then return false end
  return theme.NearColor(r, g, b, triple)
end

local function setVertex(tex, triple, a)
  -- Real API: SetVertexColor(r, g, b) with no alpha means alpha 1.
  if a == nil then a = 1 end
  if tex and tex.SetVertexColor then tex:SetVertexColor(triple[1], triple[2], triple[3], a) end
end

-- Re-tint a texture only while OpenXP still has it in the blue accent.
local function amberIfBlue(tex, alpha)
  if tex and matches(tex, theme.OXP_BLUE) then setVertex(tex, C.ACCENT, alpha) end
end

local function isFontString(fs)
  return fs and fs.SetFont and fs.SetTextColor and true or false
end

-- A step row's / history row's status colour, from OpenXP's own status
-- keys; PILL_COLORS encodes the status -> palette mapping once for the
-- step pills, the history rows and the step-list rows (default varies by
-- caller). A row's status uses OpenXP's own logic when it is reachable
-- and falls back to whatever the frames themselves show.
local PILL_COLORS = {
  done = "TITLE_DONE",
  skipped = "OBJECTIVE_DONE",
  chain = "TITLE",
}

local function pillStatus(pill, openxp)
  local fs = pill and pill.text
  if not isFontString(fs) then return nil end
  local label = fs:GetText()
  if not label or label == "" then return nil end
  local statusTable = openxp and openxp.card and openxp.card.STATUS
  if type(statusTable) == "table" then
    for key, def in pairs(statusTable) do
      if type(def) == "table" and def.text == label then return key end
    end
  end
  return "?"
end

local function skinPill(pill, openxp)
  if not pill then return end
  theme.ApplyText(pill.text, "body", "OBJECTIVE")
  local status = pillStatus(pill, openxp)
  if status and status ~= "?" then
    local colorName = PILL_COLORS[status] or "OBJECTIVE"
    local c = C[colorName]
    theme.ApplyTextColor(pill.text, colorName)
    for _, part in ipairs({ pill.bg, pill.l, pill.r }) do
      setVertex(part, c, 0.16)
    end
  end
end

local function rowStatus(row, openxp)
  if row.current then return nil end
  local addon = openxp
  if fields(addon, "card") and addon.card.StepStatus and row.index and addon.currentGuide then
    local cur = addon.GetGuideProgress and addon.GetGuideProgress() or nil
    local ok, status = pcall(addon.card.StepStatus, addon.card,
      addon.currentGuide, row.index, cur)
    if ok and status then return status end
  end
  if row.pill and row.pill.IsShown and row.pill:IsShown() then return "done" end
  return nil
end

-- ---------------------------------------------------------------------------
-- Element sections
-- ---------------------------------------------------------------------------

-- The guide's zone and level range, exactly as OpenXP splits them
-- (OpenXPCard.lua SplitGuideName: "16-19 Darkshore" -> "Darkshore", "16–19"),
-- read from the selected guide on every pass, so the header always follows
-- the guide.
local function guideZoneRange(openxp)
  local guide = openxp and openxp.currentGuide
  local name = guide and (guide.displayname or guide.name)
  if type(name) ~= "string" then return nil end
  name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("\\n", " "):gsub("\n", " ")
  local range, zone = name:match("^(%d+%s*%-%s*%d+)%s+(.+)$")
  if range then return zone, (range:gsub("%s", ""):gsub("%-", "–")) end
  return name, nil
end

local function hex(c)
  return string.format("|cFF%02X%02X%02X", math.floor(c[1] * 255 + 0.5),
    math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

-- Header text: "Darkshore (16–19)", the range dimmed, no accent dot. During
-- a quest-chain detour OpenXP shows "QUEST CHAIN" instead: title-cased, no
-- range. Layout exception 7 (Core.lua): the zone starts where the dot was,
-- and is cut with "..." where it would reach "Step n / n".
local function headerText(header, openxp)
  local zone = theme.RealFrame(header.zone)
  local hf = theme.RealFrame(header)
  if not (zone and zone.GetText and zone.SetText and hf) then return end
  local current = zone:GetText()
  if current ~= zone.oxpfuiShown then
    -- OpenXP refreshed the header since the last pass: rebuild from source.
    -- OpenXP shows the guide's zone upper-cased; anything else it shows
    -- there (the "QUEST CHAIN" detour title) is just title-cased.
    local shown
    local name, range = guideZoneRange(openxp)
    if name and type(current) == "string" and current:upper() == name:upper() then
      shown = range and (name .. " " .. hex(C.DIM) .. "(" .. range .. ")|r") or name
    else
      shown = theme.TitleCase(current)
    end
    zone:SetText(shown)
    zone.oxpfuiShown = shown
  end
  -- The accent dot goes for good: hidden and see-through (OpenXP shows the
  -- header frame, never the dot itself, so it stays hidden).
  local dot = theme.RealFrame(header.dot)
  if dot then
    if dot.SetAlpha then dot:SetAlpha(0) end
    if dot.Hide then dot:Hide() end
  end
  local range = theme.RealFrame(header.range)
  if range and range.SetAlpha then range:SetAlpha(0) end
  zone:ClearAllPoints()
  zone:SetPoint("LEFT", hf, "LEFT", theme.ART.PAD, 0)
  if zone.SetWordWrap then zone:SetWordWrap(false) end
  local step = theme.RealFrame(header.step)
  local room = (hf:GetWidth() or 0) - theme.ART.PAD * 2
    - ((step and step.GetStringWidth and step:GetStringWidth()) or 0) - 10
  if zone.SetWidth then
    zone:SetWidth(0)
    if room > 20 and (zone:GetStringWidth() or 0) > room then zone:SetWidth(room) end
  end
end

local function skinHeader(header, openxp)
  theme.ApplyText(header.zone, "zone", "ZONE")
  theme.ApplyText(header.range, "counter", "DIM")
  theme.ApplyText(header.step, "counter", "TITLE")
  headerText(header, openxp)
  -- header.stepBtn (the invisible hit area over "Step n / n" that opens the
  -- step list) is deliberately left as OpenXP draws it: no chrome.
end

-- FlareUI's header band. With section separators on (FlareUI's Blizzard
-- or FlareUI frame style, or the OXP-FUI setting) Blizzard's tracker title
-- strip sits behind the header, as on FlareUI's tracker, plus the bottom
-- strip in the bordered FlareUI style. Otherwise a plain divider texture
-- right under the header. All own textures on own band frames, anchored to
-- the header; the header itself never moves.
local function ensureDivider(cardFrame, header)
  local rf = theme.RealFrame(cardFrame)
  local hf = theme.RealFrame(header)
  if not (rf and rf.CreateTexture and hf) then return end
  local t = rf.oxpfuiDivider
  if not t then
    t = rf:CreateTexture(nil, "ARTWORK")
    t:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
    t:SetHeight(8)
    t:SetDrawLayer("ARTWORK", 1)
    rf.oxpfuiDivider = t
  end
  t:ClearAllPoints()
  t:SetPoint("TOPLEFT", hf, "BOTTOMLEFT", 2, -1)
  t:SetPoint("TOPRIGHT", hf, "BOTTOMRIGHT", -2, -1)
  local drawn = theme.ApplyWindow(rf, { header = hf, foot = false })
  if drawn then t:Hide() else t:Show() end
  return drawn
end

-- A rule between card sections, where OpenXP draws its own faint 1px
-- separator (the top of "Up next") or where a section ends (the bottom of
-- the history band): the tracker's rod with its end knobs, between the
-- sections rather than under a heading's text. OpenXP's separator steps
-- aside while the rule is drawn and comes back when it is not.
local function sectionRule(cardFrame, section, region, edge, key, ownSep)
  local rf = theme.RealFrame(cardFrame)
  local host = theme.RealFrame(section)
  local anchor = theme.RealFrame(region)
  if not (rf and host and anchor and host.GetChildren) then return end
  local drawn = theme.ApplySectionRule(rf, anchor, edge, key, host)
  local sep = theme.RealFrame(ownSep)
  if sep and sep.SetAlpha then
    if drawn then
      if sep.oxpfuiAlpha == nil then sep.oxpfuiAlpha = sep.GetAlpha and sep:GetAlpha() or 1 end
      sep:SetAlpha(0)
    elseif sep.oxpfuiAlpha ~= nil then
      sep:SetAlpha(sep.oxpfuiAlpha)
      sep.oxpfuiAlpha = nil
    end
  end
end

local function skinHist(hist, openxp)
  theme.ApplyText(hist.label, "title", "ZONE")
  theme.ApplyText(hist.hint, "body", "DIM")
  for _, row in ipairs(hist.rows or {}) do
    local status = row.status or rowStatus(row, openxp)
    local colorName = PILL_COLORS[status] or "OBJECTIVE"
    theme.ApplyText(row.text, "body", colorName)
    theme.ApplyText(row.num, "body", "DIM")
    skinPill(row.pill, openxp)
  end
end

-- OpenXP prefixes side and finished steps' titles with an all-caps label in
-- its own colour ("|cFF9EA3B3ALONG THE WAY:|r ..."): title case, like the
-- other headings.
local function titleCasePrefix(fs)
  local f = theme.RealFrame(fs)
  if not (f and f.GetText and f.SetText) then return end
  local text = f:GetText()
  if type(text) ~= "string" then return end
  local fixed = text:gsub("^(|c%x%x%x%x%x%x%x%x)([^|]-)(:|r)", function(open, label, close)
    return open .. theme.TitleCase(label) .. close
  end)
  if fixed ~= text then f:SetText(fixed) end
end

local function skinBlocks(blocks)
  for _, b in ipairs(blocks or {}) do
    theme.ApplyText(b.title, "title", "TITLE")
    titleCasePrefix(b.title)
    theme.ApplyText(b.num, "body", "DIM")
    -- travel badges are OpenXP's blue ones: amber, other kinds keep meaning.
    -- The objective bars take the badge's kind colour as a solid colour
    -- texture (no vertex colour to match), so the badge decides: a travel
    -- badge (blue, or bronze once skinned) repaints its bars bronze too.
    local ring = b.badge and b.badge.ring
    local travel = ring ~= nil and (matches(ring, theme.OXP_BLUE) or matches(ring, C.ACCENT))
    amberIfBlue(b.badge and b.badge.fill, 0.16)
    amberIfBlue(b.badge and b.badge.ring)
    amberIfBlue(b.badge and b.badge.icon)
    for _, line in ipairs(b.lines or {}) do
      local done = false
      local mark = line.mark
      if mark and mark.GetTexture then
        local ok, tex = pcall(mark.GetTexture, mark)
        done = ok and type(tex) == "string" and tex:find("check", 1, true) ~= nil
      end
      theme.ApplyText(line.text, "body", done and "OBJECTIVE_DONE" or "OBJECTIVE")
      theme.ApplyText(line.count, "body", "DIM")
      if done then setVertex(mark, C.TITLE_DONE) end
      if travel and line.bar and line.bar.SetColorTexture then
        line.bar:SetColorTexture(C.ACCENT[1], C.ACCENT[2], C.ACCENT[3], 1)
      end
    end
  end
end

-- OpenXP sizes every "Up next" line to the card width minus the "UP NEXT"
-- label measured in OpenXP's own font, then the lines hang off the label's
-- right edge. The FlareUI label font is wider, so the lines would start
-- further right but keep the old width and run past the card's right
-- padding (the client's "..." cut included). Each shown line is narrowed by
-- exactly the amount the label grew, which restores OpenXP's right edge;
-- the client then places the "..." inside that width. Layout exception 3
-- (Core.lua); only the lines'
-- own widths change, and a re-apply with an unchanged label changes nothing.
local function skinUpNext(upNext)
  local label = theme.RealFrame(upNext.label)
  local before = label and label.GetStringWidth and label:GetStringWidth() or nil
  theme.ApplyText(upNext.label, "title", "ZONE")
  if label and label.GetText then
    local text = label:GetText()
    local tc = theme.TitleCase(text)
    if tc ~= text then label:SetText(tc) end
  end
  local after = label and label.GetStringWidth and label:GetStringWidth() or nil
  local delta = (before and after) and (after - before) or 0
  for _, line in ipairs(upNext.lines or {}) do
    theme.ApplyText(line, "body", "OBJECTIVE")
    local rl = theme.RealFrame(line)
    -- Layout exception 3 also centres the first line on the label: OpenXP
    -- aligns their tops (+1px), which leaves the smaller body text 3px high
    -- next to the larger label. Later lines hang off the first, as before.
    if line == upNext.lines[1] and rl and label and rl.SetPoint then
      rl:ClearAllPoints()
      rl:SetPoint("LEFT", label, "RIGHT", 8, 0)
    end
    if delta ~= 0 and rl and rl.IsShown and rl:IsShown() and rl.GetWidth and rl.SetWidth then
      local w = rl:GetWidth()
      if type(w) == "number" and w > 0 then rl:SetWidth(math.max(1, w - delta)) end
    end
  end
end

local function skinBar(bar)
  for _, btn in ipairs({ bar.prev, bar.next, bar.menu, bar.settings,
                         bar.collapse, bar.find, bar.stop, bar.resume }) do
    if btn then
      theme.ApplyText(btn.label, "body", "TITLE")
      local label = theme.RealFrame(btn.label)
      local wide = label ~= nil and label.IsShown ~= nil and label:IsShown()
      theme.ApplyToolbarButton(btn, { wide = wide })
    end
  end
  -- The bar's own white wash goes (FlareUI draws no band behind its
  -- buttons); its 1px top line becomes the section rule when separators are
  -- on, and a faint bronze line otherwise.
  local rb = theme.RealFrame(bar)
  if bar.bg and bar.bg.SetAlpha then bar.bg:SetAlpha(0) end
  if rb and bar.line then
    local drawn = theme.ApplySectionRule(rb, theme.RealFrame(bar.line), "TOP", "toolbar", rb)
    if bar.line.SetColorTexture then
      local c = C.ACCENT
      bar.line:SetColorTexture(c[1], c[2], c[3], drawn and 0 or 0.35)
    end
  end
end

local function skinXPStrip(xpStrip)
  -- OpenXP paints these as solid colour textures (gold XP, faint blue
  -- rested), so they are repainted, not matched: XP in the title colour,
  -- rested in the bronze accent at OpenXP's own alphas.
  if xpStrip and xpStrip.fill and xpStrip.fill.SetColorTexture then
    xpStrip.fill:SetColorTexture(C.TITLE[1], C.TITLE[2], C.TITLE[3], 0.9)
  end
  if xpStrip and xpStrip.rested and xpStrip.rested.SetColorTexture then
    xpStrip.rested:SetColorTexture(C.ACCENT[1], C.ACCENT[2], C.ACCENT[3], 0.35)
  end
end

local function skinMini(mini)
  theme.ApplyText(mini.text, "title", "TITLE")
  theme.ApplyText(mini.count, "body", "DIM")
  if mini.badge then
    amberIfBlue(mini.badge.fill, 0.16)
    amberIfBlue(mini.badge.ring)
    amberIfBlue(mini.badge.icon)
  end
end

-- The step list's close button (OpenXP: a 40x30 button with a "cross" icon
-- and a hover wash) wears Blizzard's red close-button art, as FlareUI's and
-- Blizzard's windows do. Same button, size, spot and click; OpenXP's icon
-- and wash are hidden while the art shows. Without the atlas (an older
-- client) OpenXP's own look stays.
local CLOSE_SIZE, CLOSE_X, CLOSE_Y = 24, 1, 0
local function styleCloseButton(btn, list)
  local b = theme.RealFrame(btn)
  if not (b and b.CreateTexture) then return end
  local art = b.oxpfuiRed
  if not art then
    art = b:CreateTexture(nil, "ARTWORK", nil, 2)
    art:SetSize(24, 24)
    art:SetPoint("CENTER")
    if not (art.SetAtlas and art:SetAtlas("RedButton-Exit")) then
      art:Hide()
      b.oxpfuiRed = false
      return
    end
    b.oxpfuiRed = art
    if b.SetHighlightAtlas then b:SetHighlightAtlas("RedButton-Highlight", "ADD") end
    local hl = b.GetHighlightTexture and b:GetHighlightTexture()
    if hl then hl:ClearAllPoints(); hl:SetAllPoints(art) end
    b:HookScript("OnMouseDown", function() art:SetAtlas("RedButton-exit-pressed") end)
    b:HookScript("OnMouseUp", function() art:SetAtlas("RedButton-Exit") end)
    -- OpenXP's OnEnter brings its wash back; keep it hidden after it.
    b:HookScript("OnEnter", function(self) if self.bg then self.bg:SetAlpha(0) end end)
  elseif art == false then
    return
  end
  if b.icon then b.icon:SetAlpha(0) end
  if b.bg then b.bg:SetAlpha(0) end
  -- Placed like Blizzard's own close button (UIPanelCloseButtonDefaultAnchors:
  -- 24x24 at the window's TOPRIGHT, +1, 0, over the frame's corner). OpenXP's
  -- button stays where it is; its click area is moved onto the art with
  -- hit-rect insets (no layout change), so what you see is what you click.
  local l = theme.RealFrame(list)
  art:ClearAllPoints()
  local point, rel, _, x, y = nil, nil, nil, 0, 0
  if b.GetPoint then point, rel, _, x, y = b:GetPoint(1) end
  local w, h = b:GetSize()
  if l and point == "TOPRIGHT" and rel == l and type(w) == "number" and type(h) == "number" then
    art:SetPoint("TOPRIGHT", l, "TOPRIGHT", CLOSE_X, CLOSE_Y)
    x, y = x or 0, y or 0
    -- Button rect (relative to the list's top-right): right x, top y, w x h.
    -- Art rect: right CLOSE_X, top CLOSE_Y, CLOSE_SIZE square.
    local left = (CLOSE_X - CLOSE_SIZE) - (x - w)
    local right = x - CLOSE_X
    local top = CLOSE_Y - y
    local bottom = (y - h) - (CLOSE_Y - CLOSE_SIZE)
    if b.SetHitRectInsets then b:SetHitRectInsets(left, right, -top, -bottom) end
  else
    art:SetPoint("CENTER", b, "CENTER")
  end
end

-- Layout exception (documented in Core.lua): OpenXP ends a row's text at its
-- status pill, but a pill that never had a status has no width, so that row's
-- text has no right edge and runs out of the window. Every row's text ends
-- at the pill when one shows, else at the row's own right padding (OpenXP's
-- 6px), and truncates with "..." there as OpenXP intends.
-- Layout exception 4 also places the pill: ROW_RIGHT px in from the row's
-- right edge (OpenXP: 6), clear of the border art and the scroll bar, and
-- as wide as its text in the FlareUI font plus OpenXP's own 12px (OpenXP
-- sizes it for its smaller font, so the wider label overflowed its plate).
local ROW_RIGHT = 14
local function boundRowText(row)
  local text, pill, r = theme.RealFrame(row.text), theme.RealFrame(row.pill), theme.RealFrame(row)
  if not (text and r and text.SetPoint) then return end
  if pill and pill.SetPoint then
    pill:SetPoint("RIGHT", r, "RIGHT", -ROW_RIGHT, 0)
    local pt = theme.RealFrame(row.pill.text)
    local w = pt and pt.GetStringWidth and pt:GetStringWidth()
    if type(w) == "number" and w > 0 and pill.SetWidth then pill:SetWidth(w + 12) end
  end
  if pill and pill.IsShown and pill:IsShown() then
    text:SetPoint("RIGHT", pill, "LEFT", -6, 0)
  else
    text:SetPoint("RIGHT", r, "RIGHT", -ROW_RIGHT, 0)
  end
  if text.SetWordWrap then text:SetWordWrap(false) end
end

-- Layout exception 5 (Core.lua): OpenXP starts the rows 28px below the
-- list's top, right under its own small title; with the 24px title bar and
-- its rod, that leaves the first row touching the rod. The rows move down by
-- LIST_TOP_PAD and the list grows by the same amount, so the bottom keeps
-- OpenXP's own 8px. Rows are re-anchored exactly as OpenXP anchors them
-- (TOPLEFT 4 / TOPRIGHT -4, rowH apart), only lower; idempotent.
local LIST_TOP_PAD = 4
local function padListTop(list)
  local l = theme.RealFrame(list)
  if not (l and l.GetHeight and l.SetHeight) then return end
  local rows = list.rows or {}
  local rowH = list.rowH or 18
  for r, row in ipairs(rows) do
    local rr = theme.RealFrame(row)
    if rr and rr.SetPoint then
      local y = -28 - LIST_TOP_PAD - (r - 1) * rowH
      rr:SetPoint("TOPLEFT", l, "TOPLEFT", 4, y)
      rr:SetPoint("TOPRIGHT", l, "TOPRIGHT", -4, y)
    end
  end
  local expected = 28 + #rows * rowH + 8
  local h = l:GetHeight()
  if type(h) == "number" and math.abs(h - expected) < 0.5 then
    l:SetHeight(expected + LIST_TOP_PAD)
  end
end

local function skinStepList(list, openxp)
  -- A pop-up window: always a background and frame, and a Blizzard-style
  -- compact title bar (see theme.ApplyWindowTitleBar) instead of the
  -- tracker's taller title strip.
  padListTop(list)
  theme.ApplyText(list.title, "header", "TITLE")
  local rl, rt = theme.RealFrame(list), theme.RealFrame(list.title)
  if rl and rt and rl.GetChildren then
    theme.ApplyWindow(rl, { role = "popup", header = rt, headerStyle = "titlebar" })
    local bar = rl.oxpfuiBands.titlebar
    -- Layout exception 5: the title is centred in the bar (OpenXP puts it at
    -- TOPLEFT 14,-9 under a 28px header of its own).
    rt:ClearAllPoints()
    rt:SetPoint("LEFT", bar, "LEFT", theme.ART.PAD, 0)
    rt:SetPoint("RIGHT", bar, "RIGHT", -30, 0)
    if rt.SetJustifyH then rt:SetJustifyH("LEFT") end
    if rt.SetWordWrap then rt:SetWordWrap(false) end
  end
  styleCloseButton(list.close, list)
  if rl and OXPFUI.TargetsDock then OXPFUI.TargetsDock.WatchList(rl) end
  local rows = list.rows or {}
  for _, row in ipairs(rows) do
    local colorName = "TITLE"
    if row.current then
      colorName = "TITLE_FOCUS"
      if row.hl and row.hl.SetColorTexture then
        row.hl:SetColorTexture(C.TITLE_FOCUS[1], C.TITLE_FOCUS[2], C.TITLE_FOCUS[3], 0.08)
      end
      theme.ApplyText(row.num, "body", "TITLE_FOCUS")
    else
      local status = rowStatus(row, openxp)
      colorName = PILL_COLORS[status] or "TITLE"
      theme.ApplyText(row.num, "body", "DIM")
    end
    theme.ApplyText(row.text, "title", colorName)
    skinPill(row.pill, openxp)
    boundRowText(row)
  end
  -- FlareUI's procedural bronze scrollbar beside the wheel-scrolled list.
  theme.ApplyScrollBar(list, {
    state = function()
      local total = list.count or #rows
      local visible = #rows
      if total <= visible then return 0, 1, false end
      local frac = (list.offset or 0) / (total - visible)
      return frac, visible / total, true
    end,
  })
end

-- ---------------------------------------------------------------------------
-- Progress bars
-- ---------------------------------------------------------------------------

-- OpenXP draws both progress bars (the step progress under the header and
-- the XP strip along the bottom) edge to edge, 1px inside the card, so with
-- the FlareUI border art their ends sit on top of it. This is the one place
-- the card skin lays anything out: each bar is inset by BAR_INSET on BOTH
-- sides (shifting it right alone would push its right end past the border
-- and the window edge). Only the bars themselves move, never the header,
-- body or any other element; every pass is idempotent.
local BAR_INSET = 3
-- With the title strip behind the header, the step progress line drops this
-- far so it sits under the strip's bottom rod instead of on it. Only OXP-FUI's
-- own track and OpenXP's fill move; OpenXP's track (which the body and
-- history hang from) stays where it is.
local PROGRESS_DROP = 3

-- Inset the header progress bar: the 2px track and the fill that grows
-- from its left end. OpenXP anchors the body and history to the track's
-- bottom corners, so the track itself stays; it is hidden and an inset
-- copy of it is drawn instead, and only the fill is moved and shortened.
local function insetStepProgress(rf, header, ctx, underStrip)
  local hf = theme.RealFrame(header)
  local okr, regions = pcall(function() return { rf:GetRegions() } end)
  if not (hf and okr) then return end
  -- The first anchor's relative frame, for any texture (nil when unreadable).
  local function anchorOf(region)
    if region == rf.oxpfuiTrack or not region.GetObjectType
        or region:GetObjectType() ~= "Texture" then
      return nil
    end
    local ok, _, rel = pcall(region.GetPoint, region, 1)
    return ok and rel or nil
  end
  -- The track is a thin texture hung under the header (a few px tall, not
  -- compared with == so pixel rounding cannot hide it).
  local track, fill
  for _, region in ipairs(regions) do
    if anchorOf(region) == hf then
      local okh, h = pcall(region.GetHeight, region)
      if okh and type(h) == "number" and h > 0 and h <= 4 then track = region end
    end
  end
  if not track then
    ctx.Skip("card: step progress track not found")
    return
  end
  for _, region in ipairs(regions) do
    if anchorOf(region) == track then fill = region end
  end
  if not fill then ctx.Skip("card: step progress fill not found") end

  local own = rf.oxpfuiTrack
  if not own then
    own = rf:CreateTexture(nil, "ARTWORK")
    own:SetHeight(2)
    rf.oxpfuiTrack = own
  end
  local drop = underStrip and -PROGRESS_DROP or 0
  own:ClearAllPoints()
  own:SetPoint("TOPLEFT", hf, "BOTTOMLEFT", BAR_INSET, drop)
  own:SetPoint("TOPRIGHT", hf, "BOTTOMRIGHT", -BAR_INSET, drop)
  own:SetColorTexture(1, 1, 1, 0.08)
  track:SetAlpha(0)

  if not fill then return end
  -- OpenXP paints the fill once, in its blue, as a solid colour texture (no
  -- vertex colour to match): it takes the title colour of the scheme in use
  -- (Blizzard gold, FlareUI bronze), like the tracker's own accents.
  if fill.SetColorTexture then fill:SetColorTexture(C.TITLE[1], C.TITLE[2], C.TITLE[3], 1) end
  fill:ClearAllPoints()
  fill:SetPoint("TOPLEFT", track, "TOPLEFT", BAR_INSET, drop)
  -- OpenXP sizes the fill to (card width - 2) * fraction on each refresh;
  -- scale that into the shorter track, once per OpenXP-set width.
  local width, cardW = fill:GetWidth(), rf:GetWidth()
  if width and cardW and cardW > 2 + 2 * BAR_INSET
      and not (fill.oxpfuiWidth and math.abs(fill.oxpfuiWidth - width) < 0.01) then
    local scaled = math.max(1, width * (cardW - 2 - 2 * BAR_INSET) / (cardW - 2))
    fill:SetWidth(scaled)
    fill.oxpfuiWidth = scaled
  end
end

-- Inset the XP strip: the strip frame carries its track, rested and fill
-- textures with it; OpenXP sizes them from the strip's own width, so it is
-- asked to do that again once the strip is narrower.
local function insetXPStrip(xpStrip, bar, cardModule)
  local sf, bf = theme.RealFrame(xpStrip), theme.RealFrame(bar)
  if not (sf and bf and sf.SetPoint) then return end
  sf:ClearAllPoints()
  sf:SetPoint("BOTTOMLEFT", bf, "BOTTOMLEFT", BAR_INSET, 0)
  sf:SetPoint("BOTTOMRIGHT", bf, "BOTTOMRIGHT", -BAR_INSET, 0)
  if cardModule and cardModule.UpdateXP then pcall(cardModule.UpdateXP) end
end

-- ---------------------------------------------------------------------------
-- Conditional progress bars (flight and step timers)
-- ---------------------------------------------------------------------------

-- OpenXP's timer bars (LibCandyBar frames, docked under the card) are filled
-- with the foreground texture of FlareUI's unit frame bars, "FlareUI Forever"
-- (Blizzard's Forever art in grey, so the bar colour tints it). FlareUI
-- hardcodes that texture today, so the path lives in this one function; when
-- FlareUI lets its maintainer-configured texture be read, only it changes.
-- Nil while FlareUI is not installed: the bars then keep OpenXP's own.
local function flareBarTexture()
  if not (GetAddOnMetadata and GetAddOnMetadata("FlareUI", "Version")) then
    return nil
  end
  return "Interface\\AddOns\\FlareUI\\Media\\Bars\\FlareUI-Forever.tga"
end

-- Texture one bar: the fill and its background, exactly as LibCandyBar's own
-- SetTexture does, with the fill's colour carried over. A bar already
-- showing the texture is left alone (OpenXP repaints its own one on every
-- StartTimer, so what the bar shows now is the only thing to go by).
local function textureBar(bar, texture)
  if type(bar) ~= "table" then return end
  local fill = bar.candyBarBar
  if not (fill and fill.SetStatusBarTexture and fill.GetStatusBarTexture
      and fill.GetStatusBarColor and fill.SetStatusBarColor
      and bar.candyBarBackground and bar.candyBarBackground.SetTexture) then
    return
  end
  local current = fill:GetStatusBarTexture()
  if current and current.GetTexture and current:GetTexture() == texture then return end
  local r, g, b, a = fill:GetStatusBarColor()
  fill:SetStatusBarTexture(texture)
  bar.candyBarBackground:SetTexture(texture)
  if r then fill:SetStatusBarColor(r, g, b, a) end
end

-- The active bars are RXPFrame.BarContainer.bars (label -> bar). OpenXP
-- restarts a pooled bar through StartTimer, which paints its own texture
-- again; the SortTimers hook (Engine) brings this skin back after it.
local function skinTimerBars(ctx, openxp)
  local texture = flareBarTexture()
  if not texture then
    ctx.Skip("card: timer bars keep OpenXP's texture (FlareUI not installed)")
    return
  end
  local container = openxp and openxp.RXPFrame and openxp.RXPFrame.BarContainer
  if type(container) ~= "table" or type(container.bars) ~= "table" then return end
  for _, raw in pairs(container.bars) do
    local bar = ctx.Guard(raw)
    if bar then textureBar(bar, texture) end
  end
end

-- ---------------------------------------------------------------------------
-- Skin entry
-- ---------------------------------------------------------------------------

local function Apply(ctx)
  local f = ctx.Frame("OpenXPCard")
  if not f then return end
  local openxp = ctx.OpenXP()
  local cardModule = openxp and openxp.card or nil
  local rf = theme.RealFrame(f)

  -- Bronze border art + warm near-black fill at the panel opacity setting.
  theme.ApplyBackdrop(f)

  -- OpenXP's unnamed card children, found by matching field shapes.
  local ok, children = pcall(function() return { rf:GetChildren() } end)
  if not ok then children = nil end
  local header, bar, upNext, mini, list
  for _, child in ipairs(children or {}) do
    if fields(child, "step", "dot") then header = child
    elseif fields(child, "prev", "collapse") then bar = child
    elseif fields(child, "label", "lines", "sep") then upNext = child
    elseif fields(child, "expand", "count") then mini = child
    elseif fields(child, "title", "rows", "close") then list = child
    end
  end
  if header then
    skinHeader(ctx.Guard(header), openxp)
    local underStrip = ensureDivider(f, header)
    insetStepProgress(rf, header, ctx, underStrip)
  end
  if cardModule and cardModule.hist then
    skinHist(ctx.Guard(cardModule.hist), openxp)
    sectionRule(f, cardModule.hist, cardModule.hist, "BOTTOM", "history")
  end
  if cardModule then skinBlocks(cardModule.blocksForTest) end
  if upNext then
    skinUpNext(ctx.Guard(upNext))
    sectionRule(f, upNext, upNext.sep or upNext, "TOP", "upnext", upNext.sep)
  end
  if bar then skinBar(ctx.Guard(bar)) end
  if cardModule and cardModule.xpStrip then
    skinXPStrip(cardModule.xpStrip)
    if bar then insetXPStrip(cardModule.xpStrip, bar, cardModule) end
  end
  if mini then skinMini(ctx.Guard(mini)) end
  if list then skinStepList(ctx.Guard(list), openxp) end
  skinTimerBars(ctx, openxp)

  -- Any region still carrying OpenXP's blue accent (the progress strip
  -- under the header, theme-colored art) becomes FlareUI amber.
  local okr, regions = pcall(function() return { rf:GetRegions() } end)
  if okr then
    for _, region in ipairs(regions or {}) do
      if region.SetVertexColor then amberIfBlue(region) end
    end
  end
end

OXPFUI.RegisterSkin{
  name = "card",
  windows = { "card" },
  Apply = Apply,
}
