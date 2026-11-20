-- Fake Blizzard UI templates and Settings API for the OXP-FUI panel tests.
--
-- Mirrors just the parts of the Forever client's shared templates the
-- settings window uses (wow-ui-source, branch `forever`):
--
--   ButtonFrameTemplate                SharedUIPanelTemplates.xml (Inset, CloseButton, SetTitle)
--   UIPanelButtonTemplate              SharedUIPanelTemplates.xml (text, enabled state)
--   UICheckButtonTemplate              CheckButtonTemplates.xml (.Text; a click toggles, then OnClick)
--   WowStyle1DropdownTemplate          Blizzard_Menu (SetupMenu / GenerateMenu / CreateRadio)
--   MinimalSliderWithSteppersTemplate  MinimalSlider.lua (Init, RegisterCallback, Label/Event enums)
--   InputBoxTemplate                   InputBoxTemplates.xml (numeric EditBox)
--   Settings.RegisterCanvasLayoutCategory / RegisterAddOnCategory
--
-- Test drivers: HARNESS.PickDropdown(dd, text), HARNESS.TypeInto(editBox, text),
-- HARNESS.Hover(widget), HARNESS.TooltipText().

local baseCreateFrame = CreateFrame

local function addEnabledState(w)
  w.__enabled = true
  rawset(w, "SetEnabled", function(self, v) self.__enabled = v and true or false end)
  rawset(w, "IsEnabled", function(self) return self.__enabled ~= false end)
  rawset(w, "Enable", function(self) self.__enabled = true end)
  rawset(w, "Disable", function(self) self.__enabled = false end)
end

local function addText(w, fontObject)
  w.Text = w:CreateFontString(nil, "ARTWORK", fontObject)
  rawset(w, "SetText", function(self, t) self.Text:SetText(t) end)
  rawset(w, "GetText", function(self) return self.Text:GetText() end)
end

local templates = {}

templates.ButtonFrameTemplate = function(f)
  f.Inset = baseCreateFrame("Frame", nil, f)
  f.Bg = f:CreateTexture(nil, "BACKGROUND")
  f.TitleContainer = baseCreateFrame("Frame", nil, f)
  f.TitleContainer.TitleText = f.TitleContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  rawset(f, "SetTitle", function(self, t) self.TitleContainer.TitleText:SetText(t) end)
  rawset(f, "GetTitleText", function(self) return self.TitleContainer.TitleText end)
  rawset(f, "SetBorder", function(self, b) self.__border = b end)
  rawset(f, "SetPortraitShown", function(self, v) self.__portrait = v end)
  f.CloseButton = baseCreateFrame("Button", nil, f)
  f.CloseButton:SetScript("OnClick", function(self) self:GetParent():Hide() end)
  -- Real client: Show/Hide fire OnShow/OnHide.
  local origShow, origHide = f.Show, f.Hide
  rawset(f, "Show", function(self)
    if self:IsShown() then return end
    origShow(self)
    local fn = self:GetScript("OnShow"); if fn then fn(self) end
  end)
  rawset(f, "Hide", function(self)
    if not self:IsShown() then return end
    origHide(self)
    local fn = self:GetScript("OnHide"); if fn then fn(self) end
  end)
end

templates.UIPanelButtonTemplate = function(b)
  addText(b, "GameFontNormal")
  addEnabledState(b)
  local click = b.Click
  rawset(b, "Click", function(self, ...)
    if self:IsEnabled() then click(self, ...) end
  end)
end

templates.UICheckButtonTemplate = function(cb)
  cb.Text = cb:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  cb.text = cb.Text
  addEnabledState(cb)
  local click = cb.Click
  rawset(cb, "Click", function(self, ...)
    if not self:IsEnabled() then return end
    self:SetChecked(not self:GetChecked())
    click(self, ...)
  end)
end

