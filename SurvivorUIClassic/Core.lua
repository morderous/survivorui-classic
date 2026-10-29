-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the game's own interface for Azeroth Survivors, with a
-- few things more: everything movable from a minimap button, an enemy's
-- health in numbers, a build list, the jewelry worn, a run frame and boss bars.
--
-- Core: the saved settings, the one switch every piece waits on, and the
-- game's run screens given back as the game closes.
--
-- Survivor UI changes the same frames, so only one of the two runs. With both
-- on, a panel asks which one (Choice.lua). Survivor UI steps aside at its next
-- start when this one is chosen: it loads after this addon (its OptionalDeps)
-- and reads SurvivorUIClassicDB.use before any of its files does anything.

SUIC = {}

SUIC.VERSION = GetAddOnMetadata and GetAddOnMetadata("SurvivorUIClassic", "Version") or "?"
SUIC.FLAT = "Interface\\ChatFrame\\ChatFrameBackground"

-- The stock tooltip's frame: what every panel of the addon wears.
SUIC.BACKDROP = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local DEFAULTS = {
	pos = {},
	targetHealth = "both",
	playerHealth = "both",
	runFrame = true,
	bossBars = true,
	buildList = true,
	jewelry = true,
	overCards = true,
}

function SUIC.DB()
	SurvivorUIClassicDB = SurvivorUIClassicDB or {}
	local db = SurvivorUIClassicDB
	for key, value in pairs(DEFAULTS) do
		if db[key] == nil then
			if type(value) == "table" then
				db[key] = {}
			else
				db[key] = value
			end
		end
	end
	return db
end

function SUIC.Print(text)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cffffd100SurvivorUI Classic:|r "..text)
	end
end

------------------------------------------------------------------------------
-- The pieces. Each one registers a start, run once the addon is the one in
-- use; until then nothing of it shows or listens.

local starts = {}

function SUIC.OnStart(start)
	table.insert(starts, start)
	if SUIC.active then
		start()
	end
end

function SUIC.Start()
	if SUIC.active then
		return
	end
	SUIC.active = true
	for index = 1, table.getn(starts) do
		starts[index]()
	end
end

-- Survivor UI running, not standing aside.
function SUIC.OtherOn()
	return IsAddOnLoaded and IsAddOnLoaded("SurvivorUI") and not SurvivorUI_Standby
end

------------------------------------------------------------------------------
-- The game's run screens (the clock, the boss bars) this addon puts its own in
-- place of are switched off by the game's settings, which the game saves:
-- left off, a game without the addon would go on without them. So each one
-- switched off here goes back on as the game closes; the next start switches
-- it off again.

local hidden = {}

function SUIC.SetGameShown(part, shown)
	if not AZS_SetHudShown then
		return
	end
	if shown then
		-- Only what this addon put away: the player's own choice stays.
		if hidden[part] then
			hidden[part] = nil
			AZS_SetHudShown(part, true)
		end
	elseif not hidden[part] or (AZS_IsHudShown and AZS_IsHudShown(part)) then
		hidden[part] = true
		AZS_SetHudShown(part, false)
	end
end

------------------------------------------------------------------------------
-- Numbers as a bar shows them: 950, 12.3k, 4.56M.

function SUIC.Short(value)
	value = tonumber(value) or 0
	if value >= 1000000 then
		return string.format("%.2fM", value / 1000000)
	elseif value >= 10000 then
		return string.format("%.1fk", value / 1000)
	end
	return tostring(math.floor(value + 0.5))
end

-- Seconds as a clock reads them: 4:07, 1:02:30.
function SUIC.Clock(seconds)
	seconds = math.max(0, math.floor((tonumber(seconds) or 0) + 0.5))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor(math.mod(seconds, 3600) / 60)
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, math.mod(seconds, 60))
	end
	return string.format("%d:%02d", minutes, math.mod(seconds, 60))
end

-- In a run (playing, choosing cards, paused, dead or won), not in town.
function SUIC.InRun()
	if not AZS_GetPhase then
		return false
	end
	local phase = AZS_GetPhase()
	return phase ~= nil and phase ~= "ready"
end

-- Kept over the level-up and jewelry cards (the game's 0.126), as chosen.
function SUIC.OverCards(frame, wanted)
	if AZS_SetOnTopOfScreens and frame and frame:GetName() then
		AZS_SetOnTopOfScreens(frame, wanted and SUIC.DB().overCards and true or false)
	end
end

------------------------------------------------------------------------------
-- Who runs: decided once the world is up, when every addon has loaded.

local core = CreateFrame("Frame", "SUICCore")
core:RegisterEvent("PLAYER_ENTERING_WORLD")
core:RegisterEvent("PLAYER_LOGOUT")
core:SetScript("OnEvent", function()
	if event == "PLAYER_LOGOUT" then
		if AZS_SetHudShown then
			for part in pairs(hidden) do
				AZS_SetHudShown(part, true)
			end
		end
		return
	end
	if this.decided then
		return
	end
	this.decided = true
	local db = SUIC.DB()
	if not SUIC.OtherOn() then
		-- Survivor UI standing aside for this one, or away: back, it asks again.
		if IsAddOnLoaded and IsAddOnLoaded("SurvivorUI") then
			db.use = "classic"
		else
			db.use = nil
		end
		SUIC.Start()
	elseif db.use == "survivorui" then
		-- Survivor UI chosen: this one waits, quiet; /suic asks again.
		return
	elseif db.use == "classic" and SurvivorUI_CanStandBy then
		-- Chosen this session or an older one, Survivor UI not yet gone.
		SUIC.ShowRestart()
	else
		SUIC.ShowChoice()
	end
end)

SLASH_SURVIVORUICLASSIC1 = "/suic"
SlashCmdList["SURVIVORUICLASSIC"] = function(msg)
	msg = string.lower(msg or "")
	if not SUIC.active then
		SUIC.ShowChoice(true)
	elseif msg == "move" then
		SUIC.SetMoveMode(true)
	elseif msg == "reset" then
		SUIC.ResetPositions()
	else
		SUIC.Print("/suic move, /suic reset, or the button on the minimap. Version "..SUIC.VERSION..".")
	end
end
