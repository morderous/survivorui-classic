-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the panels' border round the game's clock, under the
-- minimap. The clock itself is the game's (its 0.131), drawn outside the
-- interface, in the PC's own time zone: no addon reaches it, and the game's
-- clock for addons runs in UTC. It sits under the minimap's bottom edge, the
-- same size in pixels whatever the screen and the interface's size, so the
-- border keeps to pixels too, and it goes while the cards are up.

local WIDTH, HEIGHT = 60, 21
local BELOW = -8                -- the clock's middle, under the minimap's bottom edge
local PIXELS = 1.5              -- the screen's pixels to one of the border's units
local EVERY = 0.1

local box = CreateFrame("Frame", "SUICClock", UIParent)
box:SetWidth(WIDTH)
box:SetHeight(HEIGHT)
box:Hide()

-- The window's height in pixels: its place in the game's list of sizes follows
-- the window (the gxResolution setting does not); else 1080.
local function Fit()
	local sizes = { GetScreenResolutions() }
	local _, _, height = string.find(sizes[GetCurrentResolution()] or "", "%d+x(%d+)")
	return PIXELS * GetScreenHeight() / (tonumber(height) or 1080)
end

function SUIC.RefreshClock()
	if SUIC.DB().clockFrame and not (AZS_GetPhase and AZS_GetPhase() == "choosing") then
		box:SetScale(Fit())
		box:Show()
	else
		box:Hide()
	end
end

local elapsed = 0
local watch = CreateFrame("Frame")
watch:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed < EVERY then
		return
	end
	elapsed = 0
	SUIC.RefreshClock()
end)
watch:Hide()

SUIC.OnStart(function()
	box:SetPoint("CENTER", Minimap, "BOTTOM", 0, BELOW)
	SUIC.Framed(box)
	SUIC.RefreshClock()
	watch:Show()
end)
