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

-- The stock tooltip's frame: Move frames' boxes wear it (Style.lua has the
-- panels' borders).
SUIC.BACKDROP = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local DEFAULTS = {
	pos = {},                  -- each moved piece's place (Mover.lua)
	hid = {},                  -- the game's screens this addon put away (SetGameShown)
	uiSize = 0.8,              -- the whole interface's size (Mover.lua), for everyone
	scale = {},                -- each piece's size, 1 its own
	border = "tooltip",        -- the panels' border (Style.lua)
	overCards = true,          -- tracker, build list, jewelry and meter over the cards
	hideGameRow = true,        -- the game's row of spells and jewelry, under the chat
	targetHealth = "both",
	playerHealth = "both",
	tracker = true,
	trackerBosses = true,
	trackerGuardians = true,
	trackerElites = true,
	trackerKills = true,
	trackerGold = true,
	trackerCache = true,
	bossBars = true,
	bossGuardians = true,
	bossElites = true,
	bossMost = 4,               -- guardians and elites at most; the bosses always
	bossText = "percent",
	buildList = true,
	jewelry = true,
	meter = true,
	meterLines = 7,
	meterMode = "damage",
	meterFold = true,          -- the lines under meterFoldShare% folded into Others
	meterFoldShare = 10,
	mapButton = true,          -- the addon's button on the minimap
	guideButton = true,        -- the guide's button on the minimap (Guide.lua)
	guideRead = {},            -- the guide's pages read
	mapPins = true,            -- the caches and the lairs on the minimap (MapPins.lua)
	clockFrame = true,         -- a border round the game's clock under it (Clock.lua)
	fps = true,                -- the frames a second, in the screen's corner (Fps.lua)
	cooldownText = true,       -- the numbers on the action buttons (Cooldowns.lua)
	lootLog = true,            -- the loot notices (Loot.lua)
	summons = true,            -- the summons and totems (Summons.lua)
	talentTimers = true,       -- the talents' clocks (TalentTimers.lua)
	levelUp = true,            -- the Level Up! button (LevelUp.lua)
	characterPage = true,      -- the character page in one panel (CharacterPage.lua)
	plateOverlap = true,       -- the game's Nameplate Layout, Overlapping (Nameplates.lua)
	combatText = true,         -- the game's combat text at all (CombatText.lua)
	ctColumns = false,         -- Survivor UI's numbers in its place (CombatColumns.lua)
	ctIcons = true,            -- each with its source's icon
	ctColors = true,           -- in the damage meter's color
	ctAdd = true,              -- hits close together added up (x3)
	ctCritColumn = true,       -- the crits in a column of their own
	ctPeriodic = true,         -- damage over time
	ctHitsTaken = true,        -- the damage you take
	ctHeals = true,            -- the healing
	ctSize = 1,
	numberSize = 40,           -- the damage you deal's numbers, in Barlow, 30 to 100%
	takenSize = 30,            -- the damage you take's, in Barlow too, 30 to 100%
}

local filled
function SUIC.DB()
	if filled and SurvivorUIClassicDB == filled then
		return filled
	end
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
	-- Settings the builds before 0.2.0 wrote, set once: the gold in the run
	-- tracker (the game's kills and gold line gone), the run frame no more.
	if (db.defaults or 0) < 2 then
		db.trackerGold = true
		db.runFrame = nil
		db.defaults = 2
	end
	-- The whole interface at 80% for everyone, once.
	if db.defaults < 3 then
		db.uiSize = 0.8
		db.defaults = 3
	end
	-- At most four guardians and elites in the boss bars, once.
	if db.defaults < 4 then
		db.bossMost = 4
		db.defaults = 4
	end
	-- The summons and the talent clocks back over the action bar.
	if db.defaults < 5 then
		db.pos.summons, db.pos.talentTimers = nil, nil
		db.defaults = 5
	end
	-- The talent clocks and the summons side by side over the bar.
	if db.defaults < 6 then
		db.pos.summons, db.pos.talentTimers, db.pos.levelup = nil, nil, nil
		db.defaults = 6
	end
	filled = db
	return db
end

function SUIC.Default(key)
	return DEFAULTS[key]
end

-- A class's color, r, g, b: the shaman's blue, not the old client's pink.
local SHAMAN_BLUE = { r = 0, g = 0.44, b = 0.87 }

function SUIC.ClassColor(class)
	local key = class and string.upper(class)
	local color = key == "SHAMAN" and SHAMAN_BLUE or (key and RAID_CLASS_COLORS and RAID_CLASS_COLORS[key])
	if color then
		return color.r, color.g, color.b
	end
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

-- This addon the one that will run, known as it loads (before Survivor UI
-- does): chosen, or Survivor UI away.
function SUIC.WillRun()
	local use = SUIC.DB().use
	if use == "classic" then
		return true
	elseif use == "survivorui" then
		return false
	end
	local name, _, _, enabled, loadable = GetAddOnInfo("SurvivorUI")
	return not (name and enabled and loadable)
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

--
-- The game saves its settings a second after each change, and closing it
-- the setting given back at the logout is not saved: what is put away stays
-- away. So the parts put away are kept in this addon's own settings too, and
-- with Survivor UI chosen in its place, this addon gives them back as it
-- loads (before Survivor UI puts its own away).

local function Hidden()
	return SUIC.DB().hid
end

function SUIC.SetGameShown(part, shown)
	if not AZS_SetHudShown then
		return
	end
	local hidden = Hidden()
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

local function GiveBack()
	if AZS_SetHudShown then
		for part in pairs(Hidden()) do
			AZS_SetHudShown(part, true)
		end
	end
end

local giver = CreateFrame("Frame")
giver:RegisterEvent("ADDON_LOADED")
giver:SetScript("OnEvent", function()
	if arg1 == "SurvivorUIClassic" then
		this:UnregisterEvent("ADDON_LOADED")
		if SUIC.DB().use == "survivorui" then
			GiveBack()
			SUIC.DB().hid = {}
		end
	end
end)

------------------------------------------------------------------------------
-- Numbers as a bar shows them: 950, 1.6k, 462.6k, 2.36M.

function SUIC.Short(value)
	value = tonumber(value) or 0
	if value >= 1000000 then
		return string.format("%.2fM", value / 1000000)
	elseif value >= 1000 then
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

-- Kept over the level-up and jewelry cards (the game's 0.126), as chosen:
-- the tracker, the build list, the jewelry and the meter, which help to choose.
local overs = {}
function SUIC.OverCards(frame)
	if frame and frame:GetName() then
		overs[frame:GetName()] = true
		if AZS_SetOnTopOfScreens then
			AZS_SetOnTopOfScreens(frame, SUIC.DB().overCards and true or false)
		end
	end
end

function SUIC.RefreshOverCards()
	if not AZS_SetOnTopOfScreens then
		return
	end
	for name in pairs(overs) do
		AZS_SetOnTopOfScreens(name, SUIC.DB().overCards and true or false)
	end
end

-- While the cards are up, what stands under them goes: the game can draw a
-- piece's art over the veil where a piece over it has the same (a button's
-- icon through a card, as the build list's; seen with Survivor UI). What it
-- was comes back with them.
local UNDER_CARDS = { "MainMenuBar", "SUICSummons", "SUICTalentTimers" }
local cardsUp = false
local underWatch = CreateFrame("Frame")
underWatch:Hide()
underWatch:SetScript("OnUpdate", function()
	local up = (AZS_GetPhase and AZS_GetPhase() == "choosing" and SUIC.DB().overCards) and true or false
	if up == cardsUp then
		return
	end
	cardsUp = up
	for index = 1, table.getn(UNDER_CARDS) do
		local frame = getglobal(UNDER_CARDS[index])
		if frame and up then
			frame.suicAlpha = frame:GetAlpha()
			frame:SetAlpha(0)
		elseif frame and frame.suicAlpha then
			frame:SetAlpha(frame.suicAlpha)
			frame.suicAlpha = nil
		end
	end
end)

-- The game's row of spells and jewelry under the chat: away while asked.
function SUIC.RefreshGameRow()
	SUIC.SetGameShown("build", not SUIC.DB().hideGameRow)
end
-- The game's screens this addon has none of its own for: the revive bar,
-- the banners.
-- Survivor UI puts some away for its own and, closing, cannot give them back
-- (the game has saved its settings by then): standing aside for this addon,
-- they come back.
local GAME_ONLY = { "revive", "banners" }

SUIC.OnStart(function()
	underWatch:Show()
	SUIC.RefreshGameRow()
	if SurvivorUI_Standby and AZS_SetHudShown and AZS_IsHudShown and AZS_HUD_CVARS then
		for index = 1, table.getn(GAME_ONLY) do
			local part = GAME_ONLY[index]
			if AZS_HUD_CVARS[part] and not AZS_IsHudShown(part) then
				AZS_SetHudShown(part, true)
			end
		end
		-- The game's clock too, this addon's clock, if it was Survivor UI that
		-- put it away: the player can turn it off in the game's options.
		if AZS_HUD_CVARS.localClock and SurvivorUIDB and SurvivorUIDB.hidGameLocalClock then
			AZS_SetHudShown("localClock", true)
			SurvivorUIDB.hidGameLocalClock = nil
		end
	end
end)

------------------------------------------------------------------------------
-- Who runs: decided once the world is up, when every addon has loaded.

local core = CreateFrame("Frame", "SUICCore")
core:RegisterEvent("PLAYER_ENTERING_WORLD")
core:RegisterEvent("PLAYER_LEAVING_WORLD")
core:RegisterEvent("PLAYER_LOGOUT")
core:SetScript("OnEvent", function()
	-- The game's screens given back as the world is left, before the game
	-- saves its settings on the way out (and again at the logout); the pieces
	-- put them away again when the world comes back.
	if event == "PLAYER_LEAVING_WORLD" or event == "PLAYER_LOGOUT" then
		GiveBack()
		return
	end
	if this.decided then
		if SUIC.active then
			SUIC.RefreshGameRow()
		end
		return
	end
	this.decided = true
	local db = SUIC.DB()
	-- The launcher has read it: this start is the one it was for.
	db.restartAt = nil
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
		SUIC.SetMoveMode(not SUIC.MoveMode())
	elseif msg == "reset" then
		SUIC.ResetPositions()
	elseif msg == "guide" then
		SUIC.ToggleGuide()
	elseif msg == "help" then
		SUIC.Print("/suic for the options, /suic move to move frames, /suic guide for the guide, /suic reset to put them all back. Version "..SUIC.VERSION..".")
	else
		SUIC.ToggleOptions()
	end
end
