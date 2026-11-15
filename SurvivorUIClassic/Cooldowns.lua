-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: cooldown numbers on the action buttons, from the
-- longest down to 0.1: minutes from a minute up, whole seconds from ten, and
-- tenths under ten ("8.5", "0.3"), in yellow, the end in red (its last two
-- seconds, a short one's last second). A button
-- cooling down is darkened under its count. Every cooldown counts, the
-- shortest too. Off in the options' Action bar tab. OmniCC does the same job;
-- with it installed, this stands aside.
--
-- A button in the Build panel (BarPanel.lua) keeps its icon in sight: no dark
-- and no sweep over it, a gold line at its foot running down with the
-- cooldown, and the seconds small in its top left corner, from LONG up only
-- (a spell every second would be a number flickering for ever). The line
-- stays with the numbers off. As its spell goes off (its cooldown starts
-- again), the button's rim flashes gold and fades; a spell going off faster
-- than STEADY keeps a steady, softer rim, no flicker. Off in the options.

local counters = {}
local LONG = 3            -- a panel button's seconds are written from here up
local THREAD = 3          -- the gold line's height
local FLASH = 0.4         -- the rim's fade as a spell goes off
local STEADY = 0.6        -- a cooldown under this: the rim stays lit

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
	if this.bare then
		this.thread:SetWidth(math.max(0.5, this.span * left / this.duration))
		if this.lit then
			local age = GetTime() - this.lit
			if this.steady then
				this.flash:SetAlpha(0.5)
			elseif age < FLASH then
				this.flash:SetAlpha(1 - age / FLASH)
			else
				this.lit = nil
				this.flash:Hide()
			end
		end
	end
	if not this.words then
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

-- A counter's look, the panel's or the game's bar's, and whether its seconds
-- are written; false when there is nothing of it to show.
local function Dress(counter)
	local bare = SUIC.OnPanel and SUIC.OnPanel(counter:GetParent()) and true or false
	if bare ~= counter.bare then
		counter.bare = bare
		local font = counter.text:GetFont()
		counter.text:ClearAllPoints()
		if bare then
			counter.dim:Hide()
			counter.ground:Show()
			counter.thread:Show()
			counter.text:SetFont(font or STANDARD_TEXT_FONT, 11, "OUTLINE")
			counter.text:SetPoint("TOPLEFT", counter, "TOPLEFT", 2, -2)
		else
			counter.dim:Show()
			counter.ground:Hide()
			counter.thread:Hide()
			counter.flash:Hide()
			counter.lit = nil
			counter.text:SetFont(font or STANDARD_TEXT_FONT, 18, "OUTLINE")
			counter.text:SetPoint("CENTER", counter, "CENTER", 0, 0)
		end
	end
	counter.span = counter:GetParent():GetWidth() or 36
	local words = SUIC.DB().cooldownText and (not bare or (counter.duration or 0) >= LONG) and true or false
	if words ~= counter.words then
		counter.words = words
		if not words then
			counter.text:SetText("")
		end
	end
	-- The game's sweep darkens the icon: away on a panel button, back at the
	-- next cooldown off it.
	if bare and counter.cooldown then
		counter.cooldown:Hide()
	end
	return bare or words
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
	counter.ground = counter:CreateTexture(nil, "BACKGROUND")
	counter.ground:SetTexture(SUIC.FLAT)
	counter.ground:SetVertexColor(0, 0, 0, 0.7)
	counter.ground:SetHeight(THREAD)
	counter.ground:SetPoint("BOTTOMLEFT", counter, "BOTTOMLEFT", 0, 0)
	counter.ground:SetPoint("BOTTOMRIGHT", counter, "BOTTOMRIGHT", 0, 0)
	counter.ground:Hide()
	counter.thread = counter:CreateTexture(nil, "ARTWORK")
	counter.thread:SetTexture(SUIC.FLAT)
	counter.thread:SetVertexColor(1, 0.82, 0, 1)
	counter.thread:SetHeight(THREAD)
	counter.thread:SetPoint("BOTTOMLEFT", counter, "BOTTOMLEFT", 0, 0)
	counter.thread:Hide()
	-- The rim's flash: the game's own light of a button pressed, in gold.
	counter.flash = counter:CreateTexture(nil, "OVERLAY")
	counter.flash:SetTexture("Interface\\Buttons\\CheckButtonHilight")
	counter.flash:SetBlendMode("ADD")
	counter.flash:SetVertexColor(1, 0.82, 0.2)
	counter.flash:SetAllPoints(counter)
	counter.flash:Hide()
	counter.cooldown = cooldown
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

-- The options, at once (the numbers', the Build panel's): a count under way
-- comes back where it stands, in the look its button has now.
function SUIC.RefreshCooldowns()
	for index = 1, table.getn(counters) do
		local counter = counters[index]
		local on = Dress(counter)
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
			local again = start ~= counter.start
			counter.start, counter.duration = start, duration
			if Dress(counter) then
				counter:Show()
			else
				counter:Hide()
			end
			-- The spell went off: a new cooldown on a panel button.
			if again and counter.bare and SUIC.DB().barFlash then
				counter.lit, counter.steady = GetTime(), duration < STEADY
				counter.flash:SetAlpha(counter.steady and 0.5 or 1)
				counter.flash:Show()
			elseif not SUIC.DB().barFlash and counter.lit then
				counter.lit = nil
				counter.flash:Hide()
			end
		else
			counter.start = nil
			counter.duration = nil
			counter:Hide()
		end
	end
end)
