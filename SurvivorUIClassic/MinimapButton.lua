-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the minimap button, round on the minimap's rim like the
-- game's own; drag it round the rim. Left-click opens the options, right-click
-- Move frames. Hidden in the options' Minimap tab, the options open with /suic.

local RADIUS = 80

-- A round button on the minimap's rim, its place on the rim saved under key
-- (angle the first). button.icon is its art, button.border the game's ring
-- round it, button.Place puts it there.
function SUIC.RimButton(name, key, angle)
	local rim = CreateFrame("Button", name, Minimap)
	rim:SetWidth(31)
	rim:SetHeight(31)
	rim:SetFrameStrata("MEDIUM")
	rim:SetFrameLevel(Minimap:GetFrameLevel() + 8)
	rim:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	rim:RegisterForDrag("LeftButton")
	rim:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	rim:Hide()

	rim.icon = rim:CreateTexture(nil, "ARTWORK")
	rim.icon:SetWidth(20)
	rim.icon:SetHeight(20)
	rim.icon:SetPoint("TOPLEFT", rim, "TOPLEFT", 7, -5)
	rim.border = rim:CreateTexture(nil, "OVERLAY")
	rim.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	rim.border:SetWidth(52)
	rim.border:SetHeight(52)
	rim.border:SetPoint("TOPLEFT", rim, "TOPLEFT", 0, 0)

	function rim.Place()
		local at = math.rad(SUIC.DB()[key] or angle)
		rim:ClearAllPoints()
		rim:SetPoint("CENTER", Minimap, "CENTER", math.cos(at) * RADIUS, math.sin(at) * RADIUS)
	end

	-- Round the rim after the cursor while dragged.
	local function Follow()
		local x, y = GetCursorPosition()
		local scale = Minimap:GetEffectiveScale()
		local cx, cy = Minimap:GetCenter()
		SUIC.DB()[key] = math.deg(math.atan2(y / scale - cy, x / scale - cx))
		rim.Place()
	end

	rim:SetScript("OnDragStart", function()
		this:SetScript("OnUpdate", Follow)
	end)
	rim:SetScript("OnDragStop", function()
		this:SetScript("OnUpdate", nil)
	end)
	return rim
end

local button = SUIC.RimButton("SUICMinimapButton", "mapAngle", 225)
button.icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")

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
		button.Place()
		button:Show()
	else
		button:Hide()
	end
end

SUIC.OnStart(function()
	SUIC.RefreshMapButton()
end)
