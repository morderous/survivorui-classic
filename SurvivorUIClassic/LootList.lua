-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the loot list, a panel as the others at the foot of the
-- right column, under the damage meter. What the run has dropped, the newest
-- on top: its icon once the game knows the piece, its name in its quality's
-- color, x2 when it comes again, the marks a piece already collected gives in
-- gold, "New!" when it is new in the collection, and the run second it came.
-- Hover a piece for its tooltip, once the hero has worn it (the game's loot
-- line has no details). On the title's right, the marks gathered this run:
-- hover them for each boss's, and the class's total as the game last said.
-- In a run, once something has dropped; a new run starts over.
--
-- Survivor UI's loot list (LootLog.lua), the same reading: the chat's lines,
-- read once by Loot.lua, and the bosses that fall (AZS_UNITS) for whose marks.

local W = SUIC.WIDTH
local PAD = SUIC.PAD
local TOP = SUIC.TITLE + 4
local ROW = 15
local ICON = 13
local CLOCK = 30                -- the run second's room at the right
local LINES = 8                 -- the rows at first (the options, Loot)
local KEEP = 30
local HISTORY = 24              -- the marks' tooltip, at most
local EPIC = "ffa335ee"
local BAG = "Interface\\Icons\\INV_Misc_Bag_10"

local panel = SUIC.Window("SUICLootList", "Loot")
panel.note:SetTextColor(1, 0.82, 0)

local function Lines()
	return tonumber(SUIC.DB().lootLines) or LINES
end

-- At its home, the column's foot, as many rows as the screen has room for
-- under it, the newest kept; with room for fewer than three, beside the piece
-- above it. Moved, its own lines.
local function Seat()
	if SUIC.DB().pos.lootlist then
		return
	end
	panel:ClearAllPoints()
	SUIC.ColumnHome("lootlist")(panel)
	local top = panel:GetTop()
	if top and top - 4 - TOP - 6 < 3 * ROW then
		local _, above = panel:GetPoint(1)
		if above and above ~= UIParent and above ~= MinimapCluster then
			panel:ClearAllPoints()
			panel:SetPoint("TOPRIGHT", above, "TOPLEFT", -3, 0)
		end
	end
end

local function Fit()
	local top = panel:GetTop()
	if SUIC.DB().pos.lootlist or not top then
		return Lines()
	end
	return math.max(1, math.min(Lines(), math.floor((top - 4 - TOP - 6) / ROW)))
end

local function RunSeconds()
	return AZS_GetRunTime and AZS_GetRunTime() or nil
end

-- Marks as the game writes them: 20, 22.5.
local function Amount(value)
	local whole = math.floor(value + 0.05)
	if math.abs(value - whole) < 0.05 then
		return tostring(whole)
	end
	return string.format("%.1f", value)
end

local function Number(text)
	return tonumber((string.gsub(text or "", ",", ".")))
end

-- "ffa335ee" into 0.64, 0.21, 0.93; an epic's purple when unknown.
local function Color(hex)
	if not hex or string.len(hex) ~= 8 then
		hex = EPIC
	end
	local function Part(from)
		return (tonumber(string.sub(hex, from, from + 1), 16) or 0) / 255
	end
	return Part(3), Part(5), Part(7)
end

-- The quality by its color, as the game's links have them.
local QUALITIES = {
	ff9d9d9d = "Poor", ffffffff = "Common", ff1eff00 = "Uncommon", ff0070dd = "Rare",
	ffa335ee = "Epic", ffff8000 = "Legendary", ffe6cc80 = "Artifact",
}

------------------------------------------------------------------------------
-- The pieces the hero has worn, by name, with their links and icons: the
-- game's loot line names a drop without its details, so its tooltip and icon
-- come from here once the piece has been worn. Kept for the account, since a
-- piece found on one hero is worn on another; a line with a link adds it too.

local function Known()
	local db = SUIC.DB()
	db.itemLinks = db.itemLinks or {}
	db.itemIcons = db.itemIcons or {}
	return db.itemLinks, db.itemIcons
