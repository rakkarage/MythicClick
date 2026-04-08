-- 🖱️ MythicClick: Teleports highlighted. Left click teleport. Right click LFG.

local addonName, ns = ...

ns.MythicClick = CreateFrame("Frame")
local MythicClick = ns.MythicClick
MythicClick.name = addonName

-- [mapID] = { spellID, activityGroupID }
local DUNGEON_DATA = {
	[560] = { 1254559, 400 }, -- Maisara Caverns
	[559] = { 1254563, 401 }, -- Nexus-Point Xenas
	[558] = { 1254572, 399 }, -- Magisters' Terrace
	[557] = { 1254400, 370 }, -- Windrunner Spire
	[402] = { 393273, 302 }, -- Algeth'ar Academy
	[239] = { 1254551, 133 }, -- Seat of the Triumvirate
	[161] = { 1254557, 9 }, -- Skyreach
	[556] = { 1254555, 52 }, -- Pit of Saron
}

function MythicClick_OpenLFG(mapID)
	local data = DUNGEON_DATA[mapID]
	if not data then return end
	local groupID = data[2]

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

function IsSpellKnown(spellID)
	if not spellID or spellID == 0 then return false end
	return C_SpellBook.IsSpellInSpellBook(spellID, Enum.SpellBookSpellBank.Player, false)
end

function MythicClick:InitButton(button)
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

function MythicClick:GetOrCreateButton(icon)
	if icon.__mythicClickButton then return icon.__mythicClickButton end
	local button = CreateFrame("Button", nil, icon, "InsecureActionButtonTemplate")
	self:InitButton(button)
	icon.__mythicClickButton = button
	return button
end

function MythicClick:ProcessIcon(icon)
	if InCombatLockdown() then return end

	local mapID = icon.mapID
	local data = mapID and DUNGEON_DATA[mapID] or nil
	local spellID = data and data[1] or nil
	local button = self:GetOrCreateButton(icon)
	button.mapID = mapID
	button.spellID = spellID
	local hasSpell = spellID and IsSpellKnown(spellID)
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
	else
		button:SetAttribute("type2", nil)
		button:SetAttribute("macrotext2", nil)
	end
end

function MythicClick:OnChallengesFrameUpdate()
	if not ChallengesFrame or not ChallengesFrame.DungeonIcons then return end
	for _, icon in ipairs(ChallengesFrame.DungeonIcons) do
		self:ProcessIcon(icon)
	end
end

MythicClick:RegisterEvent("ADDON_LOADED")
MythicClick:RegisterEvent("SPELLS_CHANGED")
MythicClick:RegisterEvent("PLAYER_REGEN_ENABLED")
MythicClick:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and (arg1 == "Blizzard_ChallengesUI" or arg1 == addonName) then
		if ChallengesFrame then
			hooksecurefunc(ChallengesFrame, "Update", function()
				self:OnChallengesFrameUpdate()
			end)
			self:OnChallengesFrameUpdate()
		end
	elseif event == "SPELLS_CHANGED" or event == "PLAYER_REGEN_ENABLED" then
		if not InCombatLockdown() then self:OnChallengesFrameUpdate() end
	end
end)
