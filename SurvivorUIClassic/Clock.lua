-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the clock under the minimap. The clock itself is the
-- game's (its 0.131), drawn outside the interface, in the PC's own time zone,
-- with the panels' border round it. It sits under the minimap's bottom edge,
-- the same size in pixels whatever the screen and the interface's size, so the
-- border keeps to pixels too, and it goes with the minimap, while the cards are
-- up, and when the clock is off in the game's options (its 0.136).
--
-- The game's clock has no time zone and no choice of 12 or 24 hours. Asked for
-- either (the options' Minimap tab), a clock of this addon takes its place, in
-- the same spot, and the game's is put away (its 0.136) until it can tell the
-- time asked for again. Hover it for what it can do; a click opens that tab.

local WIDTH, HEIGHT = 60, 21
local BELOW = -8                -- the clock's middle, under the minimap's bottom edge
local PIXELS = 1.5              -- the screen's pixels to one of the border's units
local EVERY = 0.1

local box = CreateFrame("Button", "SUICClock", UIParent)
box:SetWidth(WIDTH)
box:SetHeight(HEIGHT)
box:Hide()

local edge = CreateFrame("Frame", nil, box)
edge:SetAllPoints(box)

-- This addon's clock: the border's ground under it, or with no border its own.
local face = CreateFrame("Frame", nil, box)
face:SetAllPoints(box)
face:SetFrameLevel(edge:GetFrameLevel() + 2)
local ground = face:CreateTexture(nil, "BACKGROUND")
ground:SetTexture(SUIC.FLAT)
ground:SetVertexColor(0, 0, 0, 0.75)
ground:SetPoint("TOPLEFT", box, "TOPLEFT", 3, -3)
ground:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -3, 3)
local shown = SUIC.Text(face, "GameFontHighlight", 8)
shown:SetPoint("CENTER", box, "CENTER", 0, 0)

-- The window's height in pixels: its place in the game's list of sizes follows
-- the window (the gxResolution setting does not); else 1080.
local function Fit()
	local sizes = { GetScreenResolutions() }
	local _, _, height = string.find(sizes[GetCurrentResolution()] or "", "%d+x(%d+)")
	return PIXELS * GetScreenHeight() / (tonumber(height) or 1080)
end

-- The PC's time as the game's clock shows it (its 0.136), a new table each call.
local function Here()
	return AZS_GetLocalTime and AZS_GetLocalTime()
end

-- The computer's time zone in seconds: what its time stands from the game's
-- clock for addons (UTC), to the quarter of an hour.
local function ComputerZone()
	local here = Here()
	if not (here and here.hour and here.minute) then
		return nil
	end
	local apart = here.hour * 60 + here.minute - math.floor(math.mod(time(), 86400) / 60)
	if apart > 840 then
		apart = apart - 1440
	elseif apart < -720 then
		apart = apart + 1440
	end
	return math.floor(apart / 15 + 0.5) * 900
end

-- The time zone in hours: the one chosen, else the computer's.
function SUIC.TimeZoneNow()
	return SUIC.DB().clockZone or (ComputerZone() or 0) / 3600
end

-- A time zone as its name: "UTC", "UTC-3", "UTC+5:30".
function SUIC.ZoneLabel(hours)
	if hours == 0 then
		return "UTC"
	end
	local whole = math.floor(math.abs(hours))
	local minutes = math.floor((math.abs(hours) - whole) * 60 + 0.5)
	return "UTC"..(hours < 0 and "-" or "+")..whole..(minutes > 0 and string.format(":%02d", minutes) or "")
end

-- 24 hours or 12: the one chosen, else as the game's clock has it.
function SUIC.Clock24()
	local chosen = SUIC.DB().clock24
	if chosen ~= nil then
		return chosen
	end
	local here = Here()
	return here and here.is24Hour and true or false
end

-- Whether the time asked for is one the game's clock cannot tell.
local function Ours()
	if not (AZS_HUD_CVARS and AZS_HUD_CVARS.localClock) then
		return false
	end
	local db = SUIC.DB()
	if db.clockZone then
		return true
	end
	local here = Here()
	return db.clock24 ~= nil and here ~= nil and db.clock24 ~= (here.is24Hour and true or false)
end

local function ClockText()
	local now = time() + SUIC.TimeZoneNow() * 3600
	local hour, minute = math.floor(math.mod(now, 86400) / 3600), math.floor(math.mod(now, 3600) / 60)
	if SUIC.Clock24() then
		return string.format("%02d:%02d", hour, minute)
	end
	return string.format("%d:%02d %s", math.mod(hour + 11, 12) + 1, minute, hour < 12 and "AM" or "PM")
end

function SUIC.RefreshClock()
	local ours = Ours()
	if not ours then
		SUIC.SetGameShown("localClock", true)
	elseif AZS_IsHudShown("localClock") then
		SUIC.SetGameShown("localClock", false)
	end
	local clockOn = ours or not (AZS_HUD_CVARS and AZS_HUD_CVARS.localClock) or AZS_IsHudShown("localClock")
	if not (clockOn and Minimap:IsVisible()) or (AZS_GetPhase and AZS_GetPhase() == "choosing") then
		box:Hide()
		return
	end
	box:SetScale(Fit())
	box:Show()
	local framed = SUIC.DB().clockFrame
	if framed then
		edge:Show()
	else
		edge:Hide()
	end
	if ours then
		shown:SetText(ClockText())
		face:Show()
		if framed then
			ground:Hide()
		else
			ground:Show()
		end
	else
		face:Hide()
	end
end

box:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_LEFT")
	GameTooltip:SetText("Your time")
	GameTooltip:AddLine("Click for your computer's time, or untick it and slide to the time zone you want, and for 24 or 12 hours.", 1, 1, 1, 1)
	GameTooltip:Show()
end)
box:SetScript("OnLeave", function() GameTooltip:Hide() end)
box:SetScript("OnClick", function()
	SUIC.OptionsTab("Minimap")
end)

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
	SUIC.Framed(edge)
	SUIC.RefreshClock()
	watch:Show()
end)
