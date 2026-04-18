-- 🖱️ MythicClick: Awarded teleports highlighted. Left click: Teleport. Right click: LFG.

local addonName = ...

local frame = CreateFrame("Frame")

local activeCastSpellID, castProgress
local castUpdateElapsed = 0
local castingUpdateActive = false
local hooked = false

local BORDER_ALPHA = 0.75
local BORDER_HOVER = 1.0
local CASTBAR_COLOR = { 0.2, 0.8, 1.0 }
local CASTBAR = "Interface\\TargetingFrame\\UI-StatusBar"
local CASTBAR_SPARK = "Interface\\CastingBar\\UI-CastingBar-Spark"
local TOOLTIP_PORT = "Left Click: |cff80ff80Teleport|r"
local TOOLTIP_PORT_COOLDOWN = "Left Click: |cffff8080Teleport (Cooldown)|r"
local TOOLTIP_LFG = "Right Click: |cff80ff80LFG|r"

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

local function OpenLFG(mapID)
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

function MythicClick_OpenLFG(mapID)
	OpenLFG(mapID)
end

local function IsSpellKnown(spellID)
	if not spellID or spellID == 0 then return false end
	return C_SpellBook.IsSpellInSpellBook(spellID, Enum.SpellBookSpellBank.Player)
end

local function IsSpellOnCooldown(spellID)
	local startTime, duration, isEnabled = GetSpellCooldownInfo(spellID)
	return isEnabled ~= 0 and isEnabled ~= false and startTime > 0 and duration > 1.5
end

local function InitButton(button)
	button:SetAllPoints()

	local parent = button:GetParent()
	if parent then
		button:SetFrameLevel(parent:GetFrameLevel() + 1)
	end

	button:RegisterForClicks("AnyDown", "AnyUp")

	local castBar = CreateFrame("StatusBar", nil, button)
	castBar:SetStatusBarTexture(CASTBAR)
	castBar:SetMinMaxValues(0, 1)
	castBar:SetValue(0)
	castBar:SetStatusBarColor(CASTBAR_COLOR[1], CASTBAR_COLOR[2], CASTBAR_COLOR[3])
	castBar:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 2)
	castBar:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
	castBar:SetHeight(10)
	castBar:Hide()

	local castBarBg = castBar:CreateTexture(nil, "BACKGROUND")
	castBarBg:SetAllPoints()
	castBarBg:SetColorTexture(0, 0, 0, 0.65)

	local castBarSpellTex = castBar:CreateTexture(nil, "ARTWORK")
	castBarSpellTex:SetAllPoints()
	castBarSpellTex:SetAlpha(0.3)
	castBarSpellTex:Hide()

	local castBarSpark = castBar:CreateTexture(nil, "OVERLAY")
	castBarSpark:SetTexture(CASTBAR_SPARK)
	castBarSpark:SetBlendMode("ADD")
	castBarSpark:SetSize(30, 30)
	castBarSpark:Hide()

	button.castBarSpellTex = castBarSpellTex
	button.castBarSpark = castBarSpark
	button.castBar = castBar

	local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	cooldown:SetAllPoints()
	cooldown:SetFrameLevel(button:GetFrameLevel() + 3)
	cooldown:SetDrawSwipe(true)
	cooldown:SetDrawBling(false)
	cooldown:SetDrawEdge(false)
	cooldown:SetSwipeColor(0, 0, 0, 0.75)
	cooldown:SetHideCountdownNumbers(true)
	cooldown:Hide()
	button.cooldown = cooldown

	local highlight = button:CreateTexture(nil, "OVERLAY")
	highlight:SetTexture("Interface\\EncounterJournal\\UI-EncounterJournalTextures")
	highlight:SetTexCoord(0.34570313, 0.68554688, 0.33300781, 0.42675781)
	highlight:SetAllPoints()
	highlight:SetAlpha(BORDER_ALPHA)
	highlight:Hide()
	button.highlight = highlight

	button:SetScript("OnEnter", function(self)
		local p = self:GetParent()
		if p and p:GetScript("OnEnter") then
			p:GetScript("OnEnter")(p)
		end

		if self.spellID then
			self.highlight:SetAlpha(BORDER_HOVER)

			if GameTooltip:GetOwner() == p then
				GameTooltip:AddLine(" ")
				if self.hasSpell then
					local teleportText = TOOLTIP_PORT
					if IsSpellOnCooldown(self.spellID) then
						teleportText = TOOLTIP_PORT_COOLDOWN
					end
					GameTooltip:AddLine(teleportText)
				end
				GameTooltip:AddLine(TOOLTIP_LFG)
				GameTooltip:Show()
			end
		end
	end)

	button:SetScript("OnLeave", function(self)
		local p = self:GetParent()
		if p and p:GetScript("OnLeave") then
			p:GetScript("OnLeave")(p)
		end
		GameTooltip:Hide()
		if self.spellID then self.highlight:SetAlpha(BORDER_ALPHA) end
	end)
