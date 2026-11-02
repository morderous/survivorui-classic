-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: cooldown numbers on the action buttons, from the
-- longest down to 0.1: minutes from a minute up, whole seconds from ten, and
-- tenths under ten ("8.5", "0.3"), in yellow, the end in red (its last two
-- seconds, a short one's last second). A button
-- cooling down is darkened under its count. Every cooldown counts, the
-- shortest too. Off in the options' Action bar tab. OmniCC does the same job;
-- with it installed, this stands aside.

local counters = {}

local function TimeText(seconds)
	if seconds >= 60 then
		return math.floor(seconds / 60 + 0.5).."m"
	elseif seconds >= 10 then
		return tostring(math.floor(seconds))
	end
	return string.format("%.1f", math.max(0.1, seconds))
end

local function CounterUpdate()
	local left = this.start + this.duration - GetTime()
	if left <= 0 then
		this:Hide()
		return
	end
	this.text:SetText(TimeText(left))
	local soon = left <= (this.duration > 3 and 2 or 1)
	if soon ~= this.soon then
		this.soon = soon
		if soon then
			this.text:SetTextColor(1, 0.2, 0.15)
		else
			this.text:SetTextColor(1, 0.86, 0.1)
		end
	end
end

local function Counter(parent, cooldown)
	local counter = parent.suicCounter
	if counter then
		return counter
	end
	counter = CreateFrame("Frame", nil, parent)
	counter:SetAllPoints(parent)
	counter:SetFrameLevel(cooldown:GetFrameLevel() + 3)
	counter.dim = counter:CreateTexture(nil, "BACKGROUND")
	counter.dim:SetTexture(SUIC.FLAT)
	counter.dim:SetVertexColor(0, 0, 0, 0.6)
	counter.dim:SetAllPoints(counter)
	counter.text = counter:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	local font = counter.text:GetFont()
	counter.text:SetFont(font or STANDARD_TEXT_FONT, 18, "OUTLINE")
	counter.text:SetPoint("CENTER", counter, "CENTER", 0, 0)
	counter.text:SetTextColor(1, 0.86, 0.1)
	counter:SetScript("OnUpdate", CounterUpdate)
	counter:Hide()
	parent.suicCounter = counter
	table.insert(counters, counter)
	return counter
end

-- The option, at once: a count under way comes back where it stands.
function SUIC.RefreshCooldowns()
	local on = SUIC.DB().cooldownText
	for index = 1, table.getn(counters) do
		local counter = counters[index]
		if on and counter.start and counter.start + counter.duration > GetTime() then
			counter:Show()
		else
			counter:Hide()
		end
	end
end

SUIC.OnStart(function()
	if not CooldownFrame_SetTimer or OmniCC_OnUpdate then
		return
	end
	local stock = CooldownFrame_SetTimer
	CooldownFrame_SetTimer = function(cooldown, start, duration, enable)
		stock(cooldown, start, duration, enable)
		local parent = cooldown and cooldown:GetParent()
		if not parent then
			return
		end
		local counter = Counter(parent, cooldown)
		if start and start > 0 and duration and duration > 0 and enable and enable > 0 then
			counter.start, counter.duration = start, duration
			if SUIC.DB().cooldownText then
				counter:Show()
			end
		else
			counter.start = nil
			counter:Hide()
		end
	end
end)