end

local EVERY_SLOT = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 }
-- The jewelry: neck, rings, trinkets, the only pieces a run changes.
local JEWELRY_SLOTS = { 2, 11, 12, 13, 14 }

local function LearnWorn(slots)
	if not GetInventoryItemLink then
		return
	end
	local links, icons = Known()
	for index = 1, table.getn(slots) do
		local slot = slots[index]
		local link = GetInventoryItemLink("player", slot)
		if link then
			local _, _, item = string.find(link, "|H(item:[%d:%-]+)|h")
			local _, _, name = string.find(link, "%[(.-)%]")
			-- A piece the game has not named yet waits for the next look.
			if item and name and name ~= "" then
				links[name] = item
				local icon = GetInventoryItemTexture and GetInventoryItemTexture("player", slot)
				if icon then
					icons[name] = icon
				end
			end
		end
	end
end

-- A piece's icon by its name and link, when the game knows it: the loot
-- notices' too (Loot.lua).
function SUIC.LootIcon(name, item)
	local links, icons = Known()
	item = item or (name and links[name])
	if item and GetItemInfo then
		local _, _, _, _, _, _, _, _, texture = GetItemInfo(item)
		if type(texture) == "string" and texture ~= "" then
			return texture
		end
	end
	return name and icons[name]
end

------------------------------------------------------------------------------
-- The rows.

local entries = {}              -- newest first: { item, name, color, count, worth, new, at }
local earned = { total = 0 }    -- the run's marks, oldest first: { amount, at, when, paid, boss }
local rows = {}

local function RowEnter()
	local links = Known()
	local link = this.item or (this.itemName and links[this.itemName])
	GameTooltip:SetOwner(this, "ANCHOR_LEFT")
	if link then
		GameTooltip:SetHyperlink(link)
	else
		local r, g, b = Color(this.color)
		GameTooltip:SetText(this.itemName or "?", r, g, b)
		local quality = QUALITIES[string.lower(this.color or "")]
		if quality then
			GameTooltip:AddLine(SUIC.T(quality), r, g, b)
		end
		GameTooltip:AddLine(SUIC.T("Its details show here once you have worn it in a run."), 0.62, 0.62, 0.68, 1)
	end
	GameTooltip:Show()
end

local function Row(index)
	local row = rows[index]
	if row then
		return row
	end
	row = CreateFrame("Button", nil, panel)
	row:SetWidth(W - 2 * PAD)
	row:SetHeight(ROW)
	row:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -TOP - (index - 1) * ROW)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetWidth(ICON)
	row.icon:SetHeight(ICON)
	row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	row.at = SUIC.Text(row, "GameFontDisableSmall")
	row.at:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	row.name = SUIC.Text(row, "GameFontHighlightSmall")
	row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
	row.name:SetJustifyH("LEFT")
	row.name:SetHeight(ROW)
	-- The count, the marks and "New!" after the name, never cut with it.
	row.extra = SUIC.Text(row, "GameFontHighlightSmall")
	row:SetScript("OnEnter", RowEnter)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	rows[index] = row
	return row
end

-- Only the marks answer the mouse on the title's line.
local head = CreateFrame("Frame", nil, panel)
head:SetPoint("RIGHT", panel.note, "RIGHT", 4, 0)
head:SetHeight(16)
head:SetWidth(40)
head:EnableMouse(true)