end

local function GetSpellCooldownInfo(spellID)
	if not spellID then return 0, 0, 0, 1 end

	local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
	if type(cooldownInfo) == "table" then
		return cooldownInfo.startTime or 0, cooldownInfo.duration or 0, cooldownInfo.isEnabled or 0, cooldownInfo.modRate or 1
	end

	local spellName = C_Spell.GetSpellName(spellID)
	if spellName then
		local cooldownByName = C_Spell.GetSpellCooldown(spellName)
		if type(cooldownByName) == "table" then
			return cooldownByName.startTime or 0, cooldownByName.duration or 0, cooldownByName.isEnabled or 0, cooldownByName.modRate or 1
		end

		local startLegacyByName, durationLegacyByName, enabledLegacyByName, modRateLegacyByName = GetSpellCooldown(spellName)
		if startLegacyByName and durationLegacyByName then
			return startLegacyByName or 0, durationLegacyByName or 0, enabledLegacyByName or 0, modRateLegacyByName or 1
		end
	end

	local startTime, duration, isEnabled, modRate = C_Spell.GetSpellCooldown(spellID)
	if startTime and duration then
		return startTime or 0, duration or 0, isEnabled or 0, modRate or 1
	end

	local startLegacy, durationLegacy, enabledLegacy, modRateLegacy = GetSpellCooldown(spellID)
	return startLegacy or 0, durationLegacy or 0, enabledLegacy or 0, modRateLegacy or 1
end

local function IsDungeonTeleportSpell(spellID)
	if not spellID then return false end
	for _, data in pairs(DUNGEON_DATA) do
		if data and data[1] == spellID then
			return true
		end
	end
	return false
end

local function ClearButtonCooldown(button)
	if not button or not button.cooldown then return end
	button.cooldown:SetCooldown(0, 0)
end

local function UpdateButtonCooldown(button)
	if not button or not button.cooldown then return end

	if not button.spellID or not button.hasSpell then
		ClearButtonCooldown(button)
		button.cooldown:Hide()
		return
	end

	local startTime, duration, isEnabled, modRate = GetSpellCooldownInfo(button.spellID)
	if isEnabled == 0 or isEnabled == false or startTime <= 0 or duration <= 1.5 then
		ClearButtonCooldown(button)
		button.cooldown:Hide()
		return
	end

	button.cooldown:SetCooldown(startTime, duration, modRate)
	button.cooldown:Show()
end

local function GetPlayerCastState()
	local _, _, _, startTimeMS, endTimeMS, _, _, _, spellID = UnitCastingInfo("player")
	local isChannel = false

	if not spellID then
		_, _, _, startTimeMS, endTimeMS, _, _, spellID = UnitChannelInfo("player")
		isChannel = spellID ~= nil
	end

	if not spellID or not startTimeMS or not endTimeMS then return nil end

	local nowMS = GetTime() * 1000
	local duration = math.max(endTimeMS - startTimeMS, 1)
	local progress

	if isChannel then
		progress = (endTimeMS - nowMS) / duration
	else
		progress = (nowMS - startTimeMS) / duration
	end

	progress = math.max(0, math.min(1, progress))

	return spellID, progress
end

