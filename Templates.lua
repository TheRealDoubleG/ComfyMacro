ComfyMacro = ComfyMacro or {}
local CM = ComfyMacro

CM.emotes = {
    {id = "wave", en = "Wave", de = "Winken"},
    {id = "dance", en = "Dance", de = "Tanzen"},
    {id = "laugh", en = "Laugh", de = "Lachen"},
    {id = "cheer", en = "Cheer", de = "Jubeln"},
    {id = "bow", en = "Bow", de = "Verbeugen"},
    {id = "salute", en = "Salute", de = "Salutieren"},
}

CM.builderBlockTypes = {
    {id = "showtooltip", labelKey = "BLOCK_SHOWTOOLTIP", explainKey = "EXPL_SHOWTOOLTIP", valueType = "spell"},
    {id = "targetexact", labelKey = "BLOCK_TARGETEXACT", explainKey = "EXPL_TARGETEXACT", valueType = "text"},
    {id = "cast", labelKey = "BLOCK_CAST", explainKey = "EXPL_CAST", valueType = "spell"},
    {id = "mouseover", labelKey = "BLOCK_MOUSEOVER", explainKey = "EXPL_MOUSEOVER", valueType = "spell"},
    {id = "focus", labelKey = "BLOCK_FOCUS", explainKey = "EXPL_FOCUS", valueType = "spell"},
    {id = "self", labelKey = "BLOCK_SELF", explainKey = "EXPL_SELF", valueType = "spell"},
    {id = "trinket13", labelKey = "BLOCK_TRINKET13", explainKey = "EXPL_TRINKET13", valueType = "none"},
    {id = "trinket14", labelKey = "BLOCK_TRINKET14", explainKey = "EXPL_TRINKET14", valueType = "none"},
    {id = "profession", labelKey = "BLOCK_PROFESSION", explainKey = "EXPL_PROFESSION", valueType = "profession"},
    {id = "emote", labelKey = "BLOCK_EMOTE", explainKey = "EXPL_EMOTE", valueType = "emote"},
    {id = "say", labelKey = "BLOCK_SAY", explainKey = "EXPL_SAY", valueType = "text"},
    {id = "yell", labelKey = "BLOCK_YELL", explainKey = "EXPL_YELL", valueType = "text"},
}

function CM:GetBlockType(id)
    for _, block in ipairs(self.builderBlockTypes) do
        if block.id == id then return block end
    end
end

function CM:GetBlockLabel(id)
    local block = self:GetBlockType(id)
    return block and self:T(block.labelKey) or tostring(id)
end

function CM:GetBlockExplanation(id)
    local block = self:GetBlockType(id)
    return block and self:T(block.explainKey) or ""
end

function CM:GetEmoteLabel(entry)
    if GetLocale and GetLocale() == "deDE" then return entry.de end
    return entry.en
end

function CM:BuildBlockLine(block)
    if not block then return nil end
    local kind = block.type
    local value = tostring(block.value or "")

    if kind == "showtooltip" then
        if value ~= "" then return "#showtooltip " .. value end
        return "#showtooltip"
    elseif kind == "targetexact" then
        if value ~= "" then return "/targetexact " .. value end
    elseif kind == "cast" then
        if value ~= "" then return "/cast " .. value end
    elseif kind == "mouseover" then
        if value ~= "" then return "/cast [@mouseover,help,nodead][] " .. value end
    elseif kind == "focus" then
        if value ~= "" then return "/cast [@focus,help,nodead][] " .. value end
    elseif kind == "self" then
        if value ~= "" then return "/cast [@player] " .. value end
    elseif kind == "trinket13" then
        return "/use 13"
    elseif kind == "trinket14" then
        return "/use 14"
    elseif kind == "profession" then
        if value ~= "" then return "/cast " .. value end
    elseif kind == "emote" then
        if value ~= "" then return "/" .. value end
    elseif kind == "say" then
        if value ~= "" then return "/s " .. value end
    elseif kind == "yell" then
        if value ~= "" then return "/y " .. value end
    end
end

function CM:BuildBuilderBody()
    local lines = {}
    local hasShowTooltip = false
    local primary = nil

    for _, block in ipairs(self.builder.blocks or {}) do
        if block.type == "showtooltip" then hasShowTooltip = true end
        if not primary and (block.type == "cast" or block.type == "mouseover" or block.type == "focus" or block.type == "self" or block.type == "profession") then
            if block.value and block.value ~= "" then primary = block.value end
        end
    end

    -- A spell/profession block automatically gets #showtooltip so the default
    -- question-mark macro icon becomes the spell icon. Custom macro icons still
    -- remain selectable through the icon picker.
    if primary and not hasShowTooltip then
        lines[#lines + 1] = "#showtooltip " .. primary
    end

    for _, block in ipairs(self.builder.blocks or {}) do
        local line = self:BuildBlockLine(block)
        if line and line ~= "" then lines[#lines + 1] = line end
    end
    return table.concat(lines, "\n")
end

function CM:GetBuilderPrimarySpell()
    for _, block in ipairs(self.builder.blocks or {}) do
        if block.type == "showtooltip" and block.value and block.value ~= "" then return block.value end
    end
    for _, block in ipairs(self.builder.blocks or {}) do
        if (block.type == "cast" or block.type == "mouseover" or block.type == "focus" or block.type == "self" or block.type == "profession")
            and block.value and block.value ~= "" then
            return block.value
        end
    end
    return nil
end

function CM:AddBuilderBlock(kind, value)
    self.builder.blocks = self.builder.blocks or {}
    self.builder.blocks[#self.builder.blocks + 1] = {type = kind, value = value}
    if self.RefreshBuilderUI then self:RefreshBuilderUI() end
end

function CM:UndoBuilderBlock()
    if self.builder.blocks and #self.builder.blocks > 0 then
        table.remove(self.builder.blocks)
    end
    if self.RefreshBuilderUI then self:RefreshBuilderUI() end
end

function CM:ClearBuilder()
    self.builder.blocks = {}
    self.builder.autoIcon = true
    self.builder.customIcon = nil
    if self.RefreshBuilderUI then self:RefreshBuilderUI() end
end

function CM:InitializeTemplates()
    self.templates = {
        {id = "tankheal", labelKey = "TEMPLATE_TANK_HEAL", category = "heal", targetMode = "player"},
        {id = "mouseoverheal", labelKey = "TEMPLATE_MOUSEOVER_HEAL", category = "heal", targetMode = "mouseover"},
        {id = "burst", labelKey = "TEMPLATE_BURST", category = "burst"},
        {id = "profession", labelKey = "TEMPLATE_PROFESSION", category = "profession"},
        {id = "wave", labelKey = "TEMPLATE_WAVE", category = "emote", emote = "wave"},
        {id = "yell", labelKey = "TEMPLATE_YELL", category = "chat", channel = "yell"},
    }
end