local function Draw()
	panel.note:SetText(SUIC.TF("{1} marks", Amount(earned.total)))
	head:SetWidth(panel.note:GetStringWidth() + 8)
	local count = math.min(Fit(), table.getn(entries))
	for index = 1, count do
		local entry, row = entries[index], Row(index)
		row.item, row.itemName, row.color = entry.item, entry.name, entry.color
		row.icon:SetTexture(SUIC.LootIcon(entry.name, entry.item) or BAG)
		local extra = ""
		if entry.count and entry.count > 1 then
			extra = " x"..entry.count
		end
		if entry.worth then
			extra = extra.."  |cffffd100+"..Amount(entry.worth).."|r"
		end
		if entry.new then
			extra = extra.."  |cff40ff40"..SUIC.T("New!").."|r"
		end
		row.extra:SetText(extra)
		local room = W - 2 * PAD - ICON - 4 - CLOCK - (extra ~= "" and row.extra:GetStringWidth() or 0)
		row.name:SetWidth(room)
		row.name:SetText(entry.name)
		row.name:SetTextColor(Color(entry.color))
		row.extra:ClearAllPoints()
		row.extra:SetPoint("LEFT", row.name, "LEFT", math.min(row.name:GetStringWidth(), room), 0)
		row.at:SetText(entry.at and SUIC.Clock(entry.at) or "")
		row:Show()
	end
	for index = count + 1, table.getn(rows) do
		rows[index]:Hide()
	end
	panel:SetHeight(TOP + count * ROW + 6)
end

------------------------------------------------------------------------------
-- The run's marks. Two lines bring them, paid apart by the game (read in its
-- 0.138): a boss's, "You earn 20 marks (340 in all).", and a piece already
-- collected, its loot line ending "+0.5 marks". Neither names the boss, so the
-- bosses and guardians alive are watched (AZS_UNITS, as the boss bars), and one
-- gone a moment from a boss's line is that line's. A row a boss, the repeats
-- dropped with it inside; repeats on their own, a row of their own.

local FELL_WINDOW = 3           -- seconds between a boss's fall and its line
local DROP_WINDOW = 5           -- seconds a repeat joins the row before it

-- Each language's line: what the boss gave, and what the hero's class has now.
local EARNED = {
	"You earn ([%d%.,]+) marks %(([%d%.,]+) in all%)", "Zdobywasz znaki: ([%d%.,]+) %(łącznie ([%d%.,]+)%)",
	"Získáváš známky: ([%d%.,]+) %(celkem ([%d%.,]+)%)", "Du erhältst ([%d%.,]+) Marken %(insgesamt ([%d%.,]+)%)",
	"Você ganha ([%d%.,]+) marcas %(([%d%.,]+) no total%)", "Ganas ([%d%.,]+) marcas %(([%d%.,]+) en total%)",
	"Vous gagnez ([%d%.,]+) marques %(([%d%.,]+) au total%)", "Câștigi ([%d%.,]+) însemne %(([%d%.,]+) în total%)",
	"([%d%.,]+) nişan kazandın %(toplam ([%d%.,]+)%)", "Вы получаете знаки: ([%d%.,]+) %(всего ([%d%.,]+)%)",
	"Ви отримуєте знаки: ([%d%.,]+) %(усього ([%d%.,]+)%)", "你获得了([%d%.,]+)枚印记（共([%d%.,]+)枚）",
	"([%d%.,]+)マークを獲得（合計([%d%.,]+)）", "징표 ([%d%.,]+)개를 얻었습니다 %(총 ([%d%.,]+)개%)",
}

-- The marks a boss's line gives and what the class has now, or nil.
local function MarksEarned(text)
	if not string.find(text, "%d") then
		return nil
	end
	for index = 1, table.getn(EARNED) do
		local _, _, amount, total = string.find(text, EARNED[index])
		if amount then
			return Number(amount), Number(total)
		end
	end
end

local standing, fallen = {}, {} -- the bosses alive, [id] = name; those just gone, oldest first

-- One just gone: the name for a boss's line that came first, else kept for
-- the line to come.
local function Fell(name)
	local now = GetTime()
	for index = math.max(1, table.getn(earned) - 3), table.getn(earned) do
		local row = earned[index]
		if row.paid and not row.boss and now - row.when <= FELL_WINDOW then
			row.boss = name
			return
		end
	end
	table.insert(fallen, { name = name, when = now })
end

