ComfyMacro = ComfyMacro or {}
local CM = ComfyMacro

local function HubWantsBundled()
    local hub = rawget(_G, "ComfyHub")
    if type(hub) ~= "table" then return false end

    if type(hub.IsMinimapBundlingActive) == "function" then
        local ok, bundled = pcall(hub.IsMinimapBundlingActive, hub)
        if ok then return bundled and true or false end
    end

    return hub.db
        and hub.db.minimap
        and hub.db.minimap.show
        and hub.db.minimap.bundleSuiteIcons ~= false
end

local function Radius(button)
    if not Minimap then return 95 end
    local width = Minimap:GetWidth() or 140
    local height = Minimap:GetHeight() or width
    return math.min(width, height) / 2 + ((button and button:GetWidth()) or 32) / 2 + 2
end

local function Position(button, angle)
    if not Minimap then return end
    local r = math.rad(angle or 250)
    local radius = Radius(button)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(r) * radius, math.sin(r) * radius)
end

function CM:SetMinimapBundled(bundled)
    self.minimapBundled = bundled and true or false
    if self.minimapButton and self.db then
        self:UpdateMinimapPosition()
    end
end

function CM:ShouldShowMinimapButton()
    if not self.db or not self.db.minimap then return false end
    return self.db.minimap.show and not self.minimapBundled and not HubWantsBundled()
end

function CM:UpdateMinimapPosition()
    if not self.minimapButton or not self.db then return end
    Position(self.minimapButton, self.db.minimap.angle)
    self.minimapButton:SetShown(self:ShouldShowMinimapButton())
end

function CM:InitializeMinimap()
    if self.minimapButton or not Minimap then return end

    local button = CreateFrame("Button", "ComfyMacroMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetSize(20, 20)
    background:SetPoint("CENTER")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)

    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then CM:OpenOptions(2) else CM:OpenOptions(1) end
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("ComfyMacro", 1, 0.82, 0)
        GameTooltip:AddLine(CM:T("MINIMAP_LEFT"), 1, 1, 1)
        GameTooltip:AddLine(CM:T("MINIMAP_RIGHT"), 1, 1, 1)
        GameTooltip:AddLine(CM:T("MINIMAP_DRAG"), 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    button:SetScript("OnDragStart", function(self)
        if CM.db.minimap.locked then return end
        self:SetScript("OnUpdate", function(btn)
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            if scale and scale > 0 then
                cx, cy = cx / scale, cy / scale
                CM.db.minimap.angle = math.deg(math.atan2(cy - my, cx - mx))
                Position(btn, CM.db.minimap.angle)
            end
        end)
    end)

    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    self.minimapButton = button
    self.minimapBundled = HubWantsBundled()
    self:UpdateMinimapPosition()
end
