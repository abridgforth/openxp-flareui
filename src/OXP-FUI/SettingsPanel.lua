-- OXP-FUI · SettingsPanel: the /oxpfui window, built from Blizzard's own
-- UI templates so it looks and behaves like the game's settings:
--
--   ButtonFrameTemplate     window, title bar, close (X) button
--   UICheckButtonTemplate   on/off settings
--   WowStyle1DropdownTemplate  choices (font, border, tracker edge)
--   MinimalSliderWithSteppersTemplate  ranges, with < > steppers
--   UIPanelButtonTemplate   Defaults / Cancel / Save
--   GameTooltip             hover help, incl. "requires a UI reload"
--
-- Edits go into a draft (Settings.NewDraft). Every change that needs no
-- reload shows at once (Settings.Preview) without being saved. Save
-- (Settings.Commit) writes the settings and reloads the UI if and only if a
-- changed setting requires it (declared per setting in Settings.lua).
-- Cancel, X and Escape discard the draft and undo the preview. The panel is also
-- listed under Options > AddOns with a button that opens this window.
--
-- The panel is an OXP-FUI-owned frame: it never touches OpenXP frames.

local ADDON_NAME, OXPFUI = ...

local L = OXPFUI.L
local theme = OXPFUI.theme
local Settings = OXPFUI.Settings

local panel -- built lazily on first open

local WIDTH, HEIGHT = 460, 728
local LEFT = 20
local COL2 = 230
-- Sliders leave room on the right for their value label ("100%", "40px")
-- inside the window; dropdowns span the column.
local SLIDER_WIDTH = 160
local DROPDOWN_WIDTH = 200

-- ---------------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------------

local function safe(obj, method, ...)
  if type(obj) == "table" and type(obj[method]) == "function" then
    return obj[method](obj, ...)
  end
end

local function setEnabled(widget, enabled)
  if type(widget) ~= "table" then return end
  if type(widget.SetEnabled) == "function" then
    widget:SetEnabled(enabled)
  elseif enabled then
    safe(widget, "Enable")
  else
    safe(widget, "Disable")
  end
end

local function fontString(parent, fontObject, text)
  -- Inheriting a font object gives the string its font before SetText (a
  -- fresh string without one raises "Font not set").
  local fs = parent:CreateFontString(nil, "ARTWORK", fontObject)
  fs:SetText(text or "")
  fs:SetJustifyH("LEFT")
  return fs
end

local function header(parent, text, y)
  local fs = fontString(parent, "GameFontNormalLarge", text)
  fs:SetPoint("TOPLEFT", parent, "TOPLEFT", LEFT, y)
  return fs
end

-- Tooltip with the setting's help text and its reload rule.
local function reloadTip(def)
  if not def then return nil end
  local r = def.reload
  if r == true then return L.requiresReloadTip end
  if type(r) == "function" and Settings.NeedsReload(def, true, false) then
    return L.requiresReloadOffTip
  end
  return nil
end

local function attachTooltip(widget, title, body, def)
  if type(widget) ~= "table" or not widget.SetScript then return end
  widget:SetScript("OnEnter", function(self)
    if not GameTooltip or not GameTooltip.SetOwner then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 1, 1)
    if body then GameTooltip:AddLine(body, nil, nil, nil, true) end
    local note = reloadTip(def)
    if note then GameTooltip:AddLine(note, 1, 0.82, 0, true) end
    GameTooltip:Show()
  end)
  widget:SetScript("OnLeave", function()
    if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
  end)
end

-- ---------------------------------------------------------------------------
-- Controls. Each returns a control { key, widget, label, Refresh() } whose
-- widget writes into panel.draft[key] and calls panel:OnDraftChanged().
-- ---------------------------------------------------------------------------

