-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the minimap button, round on the minimap's rim like the
-- game's own; drag it round the rim. Left-click opens the options, right-click
-- Move frames. Hidden in the options' Minimap tab, the options open with /suic.

local RADIUS = 80

local button = CreateFrame("Button", "SUICMinimapButton", Minimap)
button:SetWidth(31)
button:SetHeight(31)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:RegisterForDrag("LeftButton")
button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
button:Hide()

local icon = button:CreateTexture(nil, "BACKGROUND")
icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
icon:SetWidth(20)
icon:SetHeight(20)
icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -5)
local border = button:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetWidth(52)
border:SetHeight(52)
border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)

local function Place()
	local angle = math.rad(SUIC.DB().mapAngle or 225)
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * RADIUS, math.sin(angle) * RADIUS)
end

-- Round the rim after the cursor while dragged.
local function Follow()
	local x, y = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	local cx, cy = Minimap:GetCenter()
	SUIC.DB().mapAngle = math.deg(math.atan2(y / scale - cy, x / scale - cx))
	Place()
end

button:SetScript("OnDragStart", function()
	this:SetScript("OnUpdate", Follow)
end)
button:SetScript("OnDragStop", function()
	this:SetScript("OnUpdate", nil)
end)
button:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_LEFT")
	GameTooltip:SetText("SurvivorUI Classic")
	GameTooltip:AddLine("Left-click: options", 1, 1, 1)
	GameTooltip:AddLine("Right-click: move frames", 1, 1, 1)
	GameTooltip:AddLine("Drag: move this button", 0.7, 0.7, 0.7)
	GameTooltip:Show()
end)
button:SetScript("OnLeave", function()
	GameTooltip:Hide()
end)
button:SetScript("OnClick", function()
	GameTooltip:Hide()
	if arg1 == "RightButton" then
		SUIC.SetMoveMode(not SUIC.MoveMode())
	else
		SUIC.ToggleOptions()
	end
end)

function SUIC.RefreshMapButton()
	if SUIC.active and SUIC.DB().mapButton then
		Place()
		button:Show()
	else
		button:Hide()
	end
end

SUIC.OnStart(function()
	SUIC.RefreshMapButton()
end)
