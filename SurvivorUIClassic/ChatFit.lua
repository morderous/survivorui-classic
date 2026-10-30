-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the chat kept clear of the talent cooldowns. On a
-- screen narrower than 4:3 (5:4, 1280x1024) the chat's long lines reach under
-- the talents' row at the action bar's left end: there the chat is made
-- narrower, to end before the bar's art, and gets its own width back on a
-- wider screen and as the world is left: the game saves the chat's size as
-- it closes, the size it last measured, so the chat is measured again right
-- away. Its own width is kept in the settings too, for a close that gives no
-- time (back as the game opens, with this addon or with Survivor UI chosen).
-- A chat moved in Move frames, or the talents' row moved, is left as it is.
--
-- Its place and size are the game's to keep, one for both addons, so Survivor
-- UI's would stay on here after a change of interface: this addon notes its
-- own each second and puts them back as it starts. Noted none yet, and the
-- chat where Survivor UI keeps it, it goes back to the game's first place.

local MARGIN = 8
local ROWS = 46        -- the talents' row over the bar: 6 off it, 40 tall
local NARROWEST = 200
local STOCK = { left = 32, bottom = 95, width = 430, height = 120 }   -- the game's first chat
local NEAR = 2

-- A frame's scale on the screen; a texture's, its frame's.
local function ScaleOf(object)
	if not object.GetEffectiveScale then
		object = object:GetParent()
	end
	return object:GetEffectiveScale()
end

-- A length in a frame's own scale, in UIParent's units, and back.
local function Units(frame, value)
	return value * ScaleOf(frame) / UIParent:GetEffectiveScale()
end

local function Own(frame, value)
	return value * UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
end

-- Where the action bar's art begins at the left: its gryphon, else the bar.
local function ArtLeft()
	local left = Units(MainMenuBar, MainMenuBar:GetLeft())
	local cap = MainMenuBarLeftEndCap
	if cap and cap:IsVisible() and cap:GetLeft() then
		left = math.min(left, Units(cap, cap:GetLeft()))
	end
	return left
end

-- The chat where Survivor UI keeps it (its Mover.lua's first place, or the one
-- it was moved to), by its left and width: under a UI scale the game gives it
-- back higher than Survivor UI had it.
local function AtTheOthers(chat)
	local other = SurvivorUIDB
	if not other or not chat:GetLeft() then
		return false
	end
	return math.abs(chat:GetLeft() - (other.chatLeft or 8)) < NEAR
		and (not other.chatWidth or math.abs(chat:GetWidth() - other.chatWidth) < NEAR)
end

-- This addon's place and size for the chat, back on it.
local function Home()
	local db, chat = SUIC.DB(), ChatFrame1
	if not chat then
		return
	end
	local home = db.chatHome
	if not home then
		if not AtTheOthers(chat) then
			return
		end
		home = STOCK
	end
	if not db.pos.chat then
		chat:ClearAllPoints()
		chat:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", home.left, home.bottom)
	end
	chat:SetWidth(home.width)
	chat:SetHeight(home.height)
end

-- Noted as it stands: its own width, not the one fitted here.
local function Note(chat, width)
	local db = SUIC.DB()
	db.chatHome = db.chatHome or {}
	local home = db.chatHome
	home.left = math.floor(chat:GetLeft() + 0.5)
	home.bottom = math.floor(chat:GetBottom() + 0.5)
	home.width = math.floor(width + 0.5)
	home.height = math.floor(chat:GetHeight() + 0.5)
end

local function Fit()
	local db, chat = SUIC.DB(), ChatFrame1
	if not (chat and chat:GetLeft() and MainMenuBar:GetLeft()) then
		return
	end
	local width = chat:GetWidth()
	if db.chatSet and math.abs(width - db.chatSet) > 0.5 then
		-- Sized again since, by hand: that is its own width now.
		db.chatOwn, db.chatSet = nil, nil
	end
	local own = db.chatOwn or width
	local want = own
	if db.talentTimers and not db.pos.chat and not db.pos.talentTimers then
		local left = Units(chat, chat:GetLeft())
		local rowLeft = Units(MainMenuBar, MainMenuBar:GetLeft()) + 4
		local rowsTop = Units(MainMenuBar, MainMenuBar:GetTop()) + ROWS
		if left + Units(chat, own) > rowLeft - MARGIN and Units(chat, chat:GetBottom()) < rowsTop then
			want = math.min(own, math.max(NARROWEST, Own(chat, ArtLeft() - MARGIN - left)))
		end
	end
	if math.abs(want - width) > 0.5 then
		chat:SetWidth(want)
	end
	if math.abs(want - own) > 0.5 then
		db.chatOwn, db.chatSet = own, want
	else
		db.chatOwn, db.chatSet = nil, nil
	end
	Note(chat, own)
end

local function GiveBack()
	local db = SUIC.DB()
	if db.chatOwn and ChatFrame1 then
		ChatFrame1:SetWidth(db.chatOwn)
		-- Measured now: the game saves the size it last measured.
		ChatFrame1:GetRight()
		db.chatOwn, db.chatSet = nil, nil
	end
end

-- Looked at again every second: the interface's size, a piece moved, the
-- window sized.
local fit = CreateFrame("Frame")
local elapsed = 0
fit:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed >= 1 then
		elapsed = 0
		Fit()
	end
end)
fit:Hide()
fit:RegisterEvent("PLAYER_ENTERING_WORLD")
fit:RegisterEvent("PLAYER_LEAVING_WORLD")
fit:RegisterEvent("PLAYER_LOGOUT")
fit:SetScript("OnEvent", function()
	-- As the world comes, only with this addon standing aside: running, it
	-- fits the chat within the second.
	if event ~= "PLAYER_ENTERING_WORLD" or not SUIC.active then
		GiveBack()
	end
end)

SUIC.OnStart(function()
	Home()
	fit:Show()
end)