-- The oldest boss gone a moment ago that no line has taken.
local function Claim(now)
	while fallen[1] do
		local one = table.remove(fallen, 1)
		if now - one.when <= FELL_WINDOW then
			return one.name
		end
	end
end

local function LookAtBosses()
	local units = AZS_UNITS or {}
	local seen = {}
	for index = 1, table.getn(units) do
		local unit = units[index]
		local kind = unit.kind
		if (kind == "final" or kind == "boss" or kind == "guardian") and (tonumber(unit.hp) or 0) > 0 and unit.id then
			seen[unit.id] = unit.name or "?"
		end
	end
	for id, name in pairs(standing) do
		if not seen[id] then
			Fell(name)
		end
	end
	standing = seen
	local now = GetTime()
	while fallen[1] and now - fallen[1].when > FELL_WINDOW do
		table.remove(fallen, 1)
	end
end

-- Whichever line comes first opens the boss's row; two bosses' lines, two rows.
local function AddMarks(amount, paid)
	local now, row = GetTime(), earned[table.getn(earned)]
	if row and now - row.when <= DROP_WINDOW and not (paid and row.paid) then
		row.amount = row.amount + amount
	else
		row = { amount = amount, at = RunSeconds(), when = now }
		table.insert(earned, row)
	end
	if paid then
		row.paid = true
		row.boss = Claim(now)
	end
	earned.total = earned.total + amount
end

-- What each class has, as the game last said: kept for the account, since the
-- game tells it only as a boss falls. A repeat after that line adds to it.
local function Stocks()
	local db = SUIC.DB()
	db.lootClassMarks = db.lootClassMarks or {}
	return db.lootClassMarks
end

local function ClassKey()
	local _, class = UnitClass("player")
	return class or "?"
end

local function Stock(total, amount)
	local stocks, class = Stocks(), ClassKey()
	if total then
		stocks[class] = total
	elseif stocks[class] then
		stocks[class] = stocks[class] + amount
	end
end

head:SetScript("OnEnter", function()
	GameTooltip:SetOwner(this, "ANCHOR_LEFT")
	GameTooltip:SetText(SUIC.TF("{1} marks this run", Amount(earned.total)))
	local count = table.getn(earned)
	for index = math.max(1, count - HISTORY + 1), count do
		local each = earned[index]
		local name = each.boss or SUIC.T(each.paid and "A boss" or "Repeated loot")
		GameTooltip:AddDoubleLine("|cff8c8c96"..(each.at and SUIC.Clock(each.at) or "").."|r  "..name,
			"+"..Amount(each.amount), 1, 1, 1, 1, 0.82, 0)
	end
	if count == 0 then
		GameTooltip:AddLine(SUIC.T("A boss's fall brings them, and a piece you already have."), 0.62, 0.62, 0.68, 1)
	end
	local stock = Stocks()[ClassKey()]
	if stock then
		GameTooltip:AddDoubleLine(SUIC.T("Class total"), Amount(stock), 0.8, 0.8, 0.84, 1, 0.82, 0)
	end
	GameTooltip:Show()
end)
head:SetScript("OnLeave", function() GameTooltip:Hide() end)

------------------------------------------------------------------------------
-- The chat's lines (Loot.lua reads them, once for the notices and this).

