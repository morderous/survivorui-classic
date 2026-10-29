-- SurvivorUI Classic - Copyright (C) 2026 morderous - GPL-3.0 - github.com/morderous/survivorui-classic
-- SurvivorUI Classic: the options, in a window of the game's own make: a
-- dialog frame, the tabs down its left as a quest log's titles, and the
-- game's checkboxes, sliders and radio buttons. A tab for each piece: its
-- size (it grows from where it stands), what it shows, and Reset. Opened from
-- the minimap button, or /suic; Escape closes it.

local DIALOG = {
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32,
	insets = { left = 11, right = 12, top = 12, bottom = 11 },
}
local HIGHLIGHT = "Interface\\QuestFrame\\UI-QuestTitleHighlight"
local LEFT = 172               -- the pages' left edge, past the tabs
local PAGE_WIDTH = 400

local window = CreateFrame("Frame", "SUICOptions", UIParent)
window:SetWidth(600)
window:SetHeight(500)
window:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
window:SetFrameStrata("DIALOG")
window:SetBackdrop(DIALOG)
window:EnableMouse(true)
window:SetMovable(true)
window:SetClampedToScreen(true)
window:RegisterForDrag("LeftButton")
window:SetScript("OnDragStart", function() this:StartMoving() end)
window:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
window:Hide()
table.insert(UISpecialFrames, "SUICOptions")

local inside = window:CreateTexture(nil, "BACKGROUND")
inside:SetTexture(SUIC.FLAT)
inside:SetVertexColor(0, 0, 0, 0.85)
inside:SetPoint("TOPLEFT", window, "TOPLEFT", 11, -12)
inside:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -12, 11)

local header = window:CreateTexture(nil, "ARTWORK")
header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
header:SetWidth(300)
header:SetHeight(64)
header:SetPoint("TOP", window, "TOP", 0, 12)
local heading = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
heading:SetPoint("TOP", header, "TOP", 0, -14)
heading:SetText("SurvivorUI Classic")

local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", window, "TOPRIGHT", -6, -6)

local version = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
version:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 20, 18)
version:SetText("Version "..SUIC.VERSION)

-- A line between the tabs and the page.
local divider = window:CreateTexture(nil, "ARTWORK")
divider:SetTexture(SUIC.FLAT)
divider:SetVertexColor(1, 0.82, 0, 0.25)
divider:SetWidth(1)
divider:SetPoint("TOPLEFT", window, "TOPLEFT", LEFT - 12, -36)
divider:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", LEFT - 12, 36)

------------------------------------------------------------------------------
-- The controls. Each one appends itself to its page, under the last, and
-- reads its value again whenever the page shows.

local count = 0
local function NextName()
	count = count + 1
	return "SUICOpt"..count
end

local function Place(page, control, height, indent)
	control:SetPoint("TOPLEFT", page, "TOPLEFT", indent or 0, page.y)
	page.y = page.y - height
end

local function Updates(page, update)
	table.insert(page.updates, update)
end

local function Header(page, text)
	page.y = page.y - 8
	local label = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetText(text)
	Place(page, label, 16)
	local rule = SUIC.Rule(page)
	rule:SetWidth(PAGE_WIDTH)
	Place(page, rule, 8)
end

local function Note(page, text)
	local note = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	note:SetWidth(PAGE_WIDTH)
	note:SetJustifyH("LEFT")
	note:SetText(text)
	note:SetTextColor(0.75, 0.75, 0.75)
	Place(page, note, SUIC.Lines(note, PAGE_WIDTH) * 12 + 4)
end

local function Check(page, label, get, set, tip)
	local name = NextName()
	local check = CreateFrame("CheckButton", name, page, "OptionsCheckButtonTemplate")
	getglobal(name.."Text"):SetText(label)
	check.tooltipText = tip
	check:SetScript("OnClick", function()
		set(this:GetChecked() and true or false)
	end)
	Place(page, check, 26)
	Updates(page, function()
		check:SetChecked(get() and 1 or nil)
	end)
	return check
end

-- A setting's checkbox: on or off, then its piece drawn again.
local function Setting(page, label, key, refresh, tip)
	return Check(page, label, function() return SUIC.DB()[key] end, function(on)
		SUIC.DB()[key] = on
		if refresh and SUIC[refresh] then
			SUIC[refresh]()
		end
	end, tip)
end

