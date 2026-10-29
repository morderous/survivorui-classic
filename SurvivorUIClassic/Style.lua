-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the one look every piece shares, all of it the game's
-- own art named by its path (none of it ships with the addon).
--
-- Every piece is a panel of the same make: a dark ground in the border
-- chosen in the options (grey and gold, after a Mythic+ timer's frame; gold;
-- or the tooltip's), its title in gold at the top left over a gold rule, a
-- note at the top right, and its rows under the rule. Bars are flat, on a
-- dark ground; the run tracker's and the boss bars wear the tooltip's
-- border, thin.

SUIC.WIDTH = 230               -- every panel of the right column
SUIC.TITLE = 22                -- the title and its rule; the rows start under
SUIC.PAD = 8                   -- the rows' inset from the panel's sides
SUIC.BAR = "Interface\\ChatFrame\\ChatFrameBackground"
-- The unit frames' own bar, its light rippling across: the run tracker's bar
-- and the boss bars.
SUIC.STOCK_BAR = "Interface\\TargetingFrame\\UI-StatusBar"
SUIC.CHECK = "Interface\\Buttons\\UI-CheckBox-Check"
SUIC.RADIO = "Interface\\Buttons\\UI-RadioButton"
SUIC.SKULL = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"

local EDGES = {
	grey = "Interface\\Glues\\Common\\TextPanel-Border",
	gold = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
	tooltip = "Interface\\Tooltips\\UI-Tooltip-Border",
}
SUIC.BORDER_NAMES = { grey = "Grey and gold", gold = "Gold", tooltip = "Tooltip" }
SUIC.BORDER_ORDER = { "grey", "gold", "tooltip" }

local panels = {}

local function Backdrop()
	return {
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = EDGES[SUIC.DB().border] or EDGES.grey,
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	}
end

local function Paint(frame)
	frame:SetBackdrop(Backdrop())
	frame:SetBackdropColor(0, 0, 0, 0.75)
	if SUIC.DB().border == "tooltip" then
		frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
	else
		frame:SetBackdropBorderColor(1, 1, 1, 1)
	end
end

function SUIC.RepaintPanels()
	for index = 1, table.getn(panels) do
		Paint(panels[index])
	end
end

-- A font string in the game's font, at a size of its own if given.
function SUIC.Text(parent, template, size, layer)
	local text = parent:CreateFontString(nil, layer or "OVERLAY", template or "GameFontHighlightSmall")
	if size then
		local font, _, flags = text:GetFont()
		text:SetFont(font or STANDARD_TEXT_FONT, size, flags)
	end
	return text
end

-- How many lines a text takes at a width (a wrapped font string's height is
-- not known before it is drawn).
function SUIC.Lines(text, width)
	return math.max(1, math.ceil((text:GetStringWidth() or 0) / width + 0.15))
end

-- A gold line fading out at both ends.
function SUIC.Rule(parent)
	local rule = parent:CreateTexture(nil, "ARTWORK")
	rule:SetTexture(SUIC.FLAT)
	rule:SetHeight(1)
	if rule.SetGradientAlpha then
		rule:SetGradientAlpha("HORIZONTAL", 1, 0.82, 0, 0.8, 1, 0.82, 0, 0.15)
	else
		rule:SetVertexColor(1, 0.82, 0, 0.5)
	end
	return rule
end

-- A piece's panel: name its global name, title its gold title. panel.title,
-- panel.note (the top right) and panel.rule come with it.
function SUIC.Window(name, title, width)
	local panel = CreateFrame("Frame", name, UIParent)
	panel:SetWidth(width or SUIC.WIDTH)
	panel:SetHeight(SUIC.TITLE + 20)
	table.insert(panels, panel)
	Paint(panel)
	panel.title = SUIC.Text(panel, "GameFontNormal")
	panel.title:SetPoint("TOPLEFT", panel, "TOPLEFT", SUIC.PAD, -7)
	panel.title:SetText(title or "")
	panel.note = SUIC.Text(panel, "GameFontHighlightSmall")
	panel.note:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -SUIC.PAD, -8)
	panel.rule = SUIC.Rule(panel)
	panel.rule:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -SUIC.TITLE)
	panel.rule:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -6, -SUIC.TITLE)
	panel:Hide()
	return panel
end

