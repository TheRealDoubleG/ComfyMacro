ComfyMacro = ComfyMacro or {}
local CM = ComfyMacro

local controls = {}
local builderType = "cast"
local builderValue = ""
local builderSpell = nil
local builderProfession = nil
local builderEmote = "wave"
local assistantChoiceOffset = 0
local macroPage = 1
local MACROS_PER_PAGE = 10

local function SetLabel(check, text)
    local label = check.Text or check.text
    if not label then
        label = check:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("LEFT", check, "RIGHT", 3, 1)
        check.Text = label
    end
    label:SetText(text)
end

local function CreateButton(parent, text, x, y, width, func)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 140, 24)
    button:SetPoint("TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", func)
    return button
end

local function CreateCheck(parent, text, x, y, getter, setter)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    SetLabel(cb, text)
    cb:SetScript("OnClick", function(self)
        setter(self:GetChecked() and true or false)
        CM:RefreshOptions()
    end)
    cb._getter = getter
    controls[#controls + 1] = cb
    return cb
end

local function CreateEdit(parent, x, y, width, height, multi)
    local template = multi and "BackdropTemplate" or "InputBoxTemplate"
    local edit = CreateFrame("EditBox", nil, parent, template)
    edit:SetPoint("TOPLEFT", x, y)
    edit:SetSize(width, height or 28)
    edit:SetAutoFocus(false)
    edit:SetMultiLine(multi and true or false)
    edit:SetFontObject(multi and ChatFontNormal or GameFontHighlight)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    if multi then
        edit:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = {left = 4, right = 4, top = 4, bottom = 4},
        })
        edit:SetBackdropColor(0.03, 0.03, 0.03, 0.92)
        edit:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.9)
        edit:SetJustifyH("LEFT")
        edit:SetJustifyV("TOP")
        if edit.SetTextInsets then edit:SetTextInsets(8, 8, 8, 8) end
    end

    return edit
end

local function DropdownSetText(dropdown, text)
    if UIDropDownMenu_SetText then UIDropDownMenu_SetText(dropdown, text) end
end

local function CreateDropdown(parent, x, y, width, getItems, onSelect, getCurrent)
    local dd = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", x, y)
    if UIDropDownMenu_SetWidth then UIDropDownMenu_SetWidth(dd, width or 220) end

    UIDropDownMenu_Initialize(dd, function(_, level)
        for _, entry in ipairs(getItems() or {}) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = entry.text or entry.label or tostring(entry.value)
            info.value = entry.value
            info.checked = entry.value == getCurrent()
            info.func = function()
                onSelect(entry.value)
                CloseDropDownMenus()
                if dd._refresh then dd._refresh() end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    dd._refresh = function()
        local current = getCurrent()
        local label = tostring(current or "")
        for _, entry in ipairs(getItems() or {}) do
            if entry.value == current then label = entry.text or entry.label or label break end
        end
        DropdownSetText(dd, label)
    end
    return dd
end

local function SetReadOnlyText(edit, text)
    if not edit then return end
    text = tostring(text or "")
    if edit:GetText() ~= text then
        edit._setting = true
        edit:SetText(text)
        edit:SetCursorPosition(0)
        edit._setting = false
    end
end

local function SelectTab(index)
    local frame = CM.optionsFrame
    if not frame then return end
    for i, tab in ipairs(frame.tabs) do
        tab:SetEnabled(true)
        tab:SetButtonState(i == index and "PUSHED" or "NORMAL", i == index)
        frame.pages[i]:SetShown(i == index)
    end
    CM.currentOptionsTab = index
    if index == 2 then CM:RefreshAssistantUI() end
    if index == 4 then CM:RefreshMacroListUI() end
end

function CM:SelectOptionsTab(index)
    SelectTab(index)
end

local function CreateExplanationBox(parent)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box:SetPoint("BOTTOMLEFT", 20, 10)
    box:SetSize(820, 112)
    box:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = {left = 5, right = 5, top = 5, bottom = 5},
    })
    local title = box:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText(CM:T("EXPLANATION"))
    local text = box:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", 12, -34)
    text:SetWidth(790)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    box.text = text
    return box
end

function CM:GetBuilderValueForCurrentType()
    local block = self:GetBlockType(builderType)
    if not block then return nil end
    if block.valueType == "spell" then return builderSpell
    elseif block.valueType == "profession" then return builderProfession
    elseif block.valueType == "emote" then return builderEmote
    elseif block.valueType == "text" then return builderValue end
    return nil