local function UpdateButtonCastBar(button)
	if not button or not button.castBar then return end

	if activeCastSpellID and castProgress and button.spellID == activeCastSpellID then
		button.castBar:SetValue(castProgress)

		if button.castBarSpark then
			button.castBarSpark:ClearAllPoints()
			button.castBarSpark:SetPoint("CENTER", button.castBar, "LEFT", button.castBar:GetWidth() * castProgress, 0)
			button.castBarSpark:Show()
		end

		button.castBar:Show()
	else
		if button.castBarSpark then
			button.castBarSpark:Hide()
		end
		button.castBar:Hide()
	end
end

local function UpdateAllCastBars()
	if not ChallengesFrame or not ChallengesFrame.DungeonIcons then return end
	for _, icon in ipairs(ChallengesFrame.DungeonIcons) do
		local button = icon.__mythicClickButton
		if button then
			UpdateButtonCastBar(button)
		end
	end
end

local function UpdateAllCooldowns()
	if not ChallengesFrame or not ChallengesFrame.DungeonIcons then return end
	for _, icon in ipairs(ChallengesFrame.DungeonIcons) do
		local button = icon.__mythicClickButton
		if button then
			UpdateButtonCooldown(button)
		end
	end
end

local function RefreshCastState()
	local spellID, progress = GetPlayerCastState()
	activeCastSpellID = spellID
	castProgress = progress

	if spellID and ChallengesFrame and ChallengesFrame:IsShown() then
		if not castingUpdateActive then
			castingUpdateActive = true
			frame:SetScript("OnUpdate", function(_, elapsed)
				castUpdateElapsed = castUpdateElapsed + elapsed
				if castUpdateElapsed < 0.05 then return end
				castUpdateElapsed = 0
				RefreshCastState()
			end)
		end
	elseif castingUpdateActive then
		castingUpdateActive = false
		frame:SetScript("OnUpdate", nil)
	end

	UpdateAllCastBars()
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
	if button.castBarSpellTex then
		if spellID then
			local spellTexture = C_Spell.GetSpellTexture(spellID)
			if spellTexture then
				button.castBarSpellTex:SetTexture(spellTexture)
				button.castBarSpellTex:Show()
			else
				button.castBarSpellTex:Hide()
			end
		else
			button.castBarSpellTex:Hide()
		end
	end
	local hasSpell = spellID and IsSpellKnown(spellID)
	button.hasSpell = hasSpell

	if hasSpell then
		local spellName = C_Spell.GetSpellName(spellID)
		button:SetAttribute("type1", "spell")
		button:SetAttribute("spell1", spellName)
		button.highlight:SetAlpha(BORDER_ALPHA)
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

	UpdateButtonCastBar(button)
	UpdateButtonCooldown(button)
end

local function OnChallengesFrameUpdate()
	if not ChallengesFrame or not ChallengesFrame.DungeonIcons then return end
	RefreshCastState()
	for _, icon in ipairs(ChallengesFrame.DungeonIcons) do
		ProcessIcon(icon)
	end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("SPELLS_CHANGED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
frame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
frame:RegisterEvent("UNIT_SPELLCAST_START")
frame:RegisterEvent("UNIT_SPELLCAST_STOP")
frame:RegisterEvent("UNIT_SPELLCAST_FAILED")
frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
frame:RegisterEvent("UNIT_SPELLCAST_DELAYED")
frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		local name = ...
		if name ~= addonName and name ~= "Blizzard_ChallengesUI" then return end
		if ChallengesFrame and not hooked then
			hooked = true
			hooksecurefunc(ChallengesFrame, "Update", OnChallengesFrameUpdate)
			OnChallengesFrameUpdate()
		end
	elseif event == "SPELLS_CHANGED" or event == "PLAYER_REGEN_ENABLED" then
		if not InCombatLockdown() then OnChallengesFrameUpdate() end
	elseif event == "SPELL_UPDATE_COOLDOWN" or event == "ACTIONBAR_UPDATE_COOLDOWN" then
		UpdateAllCooldowns()
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		local playerUnit, _, spellID = ...
		if playerUnit == "player" and IsDungeonTeleportSpell(spellID) then
			UpdateAllCooldowns()
		end
	elseif string.match(event, "^UNIT_SPELLCAST") then
		local playerUnit = ...
		if playerUnit == "player" then
			RefreshCastState()
		end
	end
end)
