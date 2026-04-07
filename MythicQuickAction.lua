-- MythicQuickAction - Midnight Season 1
local addonName, addon = ...

local DUNGEON_DATA = {
	-- [mapID] = { spellID, activityID, activityGroupID }
	[560] = { 1254559, 1174, 400 }, -- Maisara Caverns
	[559] = { 1254563, 1173, 401 }, -- Nexus-Point Xenas
	[558] = { 1254572, 1172, 399 }, -- Magisters' Terrace
	[557] = { 1254400, 1171, 370 }, -- Windrunner Spire
	[402] = { 393273, 1162, 302 },  -- Algeth'ar Academy
	[239] = { 1254551, 1176, 133 }, -- Seat of the Triumvirate
	[161] = { 1254557, 1175, 9 },   -- Skyreach
	[556] = { 1254555, 1170, 52 },  -- Pit of Saron
}

-- Global function to handle Right-Click (LFG)
function MQA_OpenLFG(mapID)
	local data = DUNGEON_DATA[mapID]
	if not data or not data[3] then return end

	local activityID = data[2]
	local groupID = data[3]

	-- 1. Ensure UI is loaded
	if not PVEFrame then UIParentLoadAddOn("Blizzard_LFGUI") end
	PVEFrame_ShowFrame("GroupFinderFrame", LFGListPVEStub)

	-- 2. Select Dungeons Category
	LFGListCategorySelection_SelectCategory(LFGListFrame.CategorySelection, 2, 0)

	-- 3. APPLY ADVANCED FILTER (The PGF Secret Sauce)
	local filter = {
		activities = { groupID }, -- This is the key array!
		difficultyNormal = true,
		difficultyHeroic = true,
		difficultyMythic = true,
		difficultyMythicPlus = true,
	}
	C_LFGList.SaveAdvancedFilter(filter)

	-- 4. Sync the visual UI
	local p = LFGListFrame.SearchPanel
	LFGListSearchPanel_Clear(p)
	p.filters = { [activityID] = true } -- Still set this for the checkbox visual

	-- 5. Transition to Results
	LFGListFrame.CategorySelection:Hide()
	p:Show()

	print("|cffffff00MQA:|r Advanced Filter set for Group " .. groupID)
end

local function IsSpellKnownAndReady(spellID)
	if not spellID or spellID == 0 then return false end
	return C_SpellBook.IsSpellInSpellBook(spellID, Enum.SpellBookSpellBank.Player, false)
end

local function InitButton(button)
	button:SetAllPoints()
	button:SetFrameLevel(999)
	button:RegisterForClicks("AnyUp", "AnyDown")

	local highlight = button:CreateTexture(nil, "OVERLAY")
	highlight:SetTexture("Interface\\EncounterJournal\\UI-EncounterJournalTextures")
	highlight:SetTexCoord(0.34570313, 0.68554688, 0.33300781, 0.42675781)
	highlight:SetAllPoints()
	highlight:Hide()
	button.highlight = highlight

	function button:UpdateHighlight()
		self.highlight:SetShown(self.spellID ~= nil and IsSpellKnownAndReady(self.spellID))
	end

	button:HookScript("OnClick", function(self, mouseButton)
		if mouseButton == "LeftButton" then
			print("|cffffff00MQA:|r Attempting teleport for Map " .. tostring(self.mapID))
		end
	end)
end

local function GetOrCreateButton(icon)
	if icon.__mqaButton then return icon.__mqaButton end
	local button = CreateFrame("Button", nil, icon, "InsecureActionButtonTemplate")
	InitButton(button)
	icon.__mqaButton = button
	return button
end

local function ProcessIcon(icon)
	if InCombatLockdown() then return end

	local mapID = icon.mapID
	-- FIXED: Reference correct table name and handle the new {spell, activity} structure
	local data = mapID and DUNGEON_DATA[mapID] or nil
	local spellID = data and data[1] or nil

	local button = GetOrCreateButton(icon)
	button.mapID = mapID
	button.spellID = spellID

	-- LEFT CLICK: Teleport
	if spellID and IsSpellKnownAndReady(spellID) then
		local spellName = C_Spell.GetSpellName(spellID)
		button:SetAttribute("type1", "spell")
		button:SetAttribute("spell1", spellName)
		button.highlight:Show()
	else
		button:SetAttribute("type1", nil)
		button.highlight:Hide()
	end

	-- RIGHT CLICK: LFG
	-- RIGHT CLICK: Setup UI + Click Search
	if mapID then
		button:SetAttribute("type2", "macro")
		-- The macro runs your function, then programmatically clicks the 'Refresh' button
		button:SetAttribute("macrotext2", string.format("/run MQA_OpenLFG(%d)\n/click LFGListFrame.SearchPanel.SearchButton", mapID))
	end
end

local function OnChallengesFrameUpdate()
	if not ChallengesFrame or not ChallengesFrame.DungeonIcons then return end
	for _, icon in ipairs(ChallengesFrame.DungeonIcons) do
		ProcessIcon(icon)
	end
end

-- Setup and Events
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and (arg1 == "Blizzard_ChallengesUI" or arg1 == addonName) then
		if ChallengesFrame then
			hooksecurefunc(ChallengesFrame, "Update", OnChallengesFrameUpdate)
			OnChallengesFrameUpdate()
		end
	elseif event == "SPELLS_CHANGED" or event == "PLAYER_REGEN_ENABLED" then
		if not InCombatLockdown() then OnChallengesFrameUpdate() end
	end
end)