-- The tooltip's border, thin: the run tracker's bars and the boss bars.
local THIN = {
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 8, edgeSize = 8,
	insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

-- A row's bar: flat, on a dark ground, a text at its left, one in its middle
-- and one at its right; framed, in the tooltip's thin border, the texts over
-- the frame. Its fill is set with bar:SetStatusBarColor.
function SUIC.RowBar(parent, width, height, framed, texture)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetWidth(width)
	bar:SetHeight(height)
	bar:SetStatusBarTexture(texture or SUIC.BAR)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	local ground = bar:CreateTexture(nil, "BACKGROUND")
	ground:SetTexture(SUIC.FLAT)
	ground:SetVertexColor(0, 0, 0, 0.55)
	ground:SetAllPoints(bar)
	local holder = bar
	if framed then
		local edge = CreateFrame("Frame", nil, bar)
		edge:SetPoint("TOPLEFT", bar, "TOPLEFT", -3, 3)
		edge:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 3, -3)
		edge:SetBackdrop(THIN)
		edge:SetBackdropBorderColor(0.65, 0.65, 0.65, 1)
		edge:SetFrameLevel(bar:GetFrameLevel() + 1)
		holder = CreateFrame("Frame", nil, bar)
		holder:SetAllPoints(bar)
		holder:SetFrameLevel(bar:GetFrameLevel() + 2)
	end
	bar.over = holder
	bar.left = SUIC.Text(holder, "GameFontHighlightSmall")
	bar.left:SetPoint("LEFT", bar, "LEFT", 3, 0)
	bar.left:SetJustifyH("LEFT")
	bar.left:SetHeight(height + 4)
	bar.middle = SUIC.Text(holder, "GameFontHighlightSmall")
	bar.middle:SetPoint("CENTER", bar, "CENTER", 0, 0)
	bar.right = SUIC.Text(holder, "GameFontHighlightSmall")
	bar.right:SetPoint("RIGHT", bar, "RIGHT", -3, 0)
	return bar
end

-- A checklist's mark: the check (done), a dot (next, or up now in orange), an
-- empty ring (to come).
function SUIC.Mark(parent)
	local mark = parent:CreateTexture(nil, "OVERLAY")
	mark:SetWidth(11)
	mark:SetHeight(11)
	return mark
end

function SUIC.SetMark(mark, kind)
	if kind == "done" then
		mark:SetTexture(SUIC.CHECK)
		mark:SetTexCoord(0, 1, 0, 1)
		mark:SetVertexColor(0.3, 1, 0.3)
	elseif kind == "ring" then
		mark:SetTexture(SUIC.RADIO)
		mark:SetTexCoord(0, 0.25, 0, 1)
		mark:SetVertexColor(0.8, 0.8, 0.8)
	else
		mark:SetTexture(SUIC.RADIO)
		mark:SetTexCoord(0.25, 0.5, 0, 1)
		if kind == "up" then
			mark:SetVertexColor(1, 0.5, 0.15)
		else
			mark:SetVertexColor(1, 1, 1)
		end
	end
end

------------------------------------------------------------------------------
-- The right column: under the minimap, the run tracker, the build list, the
-- jewelry and the damage meter, each under the one before that is on. A
-- piece moved stands on its own; the rest of the column follows the one
-- above it.

local COLUMN = {
	{ key = "tracker", frame = "SUICTracker", on = "tracker" },
	{ key = "build", frame = "SUICBuildList", on = "buildList" },
	{ key = "jewelry", frame = "SUICJewelry", on = "jewelry" },
	{ key = "meter", frame = "SUICMeter", on = "meter" },
}

function SUIC.ColumnHome(key)
	return function(f)
		local above
		for index = 1, table.getn(COLUMN) do
			local spot = COLUMN[index]
			if spot.key == key then
				break
			end
			if SUIC.DB()[spot.on] and getglobal(spot.frame) then
				above = getglobal(spot.frame)
			end
		end
		if above then
			f:SetPoint("TOPRIGHT", above, "BOTTOMRIGHT", 0, -3)
		elseif MinimapCluster then
			f:SetPoint("TOPRIGHT", MinimapCluster, "BOTTOMRIGHT", -6, 16)
		else
			f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -8, -180)
		end
	end
end

-- The column seated again: a piece turned on or off moves the ones under it.
function SUIC.SeatColumn()
	for index = 1, table.getn(COLUMN) do
		local spot = COLUMN[index]
		local frame = getglobal(spot.frame)
		if frame and not SUIC.DB().pos[spot.key] then
			frame:ClearAllPoints()
			SUIC.ColumnHome(spot.key)(frame)
		end
	end
end

-- The saved border is known once the settings load.
SUIC.OnStart(function()
	SUIC.RepaintPanels()
end)
