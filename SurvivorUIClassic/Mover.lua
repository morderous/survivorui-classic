-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: Move frames, and each piece's size. Every piece of the
-- screen, the game's (the minimap, the player and target frames, the party,
-- the action bar with its experience bar, the buffs, the chat) and the
-- addon's own, gets a green box with its name; drag a box to move its piece,
-- right-click it to put the piece back where it first stood. Opened from the
-- minimap button (right-click), the options or /suic move; Done or Escape
-- closes it. Sizes are set in the options, a piece staying where it stands.
--
-- While boxes are up a grid shows, a line every 32 from the screen's middle,
-- the middle lines in gold. A box let go snaps: its edges or its middle, when
-- within 8 of a grid line, the screen's edges or middle, or another box's
-- edges or middle, line up with the nearest.
--
-- A box moves, not its piece: it moves the same whether its piece shows or
-- not (the target frame with no target), and the piece is set where it was
-- let go. A place is kept from the point of the screen nearest the piece (a
-- corner, an edge's middle, or the middle), in the piece's own scale, so the
-- layout keeps its shape at any interface size: a piece in the middle stays
-- in the middle.

local GRID = 32
local SNAP = 8

local pieces = {}
local byKey = {}
local moving = false

local function Places()
	return SUIC.DB().pos
end

local function Sizes()
	return SUIC.DB().scale
end

-- The size a piece starts at, for everyone: the action bar a little smaller.
local FIRST_SIZES = { bar = 0.85 }

local function SizeOf(key)
	return Sizes()[key] or FIRST_SIZES[key] or 1
end

local function Ratio(frame)
	return frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
end

-- A place from a rectangle in the screen's units: the screen's point nearest
-- it and the piece's own point there, the offset in the piece's scale. A
-- piece held by an edge (edge "LEFT" or "RIGHT": a row of icons growing from
-- it inward) keeps that edge's point whatever the screen's.
local function PlaceOf(left, right, top, bottom, ratio, edge)
	local width, height = GetScreenWidth(), GetScreenHeight()
	local cx, cy = (left + right) / 2, (top + bottom) / 2
	local h, v = "", ""
	if cx < width / 3 then
		h = "LEFT"
	elseif cx > width * 2 / 3 then
		h = "RIGHT"
	end
	if cy > height * 2 / 3 then
		v = "TOP"
	elseif cy < height / 3 then
		v = "BOTTOM"
	end
	local own = edge or h
	local fx = (own == "LEFT" and left) or (own == "RIGHT" and right) or cx
	local fy = (v == "TOP" and top) or (v == "BOTTOM" and bottom) or cy
	local px = (h == "LEFT" and 0) or (h == "RIGHT" and width) or width / 2
	local py = (v == "TOP" and height) or (v == "BOTTOM" and 0) or height / 2
	local point, ownPoint = v..h, v..own
	if point == "" then
		point = "CENTER"
	end
	if ownPoint == "" then
		ownPoint = "CENTER"
	end
	return { point = point, own = ownPoint ~= point and ownPoint or nil,
		x = math.floor((fx - px) / ratio + 0.5), y = math.floor((fy - py) / ratio + 0.5) }
end

-- A piece's place as it stands now.
local function PlaceNow(frame, edge)
	local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
	if not (left and right and top and bottom) then
		return nil
	end
	local ratio = Ratio(frame)
	return PlaceOf(left * ratio, right * ratio, top * ratio, bottom * ratio, ratio, edge)
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
	if place.point then
		piece.frame:SetPoint(place.own or place.point, UIParent, place.point, place.x, place.y)
	else
		-- Kept by an older version: its top left corner from the screen's bottom left.
		piece.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", place.x, place.y)
	end
end

-- Its size: the one it came with times the one chosen (or its first). One
-- never sized keeps whatever the game gives it.
local function ApplySize(piece)
	local size = SizeOf(piece.key)
	if size == 1 and not piece.sized then
		return
	end
	piece.sized = true
	for index = 1, table.getn(piece.frames) do
		local frame = piece.frames[index]
		frame:SetScale((frame.suicFirstScale or 1) * size)
	end
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

-- The places an older version kept, from the screen's bottom left, kept again
-- from their nearest point; one about the middle across, in the middle.
local function Convert()
	for index = 1, table.getn(pieces) do
		local piece = pieces[index]
		local place = Places()[piece.key]
		if place and not place.point then
			local now = PlaceNow(piece.frame, piece.edge)
			if now then
				if (now.point == "TOP" or now.point == "BOTTOM" or now.point == "CENTER") and math.abs(now.x) <= GRID then
					now.x = 0
				end
				Places()[piece.key] = now
			end
		end
	end
end

------------------------------------------------------------------------------
-- The grid.

local grid = CreateFrame("Frame", "SUICGrid", UIParent)
grid:SetAllPoints(UIParent)
grid:SetFrameStrata("BACKGROUND")
grid:Hide()
grid.lines = {}

local function GridLine(index, vertical, offset, bright)
	local line = grid.lines[index]
	if not line then
		line = grid:CreateTexture(nil, "ARTWORK")
		line:SetTexture(SUIC.FLAT)
		grid.lines[index] = line
	end
	if bright then
		line:SetVertexColor(1, 0.82, 0, 0.5)
	else
		line:SetVertexColor(1, 1, 1, 0.07)
	end
	line:ClearAllPoints()
	if vertical then
		line:SetWidth(1)
		line:SetHeight(0)
		line:SetPoint("TOP", grid, "TOP", offset, 0)
		line:SetPoint("BOTTOM", grid, "BOTTOM", offset, 0)
	else
		line:SetHeight(1)
		line:SetWidth(0)
		line:SetPoint("LEFT", grid, "LEFT", 0, offset)
		line:SetPoint("RIGHT", grid, "RIGHT", 0, offset)
	end
	line:Show()
end

-- Lines from the middle out, so the middle lines fall on the screen's middle;
-- laid again at another interface size.
local function BuildGrid()
	local halfWidth, halfHeight = GetScreenWidth() / 2, GetScreenHeight() / 2
	local count = 0
	for x = 0, halfWidth, GRID do
		count = count + 1
		GridLine(count, true, x, x == 0)
		if x > 0 then
			count = count + 1
			GridLine(count, true, -x, false)
		end
	end
	for y = 0, halfHeight, GRID do
		count = count + 1
		GridLine(count, false, y, y == 0)
		if y > 0 then
			count = count + 1
			GridLine(count, false, -y, false)
		end
	end
	for index = count + 1, table.getn(grid.lines) do
		grid.lines[index]:Hide()
	end
end

-- The nearest of the targets to one of a box's lines, along one axis: the
-- shift that lines them up, or nil when none is within SNAP.
local function Nearest(mine, targets)
	local best
	for _, a in pairs(mine) do
		for _, b in pairs(targets) do
			local shift = b - a
			if math.abs(shift) <= SNAP and (not best or math.abs(shift) < math.abs(best)) then
				best = shift
			end
		end
	end
	return best
end

-- Every line a box may snap to: the grid's, the screen's edges and middle,
-- the other boxes' edges and middles.
local function Targets(own)
	local width, height = GetScreenWidth(), GetScreenHeight()
	local xs, ys = { 0, width }, { 0, height }
	for x = 0, width / 2, GRID do
		table.insert(xs, width / 2 + x)
		table.insert(xs, width / 2 - x)
	end
	for y = 0, height / 2, GRID do
		table.insert(ys, height / 2 + y)
		table.insert(ys, height / 2 - y)
	end
	for index = 1, table.getn(pieces) do
		local box = pieces[index].box
		if box ~= own and box:IsShown() and box:GetLeft() then
			local l, r, t, b = box:GetLeft(), box:GetRight(), box:GetTop(), box:GetBottom()
			table.insert(xs, l)
			table.insert(xs, r)
			table.insert(xs, (l + r) / 2)
			table.insert(ys, t)
			table.insert(ys, b)
			table.insert(ys, (t + b) / 2)
		end
	end
	return xs, ys
end

------------------------------------------------------------------------------
-- The boxes.

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
	local left, top = this:GetLeft(), this:GetTop()
	if left and top then
		local width, height = this:GetWidth(), this:GetHeight()
		local xs, ys = Targets(this)
		left = left + (Nearest({ left, left + width, left + width / 2 }, xs) or 0)
		top = top + (Nearest({ top, top - height, top - height / 2 }, ys) or 0)
		KeepFirst(piece)
		Places()[piece.key] = PlaceOf(left, left + width, top, top - height, Ratio(piece.frame), piece.edge)
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

-- frame: the piece; home(frame), for the addon's own pieces, its first place;
-- also: frames sized along with it (the other party frames); edge, "LEFT" or
-- "RIGHT", for a row held by that edge.
function SUIC.AddPiece(key, label, frame, home, also, edge)
	if not frame then
		return
	end
	local piece = { key = key, label = label, frame = frame, home = home, frames = { frame }, edge = edge }
	for index = 1, table.getn(also or {}) do
		table.insert(piece.frames, also[index])
	end
	for index = 1, table.getn(piece.frames) do
		local each = piece.frames[index]
		each.suicFirstScale = each.suicFirstScale or each:GetScale()
	end
	frame:SetMovable(true)
	table.insert(pieces, piece)
	byKey[key] = piece
	MakeBox(piece)
	if SUIC.active then
		ApplySize(piece)
		Apply(piece)
	end
	if moving then
		Seat(piece.box)
		piece.box:Show()
	end
end

------------------------------------------------------------------------------
-- Sizes, from the options: a piece grows or shrinks from where it stands, its
-- top left corner kept.

function SUIC.PieceSize(key)
	return SizeOf(key)
end

function SUIC.SetPieceSize(key, size)
	local piece = byKey[key]
	if not piece then
		return
	end
	local frame = piece.frame
	local left, top = frame:GetLeft(), frame:GetTop()
	local before = Ratio(frame)
	size = math.floor(size * 100 + 0.5) / 100
	if size == (FIRST_SIZES[key] or 1) then
		Sizes()[key] = nil
	else
		Sizes()[key] = size
	end
	piece.sized = true
	ApplySize(piece)
	if left and top then
		local after = Ratio(frame)
		local l, t = left * before, top * before
		KeepFirst(piece)
		Places()[key] = PlaceOf(l, l + frame:GetWidth() * after, t, t - frame:GetHeight() * after, after, piece.edge)
		Apply(piece)
	end
	if moving then
		Seat(piece.box)
	end
end

-- Back in its first place and at its first size.
function SUIC.ResetPiece(key)
	local piece = byKey[key]
	if not piece then
		return
	end
	Sizes()[key] = nil
	ApplySize(piece)
	PutBack(piece)
	if moving then
		Seat(piece.box)
	end
end

-- The whole interface's size (the options' General tab): every place is kept
-- from its nearest point, so the layout keeps its shape. Set once the slider
-- has rested a moment: the options window grows with it, under the mouse.
local pending, pendingAt
local function Resize()
	local size = pending
	pending = nil
	SUIC.DB().uiSize = size
	Convert()
	UIParent:SetScale(size)
	SUIC.ApplyPositions()
	if moving then
		BuildGrid()
		for index = 1, table.getn(pieces) do
			Seat(pieces[index].box)
		end
	end
