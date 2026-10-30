-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: with Survivor UI on too, the panel that asks which of
-- the two to use. It stays until one is picked: the two change the same
-- frames, so they never run together. Picking the one already running closes
-- it; picking the other one asks for the game to be closed and opened again,
-- as the game loads its addons only at its start: with the launcher open (its
-- mark, a SurvivorUILauncher addon that is only a .toc) Restart game, the
-- moment kept in restartAt, and the launcher opens the game again. With
-- Survivor UI the one running, its own box (its ChangeUI.lua) takes this
-- panel's place.

local DIALOG = {
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32,
	insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

local OPTIONS = {
	{ use = "survivorui", name = "Survivor UI",
		text = "Dark, flat frames of its own, a damage meter, run history and much more." },
	{ use = "classic", name = "SurvivorUI Classic",
		text = "The game's own look: everything movable, health numbers, a build list, the jewelry worn and a run frame." },
}

-- Everything behind it dimmed and out of reach.
local veil = CreateFrame("Frame", "SUICChoiceVeil", UIParent)
veil:SetFrameStrata("FULLSCREEN_DIALOG")
veil:SetAllPoints(UIParent)
veil:EnableMouse(true)
veil:Hide()
local shade = veil:CreateTexture(nil, "BACKGROUND")
shade:SetTexture(SUIC.FLAT)
shade:SetVertexColor(0, 0, 0, 0.55)
shade:SetAllPoints(veil)

local panel = CreateFrame("Frame", "SUICChoicePanel", veil)
panel:SetWidth(470)
panel:SetHeight(250)
panel:SetPoint("CENTER", UIParent, "CENTER", 0, -30)
panel:SetBackdrop(DIALOG)
panel:EnableMouse(true)
-- The dialog's own background lets the fight show through: darker, to read.
local inside = panel:CreateTexture(nil, "BACKGROUND")
inside:SetTexture(SUIC.FLAT)
inside:SetVertexColor(0, 0, 0, 0.6)
inside:SetPoint("TOPLEFT", panel, "TOPLEFT", 11, -12)
inside:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -12, 11)

local header = panel:CreateTexture(nil, "ARTWORK")
header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
header:SetWidth(320)
header:SetHeight(64)
header:SetPoint("TOP", panel, "TOP", 0, 12)
local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", header, "TOP", 0, -14)
title:SetText("Choose your interface")

local text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
text:SetWidth(410)
text:SetPoint("TOP", panel, "TOP", 0, -34)

local note = panel:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
note:SetWidth(410)
note:SetPoint("BOTTOM", panel, "BOTTOM", 0, 44)

local footer = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
footer:SetWidth(410)
footer:SetPoint("BOTTOM", panel, "BOTTOM", 0, 22)

local function Button(label, width)
	local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	button:SetWidth(width)
	button:SetHeight(24)
	button:SetText(label)
	return button
end

-- The two choices side by side, each with what it is under it.
local picks = {}
for index = 1, 2 do
	local option = OPTIONS[index]
	local button = Button(option.name, 190)
	button:SetPoint("TOP", panel, "TOP", index == 1 and -110 or 110, -96)
	button.use = option.use
	local about = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	about:SetWidth(190)
	about:SetPoint("TOP", button, "BOTTOM", 0, -8)
	about:SetText(option.text)
	button.about = about
	picks[index] = button
end

-- The launcher is there to open the game again.
local function LauncherHere()
	local _, _, _, _, _, reason = GetAddOnInfo("SurvivorUILauncher")
	return reason ~= "MISSING"
end

local quit = Button("Quit game", 150)
quit:SetPoint("BOTTOM", panel, "BOTTOM", -80, 16)
quit:SetScript("OnClick", function()
	if LauncherHere() then
		SUIC.DB().restartAt = time()
	end
	if Quit then
		Quit()
	end
end)
local later = Button("Later", 150)
later:SetPoint("BOTTOM", panel, "BOTTOM", 80, 16)
later:SetScript("OnClick", function()
	veil:Hide()
end)
local cancel = Button("Cancel", 120)
cancel:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 16)
cancel:SetScript("OnClick", function()
	veil:Hide()
end)

local function Running()
	if SUIC.active then
		return "classic"
	end
	return "survivorui"
end

local function NameOf(use)
	return use == "classic" and "SurvivorUI Classic" or "Survivor UI"
end

local function Open()
	if AZS_SetOnTopOfScreens then
		AZS_SetOnTopOfScreens(veil, true)
	end
	veil:Show()
end

-- The pick made, the other one still up: the game has to start again.
function SUIC.ShowRestart()
	local use = SUIC.DB().use
	if LauncherHere() then
		text:SetText(NameOf(use).." runs from the next time the game starts. The game will close and the launcher will open it again by itself.")
		quit:SetText("Restart game")
	else
		text:SetText(NameOf(use).." runs from the next time the game starts. Close the game and open it again. Until then, "..NameOf(Running()).." stays on.")
		quit:SetText("Quit game")
	end
	note:SetText("")
	footer:SetText("")
	for index = 1, 2 do
		picks[index]:Hide()
		picks[index].about:Hide()
	end
	cancel:Hide()
	quit:Show()
	later:Show()
	panel:SetHeight(150)
	Open()
end

local function Pick()
	local db = SUIC.DB()
	db.use = this.use
	if this.use == Running() then
		veil:Hide()
		if not SUIC.active then
			SUIC.Print("off: Survivor UI is in use. Type /suic to choose again.")
		end
		return
	end
	SUIC.ShowRestart()
end

for index = 1, 2 do
	picks[index]:SetScript("OnClick", Pick)
end

-- closable: asked from the menu or /suic, with a way out; at the start, none.
function SUIC.ShowChoice(closable)
	local db = SUIC.DB()
	text:SetText("Survivor UI and SurvivorUI Classic are both installed. They change the same frames, so only one of them can run. Which one do you want to use?")
	-- Off in the game's list it cannot be picked: an addon can only turn it
	-- on for the hero played, and each hero would have its own list.
	local _, _, _, enabled = GetAddOnInfo("SurvivorUI")
	if not enabled then
		note:SetText("Survivor UI is off in the game's Options, AddOns tab. Turn it on there and start the game again.")
		picks[1]:Disable()
	else
		picks[1]:Enable()
		if db.use == "classic" and not SUIC.active and not SurvivorUI_CanStandBy then
			note:SetText("This Survivor UI is too old to step aside. Update it from the launcher, or pick it here.")
		else
			note:SetText("")
		end
	end
	footer:SetText("You can change it later: Change UI, in the options.")
	for index = 1, 2 do
		picks[index]:Show()
		picks[index].about:Show()
	end
	quit:Hide()
	later:Hide()
	if closable then
		cancel:Show()
		footer:SetText("")
	else
		cancel:Hide()
	end
	panel:SetHeight(250)
	Open()
end