local function Add(text)
	local rest = SUIC.LootReceived(text)
	if not rest then
		return
	end
	local _, _, name = string.find(rest, "%[(.-)%]")
	if not name then
		return
	end
	local _, _, color = string.find(rest, "|c(%x%x%x%x%x%x%x%x)[^%[]*%[")
	local _, _, item = string.find(rest, "|H(item:[%d:%-]+)|h")
	local _, _, count = string.find(rest, "%]|?h?|?r?x(%d+)")
	if item then
		local links = Known()
		links[name] = item
	end
	-- A piece already collected: its marks, gold at the line's end, in every
	-- language with a plus before them.
	local _, _, worth = string.find(rest, "|cffffd100[^|]-%+([%d%.,]+)")
	worth = worth and Number(worth)
	if worth then
		AddMarks(worth)
		Stock(nil, worth)
	end
	-- The same piece again: its one row, counted, on top again.
	for index = 1, table.getn(entries) do
		local entry = entries[index]
		if entry.name == name then
			table.remove(entries, index)
			entry.count = (entry.count or 1) + (tonumber(count) or 1)
			entry.item = entry.item or item
			entry.new = entry.new or SUIC.LootIsNew(rest)
			if worth then
				entry.worth = (entry.worth or 0) + worth
			end
			entry.at = RunSeconds()
			table.insert(entries, 1, entry)
			return
		end
	end
	table.insert(entries, 1, {
		item = item, name = name, color = color, count = tonumber(count), worth = worth,
		new = SUIC.LootIsNew(rest), at = RunSeconds(),
	})
	while table.getn(entries) > KEEP do
		table.remove(entries)
	end
end

local runSeen, lastSeconds

local function NewRun()
	entries = {}
	earned = { total = 0 }
	fallen = {}
end

-- A new run: the game's zone given again, or its clock going back.
local function CheckRun()
	if AZS_ZONE_UPDATED ~= runSeen then
		runSeen = AZS_ZONE_UPDATED
		NewRun()
	end
	local seconds = RunSeconds()
	if seconds and lastSeconds and seconds + 3 < lastSeconds then
		NewRun()
	end
	lastSeconds = seconds
end

-- In a run, once something has dropped; hidden, as tall as its rows will be,
-- so Move frames shows the room it takes.
local function Refresh()
	CheckRun()
	Seat()
	if SUIC.DB().lootList and SUIC.InRun() and (table.getn(entries) > 0 or earned.total > 0) then
		if not panel:IsShown() then
			panel:Show()
		end
		Draw()
	else
		panel:Hide()
		panel:SetHeight(TOP + Lines() * ROW + 6)
	end
end

SUIC.OnLootLine(function(text)
	if not SUIC.DB().lootList then
		return
	end
	CheckRun()
	-- "<hero> enters <zone>. Move to begin.": a new run, an empty list.
	-- The game's Russian words too.
	if string.find(text, "Move to begin", 1, true) or string.find(text, "Двигайтесь, чтобы начать", 1, true) then
		NewRun()
	elseif string.find(text, "[", 1, true) then
		Add(text)
	else
		local amount, total = MarksEarned(text)
		if not amount then
			return
		end
		AddMarks(amount, true)
		Stock(total)
	end
	Refresh()
end)

SUIC.RefreshLootList = function()
	SUIC.RefreshLoot()
	Refresh()
	SUIC.SeatColumn()
end

-- Every piece once, as the hero comes in: the gear stays as it is through a
-- run. Then only the jewelry, as it changes. The bosses often: a boss's marks
-- come a moment from its fall.
local watch = CreateFrame("Frame")
watch:SetScript("OnEvent", function()
	if event == "PLAYER_ENTERING_WORLD" then
		LearnWorn(EVERY_SLOT)
	elseif arg1 == "player" then
		LearnWorn(JEWELRY_SLOTS)
	end
end)
local looked, ticker = 0, 0
watch:SetScript("OnUpdate", function()
	looked = looked + arg1
	if looked >= 0.2 then
		looked = 0
		if SUIC.DB().lootList then
			LookAtBosses()
		end
	end
	ticker = ticker + arg1
	if ticker < 0.5 then
		return
	end
	ticker = 0
	Refresh()
end)
watch:Hide()

SUIC.OnStart(function()
	SUIC.ColumnHome("lootlist")(panel)
	SUIC.AddPiece("lootlist", "Loot list", panel, SUIC.ColumnHome("lootlist"))
	watch:RegisterEvent("PLAYER_ENTERING_WORLD")
	watch:RegisterEvent("UNIT_INVENTORY_CHANGED")
	LearnWorn(EVERY_SLOT)
	watch:Show()
	Refresh()
end)
