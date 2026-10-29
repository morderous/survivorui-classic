-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the Level Up! button, as the game's but movable. With
-- the game's Store Level-Ups on, the levels wait and this opens them, one card
-- choice after another (AZS_OpenStoredLevels, as the game's key does): the
-- hero's level, "Level Up!" in gold, and how many wait on its icon, a gold
-- glow breathing round it. It stands in for the game's button, which is put
-- away while it is on.

local ICON = "Interface\\Icons\\Spell_Holy_DivineIntervention"

local button = CreateFrame("Button", "SUICLevelUp", UIParent)
button:SetWidth(150)
button:SetHeight(38)
button:SetBackdrop({
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 14,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
button:SetBackdropColor(0.28, 0.05, 0.04, 0.92)
button:SetBackdropBorderColor(0.85, 0.65, 0.3, 1)
button:RegisterForClicks("LeftButtonUp")
button:Hide()

local function Home(f)
	f:SetPoint("BOTTOM", MainMenuBar, "TOP", 0, 52)
end
Home(button)

local glow = button:CreateTexture(nil, "BORDER")
glow:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
glow:SetBlendMode("ADD")
glow:SetVertexColor(1, 0.7, 0.2)
glow:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)

local icon = button:CreateTexture(nil, "ARTWORK")
icon:SetTexture(ICON)
icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
icon:SetWidth(28)
icon:SetHeight(28)
icon:SetPoint("LEFT", button, "LEFT", 6, 0)

local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -1)

local level = SUIC.Text(button, "GameFontNormalSmall", 9)
level:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, 0)
level:SetTextColor(0.8, 0.7, 0.55)

local title = SUIC.Text(button, "GameFontNormalLarge")
title:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 8, -1)
title:SetText("Level Up!")

button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

local function Waiting()
	return AZS_GetStoredLevels and tonumber(AZS_GetStoredLevels()) or 0
end

button:SetScript("OnClick", function()
	if Waiting() > 0 and AZS_OpenStoredLevels then
		AZS_OpenStoredLevels()
	end
end)
button:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_TOP")
	GameTooltip:SetText("Level Up!")
	GameTooltip:AddLine(Waiting().." level(s) waiting. Click, or the game's key, to choose.", 1, 1, 1, 1)
	GameTooltip:Show()
end)
button:SetScript("OnLeave", function() GameTooltip:Hide() end)

local elapsed = 0
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed < 0.05 then
		return
	end
	elapsed = 0
	local waiting = Waiting()
	if (waiting > 0 and SUIC.InRun()) or SUIC.MoveMode() then
		count:SetText(waiting > 0 and waiting or "")
		level:SetText("LEVEL "..(UnitLevel("player") or ""))
		local beat = 0.5 + 0.5 * math.sin(GetTime() * 3)
		glow:SetAlpha(0.15 + 0.25 * beat)
		button:SetBackdropBorderColor(0.75 + 0.25 * beat, 0.55 + 0.25 * beat, 0.25 + 0.1 * beat, 1)
		button:Show()
	else
		button:Hide()
	end
end)
ticker:Hide()

function SUIC.RefreshLevelUp()
	local wanted = SUIC.DB().levelUp
	SUIC.SetGameShown("levels", not wanted)
	if wanted then
		ticker:Show()
	else
		ticker:Hide()
		button:Hide()
	end
end

SUIC.OnStart(function()
	SUIC.AddPiece("levelup", "Level Up!", button, Home)
	SUIC.RefreshLevelUp()
end)
