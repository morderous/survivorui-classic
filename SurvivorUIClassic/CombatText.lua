-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the game's combat numbers, in Barlow, each at 30 to 100%
-- of its size (the options' Combat text tab).
--
-- The damage you deal: the numbers the engine draws over the very enemy hit,
-- at a size of its own (a share of the screen's diagonal), in the face
-- DAMAGE_TEXT_FONT names, which it reads once, as the addons finish loading:
-- a change shows the next time the game opens. A smaller number is the face
-- drawn smaller in the same box (Fonts\Numbers: scaled copies of Barlow
-- Condensed SemiBold, Latin letters only).
--
-- The damage you take: the game's floating combat text over your hero, in
-- Barlow, its sizes (COMBAT_TEXT_HEIGHT and the crits') scaled.

local FOLDER = "Interface\\AddOns\\SurvivorUIClassic\\Fonts\\"
local BARLOW = FOLDER.."BarlowCondensed-SemiBold.ttf"
-- The floating combat text's own sizes (Blizzard_CombatText.lua).
local TAKEN = { COMBAT_TEXT_HEIGHT = 25, COMBAT_TEXT_CRIT_MINHEIGHT = 30, COMBAT_TEXT_CRIT_MAXHEIGHT = 60 }
local LINES = 20                -- its strings, CombatText1 to 20

function SUIC.NumberFont()
	local size = tonumber(SUIC.DB().numberSize) or SUIC.Default("numberSize")
	if size < 100 then
		size = math.max(30, math.floor(size / 10 + 0.5) * 10)
		return FOLDER.."Numbers\\Barlow-"..size..".ttf"
	end
	return BARLOW
end

function SUIC.ApplyNumberFont()
	DAMAGE_TEXT_FONT = SUIC.NumberFont()
end

-- The combat text's face and sizes; its strings are there once the game has
-- loaded it.
function SUIC.ApplyTakenSize()
	local share = (tonumber(SUIC.DB().takenSize) or SUIC.Default("takenSize")) / 100
	for name, size in pairs(TAKEN) do
		setglobal(name, math.floor(size * share + 0.5))
	end
	local height = math.floor(TAKEN.COMBAT_TEXT_HEIGHT * share + 0.5)
	if CombatTextFont and CombatTextFont.SetFont then
		CombatTextFont:SetFont(BARLOW, height)
	end
	for index = 1, LINES do
		local line = getglobal("CombatText"..index)
		if line and line.SetFont then
			line:SetFont(BARLOW, height)
		end
	end
end

-- The game's numbers turned back on: Survivor UI turns them off while its own
-- numbers show and back on as the game closes, but standing aside for this
-- addon it does neither.
function SUIC.GameNumbers()
	return GetCVar("CombatDamage") ~= "0"
end

-- The damage font set as this addon loads, the game reading it just after,
-- when this addon is the one that runs. The combat text's as it starts, and
-- again whenever the game loads its combat text (which sets its own).
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function()
	if arg1 == "SurvivorUIClassic" then
		if SUIC.WillRun() then
			SUIC.ApplyNumberFont()
		end
	elseif arg1 == "Blizzard_CombatText" and SUIC.active then
		SUIC.ApplyTakenSize()
	end
end)

SUIC.OnStart(function()
	if SurvivorUI_Standby and not SUIC.GameNumbers() then
		SetCVar("CombatDamage", "1")
	end
	SUIC.ApplyTakenSize()
end)
