ComfyMacro = ComfyMacro or {}
local CM = ComfyMacro

function CM:InitializeAssistant()
    self:ResetAssistant()
end

function CM:ResetAssistant()
    self.assistant = {
        step = "category",
        state = {
            category = nil,
            targetMode = nil,
            playerName = "",
            spell = nil,
            trinkets = "both",
            profession = nil,
            emote = nil,
            channel = nil,
            chatText = "",
            autoIcon = true,
            customIcon = nil,
            name = "ComfyMacro",
        },
        history = {},
        explanation = self:T("ASSIST_START"),
    }
    if self.RefreshAssistantUI then self:RefreshAssistantUI() end
end

local function PushStep(self, nextStep)
    local a = self.assistant
    a.history[#a.history + 1] = a.step
    a.step = nextStep
end

function CM:StartAssistant(category, seed)
    self:ResetAssistant()
    self.assistant.state.category = category
    if seed then
        for k, v in pairs(seed) do self.assistant.state[k] = v end
    end

    if category == "heal" then
        if self.assistant.state.targetMode then
            self.assistant.step = "spell"
        else
            self.assistant.step = "target"
        end
    elseif category == "burst" then
        self.assistant.step = "spell"
    elseif category == "profession" then
        self.assistant.step = "profession"
    elseif category == "emote" then
        if self.assistant.state.emote then self.assistant.step = "final" else self.assistant.step = "emote" end
    elseif category == "chat" then
        if self.assistant.state.channel then self.assistant.step = "chattext" else self.assistant.step = "channel" end
    else
        self.assistant.step = "category"
    end

    if self.SelectOptionsTab then self:SelectOptionsTab(2) end
    if self.RefreshAssistantUI then self:RefreshAssistantUI() end
end

function CM:AssistantBack()
    local a = self.assistant
    local previous = table.remove(a.history)
    if previous then a.step = previous else a.step = "category" end
    if self.RefreshAssistantUI then self:RefreshAssistantUI() end
end

function CM:GetAssistantPrompt()
    local step = self.assistant and self.assistant.step or "category"
    local keys = {
        category = "ASSIST_START",
        target = "ASSIST_TARGET",
        spell = "ASSIST_SPELL",
        playername = "ASSIST_PLAYER_NAME",
        trinkets = "ASSIST_TRINKETS",
        profession = "ASSIST_PROFESSION_PICK",
        emote = "ASSIST_EMOTE_PICK",
        channel = "ASSIST_CHAT_CHANNEL",
        chattext = "ASSIST_CHAT_TEXT",
        final = "ASSIST_FINAL",
    }
    return self:T(keys[step] or "ASSIST_START")
end

function CM:GetAssistantChoices()
    local a = self.assistant
    local step = a.step
    local choices = {}

    if step == "category" then
        return {
            {value = "heal", label = self:T("ASSIST_HEAL")},
            {value = "burst", label = self:T("ASSIST_BURST")},
            {value = "profession", label = self:T("ASSIST_PROFESSION")},
            {value = "emote", label = self:T("ASSIST_EMOTE")},
            {value = "chat", label = self:T("ASSIST_CHAT")},
        }
    elseif step == "target" then
        return {
            {value = "current", label = self:T("ASSIST_TARGET_CURRENT")},
            {value = "mouseover", label = self:T("ASSIST_TARGET_MOUSEOVER")},
            {value = "focus", label = self:T("ASSIST_TARGET_FOCUS")},
            {value = "player", label = self:T("ASSIST_TARGET_PLAYER")},
            {value = "self", label = self:T("ASSIST_TARGET_SELF")},
        }
    elseif step == "spell" then
        local spells = self:GetKnownSpells()
        for i = 1, math.min(#spells, 80) do
            choices[#choices + 1] = {value = spells[i].name, label = spells[i].name}
        end
        return choices
    elseif step == "trinkets" then
        return {
            {value = "both", label = self:T("ASSIST_TRINKETS_BOTH")},
            {value = "13", label = self:T("ASSIST_TRINKETS_13")},
            {value = "14", label = self:T("ASSIST_TRINKETS_14")},
            {value = "none", label = self:T("ASSIST_TRINKETS_NONE")},
        }
    elseif step == "profession" then
        local profs = self:GetProfessionsList()
        for _, prof in ipairs(profs) do
            choices[#choices + 1] = {value = prof.name, label = prof.name}
        end
        return choices
    elseif step == "emote" then
        for _, emote in ipairs(self.emotes or {}) do
            choices[#choices + 1] = {value = emote.id, label = self:GetEmoteLabel(emote)}
        end
        return choices
    elseif step == "channel" then
        return {
            {value = "say", label = self:T("CHANNEL_SAY")},
            {value = "yell", label = self:T("CHANNEL_YELL")},
            {value = "party", label = self:T("CHANNEL_PARTY")},
            {value = "raid", label = self:T("CHANNEL_RAID")},
        }
    end

    return choices
end

function CM:AssistantChoose(value)
    local a = self.assistant
    local step = a.step
    local s = a.state

    if step == "category" then
        s.category = value
        if value == "heal" then PushStep(self, "target")
        elseif value == "burst" then PushStep(self, "spell")
        elseif value == "profession" then PushStep(self, "profession")
        elseif value == "emote" then PushStep(self, "emote")
        elseif value == "chat" then PushStep(self, "channel") end

    elseif step == "target" then
        s.targetMode = value
        if value == "player" then PushStep(self, "playername") else PushStep(self, "spell") end

    elseif step == "spell" then
        s.spell = value
        if s.category == "burst" then PushStep(self, "trinkets") else PushStep(self, "final") end

    elseif step == "trinkets" then
        s.trinkets = value
        PushStep(self, "final")

    elseif step == "profession" then
        s.profession = value
        PushStep(self, "final")

    elseif step == "emote" then
        s.emote = value
        PushStep(self, "final")

    elseif step == "channel" then
        s.channel = value
        PushStep(self, "chattext")
    end

    a.explanation = self:GetAssistantExplanation()
    if self.RefreshAssistantUI then self:RefreshAssistantUI() end
end

function CM:AssistantSubmitText(text)
    local a = self.assistant
    local s = a.state
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")

    if a.step == "playername" then
        s.playerName = text
        PushStep(self, "spell")
    elseif a.step == "chattext" then
        s.chatText = text
        PushStep(self, "final")
    end

    a.explanation = self:GetAssistantExplanation()
    if self.RefreshAssistantUI then self:RefreshAssistantUI() end
end

function CM:GetAssistantExplanation()
    local a = self.assistant
    if not a then return "" end
    local step = a.step
    local s = a.state

    if step == "category" then return self:T("ASSIST_START") end
    if step == "target" then return self:T("ASSIST_TARGET") end
    if step == "spell" then return self:T("EXPL_CAST") end
    if step == "playername" then return self:T("EXPL_TARGETEXACT") end
    if step == "trinkets" then return self:T("EXPL_TRINKET13") .. " " .. self:T("EXPL_TRINKET14") end
    if step == "profession" then return self:T("EXPL_PROFESSION") end
    if step == "emote" then return self:T("EXPL_EMOTE") end
    if step == "channel" or step == "chattext" then return self:T("EXPL_SAY") .. " " .. self:T("EXPL_YELL") end

    if step == "final" then
        if s.category == "burst" then
            return self:T("ASSIST_FINAL") .. " Trinkets and abilities may still obey their own cooldown/global-cooldown restrictions."
        end
        return self:T("ASSIST_FINAL")
    end
    return ""
end

function CM:BuildAssistantBody()
    local s = self.assistant and self.assistant.state
    if not s or not s.category then return "" end
    local lines = {}

    if s.category == "heal" then
        if s.spell then lines[#lines + 1] = "#showtooltip " .. s.spell end

        if s.targetMode == "player" and s.playerName ~= "" then
            lines[#lines + 1] = "/targetexact " .. s.playerName
            if s.spell then lines[#lines + 1] = "/cast " .. s.spell end
        elseif s.targetMode == "mouseover" then
            if s.spell then lines[#lines + 1] = "/cast [@mouseover,help,nodead][] " .. s.spell end
        elseif s.targetMode == "focus" then
            if s.spell then lines[#lines + 1] = "/cast [@focus,help,nodead][] " .. s.spell end
        elseif s.targetMode == "self" then
            if s.spell then lines[#lines + 1] = "/cast [@player] " .. s.spell end
        else
            if s.spell then lines[#lines + 1] = "/cast " .. s.spell end
        end

    elseif s.category == "burst" then
        if s.spell then lines[#lines + 1] = "#showtooltip " .. s.spell end
        if s.trinkets == "both" or s.trinkets == "13" then lines[#lines + 1] = "/use 13" end
        if s.trinkets == "both" or s.trinkets == "14" then lines[#lines + 1] = "/use 14" end
        if s.spell then lines[#lines + 1] = "/cast " .. s.spell end

    elseif s.category == "profession" then
        if s.profession then
            lines[#lines + 1] = "#showtooltip " .. s.profession
            lines[#lines + 1] = "/cast " .. s.profession
        end

    elseif s.category == "emote" then
        if s.emote then lines[#lines + 1] = "/" .. s.emote end

    elseif s.category == "chat" then
        local command = ({say = "/s ", yell = "/y ", party = "/p ", raid = "/raid "})[s.channel or "say"] or "/s "
        if s.chatText ~= "" then lines[#lines + 1] = command .. s.chatText end
    end

    return table.concat(lines, "\n")
end

function CM:GetAssistantPrimarySpell()
    local s = self.assistant and self.assistant.state
    if not s then return nil end
    return s.spell or s.profession
end

function CM:GetAssistantDefaultName()
    local s = self.assistant and self.assistant.state
    if not s then return "ComfyMacro" end
    if s.category == "heal" then return "ComfyHeal"
    elseif s.category == "burst" then return "ComfyBurst"
    elseif s.category == "profession" then return "ComfyProfession"
    elseif s.category == "emote" then return "ComfyEmote"
    elseif s.category == "chat" then return "ComfyChat"
    end
    return "ComfyMacro"
end
