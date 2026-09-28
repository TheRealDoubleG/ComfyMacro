ComfyMacro = ComfyMacro or {}
local CM = ComfyMacro

local AUTO_ICON = "INV_MISC_QUESTIONMARK"

local function IsPassiveSpellSafe(spellID)
    if not spellID then return false end
    if C_Spell and type(C_Spell.IsSpellPassive) == "function" then
        local ok, passive = pcall(C_Spell.IsSpellPassive, spellID)
        if ok then return passive and true or false end
    end
    if type(IsPassiveSpell) == "function" then
        local ok, passive = pcall(IsPassiveSpell, spellID)
        if ok then return passive and true or false end
    end
    return false
end

local function AddUnique(list, seen, name, spellID, icon)
    if not name or name == "" then return end
    if IsPassiveSpellSafe(spellID) then return end
    local key = tostring(name):lower()
    if seen[key] then return end
    seen[key] = true
    list[#list + 1] = {
        name = tostring(name),
        spellID = tonumber(spellID),
        icon = icon,
    }
end

function CM:GetAutoIcon()
    return AUTO_ICON
end

function CM:GetSpellNameSafe(spellID)
    if not spellID then return nil end
    if C_Spell and type(C_Spell.GetSpellName) == "function" then
        local name = self:SafeCall(C_Spell.GetSpellName, spellID)
        if name then return name end
    end
    if C_Spell and type(C_Spell.GetSpellInfo) == "function" then
        local info = self:SafeCall(C_Spell.GetSpellInfo, spellID)
        if type(info) == "table" and info.name then return info.name end
    end
    if type(GetSpellInfo) == "function" then
        local name = self:SafeCall(GetSpellInfo, spellID)
        if name then return name end
    end
    return nil
end

function CM:GetSpellTextureSafe(spellID)
    if not spellID then return nil end
    if C_Spell and type(C_Spell.GetSpellTexture) == "function" then
        local texture = self:SafeCall(C_Spell.GetSpellTexture, spellID)
        if texture then return texture end
    end
    if type(GetSpellTexture) == "function" then
        local texture = self:SafeCall(GetSpellTexture, spellID)
        if texture then return texture end
    end
    return nil
end

function CM:BuildKnownSpellList()
    local list, seen = {}, {}

    if C_SpellBook and type(C_SpellBook.GetNumSpellBookSkillLines) == "function"
        and type(C_SpellBook.GetSpellBookSkillLineInfo) == "function"
        and type(C_SpellBook.GetSpellBookItemInfo) == "function" then

        local count = tonumber(self:SafeCall(C_SpellBook.GetNumSpellBookSkillLines)) or 0
        local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or nil

        for lineIndex = 1, count do
            local line = self:SafeCall(C_SpellBook.GetSpellBookSkillLineInfo, lineIndex)
            if type(line) == "table" then
                local offset = tonumber(line.itemIndexOffset) or 0
                local numItems = tonumber(line.numSpellBookItems) or 0
                for slot = offset + 1, offset + numItems do
                    local info
                    if bank ~= nil then
                        info = self:SafeCall(C_SpellBook.GetSpellBookItemInfo, slot, bank)
                    else
                        info = self:SafeCall(C_SpellBook.GetSpellBookItemInfo, slot)
                    end
                    if type(info) == "table" then
                        local spellID = tonumber(info.spellID or info.actionID)
                        local name = info.name or self:GetSpellNameSafe(spellID)
                        local icon = info.iconID or self:GetSpellTextureSafe(spellID)
                        AddUnique(list, seen, name, spellID, icon)
                    end
                end
            end
        end
    end

    if #list == 0 and type(GetNumSpellTabs) == "function" and type(GetSpellTabInfo) == "function" then
        local tabs = tonumber(self:SafeCall(GetNumSpellTabs)) or 0
        local bookType = _G.BOOKTYPE_SPELL or "spell"

        for tab = 1, tabs do
            local _, _, offset, numSpells = self:SafeCall(GetSpellTabInfo, tab)
            offset = tonumber(offset) or 0
            numSpells = tonumber(numSpells) or 0

            for slot = offset + 1, offset + numSpells do
                local name
                if type(GetSpellBookItemName) == "function" then
                    name = self:SafeCall(GetSpellBookItemName, slot, bookType)
                end

                local spellID
                if type(GetSpellBookItemInfo) == "function" then
                    local _, id = self:SafeCall(GetSpellBookItemInfo, slot, bookType)
                    spellID = tonumber(id)
                end

                if not name and spellID then name = self:GetSpellNameSafe(spellID) end

                local icon
                if type(GetSpellBookItemTexture) == "function" then
                    icon = self:SafeCall(GetSpellBookItemTexture, slot, bookType)
                end
                if not icon and spellID then icon = self:GetSpellTextureSafe(spellID) end

                AddUnique(list, seen, name, spellID, icon)
            end
        end
    end

    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
    self.knownSpells = list
    return list