local function makeCheckbox(f, key, text, tip, x, y)
  local def = Settings.Get(key)
  local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
  cb:SetSize(26, 26)
  cb:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
  local label = cb.Text or cb.text
  if label then
    label:SetFontObject("GameFontHighlight")
    label:SetText(text)
  else
    label = fontString(cb, "GameFontHighlight", text)
    label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
  end
  cb:SetScript("OnClick", function(self)
    f.draft[key] = self:GetChecked() and true or false
    f:OnDraftChanged()
  end)
  attachTooltip(cb, text, tip, def)
  local control = { key = key, widget = cb, label = text }
  function control.Refresh() cb:SetChecked(f.draft[key] == true) end
  f.controls[key] = control
  return cb
end

local function makeDropdown(f, key, text, tip, y, options)
  -- options: list of { value = ..., text = ... }
  local def = Settings.Get(key)
  local fs = fontString(f.content, "GameFontHighlight", text)
  fs:SetPoint("TOPLEFT", f, "TOPLEFT", LEFT + 4, y - 6)
  local dd = CreateFrame("DropdownButton", nil, f, "WowStyle1DropdownTemplate")
  dd:SetWidth(DROPDOWN_WIDTH)
  dd:SetPoint("TOPLEFT", f, "TOPLEFT", COL2, y)
  local function textFor(value)
    for _, o in ipairs(options) do
      if o.value == value then return o.text end
    end
    return tostring(value)
  end
  safe(dd, "SetDefaultText", textFor(def.default))
  safe(dd, "SetupMenu", function(_, root)
    for _, o in ipairs(options) do
      root:CreateRadio(o.text,
        function(value) return f.draft and f.draft[key] == value end,
        function(value)
          f.draft[key] = value
          f:OnDraftChanged()
        end,
        o.value)
    end
  end)
  attachTooltip(dd, text, tip, def)
  local control = { key = key, widget = dd, label = text, labelString = fs, textFor = textFor }
  -- Regenerating re-reads isSelected, which also updates the shown text.
  function control.Refresh() safe(dd, "GenerateMenu") end
  f.controls[key] = control
  return dd
end

local function makeSlider(f, key, text, tip, y, format)
  local def = Settings.Get(key)
  local fs = fontString(f.content, "GameFontHighlight", text)
  fs:SetPoint("TOPLEFT", f, "TOPLEFT", LEFT + 4, y - 6)
  local sl = CreateFrame("Frame", nil, f, "MinimalSliderWithSteppersTemplate")
  sl:SetSize(SLIDER_WIDTH, 20)
  sl:SetPoint("TOPLEFT", f, "TOPLEFT", COL2, y - 2)
  local steps = math.floor((def.max - def.min) / def.step + 0.5)
  local formatters = {}
  local labels = MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label
  if labels and labels.Right then formatters[labels.Right] = format end
  local initial = f.draft and f.draft[key] or def.default
  safe(sl, "Init", initial, def.min, def.max, steps, formatters)
  local event = MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Event
    and MinimalSliderWithSteppersMixin.Event.OnValueChanged
  local function onValue(_, value)
    local snapped = def.min + math.floor((value - def.min) / def.step + 0.5) * def.step
    if snapped < def.min then snapped = def.min end
    if snapped > def.max then snapped = def.max end
    -- Two decimals is plenty and keeps 0.6 == 0.6 after stepping.
    snapped = math.floor(snapped * 100 + 0.5) / 100
    if f.draft[key] ~= snapped then
      f.draft[key] = snapped
      f:OnDraftChanged()
    end
  end
  if event then safe(sl, "RegisterCallback", event, onValue, sl) end
  attachTooltip(sl, text, tip, def)
  local control = { key = key, widget = sl, label = text, labelString = fs }
  function control.Refresh() safe(sl, "SetValue", f.draft[key]) end
  f.controls[key] = control
  return sl
end

-- ---------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------