templates.WowStyle1DropdownTemplate = function(dd)
  addEnabledState(dd)
  dd.Text = dd:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  dd.__radios = {}
  rawset(dd, "SetDefaultText", function(self, t) self.__defaultText = t end)
  rawset(dd, "SetupMenu", function(self, gen)
    self.__generator = gen
    self:GenerateMenu()
  end)
  rawset(dd, "GenerateMenu", function(self)
    local radios = {}
    local root = {}
    function root:CreateRadio(text, isSelected, setSelected, data)
      radios[#radios + 1] = { text = text, isSelected = isSelected, setSelected = setSelected, data = data }
      return radios[#radios]
    end
    if self.__generator then self.__generator(self, root) end
    self.__radios = radios
    local shown = self.__defaultText
    for _, r in ipairs(radios) do
      if r.isSelected(r.data) then shown = r.text end
    end
    self.Text:SetText(shown or "")
  end)
  rawset(dd, "GetText", function(self) return self.Text:GetText() end)
  rawset(dd, "Options", function(self)
    local out = {}
    for _, r in ipairs(self.__radios) do out[#out + 1] = r.text end
    return out
  end)
end

templates.MinimalSliderWithSteppersTemplate = function(sl)
  addEnabledState(sl)
  sl.Slider = baseCreateFrame("Slider", nil, sl)
  sl.Labels = {}
  for id, key in ipairs({ "LeftText", "RightText", "TopText", "MinText", "MaxText" }) do
    sl[key] = sl:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sl.Labels[id] = sl[key]
  end
  sl.__callbacks = {}
  local function format(self, value)
    if not self.formatters then return end
    for id, fn in pairs(self.formatters) do
      if self.Labels[id] then self.Labels[id]:SetText(fn(value)) end
    end
  end
  rawset(sl, "Init", function(self, value, lo, hi, steps, formatters)
    self.Slider:SetScript("OnValueChanged", nil)
    self.Slider:SetMinMaxValues(lo, hi)
    self.Slider:SetValueStep((hi - lo) / steps)
    self.Slider:SetValue(value)
    self.formatters = formatters
    format(self, value)
    self.Slider:SetScript("OnValueChanged", function(_, v)
      format(self, v)
      for _, cb in ipairs(self.__callbacks) do
        if cb.event == "OnValueChanged" then cb.fn(cb.owner, v) end
      end
    end)
  end)
  rawset(sl, "RegisterCallback", function(self, event, fn, owner)
    self.__callbacks[#self.__callbacks + 1] = { event = event, fn = fn, owner = owner }
  end)
  rawset(sl, "SetValue", function(self, v) self.Slider:SetValue(v) end)
  rawset(sl, "GetValue", function(self) return self.Slider:GetValue() end)
end

templates.InputBoxTemplate = function(eb)
  eb.__fontObject = "ChatFontNormal" -- InputBoxVisualTemplate's FontString
  rawset(eb, "SetNumeric", function(self, v) self.__numeric = v end)
  rawset(eb, "SetMaxLetters", function(self, n) self.__maxLetters = n end)
end

MinimalSliderWithSteppersMixin = {
  Event = { OnValueChanged = "OnValueChanged" },
  Label = { Left = 1, Right = 2, Top = 3, Min = 4, Max = 5 },
}

function ButtonFrameTemplate_HidePortrait(self)
  self:SetBorder("ButtonFrameTemplateNoPortrait")
  self:SetPortraitShown(false)
end

function CreateFrame(frameType, name, parent, template, id)
  local base = frameType == "DropdownButton" and "Button" or frameType
  local f = baseCreateFrame(base, name, parent, template, id)
  if frameType == "DropdownButton" then f.__type = "DropdownButton" end
  if type(template) == "string" then
    for t in template:gmatch("[^,%s]+") do
      if templates[t] then templates[t](f) end
    end
  end
  return f
end

-- Tooltip owner/title API used by the panel's hover help.
rawset(GameTooltip, "SetOwner", function(self, owner, anchor) self.__owner = owner end)
rawset(GameTooltip, "GetOwner", function(self) return self.__owner end)
rawset(GameTooltip, "SetText", function(self, text, r, g, b)
  self:ClearLines()
  self:AddLine(text, r, g, b)
end)

function HARNESS.Hover(widget)
  local fn = widget:GetScript("OnEnter")
  if fn then fn(widget) end
end

function HARNESS.TooltipText()
  local lines = {}
  for i = 1, GameTooltip:NumLines() do
    local fs = _G["GameTooltipTextLeft" .. i]
    lines[#lines + 1] = fs and fs:GetText() or ""
  end
  return table.concat(lines, "\n")
end

function HARNESS.PickDropdown(dd, text)
  if not dd:IsEnabled() then return false end
  for _, r in ipairs(dd.__radios) do
    if r.text == text then
      r.setSelected(r.data)
      dd:GenerateMenu()
      return true
    end
  end
  error("harness: dropdown has no option " .. tostring(text))
end

function HARNESS.TypeInto(eb, text)
  eb:SetText(text)
  local fn = eb:GetScript("OnEnterPressed")
  if fn then fn(eb) end
end

-- Blizzard Settings (Options > AddOns).
HARNESS.optionsCategories = {}
Settings = {
  RegisterCanvasLayoutCategory = function(frame, name)
    local c = { ID = name, frame = frame, name = name }
    HARNESS.optionsCategories[#HARNESS.optionsCategories + 1] = c
    return c
  end,
  RegisterAddOnCategory = function(c) c.registered = true end,
}
function HideUIPanel(f) if f and f.Hide then f:Hide() end end

-- Atlas info for the quest tracker strips (sizes are test values; the real
-- ones come from the game).
HARNESS.atlases = {
  ["ui-questtracker-primary-objective-header"] = { file = "Interface\\QuestFrame\\ObjectiveTracker",
    width = 300, height = 40, leftTexCoord = 0, rightTexCoord = 0.5, topTexCoord = 0, bottomTexCoord = 0.25 },
  ["UI-QuestTracker-Secondary-Objective-Header"] = { file = "Interface\\QuestFrame\\ObjectiveTracker",
    width = 280, height = 24, leftTexCoord = 0, rightTexCoord = 0.5, topTexCoord = 0.25, bottomTexCoord = 0.4 },
}
C_Texture = C_Texture or {}
C_Texture.GetAtlasInfo = function(atlas) return HARNESS.atlases[atlas] end
