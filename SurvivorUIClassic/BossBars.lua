-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the boss bars, kept quiet. A thin bar for each boss
-- alive, the final boss first: its name, its health's share, an enraged one's
-- name in orange. They stand in for the game's boss bars, which are put away
-- while these are on and given back as the game closes.
--
-- From the game's addon API (AZS_GetBosses); with no boss up, nothing shows.

local MOST = 4
local WIDTH = 210
local HEIGHT = 12
local GAP = 3

local holder = CreateFrame("Frame", "SUICBossBars", UIParent)
holder:SetWidth(WIDTH)
holder:SetHeight(MOST * (HEIGHT + GAP))

local function Home(f)
	f:SetPoint("TOP", UIParent, "TOP", 0, -100)
end
Home(holder)

local bars = {}
for index = 1, MOST do
	local bar = CreateFrame("StatusBar", nil, holder)
	bar:SetWidth(WIDTH)
	bar:SetHeight(HEIGHT)
	bar:SetPoint("TOP", holder, "TOP", 0, -(index - 1) * (HEIGHT + GAP))
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:SetStatusBarColor(0.7, 0.1, 0.1)
	bar:SetMinMaxValues(0, 1)
	local back = bar:CreateTexture(nil, "BACKGROUND")
	back:SetTexture(SUIC.FLAT)
	back:SetVertexColor(0, 0, 0, 0.55)
	back:SetAllPoints(bar)
	bar.name = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	bar.name:SetPoint("LEFT", bar, "LEFT", 4, 0)
	bar.share = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	bar.share:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
	bar:Hide()
	bars[index] = bar
end

local function Draw()
	local bosses = {}
	if SUIC.InRun() and AZS_GetBosses then
		bosses = AZS_GetBosses()
		table.sort(bosses, function(a, b)
			if a.final ~= b.final then
				return a.final and true or false
			end
			return (tonumber(a.id) or 0) < (tonumber(b.id) or 0)
		end)
	end
	for index = 1, MOST do
		local bar, boss = bars[index], bosses[index]
		local hpm = boss and tonumber(boss.hpm) or 0
		if boss and hpm > 0 then
			local share = (tonumber(boss.hp) or 0) / hpm
			bar:SetValue(share)
			bar.name:SetText(boss.name or "?")
			if boss.enraged then
				bar.name:SetTextColor(1, 0.5, 0.15)
			elseif boss.final then
				bar.name:SetTextColor(1, 0.82, 0)
			else
				bar.name:SetTextColor(1, 1, 1)
			end
			bar.share:SetText(math.floor(share * 100 + 0.5).."%")
			bar:Show()
		else
			bar:Hide()
		end
	end
end

local elapsed = 0
holder:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed < 0.2 then
		return
	end
	elapsed = 0
	Draw()
end)
holder:Hide()

function SUIC.RefreshBossBars()
	local wanted = SUIC.DB().bossBars
	SUIC.SetGameShown("bosses", not wanted)
	if wanted then
		holder:Show()
		Draw()
	else
		holder:Hide()
	end
end

SUIC.OnStart(function()
	SUIC.AddPiece("bosses", "Boss bars", holder, Home)
	SUIC.RefreshBossBars()
end)
