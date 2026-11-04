-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the loot notices, as the game's but movable. What drops
-- shows a while and fades, the newest on top: its icon when the game gives
-- one, its name in its quality's color, how many, "New!" when it is new in
-- the collection. They stand in for the game's loot notices, which are put
-- away while these or the loot list (LootList.lua) are on.
--
-- The game tells addons nothing of loot, so this reads the chat's "You
-- receive loot: [item]" lines (Survivor UI's LootLog.lua, the same reading),
-- once for the notices and the loot list both.

local MOST = 6
local ROW = 16
local WIDTH = 230
local SHOWN = 8                 -- seconds a notice stays whole, then fades
local FADE = 2

local holder = CreateFrame("Frame", "SUICLoot", UIParent)
holder:SetWidth(WIDTH)
holder:SetHeight(MOST * ROW)

local function Home(f)
	f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -256, -200)
end
Home(holder)

local rows = {}
for index = 1, MOST do
	local row = CreateFrame("Frame", nil, holder)
	row:SetWidth(WIDTH)
	row:SetHeight(ROW)
	row:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, -(index - 1) * ROW)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetWidth(ROW - 2)
	row.icon:SetHeight(ROW - 2)
	row.icon:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	row.text = SUIC.Text(row, "GameFontNormal")
	row.text:SetPoint("RIGHT", row.icon, "LEFT", -4, 0)
	row.text:SetJustifyH("RIGHT")
	row:Hide()
	rows[index] = row
end

-- The line as the game writes it in each of its languages (Survivor UI's).
local RECEIVE = {
	"You receive loot:", "Otrzymujesz łup:", "Du erhältst Beute:", "Você recebe saque:",
	"Recibes botín:", "Vous recevez du butin :", "Ganimet aldın:", "Вы получаете добычу:",
	"你获得了战利品：", "전리품을 받았습니다:",
	"Primești pradă:", "Ви отримуєте здобич:", "戦利品を入手：", "Získáváš kořist:",
}
local NEW = {
	"New in your collection", "Nowość w kolekcji", "Neu in deiner Sammlung", "Novo na sua coleção",
	"Nuevo en tu colección", "Nouveau dans votre collection", "Koleksiyonunda yeni",
	"Новое в вашей коллекции", "收藏新增", "수집품에 새로 추가",
	"Nou în colecția ta", "Нове у вашій колекції", "コレクションに新しく追加", "Novinka ve tvé sbírce",
}

-- What follows "You receive loot:" (or its own words), or nil.
function SUIC.LootReceived(message)
	for index = 1, table.getn(RECEIVE) do
		local _, last = string.find(message, RECEIVE[index], 1, true)
		if last then
			return string.sub(message, last + 1)
		end
	end
	local _, _, rest = string.find(message, "You receive [%a ]+: (.+)")
	return rest
end

function SUIC.LootIsNew(rest)
	for index = 1, table.getn(NEW) do
		if string.find(rest, NEW[index], 1, true) then
			return true
		end
	end
	return false
end

local notices = {}

local function Add(message)
	local rest = SUIC.LootReceived(message)
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
	table.insert(notices, 1, { name = name, color = color or "ffffffff", count = tonumber(count),
		new = SUIC.LootIsNew(rest), icon = SUIC.LootIcon and SUIC.LootIcon(name, item), at = GetTime() })
	while table.getn(notices) > MOST do
		table.remove(notices)
	end
end

local function Draw()
	local now = GetTime()
	for index = table.getn(notices), 1, -1 do
		if now - notices[index].at > SHOWN + FADE then
			table.remove(notices, index)
		end
	end
	for index = 1, MOST do
		local row, notice = rows[index], notices[index]
		if notice then
			local text = "|c"..notice.color..notice.name.."|r"
			if notice.count and notice.count > 1 then
				text = text.." x"..notice.count
			end
			if notice.new then
				text = "|cff40ff40"..SUIC.T("New!").."|r  "..text
			end
			row.text:SetText(text)
			row.icon:SetTexture(notice.icon or "Interface\\Icons\\INV_Misc_Bag_10")
			local age = now - notice.at
			row:SetAlpha(age > SHOWN and math.max(0, 1 - (age - SHOWN) / FADE) or 1)
			row:Show()
		else
			row:Hide()
		end
	end
end

------------------------------------------------------------------------------
-- The chat's lines, to each piece that reads them: the notices here, the loot
-- list. The same line can arrive twice, by the event and by the window, and
-- the same piece twice in a moment twice by each (Survivor UI's reading): a
-- line counts only when the way that has brought it most brings it once more,
-- each line kept apart for a second.

local readers = {}

function SUIC.OnLootLine(reader)
	table.insert(readers, reader)
end

local recent = {}

local function Fresh(text, way)
	local now = GetTime()
	for line, seen in pairs(recent) do
		if now - seen.at >= 1 then
			recent[line] = nil
		end
	end
	local seen = recent[text]
	if not seen then
		seen = { at = now, event = 0, window = 0 }
		recent[text] = seen
	end
	seen[way] = seen[way] + 1
	return seen[way] > seen[way == "event" and "window" or "event"]
end

local function Seen(text, way)
	if not (text and SUIC.active) then
		return
	end
	local db = SUIC.DB()
	-- A loot line kept by what it got, whatever the window puts before it.
	if not (db.lootLog or db.lootList) or not Fresh(SUIC.LootReceived(text) or text, way) then
		return
	end
	for index = 1, table.getn(readers) do
		readers[index](text)
	end
end

SUIC.OnLootLine(function(text)
	if SUIC.DB().lootLog and string.find(text, "[", 1, true) then
		Add(text)
	end
end)

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function() Seen(arg1, "event") end)

local elapsed = 0
holder:SetScript("OnUpdate", function()
	elapsed = elapsed + arg1
	if elapsed < 0.1 then
		return
	end
	elapsed = 0
	Draw()
end)
holder:Hide()

function SUIC.RefreshLoot()
	local db = SUIC.DB()
	SUIC.SetGameShown("loot", not (db.lootLog or db.lootList))
	if db.lootLog then
		holder:Show()
	else
		holder:Hide()
	end
end

SUIC.OnStart(function()
	local names = { "CHAT_MSG_LOOT", "CHAT_MSG_SYSTEM", "CHAT_MSG_MONEY", "CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_MONSTER_EMOTE" }
	for index = 1, table.getn(names) do
		events:RegisterEvent(names[index])
	end
	-- Every line the main chat window shows, whatever brought it there.
	if ChatFrame1 and not ChatFrame1.suicLootWatched then
		ChatFrame1.suicLootWatched = true
		local stock = ChatFrame1.AddMessage
		ChatFrame1.AddMessage = function(self, text, r, g, b, id, hold)
			Seen(text, "window")
			return stock(self, text, r, g, b, id, hold)
		end
	end
	SUIC.AddPiece("loot", "Loot", holder, Home)
	SUIC.RefreshLoot()
end)
