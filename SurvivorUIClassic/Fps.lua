-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the frames a second, in the screen's bottom left corner.
--
-- The game has no GetFramerate: the frames are counted here, one OnUpdate a
-- frame, over half a second. Green from 60, gold from 30, red under.

local WIDTH, HEIGHT = 44, 12
local EDGE = 2                  -- from the screen's edges
local EVERY = 0.5

local tag = CreateFrame("Frame", "SUICFps", UIParent)
tag:SetWidth(WIDTH)
tag:SetHeight(HEIGHT)
tag:Hide()

local function Home(f)
	f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", EDGE, EDGE)
end

local text = SUIC.Text(tag, "GameFontHighlightSmall", 10)
text:SetPoint("LEFT", tag, "LEFT", 0, 0)
text:SetShadowColor(0, 0, 0, 1)
text:SetShadowOffset(1, -1)

local frames, counted = 0, EVERY
tag:SetScript("OnUpdate", function()
	frames = frames + 1
	counted = counted + arg1
	if counted < EVERY then
		return
	end
	local fps = math.floor(frames / counted + 0.5)
	frames, counted = 0, 0
	local color = fps >= 60 and "66ff66" or (fps >= 30 and "ffd100" or "ff5050")
	text:SetText("|cff"..color..fps.."|r |cffe8e0c8fps|r")
end)

function SUIC.RefreshFps()
	if SUIC.DB().fps then
		tag:Show()
	else
		tag:Hide()
	end
end

SUIC.OnStart(function()
	Home(tag)
	SUIC.AddPiece("fps", "Frames a second", tag, Home)
	SUIC.RefreshFps()
end)