local function Slider(page, label, low, high, step, get, set, shown)
	local name = NextName()
	page.y = page.y - 18
	local slider = CreateFrame("Slider", name, page, "OptionsSliderTemplate")
	slider:SetWidth(220)
	slider:SetMinMaxValues(low, high)
	slider:SetValueStep(step)
	getglobal(name.."Low"):SetText(shown(low))
	getglobal(name.."High"):SetText(shown(high))
	local text = getglobal(name.."Text")
	slider:SetScript("OnValueChanged", function()
		local value = math.floor(this:GetValue() / step + 0.5) * step
		text:SetText(label..": "..shown(value))
		if not this.reading then
			set(value)
		end
	end)
	Place(page, slider, 34, 8)
	Updates(page, function()
		slider.reading = true
		slider:SetValue(get())
		text:SetText(label..": "..shown(get()))
		slider.reading = nil
	end)
	return slider
end

local function Percent(value)
	return math.floor(value * 100 + 0.5).."%"
end

-- A piece's size, 50 to 150%.
local function Size(page, label, key)
	return Slider(page, label, 0.5, 1.5, 0.05, function() return SUIC.PieceSize(key) end, function(value)
		SUIC.SetPieceSize(key, value)
	end, Percent)
end

-- A row of radio buttons: one of choices ({ value, label } each).
local function Radio(page, label, choices, get, set)
	local text = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetText(label)
	Place(page, text, 16, 4)
	local buttons = {}
	local x = 4
	for index = 1, table.getn(choices) do
		local name = NextName()
		local button = CreateFrame("CheckButton", name, page, "UIRadioButtonTemplate")
		button.value = choices[index][1]
		local caption = getglobal(name.."Text")
		caption:SetText(choices[index][2])
		button:SetPoint("TOPLEFT", page, "TOPLEFT", x, page.y)
		x = x + 24 + caption:GetStringWidth() + 14
		button:SetScript("OnClick", function()
			set(this.value)
			for each = 1, table.getn(buttons) do
				buttons[each]:SetChecked(buttons[each].value == this.value and 1 or nil)
			end
		end)
		table.insert(buttons, button)
	end
	page.y = page.y - 24
	Updates(page, function()
		local current = get()
		for each = 1, table.getn(buttons) do
			buttons[each]:SetChecked(buttons[each].value == current and 1 or nil)
		end
	end)
end

local function Button(page, label, width, onClick, x)
	local button = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	button:SetWidth(width)
	button:SetHeight(22)
	button:SetText(label)
	button:SetScript("OnClick", onClick)
	button:SetPoint("TOPLEFT", page, "TOPLEFT", x or 0, page.y)
	return button
end

-- A dropdown: a button with the choice on it, its menu the choices
-- ({ value, label } each); the game's own menu.
local dropMenu = CreateFrame("Frame", "SUICOptionsDrop", UIParent, "UIDropDownMenuTemplate")
local function Dropdown(page, label, choices, get, set)
	local text = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetText(label)
	Place(page, text, 16, 4)
	local button = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	button:SetWidth(120)
	button:SetHeight(22)
	button:SetPoint("TOPLEFT", page, "TOPLEFT", 4, page.y)
	page.y = page.y - 28
	local function LabelOf(value)
		for index = 1, table.getn(choices) do
			if choices[index][1] == value then
				return choices[index][2]
			end
		end
		return tostring(value)
	end
	local function Pick(value)
		set(value)
		button:SetText(LabelOf(value).."  v")
	end
	button:SetScript("OnClick", function()
		UIDropDownMenu_Initialize(dropMenu, function()
			for index = 1, table.getn(choices) do
				UIDropDownMenu_AddButton({ text = choices[index][2], func = Pick, arg1 = choices[index][1],
					checked = get() == choices[index][1] })
			end
		end, "MENU")
		ToggleDropDownMenu(1, nil, dropMenu, this, 0, 0)
	end)
	Updates(page, function()
		button:SetText(LabelOf(get()).."  v")
	end)
	return button
end

-- The page's Reset: its pieces back in their first places, at their sizes.
local function Reset(page, keys)
	page.y = page.y - 8
	Button(page, "Reset", 120, function()
		for index = 1, table.getn(keys) do
			SUIC.ResetPiece(keys[index])
		end
		this:GetParent():Hide()
		this:GetParent():Show()
	end)
	page.y = page.y - 26
end

------------------------------------------------------------------------------
-- The pages.

