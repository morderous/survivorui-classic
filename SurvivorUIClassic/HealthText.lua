-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: health and mana in numbers on the player and target
-- frames, the mana's words as the health's.
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
	text.bar = bar
	text:Hide()
	return text
end

-- The text in the bar's font, smaller, and smaller still until it fits
-- inside the bar whole.
local function Fit(text, words)
	local font, _, flags = text:GetFont()
	local room = text.bar:GetWidth() - 6
	local size = 10
	text:SetFont(font, size, flags)
	text:SetText(words)
	while size > 7 and text:GetStringWidth() > room do
		size = size - 1
		text:SetFont(font, size, flags)
		text:SetText(words)
	end
end

local playerText = MakeText(PlayerFrameHealthBar, PlayerFrame)
local targetText = MakeText(TargetFrameHealthBar, TargetFrame)
local playerMana = MakeText(PlayerFrameManaBar, PlayerFrame)
local targetMana = MakeText(TargetFrameManaBar, TargetFrame)

-- A frame's mana, rage or energy, in the health's style: the stock numbers
-- ("Mana 100 / 100", in a larger font) kept off, as on the health's bar.
local function UpdateMana(text, bar, stock, unit, style)
	if not text then
		return
	end
	if style == "off" then
		if stock then
			bar.TextString = stock
		end
		text:Hide()
		return
	end
	if stock then
		bar.TextString = nil
		stock:Hide()
	end
	local most = UnitManaMax(unit) or 0
	if most > 0 and UnitExists(unit) then
		Fit(text, Text(style, UnitMana(unit), most))
		text:Show()
	else
		text:Hide()
	end
end

-- The shields on you (AZS_RUN's sh, the game's; ٴٴ, 2026-11-03), as the
-- Survivor UI draws them: striped light blue on your health bar from where
-- the health ends, a bright edge at its end; past the bar's end, over its
-- right end instead. In the numbers too: the health and the shield together,
-- light blue, the share past 100%. Off with "Shields on your health"
-- (shieldBar, the Unit frames tab).
local shield
if PlayerFrameHealthBar then
	shield = CreateFrame("Frame", nil, PlayerFrameHealthBar)
	shield:SetAllPoints(PlayerFrameHealthBar)
	shield:SetFrameLevel(PlayerFrameHealthBar:GetFrameLevel() + 1)
	shield.fill = shield:CreateTexture(nil, "BACKGROUND")
	shield.fill:SetTexture(SUIC.FLAT)
	shield.fill:SetVertexColor(0.59, 0.82, 1, 0.45)
	shield.stripes = shield:CreateTexture(nil, "BORDER")
	shield.stripes:SetTexture("Interface\\AddOns\\SurvivorUIClassic\\Art\\ShieldStripes")
	shield.edge = shield:CreateTexture(nil, "ARTWORK")
	shield.edge:SetTexture(SUIC.FLAT)
	shield.edge:SetVertexColor(0.9, 0.97, 1, 1)
	shield:Hide()
end

-- What the shields hold now; 0 with "Shields on your health" off.
local function Held()
	if not SUIC.DB().shieldBar then
		return 0
	end
	return tonumber((AZS_RUN or {}).sh) or 0
end

local function UpdateShield()
	if not shield then
		return
	end
	local most = tonumber((AZS_RUN or {}).hpm) or UnitHealthMax("player") or 0
	local held = most > 0 and Held() / most or 0
	if held <= 0.002 or not SUIC.active then
		shield:Hide()
		return
	end
	local width = PlayerFrameHealthBar:GetWidth()
	local health = UnitHealthMax("player") > 0 and UnitHealth("player") / UnitHealthMax("player") or 0
	held = math.min(1, held)
	local from, to, edge = health, health + held, health + held
	if to > 1 then
		from, to, edge = 1 - held, 1, 1 - held
	end
	local bar = PlayerFrameHealthBar
	shield.fill:ClearAllPoints()
	shield.fill:SetPoint("TOPLEFT", bar, "TOPLEFT", width * from, 0)
	shield.fill:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", width * to, 0)
	shield.stripes:ClearAllPoints()
	shield.stripes:SetPoint("TOPLEFT", bar, "TOPLEFT", width * from, 0)
	shield.stripes:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", width * to, 0)
	shield.stripes:SetTexCoord(from, to, 0, 1)
	shield.edge:ClearAllPoints()
	shield.edge:SetPoint("TOPLEFT", bar, "TOPLEFT", width * edge - 1, 0)
	shield.edge:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", width * edge + 1, 0)
	shield:Show()
end

local function UpdatePlayer()
	if not playerText then
		return
	end
	local style = SUIC.DB().playerHealth
	local held = Held()
	if held >= 1 then
		Fit(playerText, Text(style, UnitHealth("player") + held, UnitHealthMax("player")))
		playerText:SetTextColor(0.59, 0.82, 1)
	else
		Fit(playerText, Text(style, UnitHealth("player"), UnitHealthMax("player")))
		playerText:SetTextColor(1, 1, 1)
	end
	UpdateShield()
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
	UpdateMana(playerMana, PlayerFrameManaBar, PlayerFrameManaBarText, "player", style)
end

local function UpdateTarget()
	if not targetText then
		return
	end
	local style = SUIC.DB().targetHealth
	UpdateMana(targetMana, TargetFrameManaBar, TargetFrameManaBarText, "target", style)
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
	Fit(targetText, Text(style, hp, hpm, shareOnly))
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

-- The shields come and go with no event of their own: looked at five times a
-- second.
local shieldWait = 0
watch:SetScript("OnUpdate", function()
	shieldWait = shieldWait + arg1
	if shieldWait >= 0.2 then
		shieldWait = 0
		if SUIC.active then
			UpdatePlayer()
		else
			UpdateShield()
		end
	end
end)

SUIC.OnStart(function()
	watch:RegisterEvent("PLAYER_ENTERING_WORLD")
	watch:RegisterEvent("PLAYER_TARGET_CHANGED")
	watch:RegisterEvent("UNIT_HEALTH")
	watch:RegisterEvent("UNIT_MAXHEALTH")
	watch:RegisterEvent("UNIT_MANA")
	watch:RegisterEvent("UNIT_MAXMANA")
	watch:RegisterEvent("UNIT_RAGE")
	watch:RegisterEvent("UNIT_ENERGY")
	watch:RegisterEvent("UNIT_DISPLAYPOWER")
	watch:RegisterEvent("CHAT_MSG_ADDON")
	SUIC.UpdateHealthText()
end)
