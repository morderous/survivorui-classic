-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: health in numbers on the player and target frames.
--
-- The client alone gives an enemy's health only as a share (its most is 100);
-- the game sends addons the real numbers of the target (AZS_TARGET), so the
-- target frame reads "12.3k / 40.0k (31%)". Off, Value, Percent or Both, for
-- each frame (the minimap button's menu). The text sits in the middle of the
-- bar, in the game's own bar font.

local STYLES = { "off", "value", "percent", "both" }
SUIC.HEALTH_STYLES = STYLES
SUIC.HEALTH_NAMES = { off = "Off", value = "Value", percent = "Percent", both = "Both" }

local function Text(style, hp, hpm, shareOnly)
	if style == "off" or not hpm or hpm <= 0 then
		return ""
	end
	local share = math.floor(hp / hpm * 100 + 0.5).."%"
	if shareOnly or style == "percent" then
		return share
	elseif style == "value" then
		return SUIC.Short(hp).." / "..SUIC.Short(hpm)
	end
	return SUIC.Short(hp).." / "..SUIC.Short(hpm).." ("..share..")"
end

-- On a frame of its own over the bar and the unit frame's art: on the unit
-- frame itself, the bar (its child) would lie over it.
local function MakeText(bar, unitFrame)
	if not (bar and unitFrame) then
		return nil
	end
	local holder = CreateFrame("Frame", nil, unitFrame)
	holder:SetAllPoints(bar)
	holder:SetFrameLevel(unitFrame:GetFrameLevel() + 10)
	local text = holder:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
	text:SetPoint("CENTER", bar, "CENTER", 0, 0)
	text:Hide()
	return text
end

local playerText = MakeText(PlayerFrameHealthBar, PlayerFrame)
local targetText = MakeText(TargetFrameHealthBar, TargetFrame)

local function UpdatePlayer()
	if not playerText then
		return
	end
	local style = SUIC.DB().playerHealth
	playerText:SetText(Text(style, UnitHealth("player"), UnitHealthMax("player")))
	-- The stock numbers, shown on hover, would lie on ours.
	if PlayerFrameHealthBarText then
		if style == "off" then
			PlayerFrameHealthBar.TextString = PlayerFrameHealthBarText
		else
			PlayerFrameHealthBar.TextString = nil
			PlayerFrameHealthBarText:Hide()
		end
	end
	if style == "off" then
		playerText:Hide()
	else
		playerText:Show()
	end
end

local function UpdateTarget()
	if not targetText then
		return
	end
	local style = SUIC.DB().targetHealth
	if style == "off" or not UnitExists("target") then
		targetText:Hide()
		return
	end
	local hp, hpm = UnitHealth("target"), UnitHealthMax("target")
	local shareOnly = false
	local name = UnitName("target")
	if AZS_TARGET and AZS_TARGET.name == name and (tonumber(AZS_TARGET.hpm) or 0) > 0 then
		hp, hpm = tonumber(AZS_TARGET.hp) or 0, tonumber(AZS_TARGET.hpm)
	elseif not UnitIsPlayer("target") and hpm == 100 then
		-- No numbers sent for it: its share alone.
		shareOnly = true
	end
	if UnitIsDead("target") then
		hp = 0
	end
	targetText:SetText(Text(style, hp, hpm, shareOnly))
	targetText:Show()
end

function SUIC.UpdateHealthText()
	if SUIC.active then
		UpdatePlayer()
		UpdateTarget()
	end
end

local watch = CreateFrame("Frame")
watch:SetScript("OnEvent", function()
	if event == "CHAT_MSG_ADDON" then
		if arg1 == "AZSTGT" then
			UpdateTarget()
		end
	elseif event == "PLAYER_TARGET_CHANGED" then
		UpdateTarget()
	elseif arg1 == "player" then
		UpdatePlayer()
	elseif arg1 == "target" then
		UpdateTarget()
	else
		UpdatePlayer()
		UpdateTarget()
	end
end)

SUIC.OnStart(function()
	watch:RegisterEvent("PLAYER_ENTERING_WORLD")
	watch:RegisterEvent("PLAYER_TARGET_CHANGED")
	watch:RegisterEvent("UNIT_HEALTH")
	watch:RegisterEvent("UNIT_MAXHEALTH")
	watch:RegisterEvent("CHAT_MSG_ADDON")
	SUIC.UpdateHealthText()
end)