local HEALTH = { { "off", "Off" }, { "value", "Value" }, { "percent", "Percent" }, { "both", "Both" } }

local function Health(page, label, key)
	Radio(page, label, HEALTH, function() return SUIC.DB()[key] end, function(value)
		SUIC.DB()[key] = value
		SUIC.UpdateHealthText()
	end)
end

local PAGES = {}

PAGES[1] = { "General", "The whole interface's size, the look of every panel, and where everything stands.", function(page)
	Header(page, "Interface")
	Slider(page, "Size", 0.6, 1.2, 0.05, function() return SUIC.DB().uiSize or UIParent:GetScale() end, function(value)
		SUIC.SetUISize(value)
	end, Percent)
	Header(page, "Panels")
	local borders = {}
	for index = 1, table.getn(SUIC.BORDER_ORDER) do
		local key = SUIC.BORDER_ORDER[index]
		table.insert(borders, { key, SUIC.BORDER_NAMES[key] })
	end
	Radio(page, "Border", borders, function() return SUIC.DB().border end, function(value)
		SUIC.DB().border = value
		SUIC.RepaintPanels()
	end)
	Setting(page, "Over the game's cards", "overCards", "RefreshOverCards",
		"While a level's cards or a new piece of jewelry are up, the run tracker, the build list, the jewelry and the damage meter stay lit over the game's dark veil.")
	Setting(page, "Hide the game's row of spells and jewelry", "hideGameRow", "RefreshGameRow",
		"The game's own row of icons under the chat; the build list and the jewelry show the same.")
	Header(page, "Layout")
	Button(page, "Move frames", 130, function()
		window:Hide()
		SUIC.SetMoveMode(true)
	end)
	Button(page, "Reset positions", 130, function() SUIC.ResetPositions() end, 136)
	Button(page, "Reset everything", 130, function() SUIC.ResetEverything() end, 272)
	page.y = page.y - 26
	Note(page, "Move frames has a box for every piece, the tooltip's too. Each tab sets its piece's size.")
	if IsAddOnLoaded("SurvivorUI") then
		page.y = page.y - 4
		Button(page, "Switch to Survivor UI", 170, function()
			window:Hide()
			SUIC.ShowChoice(true)
		end)
		page.y = page.y - 26
	end
end }

PAGES[2] = { "Action bar", "The game's action bar, its experience bar on top.", function(page)
	Size(page, "Size", "bar")
	Reset(page, { "bar" })
end }

PAGES[3] = { "Unit frames", "Your frame, your target's and the party's, and the health on them in numbers.", function(page)
	Size(page, "Player", "player")
	Size(page, "Target", "target")
	Size(page, "Party", "party")
	Header(page, "Health text")
	Health(page, "On your frame", "playerHealth")
	Health(page, "On your target's frame (an enemy's real health)", "targetHealth")
	Reset(page, { "player", "target", "party" })
end }

PAGES[4] = { "Minimap", "The minimap with its zone name and its buttons.", function(page)
	Size(page, "Size", "minimap")
	Setting(page, "The addon's button on the minimap", "mapButton", "RefreshMapButton",
		"Hidden, the options open with /suic.")
	Setting(page, "Caches and lairs on the minimap", "mapPins", "RefreshMapPins",
		"A chest for every cache, a red flag for every guardian's lair (faint when empty, beating while it fights), in place of the game's one flag.")
	Reset(page, { "minimap" })
end }

PAGES[5] = { "Run tracker", "The run after a Mythic+ timer: the time, every boss, the guardians, the kills and the gold. It stands in for the game's clock and its kills and gold line.", function(page)
	Setting(page, "Show the run tracker", "tracker", "RefreshTracker")
	Size(page, "Size", "tracker")
	Header(page, "Lines")
	Setting(page, "Bosses, each with its second", "trackerBosses")
	Setting(page, "Guardians slain (hover for every lair)", "trackerGuardians")
	Setting(page, "Elites slain", "trackerElites")
	Setting(page, "Kills", "trackerKills")
	Setting(page, "Gold", "trackerGold")
	Setting(page, "Next cache's price", "trackerCache")
	Reset(page, { "tracker" })
end }

