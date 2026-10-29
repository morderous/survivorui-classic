-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the minimap button, round on the minimap's rim like the
-- game's own; drag it round the rim. A click opens the addon's menu: Move
-- frames, the health text of each frame, each piece on or off, whether they
-- stay over the game's cards, the frames back in their places, and the switch
-- back to Survivor UI when it is installed.

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
	GameTooltip:AddLine("Click for the menu. Drag to move this button.", 1, 1, 1)
	GameTooltip:Show()
end)
button:SetScript("OnLeave", function()
	GameTooltip:Hide()
end)

------------------------------------------------------------------------------
-- The menu.

local menu = CreateFrame("Frame", "SUICMenu", UIParent, "UIDropDownMenuTemplate")

local PIECES = {
	{ "runFrame", "Run frame", "RefreshRunFrame" },
	{ "bossBars", "Boss bars", "RefreshBossBars" },
	{ "buildList", "Build list", "RefreshBuildList" },
	{ "jewelry", "Jewelry", "RefreshJewelry" },
}

local function Toggle(key, refresh)
	local db = SUIC.DB()
	db[key] = not db[key]
	if refresh and SUIC[refresh] then
		SUIC[refresh]()
	end
end

local function ToggleOverCards()
	local db = SUIC.DB()
	db.overCards = not db.overCards
	SUIC.OverCards(SUICRunFrame, true)
	SUIC.OverCards(SUICBuildList, true)
	SUIC.OverCards(SUICJewelry, true)
end

local function SetHealth(key, style)
	SUIC.DB()[key] = style
	SUIC.UpdateHealthText()
	CloseDropDownMenus()
end

local function Add(info, level)
	UIDropDownMenu_AddButton(info, level)
end

local function HealthChoices(key, level)
	local current = SUIC.DB()[key]
	for index = 1, table.getn(SUIC.HEALTH_STYLES) do
		local style = SUIC.HEALTH_STYLES[index]
		Add({ text = SUIC.HEALTH_NAMES[style], func = SetHealth, arg1 = key, arg2 = style,
			checked = current == style }, level)
	end
end

local function Init()
	local level = UIDROPDOWNMENU_MENU_LEVEL or 1
	if level == 2 then
		HealthChoices(UIDROPDOWNMENU_MENU_VALUE, level)
		return
	end
	local db = SUIC.DB()
	Add({ text = "SurvivorUI Classic", isTitle = 1, notCheckable = 1 }, level)
	Add({ text = "Move frames", notCheckable = 1, func = function()
		SUIC.SetMoveMode(not SUIC.MoveMode())
	end }, level)
	Add({ text = "Target health", notCheckable = 1, hasArrow = 1, value = "targetHealth" }, level)
	Add({ text = "Player health", notCheckable = 1, hasArrow = 1, value = "playerHealth" }, level)
	for index = 1, table.getn(PIECES) do
		local piece = PIECES[index]
		Add({ text = piece[2], checked = db[piece[1]], keepShownOnClick = 1,
			func = Toggle, arg1 = piece[1], arg2 = piece[3] }, level)
	end
	Add({ text = "Over the game's cards", checked = db.overCards, keepShownOnClick = 1,
		func = ToggleOverCards }, level)
	Add({ text = "Reset positions", notCheckable = 1, func = SUIC.ResetPositions }, level)
	if IsAddOnLoaded("SurvivorUI") then
		Add({ text = "Switch to Survivor UI", notCheckable = 1, func = function()
			SUIC.ShowChoice(true)
		end }, level)
	end
	Add({ text = CLOSE or "Close", notCheckable = 1, func = CloseDropDownMenus }, level)
end

UIDropDownMenu_Initialize(menu, Init, "MENU")

button:SetScript("OnClick", function()
	UIDropDownMenu_Initialize(menu, Init, "MENU")
	ToggleDropDownMenu(1, nil, menu, "SUICMinimapButton", 0, 0)
end)

SUIC.OnStart(function()
	Place()
	button:Show()
end)
