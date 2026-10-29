-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: Move frames. Every piece of the screen, the game's
-- (the minimap, the player and target frames, the party, the action bar with
-- its experience bar, the buffs, the chat) and the addon's own, gets a green
-- box with its name; drag a box to move its piece, right-click it to put the
-- piece back where it first stood. Opened from the minimap button's menu, or
-- /suic move; Done or Escape closes it.
--
-- A piece's box moves, not the piece: a box moves the same whether its piece
-- shows or not (the target frame with no target, the party alone), and the
-- piece is set where the box was let go. Places are kept as the top left
-- corner's, in the piece's own scale, from the screen's bottom left.

local pieces = {}
local moving = false

local function Places()
	return SUIC.DB().pos
end

-- The piece's first anchors, kept before it is ever moved: Reset puts them back.
local function KeepFirst(piece)
	local frame = piece.frame
	if piece.first or not frame.GetNumPoints then
		return
	end
	piece.first = {}
	for index = 1, frame:GetNumPoints() do
		local point, relative, relativePoint, x, y = frame:GetPoint(index)
		table.insert(piece.first, { point, relative, relativePoint, x, y })
	end
end

local function Apply(piece)
	local place = Places()[piece.key]
	if not place then
		return
	end
	KeepFirst(piece)
	piece.frame:ClearAllPoints()
	piece.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", place.x, place.y)
end

local function PutBack(piece)
	Places()[piece.key] = nil
	local frame = piece.frame
	if piece.home then
		frame:ClearAllPoints()
		piece.home(frame)
	elseif piece.first and table.getn(piece.first) > 0 then
		frame:ClearAllPoints()
		for index = 1, table.getn(piece.first) do
			local p = piece.first[index]
			frame:SetPoint(p[1], p[2] or UIParent, p[3], p[4], p[5])
		end
	end
	if UIParent_ManageFramePositions then
		UIParent_ManageFramePositions()
	end
end

function SUIC.ApplyPositions()
	for index = 1, table.getn(pieces) do
		Apply(pieces[index])
	end
end

------------------------------------------------------------------------------
-- The boxes.

local function Ratio(frame)
	return frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

local function Seat(box)
	box:ClearAllPoints()
	box:SetAllPoints(box.piece.frame)
end

local function DragStart()
	local frame = this.piece.frame
	local left, top = frame:GetLeft(), frame:GetTop()
	if not (left and top) then
		return
	end
	local ratio = Ratio(frame)
	this:ClearAllPoints()
	this:SetWidth(frame:GetWidth() * ratio)
	this:SetHeight(frame:GetHeight() * ratio)
	this:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * ratio, top * ratio)
	this.dragging = true
	this:StartMoving()
end

local function DragStop()
	if not this.dragging then
		return
	end
	this.dragging = nil
	this:StopMovingOrSizing()
	local piece = this.piece
	local ratio = Ratio(piece.frame)
	local left, top = this:GetLeft(), this:GetTop()
	if left and top then
		Places()[piece.key] = { x = math.floor(left / ratio + 0.5), y = math.floor(top / ratio + 0.5) }
		Apply(piece)
	end
	Seat(this)
end

local function BoxClick()
	if arg1 == "RightButton" then
		PutBack(this.piece)
		Seat(this)
	end
end

local function MakeBox(piece)
	local box = CreateFrame("Button", nil, UIParent)
	box:SetFrameStrata("DIALOG")
	box:SetMovable(true)
	box:SetClampedToScreen(true)
	box:EnableMouse(true)
	box:RegisterForDrag("LeftButton")
	box:RegisterForClicks("RightButtonUp")
	box:SetBackdrop(SUIC.BACKDROP)
	box:SetBackdropColor(0.1, 0.7, 0.1, 0.35)
	box:SetBackdropBorderColor(0.3, 1, 0.3, 1)
	local label = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	label:SetPoint("CENTER", box, "CENTER", 0, 0)
	label:SetText(piece.label)
	box.piece = piece
	box:SetScript("OnDragStart", DragStart)
	box:SetScript("OnDragStop", DragStop)
	box:SetScript("OnClick", BoxClick)
	box:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_TOP")
		GameTooltip:SetText(this.piece.label)
		GameTooltip:AddLine("Drag to move. Right-click to put it back.", 1, 1, 1)
		GameTooltip:Show()
	end)
	box:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	box:Hide()
	piece.box = box
