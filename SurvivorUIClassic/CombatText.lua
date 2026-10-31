-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the game's combat numbers, in Barlow, each at 30 to 100%
-- of its size, or none of it at all (the options' Combat text tab).
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
--
-- None at all: CombatDamage off stops the numbers and words over the enemies;
-- it is the game's own setting, which the game saves, so it goes back on as the
-- world is left, as the game's screens do, with the same limit: closing the
-- game, that is not saved (Core.lua). The text over your hero stops short of
-- its strings, every kind of it, whatever the game's options show: none of the
-- game's settings is touched for it.

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

local stockAdd

local function HoldText()
	if not stockAdd and CombatText_AddMessage then
		stockAdd = CombatText_AddMessage
		CombatText_AddMessage = function(message, scroll, r, g, b, kind, staggered)
			if SUIC.DB().combatText then
				return stockAdd(message, scroll, r, g, b, kind, staggered)
			end
		end
	end
end

function SUIC.ApplyCombatText()
	HoldText()
	SetCVar("CombatDamage", SUIC.DB().combatText and "1" or "0")
end

-- The damage font set as this addon loads, the game reading it just after,
-- when this addon is the one that runs. The combat text's as it starts, and
-- again whenever the game loads its combat text (which sets its own).
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:RegisterEvent("PLAYER_LEAVING_WORLD")
loader:RegisterEvent("PLAYER_LOGOUT")
loader:SetScript("OnEvent", function()
	if event ~= "ADDON_LOADED" then
		if SUIC.active and not SUIC.DB().combatText then
			SetCVar("CombatDamage", event == "PLAYER_ENTERING_WORLD" and "0" or "1")
		end
	elseif arg1 == "SurvivorUIClassic" then
		if SUIC.WillRun() then
			SUIC.ApplyNumberFont()
		end
	elseif arg1 == "Blizzard_CombatText" and SUIC.active then
		SUIC.ApplyTakenSize()
		HoldText()
	end
end)

SUIC.OnStart(function()
	if not SUIC.DB().combatText then
		SetCVar("CombatDamage", "0")
	elseif SurvivorUI_Standby and not SUIC.GameNumbers() then
		SetCVar("CombatDamage", "1")
	end
	HoldText()
	SUIC.ApplyTakenSize()
end)