local function buildPanel()
  local f = CreateFrame("Frame", "OXPFUIPanel", UIParent, "ButtonFrameTemplate")
  f:SetSize(WIDTH, HEIGHT)
  f:SetPoint("CENTER", UIParent, "CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  if ButtonFrameTemplate_HidePortrait then pcall(ButtonFrameTemplate_HidePortrait, f) end
  safe(f, "SetTitle", L.panelTitle)
  if f.Inset then
    f.Inset:ClearAllPoints()
    f.Inset:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -26)
    f.Inset:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 32)
  end
  -- Text layer above the Inset: the template draws the Inset at the
  -- window's own frame level, which would cover strings drawn on the
  -- window itself. Controls are child frames and already sit above it.
  f.content = CreateFrame("Frame", nil, f)
  f.content:SetAllPoints(f)
  f.content:SetFrameLevel((f:GetFrameLevel() or 0) + 2)

  -- Hidden until the build completes (OpenPanel shows it): a mid-build
  -- error must never leave a shown, half-built panel on screen. Escape
  -- closes it (= Cancel) via the client's UISpecialFrames list.
  f:Hide()
  tinsert(UISpecialFrames, f:GetName())

  f.controls = {}
  f.draft = Settings.NewDraft()

  -- Subtitle + version note ------------------------------------------------
  f.subtitle = fontString(f.content, "GameFontHighlightSmall", L.panelSubtitle)
  f.subtitle:SetPoint("TOPLEFT", f, "TOPLEFT", LEFT, -36)
  local mismatch = OXPFUI.VersionMismatch and OXPFUI.VersionMismatch()
  if mismatch then
    f.versionNote = fontString(f.content, "GameFontRedSmall",
      L.versionNote:format(mismatch, OXPFUI.testedOpenXP))
    f.versionNote:SetPoint("TOPLEFT", f.subtitle, "BOTTOMLEFT", 0, -2)
    -- Pinned to the pane's right edge so a long note wraps, not overflows.
    f.versionNote:SetPoint("RIGHT", f, "RIGHT", -LEFT, 0)
  end

  -- General ------------------------------------------------------------------
  local y = -62
  f.generalHeader = header(f.content, L.generalHeader, y)
  y = y - 22
  f.masterBtn = makeCheckbox(f, "enabled", L.masterLabel, L.masterTip, LEFT, y)
  f.followBtn = makeCheckbox(f, "followFlareUI", L.followLabel, L.followTip, COL2, y)

  -- Windows ------------------------------------------------------------------
  y = y - 36
  f.windowsHeader = header(f.content, L.windowsHeader, y)
  y = y - 22
  f.windowBtns = {}
  for i, w in ipairs(OXPFUI.WINDOWS) do
    local col = (i - 1) % 2
    local row = math.floor((i - 1) / 2)
    f.windowBtns[w] = makeCheckbox(f, "windows." .. w, L.windows[w], L.windowsTip,
      col == 0 and LEFT or COL2, y - row * 26)
  end
  y = y - math.ceil(#OXPFUI.WINDOWS / 2) * 26 - 10

  -- Appearance ----------------------------------------------------------------
  f.appearanceHeader = header(f.content, L.appearanceHeader, y)
  f.styleNote = fontString(f.content, "GameFontDisableSmall", "")
  f.styleNote:SetPoint("LEFT", f.appearanceHeader, "RIGHT", 10, 0)
  f.styleNote:SetPoint("RIGHT", f, "RIGHT", -LEFT, 0)
  y = y - 26
  local fontOptions = {}
  for _, entry in ipairs(theme.FONTS) do
    fontOptions[#fontOptions + 1] = { value = entry.key, text = entry.key }
  end
  f.frameStyleDropdown = makeDropdown(f, "frameStyle", L.frameStyleLabel, L.frameStyleTip, y, {
    { value = "blizzard", text = L.frameStyles.blizzard },
    { value = "flareui", text = L.frameStyles.flareui },
    { value = "custom", text = L.frameStyles.custom },
  })
  y = y - 32
  f.fontDropdown = makeDropdown(f, "font", L.fontLabel, L.fontTip, y, fontOptions)
  y = y - 32
  local borderOptions = {}
  for _, k in ipairs(theme.BORDER_ORDER) do
    borderOptions[#borderOptions + 1] = { value = k, text = L.borderNames[k] or k }
  end
  f.borderDropdown = makeDropdown(f, "borderStyle", L.borderLabel, L.borderTip, y, borderOptions)
  y = y - 32
  f.opacitySlider = makeSlider(f, "opacity", L.opacityLabel, L.opacityTip, y,
    function(v) return L.opacityValue:format(math.floor(v * 100 + 0.5)) end)

  -- FlareUI Quest Tracker ----------------------------------------------------
  y = y - 36
  f.trackerHeader = header(f.content, L.trackerHeader, y)
  y = y - 22
  f.attachBtn = makeCheckbox(f, "attachTracker", L.attachLabel, L.attachTip, LEFT, y)
  y = y - 30
  f.attachSideDropdown = makeDropdown(f, "attachSide", L.attachSideLabel, L.attachSideTip, y, {
    { value = "bottom", text = L.sideBottom },
    { value = "top", text = L.sideTop },
  })
  y = y - 32
  f.paddingSlider = makeSlider(f, "attachPadding", L.attachPaddingLabel, L.attachPaddingTip, y,
    function(v) return L.attachPaddingValue:format(math.floor(v + 0.5)) end)
  y = y - 30
  f.matchBtn = makeCheckbox(f, "matchTrackerWidth", L.matchWidthLabel, L.matchWidthTip, LEFT, y)

  -- Quest Targets ------------------------------------------------------------
  y = y - 36
  f.targetsHeader = header(f.content, L.targetsHeader, y)
  y = y - 28
  f.pinDropdown = makeDropdown(f, "pinTargets", L.pinLabel, L.pinTip, y, {
    { value = "off", text = L.pinChoices.off },
    { value = "below", text = L.pinChoices.below },
    { value = "side", text = L.pinChoices.side },
  })

  -- Reload note (shown only when the pending changes need a reload) -------
  f.reloadNote = fontString(f.content, "GameFontNormalSmall", "")
  f.reloadNote:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", LEFT, 40)
  f.reloadNote:SetPoint("RIGHT", f, "RIGHT", -LEFT, 0)
  safe(f.reloadNote, "SetWordWrap", true)
  f.reloadNote:Hide()

  -- Buttons --------------------------------------------------------------------
  local function button(text, w)
    local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    b:SetSize(w or 96, 22)
    b:SetText(text)
    return b
  end
  f.saveBtn = button(L.saveButton, 120)
  f.saveBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 6)
  f.cancelBtn = button(L.cancelButton)
  f.cancelBtn:SetPoint("RIGHT", f.saveBtn, "LEFT", -4, 0)
  f.defaultsBtn = button(L.defaultsButton)
  f.defaultsBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 6)

  f.saveBtn:SetScript("OnClick", function() f:Save() end)
  f.cancelBtn:SetScript("OnClick", function() f:Hide() end)
  f.defaultsBtn:SetScript("OnClick", function()
    f.draft = Settings.DefaultDraft()
    f:RefreshControls()
  end)

  -- Behaviour --------------------------------------------------------------------
  function f:RefreshControls()
    for _, control in pairs(self.controls) do control.Refresh() end
    self:OnDraftChanged()
  end

  -- Pending changes drive the Save button, the reload note and the
  -- follow-FlareUI lock on the appearance controls.
  function f:OnDraftChanged()
    local changes = Settings.Changes(self.draft)
    local needsReload = Settings.ChangesNeedReload(changes)
    setEnabled(self.saveBtn, #changes > 0)
    self.saveBtn:SetText(needsReload and L.saveReloadButton or L.saveButton)
    if needsReload then
      local names = {}
      for _, c in ipairs(changes) do
        if c.reload then
          local control = self.controls[c.def.key]
          names[#names + 1] = control and control.label or c.def.key
        end
      end
      self.reloadNote:SetText(L.reloadPending:format(table.concat(names, ", ")))
      self.reloadNote:Show()
    else
      self.reloadNote:Hide()
    end

    local flareAvailable = OXPFUI.FlareStyle and OXPFUI.FlareStyle.Available()
    local following = self.draft.followFlareUI == true and flareAvailable
    for _, key in ipairs({ "frameStyle", "font", "borderStyle", "opacity" }) do
      local control = self.controls[key]
      if control then setEnabled(control.widget, not following) end
    end
    -- FlareUI's rules: the border is only a choice in the Custom style, the
    -- opacity in FlareUI and Custom (Blizzard has no background).
    if not following then
      local style = self.draft.frameStyle
      setEnabled(self.controls.borderStyle and self.controls.borderStyle.widget, style == "custom")
      setEnabled(self.controls.opacity and self.controls.opacity.widget, style ~= "blizzard")
    end
    if following then
      self.styleNote:SetText(L.followActiveNote)
    elseif self.draft.followFlareUI == true then
      self.styleNote:SetText(L.flareMissingNote)
    else
      self.styleNote:SetText("")
    end

    -- Live preview: show every change that needs no reload right away.
    local live = false
    for _, c in ipairs(changes) do
      if not c.reload then live = true end
    end
    if live then
      Settings.Preview(self.draft)
    elseif Settings.IsPreviewing() then
      Settings.EndPreview() -- the last live change was undone
    end
  end

  function f:Save()
    local _, reloaded = Settings.Commit(self.draft)
    if not reloaded then self:Hide() end
  end

  -- Every open starts from the saved settings; closing discards the draft.
  f:SetScript("OnShow", function(self)
    self.draft = Settings.NewDraft()
    self:RefreshControls()
  end)
  f:SetScript("OnHide", function(self)
    if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
    Settings.EndPreview() -- no-op after Save (Commit ends the preview)
    self.draft = Settings.NewDraft()
  end)

  f:RefreshControls()
  return f
end

function OXPFUI.OpenPanel()
  if not panel then panel = buildPanel() end
  if panel:IsShown() then
    panel:Raise()
  else
    panel:Show()
  end
  return panel
end

function OXPFUI.Panel() -- for tests and debugging
  return panel
end

-- ---------------------------------------------------------------------------
-- Options > AddOns entry: a short page with a button that opens the window.
-- ---------------------------------------------------------------------------

local function registerOptionsCategory()
  local S = rawget(_G, "Settings")
  if type(S) ~= "table" or type(S.RegisterCanvasLayoutCategory) ~= "function" then return end
  local page = CreateFrame("Frame", "OXPFUIOptionsPage")
  page.name = L.panelTitle
  local title = fontString(page, "GameFontNormalLarge", L.panelTitle)
  title:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -16)
  local desc = fontString(page, "GameFontHighlight", L.optionsDescription)
  desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  desc:SetPoint("RIGHT", page, "RIGHT", -16, 0)
  local open = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
  open:SetSize(200, 24)
  open:SetText(L.openSettingsButton)
  open:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)
  open:SetScript("OnClick", function()
    local sp = rawget(_G, "SettingsPanel")
    if sp and HideUIPanel then pcall(HideUIPanel, sp) end
    OXPFUI.OpenPanel()
  end)
  page.openButton = open
  local category = S.RegisterCanvasLayoutCategory(page, L.panelTitle)
  if type(S.RegisterAddOnCategory) == "function" then S.RegisterAddOnCategory(category) end
  OXPFUI.optionsCategory = category
  OXPFUI.optionsPage = page
end

local ok, err = pcall(registerOptionsCategory)
if not ok and OXPFUI.Log then OXPFUI.Log("error", "options", tostring(err)) end
