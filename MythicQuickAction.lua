-- MythicQuickAction - DEBUG TEST VERSION
-- Left click: teleport to dungeon ONLY (no LFG yet)
-- Testing: Midnight Season 1 dungeons

local addonName, addon = ...

local DUNGEON_TELEPORTS = {
	-- Midnight Season 1 (CURRENT)
	[402] = 393273, -- Algethar Academy
	[556] = 1254555, -- Pit of Saron
	[557] = 1254400, -- Windrunner Spire
	[558] = 1254572, -- Magisters' Terrace
	[559] = 1254563, -- Nexus-Point Xenas
	[560] = 1254559, -- Maisara Caverns
	[161] = 1254557, -- Skyreach
	[239] = 1254551, -- Seat of the Triumvirate
}

local frameSetAttribute = GetFrameMetatable().__index.SetAttribute

-- Check if spell is known
local function IsSpellKnownAndReady(spellID)
	if not spellID or spellID == 0 then return false end
	return C_SpellBook.IsSpellInSpellBook(spellID, Enum.SpellBookSpellBank.Player, false)
end

local function GetSpellDebugText(spellID)
	if not spellID then
		return "spellID=nil"
	end

	local spellName = C_Spell.GetSpellName and C_Spell.GetSpellName(spellID) or nil
	local known = IsSpellKnownAndReady(spellID)
	return string.format("spellID=%s name=%s known=%s", spellID, tostring(spellName), tostring(known))
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

	function button:RegisterSpell(mapID, spellID)
		self.mapID = mapID
		self.spellID = spellID
		frameSetAttribute(self, "spell", spellID)
		self.highlight:SetShown(spellID ~= nil and IsSpellKnownAndReady(spellID))
	end

	function button:UpdateHighlight()
		self.highlight:SetShown(self.spellID ~= nil and IsSpellKnownAndReady(self.spellID))
	end

	button:HookScript("OnClick", function(self, mouseButton)
		print("|cffffff00MythicQuickAction:|r click dungeonID=" .. tostring(self.mapID) .. " button=" .. tostring(mouseButton) .. " -> " .. GetSpellDebugText(self.spellID))
	end)

	button:SetScript("OnEnter", function(self)
		print("|cffffff00MythicQuickAction:|r mouseover dungeonID=" .. tostring(self.mapID) .. " -> " .. GetSpellDebugText(self.spellID))
	end)

	button:SetScript("OnLeave", function()
		print("|cffffff00MythicQuickAction:|r Mouse left dungeon")
	end)
end

local function GetOrCreateButton(icon)
	if icon.__mqaButton then
		return icon.__mqaButton
	end

	local button = CreateFrame("Button", nil, icon, "InsecureActionButtonTemplate")
	InitButton(button)
	icon.__mqaButton = button
	return button
end

local function ProcessIcon(icon)
	local mapID = icon.mapID
	local spellID = mapID and DUNGEON_TELEPORTS[mapID] or nil
	local button = GetOrCreateButton(icon)

	button.mapID = mapID
	button.spellID = spellID

	if spellID and IsSpellKnownAndReady(spellID) then
		local spellName = C_Spell.GetSpellName(spellID)
		-- Set standard attributes
		button:SetAttribute("type", "spell")
		button:SetAttribute("spell", spellName)
		button.highlight:Show()
	else
		button:SetAttribute("type", nil)
		button.highlight:Hide()
	end
end

local function OnChallengesFrameUpdate()
	if not ChallengesFrame or not ChallengesFrame.DungeonIcons then return end
	for _, icon in ipairs(ChallengesFrame.DungeonIcons) do
		if icon.mapID and DUNGEON_TELEPORTS[icon.mapID] then
			ProcessIcon(icon)
		end
	end
end

local function RefreshHighlights()
	if not ChallengesFrame or not ChallengesFrame.DungeonIcons then return end
	for _, icon in ipairs(ChallengesFrame.DungeonIcons) do
		if icon.__mqaButton then
			icon.__mqaButton.UpdateHighlight()
		end
	end
end

-- Setup hooks
local challengesHooked = false
local function SetupChallengesHook()
	if not ChallengesFrame or challengesHooked then return end
	challengesHooked = true
	hooksecurefunc(ChallengesFrame, "Update", OnChallengesFrameUpdate)
	OnChallengesFrameUpdate()
end

-- Event handler
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == "Blizzard_ChallengesUI" or arg1 == addonName then
			SetupChallengesHook()
		end
	elseif event == "SPELLS_CHANGED" then
		RefreshHighlights()
	end
end)

SLASH_MYTHICQUICKACTION1 = "/mqa"
SlashCmdList.MYTHICQUICKACTION = function(msg)
	local spellID = tonumber(msg and msg:match("%d+"))
	if not spellID then
		print("|cffffff00MythicQuickAction:|r Usage: /mqa <spellID>")
		return
	end

	local spellName = C_Spell.GetSpellName and C_Spell.GetSpellName(spellID) or nil
	local known = IsSpellKnownAndReady(spellID)
	local cooldownInfo = C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(spellID) or nil
	local startTime = cooldownInfo and cooldownInfo.startTime or 0
	local duration = cooldownInfo and cooldownInfo.duration or 0
	print("|cffffff00MythicQuickAction:|r /mqa dungeon test -> " .. GetSpellDebugText(spellID) .. " start=" .. tostring(startTime) .. " duration=" .. tostring(duration))
	if spellName then
		print("|cffffff00MythicQuickAction:|r test macro: /cast " .. spellName)
	else
		print("|cffffff00MythicQuickAction:|r no spell name found for spellID=" .. tostring(spellID))
	end
end

print("|cffffff00MythicQuickAction DEBUG|r loaded. Check chat for debug messages. Click dungeon icons to test teleport.")
