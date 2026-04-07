-- 🖱️ MythicClick: Teleports highlighted. Left click teleport. Right click LFG.

local addonName, ns = ...

-- [mapID] = { spellID, activityID, activityGroupID }
local DUNGEON_DATA = {
	[560] = { 1254559, 1174, 400 }, -- Maisara Caverns
	[559] = { 1254563, 1173, 401 }, -- Nexus-Point Xenas
	[558] = { 1254572, 1172, 399 }, -- Magisters' Terrace
	[557] = { 1254400, 1171, 370 }, -- Windrunner Spire
	[402] = { 393273, 1162, 302 }, -- Algeth'ar Academy
	[239] = { 1254551, 1176, 133 }, -- Seat of the Triumvirate
	[161] = { 1254557, 1175, 9 }, -- Skyreach
	[556] = { 1254555, 1170, 52 }, -- Pit of Saron
}

function MythicClick_OpenLFG(mapID)
	local data = DUNGEON_DATA[mapID]
	if not data then return end
	local groupID = data[3]

	local filter = C_LFGList.GetAdvancedFilter()
	filter.activities = { groupID }
	filter.difficultyNormal = false
	filter.difficultyHeroic = false
	filter.difficultyMythic = false
	filter.difficultyMythicPlus = true
	C_LFGList.SaveAdvancedFilter(filter)

	if not PVEFrame then UIParentLoadAddOn("Blizzard_LFGUI") end
	PVEFrame_ShowFrame("GroupFinderFrame", "LFGListPVEStub")
	LFGListCategorySelection_SelectCategory(LFGListFrame.CategorySelection, 2, 0)

	local findBtn = LFGListFrame.CategorySelection and LFGListFrame.CategorySelection.FindGroupButton
	if findBtn and findBtn:IsEnabled() then
		findBtn:Click()
	end
end

local function IsSpellKnownAndReady(spellID)
	if not spellID or spellID == 0 then return false end
	return C_SpellBook.IsSpellInSpellBook(spellID, Enum.SpellBookSpellBank.Player, false)
end

local function InitButton(button)
	button:SetAllPoints()

	local parent = button:GetParent()
	if parent then
		button:SetFrameLevel(parent:GetFrameLevel() + 1)
	end

	button:RegisterForClicks("AnyUp", "AnyDown")

	local highlight = button:CreateTexture(nil, "OVERLAY")
	highlight:SetTexture("Interface\\EncounterJournal\\UI-EncounterJournalTextures")
	highlight:SetTexCoord(0.34570313, 0.68554688, 0.33300781, 0.42675781)
	highlight:SetAllPoints()
	highlight:Hide()
	button.highlight = highlight

	button:SetScript("OnEnter", function(self)
		local p = self:GetParent()
		if p and p:GetScript("OnEnter") then
			p:GetScript("OnEnter")(p)
		end

		if self.spellID then
			self.highlight:SetAlpha(0.7)

			GameTooltip:AddLine(" ")
			if self.hasSpell then
				GameTooltip:AddLine("Left Click: |cff80ff80Teleport|r")
			end
			GameTooltip:AddLine("Right Click: |cff80ff80LFG|r")
			GameTooltip:Show()
		end
	end)

	button:SetScript("OnLeave", function(self)
		local p = self:GetParent()
		if p and p:GetScript("OnLeave") then
			p:GetScript("OnLeave")(p)
		end
		GameTooltip:Hide()
		if self.spellID then self.highlight:SetAlpha(1.0) end
	end)
end

local function GetOrCreateButton(icon)
	if icon.__mythicClickButton then return icon.__mythicClickButton end
	local button = CreateFrame("Button", nil, icon, "InsecureActionButtonTemplate")
	InitButton(button)
	icon.__mythicClickButton = button
	return button
end

local function ProcessIcon(icon)
	if InCombatLockdown() then return end

	local mapID = icon.mapID
	local data = mapID and DUNGEON_DATA[mapID] or nil
	local spellID = data and data[1] or nil
	local button = GetOrCreateButton(icon)
	button.mapID = mapID
	button.spellID = spellID
	local hasSpell = spellID and IsSpellKnownAndReady(spellID)
	button.hasSpell = hasSpell

	if hasSpell then
		local spellName = C_Spell.GetSpellName(spellID)
		button:SetAttribute("type1", "spell")
		button:SetAttribute("spell1", spellName)
		button.highlight:Show()
	else
		button:SetAttribute("type1", nil)
		button.highlight:Hide()
	end

	if mapID then
		button:SetAttribute("type2", "macro")
		button:SetAttribute("macrotext2", string.format("/run MythicClick_OpenLFG(%d)", mapID))
	end
end

local function OnChallengesFrameUpdate()
	if not ChallengesFrame or not ChallengesFrame.DungeonIcons then return end
	for _, icon in ipairs(ChallengesFrame.DungeonIcons) do
		ProcessIcon(icon)
	end
end

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
