-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the note, once for each player, that the run tracker,
-- the build list, the jewelry and the meter hide while a level's cards are up
-- (since 0.2.8, Core.lua: on a small screen the cards are large and the pieces
-- stood on them). Some seconds into town, in a dialog of the game's make: keep
-- it so, the four back as before, or the options' Card choice tab.

local WIDTH = 450
local WAIT = 4                  -- seconds in town before it shows

local window

local function Button(label, x, onClick)
	local button = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
	button:SetWidth(134)
	button:SetHeight(22)
	button:SetPoint("BOTTOM", window, "BOTTOM", x, 20)
	button:SetText(label)
	button:SetScript("OnClick", function()
		window:Hide()
		onClick()
	end)
end

local function Build()
	window = SUIC.Dialog("SUICCardsNotice", "Card choice", WIDTH, 100)
	-- Under the game's "Move to begin", not on it.
	window:ClearAllPoints()
	window:SetPoint("CENTER", UIParent, "CENTER", 0, -70)
	local text = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	text:SetWidth(WIDTH - 50)
	text:SetPoint("TOP", window, "TOP", 0, -36)
	text:SetText("SurvivorUI Classic now hides the run tracker, the build list, the jewelry and the damage meter while you choose a card, so the cards fit on any screen. You can bring them all back as they were, or show only some of them.")
	Button("Keep them hidden", -140, function() end)
	Button("Show as before", 0, function()
		local shown = SUIC.CardsShown()
		for index = 1, table.getn(SUIC.CARD_PIECES) do
			shown[SUIC.CARD_PIECES[index][1]] = true
		end
		SUIC.RefreshOverCards()
	end)
	Button("Choose pieces", 140, function()
		SUIC.OptionsTab("Card choice")
	end)
	window:SetHeight(36 + text:GetHeight() + 16 + 22 + 20)
end

local watch = CreateFrame("Frame")
watch:Hide()
local wait, inTown = 0, 0
watch:SetScript("OnUpdate", function()
	wait = wait + arg1
	if wait < 1 then
		return
	end
	wait = 0
	if SUIC.DB().cardsNoticeSeen or not AZS_SetOnTopOfScreens then
		this:Hide()
		return
	end
	local choice = getglobal("SUICChoiceVeil")
	if not AZS_GetPhase or AZS_GetPhase() ~= "ready" or (choice and choice:IsShown()) then
		inTown = 0
		return
	end
	inTown = inTown + 1
	if inTown >= WAIT then
		SUIC.DB().cardsNoticeSeen = true
		this:Hide()
		Build()
		window:Show()
	end
end)

SUIC.OnStart(function()
	watch:Show()
end)
