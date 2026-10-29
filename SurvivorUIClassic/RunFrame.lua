-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the run frame, at the top of the screen in the middle.
--
-- The zone (and its Heroic level, or Endless), the time gone against the
-- second the final boss comes, a bar of the run with a skull for every boss
-- at its second (grey to come, white the next, orange alive, green slain),
-- and what comes next: "Hogger in 1:23". It stands in for the game's clock,
-- which is put away while it is on and given back as the game closes.
--
-- From the game's addon API (AZS_RUN, AZS_ZONE, AZS_SCHEDULE); out of a run it
-- hides.

local WIDTH = 250
local BAR_WIDTH = 220
local SKULL = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"
local COLORS = {
	due = { 0.55, 0.55, 0.55 },
	next = { 1, 1, 1 },
	up = { 1, 0.5, 0.15 },
	dead = { 0.25, 0.85, 0.25 },
}

local frame = CreateFrame("Frame", "SUICRunFrame", UIParent)
frame:SetWidth(WIDTH)
frame:SetHeight(86)
frame:SetBackdrop(SUIC.BACKDROP)
frame:SetBackdropColor(0, 0, 0, 0.7)
frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
frame:Hide()

local function Home(f)
	f:SetPoint("TOP", UIParent, "TOP", 0, -8)
end
Home(frame)

local zone = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
zone:SetPoint("TOP", frame, "TOP", 0, -9)

local tag = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
tag:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -11)

local clock = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
clock:SetPoint("TOP", frame, "TOP", 0, -26)

local bar = CreateFrame("StatusBar", nil, frame)
bar:SetWidth(BAR_WIDTH)
bar:SetHeight(10)
bar:SetPoint("TOP", frame, "TOP", 0, -50)
bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
bar:SetStatusBarColor(1, 0.75, 0.1)
bar:SetMinMaxValues(0, 1)
local barBack = bar:CreateTexture(nil, "BACKGROUND")
barBack:SetTexture(SUIC.FLAT)
barBack:SetVertexColor(0, 0, 0, 0.6)
barBack:SetAllPoints(bar)

local nextLine = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
nextLine:SetPoint("TOP", bar, "BOTTOM", 0, -8)

-- A skull for each boss, its tooltip its name and its second.
local skulls = {}
local function Skull(index)
	if skulls[index] then
		return skulls[index]
	end
	local skull = CreateFrame("Frame", nil, bar)
	skull:SetWidth(14)
	skull:SetHeight(14)
	skull:EnableMouse(true)
	skull.icon = skull:CreateTexture(nil, "OVERLAY")
	skull.icon:SetTexture(SKULL)
	skull.icon:SetAllPoints(skull)
	skull:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_BOTTOM")
		GameTooltip:SetText(this.name or "?")
		GameTooltip:AddLine(this.when or "", 1, 1, 1)
		GameTooltip:Show()
	end)
	skull:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	skulls[index] = skull
	return skull
end

local function Num(value)
	return tonumber(value) or 0
end

local HEROIC = { "I", "II", "III", "IV", "V" }

local function Draw()
	local run, zoneInfo = AZS_RUN or {}, AZS_ZONE or {}
	local now = AZS_GetRunTime and AZS_GetRunTime() or Num(run.t)
	local length = Num(zoneInfo.len)
	local endless = Num(run.endl) == 1
	zone:SetText(zoneInfo.zname or "")
	local heroic = Num(zoneInfo.heroic)
	if endless then
		tag:SetText("|cffd080ffEndless|r")
	elseif heroic > 0 then
		tag:SetText("|cffff7a2eHeroic "..(HEROIC[heroic] or heroic).."|r")
	else
		tag:SetText("")
	end

	if endless or length <= 0 then
		clock:SetText(SUIC.Clock(now))
		bar:SetValue(1)
		bar:SetStatusBarColor(0.6, 0.35, 0.8)
	else
		clock:SetText(SUIC.Clock(now).." |cffaaaaaa/ "..SUIC.Clock(length).."|r")
		bar:SetValue(math.min(1, now / length))
		bar:SetStatusBarColor(1, 0.75, 0.1)
	end

	-- The bosses on the bar; the first one still to come is the next.
	local schedule = AZS_SCHEDULE or {}
	local count = endless and 0 or table.getn(schedule)
	local nextBoss, upBoss
	for index = 1, count do
		local boss = schedule[index]
		local state = boss.state or "due"
		if state == "due" and not nextBoss then
			nextBoss = boss
			state = "next"
		elseif state == "up" and not upBoss then
			upBoss = boss
		end
		local skull = Skull(index)
		local at = Num(boss.at)
		local size = Num(boss.final) == 1 and 18 or 14
		skull:SetWidth(size)
		skull:SetHeight(size)
		skull:ClearAllPoints()
		skull:SetPoint("CENTER", bar, "LEFT", BAR_WIDTH * math.min(1, at / length), 0)
		local color = COLORS[state] or COLORS.due
		skull.icon:SetVertexColor(color[1], color[2], color[3])
		skull.name = boss.name
		skull.when = SUIC.Clock(at)
		skull:Show()
	end
	for index = count + 1, table.getn(skulls) do
		skulls[index]:Hide()
	end

	if Num(run.won) == 1 and not endless then
		nextLine:SetText("|cff40d940Victory|r")
	elseif upBoss then
		nextLine:SetText("|cffff8026"..(upBoss.name or "?").." is here|r")
	elseif nextBoss then
		nextLine:SetText((nextBoss.name or "?").." in "..SUIC.Clock(Num(nextBoss.at) - now))
	elseif Num(run.nb) >= 0 and run.nb then
		nextLine:SetText("Next boss in "..SUIC.Clock(run.nb))
	else
		nextLine:SetText("")
	end
end

local elapsed = 0
frame:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed < 0.1 then
		return
	end
	elapsed = 0
	Draw()
end)

-- Shown in a run, while it is wanted; the game's clock away while it is.
local watch = CreateFrame("Frame")
local function Refresh()
	local wanted = SUIC.DB().runFrame
	SUIC.SetGameShown("clock", not wanted)
	if wanted and SUIC.InRun() then
		if not frame:IsShown() then
			frame:Show()
			Draw()
		end
	else
		frame:Hide()
	end
end
SUIC.RefreshRunFrame = Refresh

local ticker = 0
watch:SetScript("OnUpdate", function()
	ticker = ticker + arg1
	if ticker < 0.5 then
		return
	end
	ticker = 0
	Refresh()
end)
watch:Hide()

SUIC.OnStart(function()
	SUIC.AddPiece("run", "Run frame", frame, Home)
	SUIC.OverCards(frame, true)
	watch:Show()
	Refresh()
end)