end

function CM:RefreshBuilderUI()
    if not self.builderPage then return end
    local block = self:GetBlockType(builderType)
    if self.builderTypeDropdown and self.builderTypeDropdown._refresh then self.builderTypeDropdown._refresh() end
    if self.builderSpellDropdown and self.builderSpellDropdown._refresh then self.builderSpellDropdown._refresh() end
    if self.builderProfessionDropdown and self.builderProfessionDropdown._refresh then self.builderProfessionDropdown._refresh() end
    if self.builderEmoteDropdown and self.builderEmoteDropdown._refresh then self.builderEmoteDropdown._refresh() end

    if self.builderTextEdit then
        self.builderTextEdit:SetShown(block and block.valueType == "text")
        if block and block.valueType == "text" and not self.builderTextEdit:HasFocus() then
            self.builderTextEdit:SetText(builderValue or "")
        end
    end
    if self.builderSpellDropdown then self.builderSpellDropdown:SetShown(block and block.valueType == "spell") end
    if self.builderProfessionDropdown then self.builderProfessionDropdown:SetShown(block and block.valueType == "profession") end
    if self.builderEmoteDropdown then self.builderEmoteDropdown:SetShown(block and block.valueType == "emote") end

    local body = self:BuildBuilderBody()
    SetReadOnlyText(self.builderPreview, body ~= "" and body or self:T("EMPTY_PREVIEW"))
    if self.builderExplanation then
        local validation, analysis=self:GetValidationText(body)
        local explanation=analysis.explanation:gsub("\n","  ")
        self.builderExplanation.text:SetText(self:GetBlockExplanation(builderType).."\n"..self:T("EXPLAIN_SUMMARY")..": "..explanation.."\n"..self:T("VALIDATION_TITLE")..": "..validation:gsub("\n","  "))
    end

    if self.builderIconState then
        self.builderIconState:SetText(self.builder.autoIcon and self:T("ICON_AUTOMATIC") or self:T("ICON_CUSTOM"))
    end

    if self.builderBlocksText then
        local labels = {}
        for i, item in ipairs(self.builder.blocks or {}) do
            labels[#labels + 1] = string.format("%d. %s%s", i, self:GetBlockLabel(item.type), item.value and item.value ~= "" and (" — " .. item.value) or "")
        end
        self.builderBlocksText:SetText(#labels > 0 and table.concat(labels, "\n") or self:T("EMPTY_PREVIEW"))
    end
end

function CM:RefreshAssistantUI()
    if not self.assistantPage or not self.assistant then return end
    self.assistantPrompt:SetText(self:GetAssistantPrompt())
    local step = self.assistant.step
    local choices = self:GetAssistantChoices()
    local isText = step == "playername" or step == "chattext"
    local isFinal = step == "final"

    self.assistantTextEdit:SetShown(isText)
    self.assistantNextButton:SetShown(isText)
    self.assistantCreateButton:SetShown(isFinal)
    self.assistantIconButton:SetShown(isFinal)
    self.assistantAutoIconButton:SetShown(isFinal)
    self.assistantNameEdit:SetShown(isFinal)
    self.assistantNameLabel:SetShown(isFinal)

    if isFinal and not self.assistantNameEdit:HasFocus() then
        local current = self.assistantNameEdit:GetText()
        if current == "" or current == "ComfyMacro" then
            self.assistantNameEdit:SetText(self:GetAssistantDefaultName())
        end
    end

    if isText and not self.assistantTextEdit:HasFocus() then
        self.assistantTextEdit:SetText("")
    end

    local visibleChoices = math.min(6, #choices)
    if assistantChoiceOffset > math.max(0, #choices - 6) then assistantChoiceOffset = math.max(0, #choices - 6) end

    for i, button in ipairs(self.assistantChoiceButtons) do
        local entry = choices[i + assistantChoiceOffset]
        if entry and not isText and not isFinal then
            button:SetText(entry.label)
            button._value = entry.value
            button:Show()
        else
            button:Hide()
        end
    end

    self.assistantChoicePrev:SetShown(#choices > 6 and assistantChoiceOffset > 0 and not isText and not isFinal)
    self.assistantChoiceNext:SetShown(#choices > 6 and assistantChoiceOffset + 6 < #choices and not isText and not isFinal)

    local body = self:BuildAssistantBody()
    SetReadOnlyText(self.assistantPreview, body ~= "" and body or self:T("EMPTY_PREVIEW"))
    local validation,analysis=self:GetValidationText(body)
    if isFinal then
        self.assistantExplanation.text:SetText(self:T("EXPLAIN_SUMMARY")..": "..analysis.explanation:gsub("\n","  ").."\n"..self:T("VALIDATION_TITLE")..": "..validation:gsub("\n","  "))
    else
        self.assistantExplanation.text:SetText(self:GetAssistantExplanation().."\n"..self:T("VALIDATION_TITLE")..": "..validation:gsub("\n","  "))
    end
end

function CM:OpenIconPicker(target)
    if not self.iconPicker then return end
    self.iconPickerTarget = target
    self.iconPickerPage = 1
    self:RefreshIconPicker()
    self.iconPicker:Show()
    self.iconPicker:Raise()
end

function CM:RefreshIconPicker()
    if not self.iconPicker then return end
    local icons = self:GetMacroIconsList()
    local perPage = #self.iconPicker.buttons
    local page = self.iconPickerPage or 1
    local pages = math.max(1, math.ceil(#icons / perPage))
    if page > pages then page = pages end
    if page < 1 then page = 1 end
    self.iconPickerPage = page

    for i, button in ipairs(self.iconPicker.buttons) do
        local icon = icons[(page - 1) * perPage + i]
        if icon then
            button.icon:SetTexture(icon)
            button._icon = icon
            button:Show()
        else
            button:Hide()
        end
    end
    self.iconPicker.pageText:SetText(page .. " / " .. pages)
end

function CM:ChooseCustomIcon(icon)
    if self.iconPickerTarget == "assistant" then
        self.assistant.state.autoIcon = false
        self.assistant.state.customIcon = icon
    else
        self.builder.autoIcon = false
        self.builder.customIcon = icon
    end
    self.iconPicker:Hide()
    self:RefreshOptions()
end

function CM:GetBuilderMacroIcon()
    if self.builder.autoIcon then return self:GetAutoIcon() end
    return self.builder.customIcon or self:GetAutoIcon()
end

function CM:GetAssistantMacroIcon()
    if self.assistant.state.autoIcon then return self:GetAutoIcon() end
    return self.assistant.state.customIcon or self:GetAutoIcon()
end

function CM:CreateBuilderMacro()
    local name = self.builderNameEdit and self.builderNameEdit:GetText() or self.builder.name
    local body = self:BuildBuilderBody()
    self.builder.name = name
    self:CreateMacroCompat(name, self:GetBuilderMacroIcon(), body, self.builder.perCharacter)
end

function CM:CreateAssistantMacro()
    local name = self.assistantNameEdit and self.assistantNameEdit:GetText() or self:GetAssistantDefaultName()
    self:CreateMacroCompat(name, self:GetAssistantMacroIcon(), self:BuildAssistantBody(), true)
end

function CM:RefreshMacroListUI()
    if not self.macroRows then return end
    self.macroList = self:GetMacroList()
    local pages = math.max(1, math.ceil(#self.macroList / MACROS_PER_PAGE))
    if macroPage > pages then macroPage = pages end
    if macroPage < 1 then macroPage = 1 end

    for i, row in ipairs(self.macroRows) do
        local macro = self.macroList[(macroPage - 1) * MACROS_PER_PAGE + i]
        row._macro = macro
        if macro then
            row:SetText((macro.scope == "character" and "[C] " or "[A] ") .. macro.name)
            row:Show()
        else
            row:Hide()
        end
    end

    if self.macroPageText then self.macroPageText:SetText(macroPage .. " / " .. pages) end
end

function CM:SelectExistingMacro(macro)
    self.selectedMacro = macro
    if not macro then return end
    self.existingMacroName:SetText(macro.name)
    self.existingMacroBody:SetText(macro.body or "")
    self.existingMacroBody:SetCursorPosition(0)
    self.existingMacroScope:SetText(macro.scope == "character" and self:T("CHARACTER") or self:T("ACCOUNT"))
end

function CM:RefreshOptions()
    if not self.optionsFrame then return end
    for _, control in ipairs(controls) do
        if control._getter then control:SetChecked(control._getter() and true or false) end
    end
    self:RefreshBuilderUI()
    self:RefreshAssistantUI()
    self:RefreshMacroListUI()
    if self.RefreshSharedSettingsPage then self:RefreshSharedSettingsPage() end
end

function CM:RegisterBlizzardSettingsCategory()
    if self.settingsCategory then return end
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end

    local canvas = CreateFrame("Frame")
    local isDE = type(GetLocale) == "function" and GetLocale() == "deDE"

    local title = canvas:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("ComfyMacro")

    local desc = canvas:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    desc:SetWidth(520)
    desc:SetJustifyH("LEFT")
    desc:SetText(isDE
        and "Öffnet das vollständige ComfyMacro-Einstellungsfenster der Comfy Suite."
        or "Opens the full ComfyMacro settings window for the Comfy Suite.")

    CreateButton(canvas, isDE and "Einstellungen öffnen" or "Open settings", 16, -90, 220, function()
        CM:ShowOptions()
    end)

    local category = Settings.RegisterCanvasLayoutCategory(canvas, "ComfyMacro")
    Settings.RegisterAddOnCategory(category)
    self.settingsCategory = category
end

function CM:InitializeOptions()
    if self.optionsFrame then return end

    local frame = CreateFrame("Frame", "ComfyMacroOptions", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(920, 660)
    local saved = self.db and self.db.optionsWindow or nil
    local point = saved and saved.point or "CENTER"
    local relativePoint = saved and saved.relativePoint or point
    frame:SetPoint(point, UIParent, relativePoint, saved and saved.x or 0, saved and saved.y or 10)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(20)
    if frame.SetToplevel then frame:SetToplevel(true) end
    frame:Hide()
    frame.TitleText:SetText("ComfyMacro")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnMouseDown", function(self) self:Raise() end)
    frame:SetScript("OnDragStart", function(self)
        if CM:IsOptionsWindowLocked() then return end
        self:Raise()
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint(1)
        if CM.db and p then
            CM.db.optionsWindow.point = p
            CM.db.optionsWindow.relativePoint = rp or p
            CM.db.optionsWindow.x = x or 0
            CM.db.optionsWindow.y = y or 0
        end
    end)
    table.insert(UISpecialFrames, frame:GetName())

    self.optionsFrame = frame
    frame.tabs, frame.pages = {}, {}

    local tabs = {
        self:T("TAB_BUILDER"),
        self:T("TAB_ASSISTANT"),
        self:T("TAB_TEMPLATES"),
        self:T("TAB_MY_MACROS"),
        self:GetSharedSettingsTabLabel(),
        self:T("TAB_INFO"),
    }

    for i, label in ipairs(tabs) do
        local tab = CreateButton(frame, label, 18 + (i - 1) * 120, -35, 110, function() SelectTab(i) end)
        frame.tabs[i] = tab
        local page = CreateFrame("Frame", nil, frame)
        page:SetPoint("TOPLEFT", 12, -70)
        page:SetPoint("BOTTOMRIGHT", -12, 12)
        frame.pages[i] = page
    end

    -- BUILDER
    local builder = frame.pages[1]
    self.builderPage = builder

    local btitle = builder:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    btitle:SetPoint("TOPLEFT", 20, -10)
    btitle:SetText(self:T("TAB_BUILDER"))

    local nameLabel = builder:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", 20, -48)
    nameLabel:SetText(self:T("MACRO_NAME"))

    self.builderNameEdit = CreateEdit(builder, 20, -68, 190, 28, false)
    self.builderNameEdit:SetText(self.builder.name or "ComfyMacro")

    local typeLabel = builder:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    typeLabel:SetPoint("TOPLEFT", 245, -48)
    typeLabel:SetText(self:T("BLOCK_TYPE"))

    self.builderTypeDropdown = CreateDropdown(builder, 225, -62, 210,
        function()
            local items = {}
            for _, block in ipairs(CM.builderBlockTypes) do
                items[#items + 1] = {value = block.id, text = CM:T(block.labelKey)}
            end
            return items
        end,
        function(value) builderType = value builderValue = "" CM:RefreshBuilderUI() end,
        function() return builderType end)

    local valueLabel = builder:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    valueLabel:SetPoint("TOPLEFT", 475, -48)
    valueLabel:SetText(self:T("BLOCK_VALUE"))

    self.builderSpellDropdown = CreateDropdown(builder, 455, -62, 230,
        function()
            local items = {}
            for _, spell in ipairs(CM:GetKnownSpells()) do items[#items + 1] = {value = spell.name, text = spell.name} end
            if #items == 0 then items[1] = {value = "", text = CM:T("NO_SPELLS")} end
            return items
        end,
        function(value) builderSpell = value CM:RefreshBuilderUI() end,
        function() return builderSpell end)

    self.builderProfessionDropdown = CreateDropdown(builder, 455, -62, 230,
        function()
            local items = {}
            for _, prof in ipairs(CM:GetProfessionsList()) do items[#items + 1] = {value = prof.name, text = prof.name} end
            if #items == 0 then items[1] = {value = "", text = CM:T("NO_PROFESSIONS")} end
            return items
        end,
        function(value) builderProfession = value CM:RefreshBuilderUI() end,
        function() return builderProfession end)

    self.builderEmoteDropdown = CreateDropdown(builder, 455, -62, 230,
        function()
            local items = {}
            for _, emote in ipairs(CM.emotes) do items[#items + 1] = {value = emote.id, text = CM:GetEmoteLabel(emote)} end
            return items
        end,
        function(value) builderEmote = value CM:RefreshBuilderUI() end,
        function() return builderEmote end)

    self.builderTextEdit = CreateEdit(builder, 475, -68, 245, 28, false)
    self.builderTextEdit:SetScript("OnTextChanged", function(self, userInput)
        if userInput then builderValue = self:GetText() end
    end)

    CreateButton(builder, self:T("ADD_BLOCK"), 735, -66, 135, function()
        local value = CM:GetBuilderValueForCurrentType()
        CM:AddBuilderBlock(builderType, value)
    end)

    local blocksTitle = builder:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    blocksTitle:SetPoint("TOPLEFT", 20, -120)
    blocksTitle:SetText(self:T("TAB_BUILDER"))

    self.builderBlocksText = builder:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    self.builderBlocksText:SetPoint("TOPLEFT", 20, -145)
    self.builderBlocksText:SetWidth(350)
    self.builderBlocksText:SetHeight(220)
    self.builderBlocksText:SetJustifyH("LEFT")
    self.builderBlocksText:SetJustifyV("TOP")

    local previewTitle = builder:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    previewTitle:SetPoint("TOPLEFT", 400, -120)
    previewTitle:SetText(self:T("PREVIEW"))

    self.builderPreview = CreateEdit(builder, 400, -145, 460, 205, true)
    self.builderPreview:SetScript("OnTextChanged", function(self, userInput)
        if userInput and not self._setting then SetReadOnlyText(self, CM:BuildBuilderBody()) end
    end)

    CreateButton(builder, self:T("UNDO_BLOCK"), 20, -385, 145, function() CM:UndoBuilderBlock() end)
    CreateButton(builder, self:T("CLEAR"), 175, -385, 100, function() CM:ClearBuilder() end)

    self.builderIconState = builder:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    self.builderIconState:SetPoint("TOPLEFT", 400, -390)
    self.builderIconState:SetWidth(125)
    self.builderIconState:SetJustifyH("LEFT")

    CreateButton(builder, self:T("CUSTOM_ICON"), 525, -385, 145, function() CM:OpenIconPicker("builder") end)
    CreateButton(builder, self:T("RESET_ICON"), 675, -385, 185, function()
        CM.builder.autoIcon = true
        CM.builder.customIcon = nil
        CM:RefreshBuilderUI()
    end)

    CreateButton(builder, self:T("CREATE_MACRO"), 690, -410, 170, function() CM:CreateBuilderMacro() end)
    self.builderExplanation = CreateExplanationBox(builder)

    -- ASSISTANT
    local assistant = frame.pages[2]
    self.assistantPage = assistant

    local atitle = assistant:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    atitle:SetPoint("TOPLEFT", 20, -10)
    atitle:SetText(self:T("TAB_ASSISTANT"))

    self.assistantPrompt = assistant:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    self.assistantPrompt:SetPoint("TOPLEFT", 20, -55)
    self.assistantPrompt:SetWidth(520)
    self.assistantPrompt:SetJustifyH("LEFT")

    self.assistantChoiceButtons = {}
    for i = 1, 6 do
        local button = CreateButton(assistant, "", 20, -100 - (i - 1) * 42, 300, function(self)
            assistantChoiceOffset = 0
            CM:AssistantChoose(self._value)
        end)
        self.assistantChoiceButtons[i] = button
    end

    self.assistantChoicePrev = CreateButton(assistant, "<", 20, -360, 45, function()
        assistantChoiceOffset = math.max(0, assistantChoiceOffset - 6)
        CM:RefreshAssistantUI()
    end)
    self.assistantChoiceNext = CreateButton(assistant, ">", 275, -360, 45, function()
        assistantChoiceOffset = assistantChoiceOffset + 6
        CM:RefreshAssistantUI()
    end)

    self.assistantTextEdit = CreateEdit(assistant, 20, -105, 380, 28, false)
    self.assistantNextButton = CreateButton(assistant, self:T("ASSIST_NEXT"), 415, -103, 100, function()
        CM:AssistantSubmitText(CM.assistantTextEdit:GetText())
    end)

    local apreviewTitle = assistant:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    apreviewTitle:SetPoint("TOPLEFT", 545, -55)
    apreviewTitle:SetText(self:T("PREVIEW"))

    self.assistantPreview = CreateEdit(assistant, 545, -80, 315, 245, true)
    self.assistantPreview:SetScript("OnTextChanged", function(self, userInput)
        if userInput and not self._setting then SetReadOnlyText(self, CM:BuildAssistantBody()) end
    end)

    self.assistantNameLabel = assistant:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    self.assistantNameLabel:SetPoint("TOPLEFT", 545, -345)
    self.assistantNameLabel:SetText(self:T("MACRO_NAME"))

    self.assistantNameEdit = CreateEdit(assistant, 545, -365, 180, 28, false)

    self.assistantIconButton = CreateButton(assistant, self:T("CUSTOM_ICON"), 545, -410, 145, function() CM:OpenIconPicker("assistant") end)
    self.assistantAutoIconButton = CreateButton(assistant, self:T("RESET_ICON"), 700, -410, 160, function()
        CM.assistant.state.autoIcon = true
        CM.assistant.state.customIcon = nil
        CM:RefreshAssistantUI()
    end)
    self.assistantCreateButton = CreateButton(assistant, self:T("CREATE_MACRO"), 690, -420, 170, function() CM:CreateAssistantMacro() end)

    CreateButton(assistant, self:T("ASSIST_BACK"), 20, -405, 100, function() CM:AssistantBack() end)
    CreateButton(assistant, self:T("ASSIST_RESTART"), 130, -405, 130, function()
        assistantChoiceOffset = 0
        CM:ResetAssistant()
    end)

    self.assistantExplanation = CreateExplanationBox(assistant)

    -- TEMPLATES
    local templates = frame.pages[3]
    local ttitle = templates:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    ttitle:SetPoint("TOPLEFT", 20, -10)
    ttitle:SetText(self:T("TAB_TEMPLATES"))

    local thint = templates:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    thint:SetPoint("TOPLEFT", 20, -48)
    thint:SetWidth(800)
    thint:SetJustifyH("LEFT")
    thint:SetText(self:T("TEMPLATE_HINT"))

    for i, template in ipairs(self.templates or {}) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        CreateButton(templates, self:T(template.labelKey), 30 + col * 390, -105 - row * 80, 340, function()
            local seed = {}
            if template.targetMode then seed.targetMode = template.targetMode end
            if template.emote then seed.emote = template.emote end
            if template.channel then seed.channel = template.channel end
            CM:StartAssistant(template.category, seed)
        end)
    end

    local tinfo = templates:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    tinfo:SetPoint("TOPLEFT", 30, -390)
    tinfo:SetWidth(780)
    tinfo:SetJustifyH("LEFT")
    tinfo:SetText("Trinkets, racials and spells still obey WoW's cooldown and one-keypress rules. ComfyMacro only creates normal macros.")

    -- MY MACROS
    local macros = frame.pages[4]
    local mtitle = macros:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    mtitle:SetPoint("TOPLEFT", 20, -10)
    mtitle:SetText(self:T("TAB_MY_MACROS"))

    local mhint = macros:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    mhint:SetPoint("TOPLEFT", 20, -45)
    mhint:SetWidth(830)
    mhint:SetJustifyH("LEFT")
    mhint:SetText(self:T("MY_MACROS_HINT"))

    self.macroRows = {}
    for i = 1, MACROS_PER_PAGE do
        local row = CreateButton(macros, "", 20, -80 - (i - 1) * 38, 300, function(self)
            if self._macro then CM:SelectExistingMacro(self._macro) end
        end)
        self.macroRows[i] = row
    end

    CreateButton(macros, "<", 20, -475, 45, function()
        macroPage = math.max(1, macroPage - 1)
        CM:RefreshMacroListUI()
    end)
    self.macroPageText = macros:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    self.macroPageText:SetPoint("TOPLEFT", 75, -481)
    self.macroPageText:SetWidth(110)
    self.macroPageText:SetJustifyH("CENTER")
    CreateButton(macros, ">", 195, -475, 45, function()
        local pages = math.max(1, math.ceil(#(CM.macroList or {}) / MACROS_PER_PAGE))
        macroPage = math.min(pages, macroPage + 1)
        CM:RefreshMacroListUI()
    end)

    self.existingMacroScope = macros:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    self.existingMacroScope:SetPoint("TOPLEFT", 360, -80)
    self.existingMacroScope:SetWidth(120)
    self.existingMacroScope:SetJustifyH("LEFT")

    self.existingMacroName = CreateEdit(macros, 360, -105, 250, 28, false)
    self.existingMacroBody = CreateEdit(macros, 360, -150, 500, 300, true)

    CreateButton(macros, self:T("UPDATE_MACRO"), 360, -475, 160, function()
        if not CM.selectedMacro then return end
        CM:EditMacroCompat(CM.selectedMacro.index, CM.existingMacroName:GetText(), CM.selectedMacro.icon, CM.existingMacroBody:GetText())
    end)

    CreateButton(macros, self:T("DELETE"), 535, -475, 100, function()
        if CM.selectedMacro then
            CM:DeleteMacroCompat(CM.selectedMacro.index)
            CM.selectedMacro = nil
            CM.existingMacroName:SetText("")
            CM.existingMacroBody:SetText("")
        end
    end)

    CreateButton(macros, self:T("HISTORY_RESTORE"), 650, -475, 205, function()
        if CM.selectedMacro then
            local name=CM.selectedMacro.name
            if CM:RestoreLatestMacroSnapshot(name) then
                local idx=CM:GetMacroIndexByNameCompat(name)
                if idx then
                    local refreshed=CM:GetMacroInfoCompat(idx)
                    if refreshed then
                        refreshed.scope=CM.selectedMacro.scope
                        CM:SelectExistingMacro(refreshed)
                    end
                end
            end
        end
    end)

    -- SETTINGS
    local settingsPage = frame.pages[5]
    self:BuildSharedSettingsPage(settingsPage)

    -- INFO
    local infoPage = frame.pages[6]
    local ititle = infoPage:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    ititle:SetPoint("TOPLEFT", 20, -10)
    ititle:SetText(self:T("INFO_TITLE"))

    local infoBox = CreateFrame("Frame", nil, infoPage, "BackdropTemplate")
    infoBox:SetPoint("TOPLEFT", 20, -52)
    infoBox:SetSize(680, 455)
    infoBox:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = {left = 8, right = 8, top = 8, bottom = 8},
    })

    local addonName = infoBox:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    addonName:SetPoint("TOPLEFT", 28, -26)
    addonName:SetText("ComfyMacro")

    local familyBadge = infoBox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    familyBadge:SetPoint("TOPRIGHT", -28, -30)
    familyBadge:SetText("Comfy Suite")
    familyBadge:SetTextColor(1.00, 0.82, 0.00)

    local tagline = infoBox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    tagline:SetPoint("TOPLEFT", addonName, "BOTTOMLEFT", 0, -7)
    tagline:SetWidth(620)
    tagline:SetJustifyH("LEFT")
    tagline:SetText("Guided in-game macro builder for WoW Forever.")

    local function InfoRow(label, value, y)
        local l = infoBox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        l:SetPoint("TOPLEFT", 28, y)
        l:SetText(label)
        local v = infoBox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        v:SetPoint("TOPLEFT", 185, y)
        v:SetWidth(455)
        v:SetJustifyH("LEFT")
        v:SetText(value or "-")
        return l, v
    end

    local clientVersion, clientBuild, _, clientInterface = CM:GetClientBuildInfo()
    local compatible, compatibilityText = CM:GetCompatibilityStatus()

    InfoRow(self:T("INFO_VERSION"), CM.version, -100)
    InfoRow(self:T("INFO_BUILD_DATE"), CM.buildDate, -122)
    InfoRow(self:T("INFO_STATUS"), CM.status, -144)
    InfoRow(self:T("INFO_CLIENT"), "WoW Forever " .. tostring(clientVersion) .. " / Build " .. tostring(clientBuild) .. " / Interface " .. tostring(clientInterface or "?"), -166)
    InfoRow(self:T("INFO_TESTED_TARGET"), CM.gameVersion .. " / Build " .. CM.targetBuild .. " / Interface " .. tostring(CM.interface), -188)
    local _, compatibilityValue = InfoRow(self:T("INFO_COMPAT_STATUS"), compatibilityText, -210)
    compatibilityValue:SetTextColor(compatible and 0.20 or 1.00, compatible and 1.00 or 0.35, compatible and 0.20 or 0.20)
    InfoRow(self:T("INFO_AUTHOR"), CM.author, -232)

    local discordLabel = infoBox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    discordLabel:SetPoint("TOPLEFT", 28, -257)
    discordLabel:SetText(self:T("INFO_DISCORD"))
    local discordBox = CreateEdit(infoBox, 180, -248, 275, 30, false)
    discordBox:SetText(CM.discord)
    discordBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

    local copyHint = infoBox:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    copyHint:SetPoint("TOPLEFT", 470, -255)
    copyHint:SetWidth(165)
    copyHint:SetText(self:T("INFO_COPY"))

    local githubLabel = infoBox:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    githubLabel:SetPoint("TOPLEFT", 28, -292)
    githubLabel:SetText(self:T("INFO_GITHUB"))
    local githubBox = CreateEdit(infoBox, 180, -283, 395, 30, false)
    githubBox:SetText(CM.github)
    githubBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

    InfoRow(self:T("INFO_COMMANDS"), "/comfymacro  ·  /cm", -328)

    local notice = infoBox:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    notice:SetPoint("TOPLEFT", 28, -345)
    notice:SetWidth(620)
    notice:SetHeight(42)
    notice:SetJustifyH("LEFT")
    notice:SetJustifyV("TOP")
    notice:SetText(self:T("INFO_NOTICE"))

    local copyright = infoBox:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    copyright:SetPoint("BOTTOMLEFT", 28, 48)
    copyright:SetText("© 2026 TheRealDoubleG")

    local thanks = infoBox:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    thanks:SetPoint("BOTTOMLEFT", 28, 16)
    thanks:SetWidth(620)
    thanks:SetJustifyH("LEFT")
    thanks:SetText(self:T("INFO_THANKS"))

    -- ICON PICKER
    local picker = CreateFrame("Frame", "ComfyMacroIconPicker", UIParent, "BasicFrameTemplateWithInset")
    picker:SetSize(420, 390)
    picker:SetPoint("CENTER")
    picker:SetFrameStrata("DIALOG")
    picker:SetFrameLevel(30)
    picker:SetClampedToScreen(true)
    picker:Hide()
    picker.TitleText:SetText(self:T("CUSTOM_ICON"))
    picker.buttons = {}

    for i = 1, 36 do
        local col = (i - 1) % 6
        local row = math.floor((i - 1) / 6)
        local button = CreateFrame("Button", nil, picker)
        button:SetSize(42, 42)
        button:SetPoint("TOPLEFT", 38 + col * 57, -58 - row * 48)
        local tex = button:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        button.icon = tex
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        button:SetScript("OnClick", function(self) if self._icon then CM:ChooseCustomIcon(self._icon) end end)
        picker.buttons[i] = button
    end

    CreateButton(picker, "<", 80, -340, 50, function()
        CM.iconPickerPage = math.max(1, (CM.iconPickerPage or 1) - 1)
        CM:RefreshIconPicker()
    end)
    picker.pageText = picker:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    picker.pageText:SetPoint("TOP", 0, -346)
    CreateButton(picker, ">", 290, -340, 50, function()
        CM.iconPickerPage = (CM.iconPickerPage or 1) + 1
        CM:RefreshIconPicker()
    end)

    self.iconPicker = picker

    frame:SetScript("OnShow", function()
        CM:ApplySharedWindowSettings()
        CM:RefreshKnownData()
        CM:RefreshOptions()
    end)

    self:ApplySharedWindowSettings()
    SelectTab(1)
    self:RefreshOptions()
    self:RegisterBlizzardSettingsCategory()
end

function CM:ShowOptions(tab)
    if not self.optionsFrame then self:InitializeOptions() end
    self.optionsFrame:Show()
    self.optionsFrame:Raise()
    SelectTab(tonumber(tab) or self.currentOptionsTab or 1)
    self:RefreshOptions()
end