PAGES[6] = { "Boss bars", "The game's boss bars as they look, that move and target: click one to target its enemy, hover it for its health. Guardians and elites as chosen.", function(page)
	Setting(page, "Show the boss bars", "bossBars", "RefreshBossBars")
	Size(page, "Size", "bosses")
	Setting(page, "Lair guardians, awake or hurt", "bossGuardians")
	Setting(page, "Elites", "bossElites")
	Slider(page, "Guardians and elites at most (bosses always)", 0, 8, 1, function() return tonumber(SUIC.DB().bossMost) or 4 end, function(value)
		SUIC.DB().bossMost = value
	end, function(value) return tostring(value) end)
	Reset(page, { "bosses" })
end }

PAGES[7] = { "Build list", "Your six spell slots and your racial, with their ranks and cooldowns.", function(page)
	Setting(page, "Show the build list", "buildList", "RefreshBuildList")
	Size(page, "Size", "build")
	Reset(page, { "build" })
end }

PAGES[8] = { "Jewelry", "The neck, the rings and the trinkets you wear this run, and what each gives.", function(page)
	Setting(page, "Show the jewelry", "jewelry", "RefreshJewelry")
	Size(page, "Size", "jewelry")
	Reset(page, { "jewelry" })
end }

PAGES[9] = { "Damage meter", "Damage done, healing, the last boss fight and the party: click its title for the page. It stands in for the game's meter.", function(page)
	Setting(page, "Show the damage meter", "meter", "RefreshMeter")
	Size(page, "Size", "meter")
	Slider(page, "Lines", 3, 15, 1, function() return tonumber(SUIC.DB().meterLines) or SUIC.Default("meterLines") end, function(value)
		SUIC.DB().meterLines = value
	end, function(value) return tostring(value) end)
	local sizes = {}
	for size = 8, 14 do
		table.insert(sizes, { size, size..(size == 10 and " (default)" or "") })
	end
	Dropdown(page, "Font size", sizes, function() return tonumber(SUIC.DB().meterFont) or 10 end, function(value)
		SUIC.DB().meterFont = value
		SUIC.ApplyMeterFont()
	end)
	Setting(page, "Fold the small lines into Others", "meterFold", "RefreshMeter",
		"The lines under the share below, folded into one grey line at the bottom; hover it for each. The button beside the meter's title does the same.")
	Slider(page, "Fold under", 1, 20, 1, function() return tonumber(SUIC.DB().meterFoldShare) or 10 end, function(value)
		SUIC.DB().meterFoldShare = value
	end, function(value) return value.."%" end)
	Reset(page, { "meter" })
end }

PAGES[13] = { "Level Up!", "The button that opens the levels waiting (the game's Store Level-Ups), as the game's but movable. It stands in for the game's.", function(page)
	Setting(page, "Show the Level Up! button", "levelUp", "RefreshLevelUp")
	Size(page, "Size", "levelup")
	Reset(page, { "levelup" })
end }

PAGES[14] = { "Nameplates", "The game's own nameplates over the enemies and the friends.", function(page)
	Header(page, "Keys")
	local keys = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	keys:SetWidth(PAGE_WIDTH)
	keys:SetJustifyH("LEFT")
	Place(page, keys, 30)
	Updates(page, function()
		local enemy = GetBindingKey and GetBindingKey("SUIC_ENEMYPLATES") or nil
		local friend = GetBindingKey and GetBindingKey("SUIC_FRIENDPLATES") or nil
		keys:SetText("|cffffd100"..(enemy or "No key").."|r   shows or hides the enemies' nameplates\n"
			.."|cffffd100"..(friend or "No key").."|r   shows or hides the friends' nameplates")
	end)
	Note(page, "Each on its own: one never hides the other. Set the keys again in the game's Key Bindings, under SurvivorUI Classic.")
	Header(page, "Shown now")
	Check(page, "Enemy nameplates", function() return NAMEPLATES_ON end, function(on)
		if (NAMEPLATES_ON and true or false) ~= on then
			SUIC_ToggleEnemyPlates()
		end
	end, "The plates over every enemy: its name and its health.")
	Check(page, "Friendly nameplates", function() return FRIENDNAMEPLATES_ON end, function(on)
		if (FRIENDNAMEPLATES_ON and true or false) ~= on then
			SUIC_ToggleFriendPlates()
		end
	end, "The plates over your party and your summons.")
	Header(page, "Which enemies")
	Setting(page, "Show only your target", "platesTarget", nil,
		"Every other enemy's plate is put away.")
	Setting(page, "Show only bosses, guardians and elites", "platesImportant", nil,
		"The rank and file's plates are put away; your target's always shows.")
end }

