local ADDON_NAME = ...

ComfyMacro = ComfyMacro or {}
local CM = ComfyMacro

CM.name = ADDON_NAME or "ComfyMacro"
CM.version = "0.4"
CM.buildDate = "27.09.2026"
CM.status = "Beta"
CM.gameVersion = "WoW Forever 1.60.1"
CM.targetBuild = "70009"
CM.interface = 16001
CM.author = "TheRealDoubleG"
CM.discord = "the.real.double.g"
CM.github = "https://github.com/TheRealDoubleG/ComfyMacro"
CM.macroMaxLength = 255

CM.colors = {
    gold = {1.00, 0.82, 0.00},
    green = {0.20, 1.00, 0.20},
    red = {1.00, 0.25, 0.20},
    muted = {0.65, 0.65, 0.65},
}

local defaults = {
    enabled = true,
    minimap = {
        show = true,
        locked = false,
        angle = 250,
    },
    optionsWindow = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 10,
    },
    ui = {
        windowLocked = false,
        windowOpacity = 100,
        showWindowBorder = true,
        backgroundAlpha = 92,
    },
}

local function CopyTable(src)
    if type(src) ~= "table" then return src end
    local dst = {}
    for k, v in pairs(src) do dst[k] = CopyTable(v) end
    return dst
end
CM.CopyTable = CopyTable

local function ApplyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            ApplyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function CM:Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd200ComfyMacro:|r " .. tostring(msg))
    end
end

function CM:SafeCall(func, ...)
    if type(func) ~= "function" then return nil end
    local ok, a, b, c, d, e, f, g, h = pcall(func, ...)
    if not ok then return nil end
    return a, b, c, d, e, f, g, h
end

function CM:GetClientBuildInfo()
    if type(GetBuildInfo) ~= "function" then return "?", "?", "?", nil end
    local version, build, buildDate, interface = GetBuildInfo()
    return tostring(version or "?"), tostring(build or "?"), tostring(buildDate or "?"), tonumber(interface)
end

function CM:GetCompatibilityStatus()
    local _, _, _, clientInterface = self:GetClientBuildInfo()
    if clientInterface and tonumber(clientInterface) == tonumber(self.interface) then
        return true, self:T("COMPAT_MATCH")
    end
    return false, self:T("COMPAT_UPDATE_REQUIRED")
end

function CM:InitializeDB()
    if self.InitializeProfileStorage then
        self:InitializeProfileStorage(defaults, "ComfyMacroDB")
    else
        if type(ComfyMacroDB) ~= "table" then
            ComfyMacroDB = CopyTable(defaults)
        else
            ApplyDefaults(ComfyMacroDB, defaults)
        end
        self.db = ComfyMacroDB
    end
end

function CM:OpenOptions(tab)
    if self.ShowOptions then self:ShowOptions(tab) end
end

SLASH_COMFYMACRO1 = "/comfymacro"
SLASH_COMFYMACRO2 = "/cm"
SlashCmdList.COMFYMACRO = function(msg)
    msg = tostring(msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "assistant" or msg == "assistent" then
        CM:OpenOptions(2)
    else
        CM:OpenOptions()
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")

events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == CM.name then
        CM:InitializeDB()
        if CM.InitializeMacroAPI then CM:InitializeMacroAPI() end
        if CM.InitializeTemplates then CM:InitializeTemplates() end
        if CM.InitializeAssistant then CM:InitializeAssistant() end
        if CM.InitializeMinimap then CM:InitializeMinimap() end
        if CM.InitializeOptions then CM:InitializeOptions() end
    elseif event == "PLAYER_LOGIN" then
        if CM.RefreshKnownData then CM:RefreshKnownData() end
        if CM.UpdateMinimapPosition then CM:UpdateMinimapPosition() end
    end
end)