end

local resizer = CreateFrame("Frame")
resizer:SetScript("OnUpdate", function()
	if pending and GetTime() - pendingAt >= 0.4 then
		Resize()
	end
end)

function SUIC.SetUISize(size)
	pending = math.floor(size * 100 + 0.5) / 100
	pendingAt = GetTime()
end

------------------------------------------------------------------------------
-- The bar over the screen while boxes are up.

local bar = CreateFrame("Frame", "SUICMoveBar", UIParent)
bar:SetFrameStrata("DIALOG")
bar:SetWidth(380)
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
barText:SetText("Drag a green box: it snaps to the grid and the others. Right-click puts it back.")

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
		BuildGrid()
		grid:Show()
		bar:Show()
	else
		grid:Hide()
		bar:Hide()
	end
	if SUIC.OnMoveMode then
		SUIC.OnMoveMode(moving)
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

-- Every place and every size back to the first.
function SUIC.ResetEverything()
	for index = 1, table.getn(pieces) do
		SUIC.ResetPiece(pieces[index].key)
	end
	SUIC.Print("every frame is back in its first place, at its first size.")
end

------------------------------------------------------------------------------
-- The game's own pieces. The stock interface seats some of them again as the
-- world loads and as panels open (UIParent_ManageFramePositions): each moved
-- one is put back after it, and once more a moment after the world loads.

SUIC.AddPiece("minimap", "Minimap", MinimapCluster)
SUIC.AddPiece("player", "Player", PlayerFrame)
SUIC.AddPiece("target", "Target", TargetFrame)
SUIC.AddPiece("party", "Party", PartyMemberFrame1, nil, { PartyMemberFrame2, PartyMemberFrame3, PartyMemberFrame4 })
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

-- The sizes, the places (an older version's kept again from their nearest
-- point), then the whole interface's size.
SUIC.OnStart(function()
	for index = 1, table.getn(pieces) do
		ApplySize(pieces[index])
	end
	SUIC.ApplyPositions()
	Convert()
	UIParent:SetScale(SUIC.DB().uiSize or 0.8)
	SUIC.ApplyPositions()
	again = GetTime() + 1
end)