PAGES[10] = { "Loot", "What drops, a while and fading, as the game's notices but movable. They stand in for the game's.", function(page)
	Setting(page, "Show the loot notices", "lootLog", "RefreshLoot")
	Size(page, "Size", "loot")
	Reset(page, { "loot" })
end }

PAGES[11] = { "Summons", "Your summons and totems as the game's buffs: how many are out and the time the first goes.", function(page)
	Setting(page, "Show the summons and totems", "summons", "RefreshSummons")
	Size(page, "Size", "summons")
	Reset(page, { "summons" })
end }

PAGES[12] = { "Talent cooldowns", "The talents' clocks over the action bar: a second life's wait, a heal's, a proc's, a summoning talent's next.", function(page)
	Setting(page, "Show the talent cooldowns", "talentTimers", "RefreshTalentTimers")
	Size(page, "Size", "talentTimers")
	Reset(page, { "talentTimers" })
end }

local TEXT_PAGE = { "Combat text", "The numbers over the enemies you hit and over your hero, in Barlow: their size.", function(page)
	Slider(page, "Damage you deal", 30, 100, 10, function() return tonumber(SUIC.DB().numberSize) or SUIC.Default("numberSize") end, function(value)
		SUIC.DB().numberSize = value
		SUIC.ApplyNumberFont()
	end, function(value) return value.."%" end)
	Note(page, "From the next time the game opens: it reads these numbers' font once, as it loads.")
	Slider(page, "Damage you take", 30, 100, 10, function() return tonumber(SUIC.DB().takenSize) or SUIC.Default("takenSize") end, function(value)
		SUIC.DB().takenSize = value
		SUIC.ApplyTakenSize()
	end, function(value) return value.."%" end)
end }

-- The combat text's tab, second, after General.
table.insert(PAGES, 2, TEXT_PAGE)

------------------------------------------------------------------------------
-- The tabs.

local tabs, pages = {}, {}
local current

local function Build(index)
	if pages[index] then
		return pages[index]
	end
	local spec = PAGES[index]
	local page = CreateFrame("Frame", nil, window)
	page:SetPoint("TOPLEFT", window, "TOPLEFT", LEFT, -36)
	page:SetWidth(PAGE_WIDTH)
	page:SetHeight(420)
	page.updates = {}
	page.y = 0
	local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetText(spec[1])
	Place(page, title, 22)
	local about = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	about:SetWidth(PAGE_WIDTH)
	about:SetJustifyH("LEFT")
	about:SetText(spec[2])
	Place(page, about, SUIC.Lines(about, PAGE_WIDTH) * 12 + 8)
	spec[3](page)
	page:SetScript("OnShow", function()
		for each = 1, table.getn(this.updates) do
			this.updates[each]()
		end
	end)
	page:Hide()
	pages[index] = page
	return page
end

local function Select(index)
	current = index
	for each = 1, table.getn(PAGES) do
		if pages[each] then
			pages[each]:Hide()
		end
		if each == index then
			tabs[each].selected:Show()
		else
			tabs[each].selected:Hide()
		end
	end
	Build(index):Show()
end

for index = 1, table.getn(PAGES) do
	local tab = CreateFrame("Button", nil, window)
	tab:SetWidth(LEFT - 34)
	tab:SetHeight(20)
	tab:SetPoint("TOPLEFT", window, "TOPLEFT", 18, -36 - (index - 1) * 22)
	tab.text = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	tab.text:SetPoint("LEFT", tab, "LEFT", 8, 0)
	tab.text:SetText(PAGES[index][1])
	tab:SetHighlightTexture(HIGHLIGHT, "ADD")
	tab.selected = tab:CreateTexture(nil, "BACKGROUND")
	tab.selected:SetTexture(HIGHLIGHT)
	tab.selected:SetBlendMode("ADD")
	tab.selected:SetVertexColor(1, 0.82, 0)
	tab.selected:SetAllPoints(tab)
	tab.selected:Hide()
	tab.index = index
	tab:SetScript("OnClick", function()
		Select(this.index)
	end)
	tabs[index] = tab
end

-- A tab by its number (the tests' driver opens each one).
function SUIC.OptionsTab(index)
	if not window:IsShown() then
		window:Show()
	end
	Select(index)
end

function SUIC.ToggleOptions()
	if not SUIC.active then
		SUIC.ShowChoice(true)
		return
	end
	if window:IsShown() then
		window:Hide()
	else
		window:Show()
		Select(current or 1)
	end
end