end

-- frame: the piece; home(frame), for the addon's own pieces, its first place.
function SUIC.AddPiece(key, label, frame, home)
	if not frame then
		return
	end
	local piece = { key = key, label = label, frame = frame, home = home }
	frame:SetMovable(true)
	table.insert(pieces, piece)
	MakeBox(piece)
	if SUIC.active then
		Apply(piece)
	end
	if moving then
		Seat(piece.box)
		piece.box:Show()
	end
end

------------------------------------------------------------------------------
-- The bar over the screen while boxes are up.

local bar = CreateFrame("Frame", "SUICMoveBar", UIParent)
bar:SetFrameStrata("DIALOG")
bar:SetWidth(360)
bar:SetHeight(64)
bar:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
bar:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32,
	insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
bar:EnableMouse(true)
bar:Hide()
local barText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
barText:SetPoint("TOP", bar, "TOP", 0, -16)
barText:SetText("Drag a green box to move it. Right-click puts it back.")

local resetAll = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
resetAll:SetWidth(110)
resetAll:SetHeight(22)
resetAll:SetPoint("BOTTOM", bar, "BOTTOM", -60, 12)
resetAll:SetText("Reset all")
resetAll:SetScript("OnClick", function()
	SUIC.ResetPositions()
end)
local done = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
done:SetWidth(110)
done:SetHeight(22)
done:SetPoint("BOTTOM", bar, "BOTTOM", 60, 12)
done:SetText("Done")
done:SetScript("OnClick", function()
	SUIC.SetMoveMode(false)
end)
-- Escape closes it, as the game's own panels.
table.insert(UISpecialFrames, "SUICMoveBar")
bar:SetScript("OnHide", function()
	if moving then
		SUIC.SetMoveMode(false)
	end
end)

function SUIC.MoveMode()
	return moving
end

function SUIC.SetMoveMode(on)
	if not SUIC.active then
		return
	end
	moving = on and true or false
	for index = 1, table.getn(pieces) do
		local box = pieces[index].box
		if moving then
			Seat(box)
			box:Show()
		else
			box:Hide()
		end
	end
	if moving then
		bar:Show()
	else
		bar:Hide()
	end
end

function SUIC.ResetPositions()
	for index = 1, table.getn(pieces) do
		local piece = pieces[index]
		if Places()[piece.key] then
			PutBack(piece)
		end
		if moving then
			Seat(piece.box)
		end
	end
	SUIC.Print("every frame is back in its first place.")
end

------------------------------------------------------------------------------
-- The game's own pieces. The stock interface seats some of them again as the
-- world loads and as panels open (UIParent_ManageFramePositions): each moved
-- one is put back after it, and once more a moment after the world loads.

SUIC.AddPiece("minimap", "Minimap", MinimapCluster)
SUIC.AddPiece("player", "Player", PlayerFrame)
SUIC.AddPiece("target", "Target", TargetFrame)
SUIC.AddPiece("party", "Party", PartyMemberFrame1)
SUIC.AddPiece("bar", "Action bar", MainMenuBar)
SUIC.AddPiece("buffs", "Buffs", BuffFrame)
SUIC.AddPiece("chat", "Chat", ChatFrame1)

if UIParent_ManageFramePositions then
	local stock = UIParent_ManageFramePositions
	UIParent_ManageFramePositions = function(a1, a2, a3)
		stock(a1, a2, a3)
		if SUIC.active then
			SUIC.ApplyPositions()
		end
	end
end

local again
local seat = CreateFrame("Frame")
seat:RegisterEvent("PLAYER_ENTERING_WORLD")
seat:SetScript("OnEvent", function()
	if SUIC.active then
		SUIC.ApplyPositions()
		again = GetTime() + 1
	end
end)
seat:SetScript("OnUpdate", function()
	if again and GetTime() >= again then
		again = nil
		SUIC.ApplyPositions()
	end
end)

SUIC.OnStart(function()
	SUIC.ApplyPositions()
	again = GetTime() + 1
end)