end

function CM:GetKnownSpells(refresh)
    if refresh or not self.knownSpells then return self:BuildKnownSpellList() end
    return self.knownSpells
end

function CM:BuildProfessionList()
    local list, seen = {}, {}

    if type(GetProfessions) == "function" and type(GetProfessionInfo) == "function" then
        local professions = {self:SafeCall(GetProfessions)}
        for _, index in ipairs(professions) do
            if index then
                local name, icon = self:SafeCall(GetProfessionInfo, index)
                if name and not seen[name] then
                    seen[name] = true
                    list[#list + 1] = {name = tostring(name), icon = icon}
                end
            end
        end
    end

    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
    self.professions = list
    return list
end

function CM:GetProfessionsList(refresh)
    if refresh or not self.professions then return self:BuildProfessionList() end
    return self.professions
end

function CM:RefreshKnownData()
    self:BuildKnownSpellList()
    self:BuildProfessionList()
    self:BuildIconList()
    if self.RefreshOptions then self:RefreshOptions() end
end

function CM:BuildIconList()
    local icons, seen = {}, {}
    local function add(icon)
        if not icon then return end
        local key = tostring(icon)
        if seen[key] then return end
        seen[key] = true
        icons[#icons + 1] = icon
    end

    if type(GetMacroIcons) == "function" then
        local tmp = {}
        self:SafeCall(GetMacroIcons, tmp)
        for _, icon in ipairs(tmp) do add(icon) end
    end

    if type(GetMacroItemIcons) == "function" then
        local tmp = {}
        self:SafeCall(GetMacroItemIcons, tmp)
        for _, icon in ipairs(tmp) do add(icon) end
    end

    for _, spell in ipairs(self:GetKnownSpells()) do add(spell.icon) end

    local fallback = {
        "Interface\\Icons\\INV_Misc_Note_01",
        "Interface\\Icons\\INV_Misc_QuestionMark",
        "Interface\\Icons\\INV_Misc_Bag_10",
        "Interface\\Icons\\INV_Misc_Gear_01",
        "Interface\\Icons\\Spell_Holy_FlashHeal",
        "Interface\\Icons\\Ability_Rogue_Sprint",
        "Interface\\Icons\\INV_Trinket_80_Titan02b",
        "Interface\\Icons\\Trade_Engineering",
    }
    for _, icon in ipairs(fallback) do add(icon) end

    self.macroIcons = icons
    return icons
end

function CM:GetMacroIconsList()
    if not self.macroIcons then return self:BuildIconList() end
    return self.macroIcons
end

function CM:IsMacroChangeAllowed()
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        self:Print(self:T("ERROR_COMBAT"))
        return false
    end
    return true
end

function CM:NormalizeMacroName(name)
    name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if #name > 16 then name = name:sub(1, 16) end
    return name
end

function CM:ValidateMacro(name, body)
    name = self:NormalizeMacroName(name)
    body = tostring(body or "")
    if name == "" then return false, self:T("ERROR_NAME") end
    if body == "" then return false, self:T("ERROR_BODY") end
    if #body > self.macroMaxLength then
        return false, string.format(self:T("ERROR_TOO_LONG"), self.macroMaxLength)
    end
    return true, nil, name
end

function CM:GetKnownSpellNameSet()
    local set = {}
    for _, spell in ipairs(self:GetKnownSpells() or {}) do
        set[string.lower(tostring(spell.name or ""))] = true
    end
    for _, prof in ipairs(self:GetProfessionsList() or {}) do
        set[string.lower(tostring(prof.name or ""))] = true
    end
    return set
end

local knownCommands = {
    ["#showtooltip"]=true, ["/cast"]=true, ["/castsequence"]=true, ["/castrandom"]=true,
    ["/use"]=true, ["/target"]=true, ["/targetexact"]=true, ["/targetlasttarget"]=true,
    ["/focus"]=true, ["/clearfocus"]=true, ["/stopcasting"]=true, ["/startattack"]=true,
    ["/stopattack"]=true, ["/petattack"]=true, ["/petfollow"]=true, ["/petstay"]=true,
    ["/petpassive"]=true, ["/petdefensive"]=true, ["/petassist"]=true,
    ["/s"]=true, ["/say"]=true, ["/y"]=true, ["/yell"]=true, ["/p"]=true, ["/party"]=true,
    ["/raid"]=true, ["/rw"]=true, ["/emote"]=true, ["/e"]=true, ["/run"]=true, ["/script"]=true,
}

local function StripMacroOptions(value)
    value=tostring(value or "")
    value=value:gsub("^%s*%b[]%s*","")
    return value:gsub("^%s+",""):gsub("%s+$","")
end

function CM:AnalyzeMacro(body)
    body=tostring(body or "")
    local warnings={}
    local explanations={}
    local knownSpells=self:GetKnownSpellNameSet()

    for line in body:gmatch("[^\r\n]+") do
        local clean=line:gsub("^%s+",""):gsub("%s+$","")
        if clean~="" then
            local command=clean:match("^(#%S+)") or clean:match("^(/%S+)")
            if command then
                command=string.lower(command)
                if not knownCommands[command] then
                    warnings[#warnings+1]=string.format(self:T("WARNING_UNKNOWN_COMMAND"),command)
                end
                if command=="/run" or command=="/script" then
                    warnings[#warnings+1]=self:T("WARNING_SCRIPT")
                    explanations[#explanations+1]="• "..clean
                elseif command=="#showtooltip" then
                    explanations[#explanations+1]="• Tooltip/Icon: "..StripMacroOptions(clean:sub(#command+1))
                elseif command=="/cast" or command=="/castsequence" or command=="/castrandom" then
                    local arg=StripMacroOptions(clean:sub(#command+1))
                    local first=arg:match("^([^,;]+)") or arg
                    first=first:gsub("^reset=[^%s]+%s*",""):gsub("^%s+",""):gsub("%s+$","")
                    if first~="" and not tonumber(first) and not knownSpells[string.lower(first)] then
                        warnings[#warnings+1]=string.format(self:T("WARNING_UNKNOWN_SPELL"),first)
                    end
                    explanations[#explanations+1]="• Cast: "..arg
                elseif command=="/use" then
                    explanations[#explanations+1]="• Use: "..StripMacroOptions(clean:sub(#command+1))
                elseif command=="/target" or command=="/targetexact" then
                    explanations[#explanations+1]="• Target: "..StripMacroOptions(clean:sub(#command+1))
                elseif command=="/focus" then
                    explanations[#explanations+1]="• Focus: "..StripMacroOptions(clean:sub(#command+1))
                elseif command=="/s" or command=="/say" or command=="/y" or command=="/yell" or command=="/p" or command=="/party" or command=="/raid" or command=="/rw" then
                    explanations[#explanations+1]="• Chat: "..StripMacroOptions(clean:sub(#command+1))
                elseif command=="/emote" or command=="/e" then
                    explanations[#explanations+1]="• Emote: "..StripMacroOptions(clean:sub(#command+1))
                else
                    explanations[#explanations+1]="• "..clean
                end
            end
        end
    end

    if #body > math.floor(self.macroMaxLength*0.85) then
        warnings[#warnings+1]=string.format(self:T("WARNING_LONG"),#body,self.macroMaxLength)
    end
    return {
        ok=#warnings==0 and #body<=self.macroMaxLength,
        warnings=warnings,
        explanation=#explanations>0 and table.concat(explanations,"\n") or self:T("EMPTY_PREVIEW"),
        length=#body,
        maxLength=self.macroMaxLength,
    }
end

function CM:GetValidationText(body)
    local result=self:AnalyzeMacro(body)
    local lines={string.format("%d / %d",result.length,result.maxLength)}
    if #result.warnings==0 then
        lines[#lines+1]="✓ "..self:T("VALIDATION_OK")
    else
        for _,warning in ipairs(result.warnings) do lines[#lines+1]="! "..warning end
    end
    return table.concat(lines,"\n"), result
end

function CM:SaveMacroSnapshot(info, reason)
    if not self.db or not info then return end
    self.db.macroHistory=self.db.macroHistory or {}
    local history=self.db.macroHistory
    history[#history+1]={
        name=tostring(info.name or ""),
        body=tostring(info.body or ""),
        icon=info.icon,
        scope=info.scope or (info.isLocal and "character" or "account"),
        reason=reason or "edit",
        savedAt=(type(time)=="function" and time()) or 0,
    }
    while #history>20 do table.remove(history,1) end
end

function CM:FindLatestMacroSnapshot(name)
    local history=self.db and self.db.macroHistory or {}
    for i=#history,1,-1 do
        if history[i].name==name then return history[i],i end
    end
end

function CM:RestoreLatestMacroSnapshot(name)
    local snap,index=self:FindLatestMacroSnapshot(name)
    if not snap then self:Print(self:T("HISTORY_NONE")) return false end
    local macroIndex=self:GetMacroIndexByNameCompat(name)
    if not macroIndex then self:Print(self:T("HISTORY_NONE")) return false end
    local current=self:GetMacroInfoCompat(macroIndex)
    if current then current.scope=snap.scope self:SaveMacroSnapshot(current,"restore") end
    local ok=self:EditMacroCompat(macroIndex,snap.name,snap.icon,snap.body,true)
    if ok then
        table.remove(self.db.macroHistory,index)
        self:Print(string.format(self:T("HISTORY_RESTORED"),snap.name))
        if self.RefreshMacroListUI then self:RefreshMacroListUI() end
        return true
    end
    return false
end

function CM:GetMacroIndexByNameCompat(name)
    if type(GetMacroIndexByName) == "function" then
        local index = tonumber(self:SafeCall(GetMacroIndexByName, name))
        if index and index > 0 then return index end
    end

    for _, macro in ipairs(self:GetMacroList()) do
        if macro.name == name then return macro.index end
    end
    return nil
end

function CM:CreateMacroCompat(name, icon, body, perCharacter)
    if not self:IsMacroChangeAllowed() then return nil end
    if type(CreateMacro) ~= "function" then
        self:Print(self:T("ERROR_API"))
        return nil
    end

    local valid, err, cleanName = self:ValidateMacro(name, body)
    if not valid then self:Print(err) return nil end

    if self:GetMacroIndexByNameCompat(cleanName) then
        self:Print(self:T("ERROR_EXISTS"))
        return nil
    end

    local macroIcon = icon or AUTO_ICON
    local ok, index = pcall(CreateMacro, cleanName, macroIcon, body, perCharacter and true or false)
    if not ok or not index then
        self:Print(self:T("ERROR_CREATE"))
        return nil
    end

    self:Print(string.format(self:T("CREATED"), cleanName))
    if self.RefreshMacroListUI then self:RefreshMacroListUI() end
    return index
end

function CM:EditMacroCompat(index, name, icon, body, skipSnapshot)
    if not self:IsMacroChangeAllowed() then return nil end
    if type(EditMacro) ~= "function" then
        self:Print(self:T("ERROR_API"))
        return nil
    end

    local valid, err, cleanName = self:ValidateMacro(name, body)
    if not valid then self:Print(err) return nil end

    if not skipSnapshot then
        local before=self:GetMacroInfoCompat(index)
        if before then
            before.scope=before.isLocal and "character" or "account"
            self:SaveMacroSnapshot(before,"edit")
        end
    end

    local ok, result = pcall(EditMacro, index, cleanName, icon, body)
    if not ok then
        self:Print(self:T("ERROR_CREATE"))
        return nil
    end

    self:Print(string.format(self:T("UPDATED"), cleanName))
    if self.RefreshMacroListUI then self:RefreshMacroListUI() end
    return result or index
end

function CM:DeleteMacroCompat(index)
    if not self:IsMacroChangeAllowed() then return false end
    if type(DeleteMacro) ~= "function" then
        self:Print(self:T("ERROR_API"))
        return false
    end

    local before=self:GetMacroInfoCompat(index)
    if before then
        before.scope=before.isLocal and "character" or "account"
        self:SaveMacroSnapshot(before,"delete")
    end
    local ok = pcall(DeleteMacro, index)
    if ok then
        self:Print(self:T("DELETED"))
        if self.RefreshMacroListUI then self:RefreshMacroListUI() end
        return true
    end
    return false
end

function CM:GetMacroInfoCompat(index)
    if type(GetMacroInfo) ~= "function" then return nil end
    local name, icon, body, isLocal = self:SafeCall(GetMacroInfo, index)
    if not name then return nil end
    return {
        index = index,
        name = tostring(name),
        icon = icon,
        body = tostring(body or ""),
        isLocal = isLocal and true or false,
    }
end

function CM:GetMacroList()
    local out = {}
    if type(GetNumMacros) ~= "function" or type(GetMacroInfo) ~= "function" then return out end

    local accountCount, charCount = self:SafeCall(GetNumMacros)
    accountCount = tonumber(accountCount) or 0
    charCount = tonumber(charCount) or 0

    for index = 1, accountCount do
        local info = self:GetMacroInfoCompat(index)
        if info then info.scope = "account" out[#out + 1] = info end
    end

    local charBase = tonumber(_G.MAX_ACCOUNT_MACROS) or 120
    for offset = 1, charCount do
        local info = self:GetMacroInfoCompat(charBase + offset)
        if info then info.scope = "character" out[#out + 1] = info end
    end

    return out
end

function CM:InitializeMacroAPI()
    self.builder = self.builder or {
        name = "ComfyMacro",
        blocks = {},
        autoIcon = true,
        customIcon = nil,
        perCharacter = true,
    }
    self:RefreshKnownData()
end
