-- MythicQuickAction
-- Left click: teleport to dungeon
-- Right click: open LFG filtered to this dungeon

local addonName, addon = ...

local DUNGEON_TELEPORTS = {
    -- Dragonflight
    [399] = 393256,  -- Ruby Life Pools
    [400] = 393262,  -- The Nokhud Offensive
    [401] = 393279,  -- The Azure Vault
    [402] = 393273,  -- Algeth'ar Academy
    [403] = 393222,  -- Uldaman: Legacy of Tyr
    [404] = 393276,  -- Neltharus
    [405] = 393267,  -- Brackenhide Hollow
    [406] = 393283,  -- Halls of Infusion
    -- The War Within Season 1
    [499] = 445444,  -- Priory of the Sacred Flame
    [500] = 445443,  -- The Rookery
    [501] = 445269,  -- The Stonevault
    [502] = 445416,  -- City of Threads
    [503] = 445417,  -- Ara-Kara, City of Echoes
    [504] = 445441,  -- Darkflame Cleft
    [505] = 445414,  -- The Dawnbreaker
    [506] = 445440,  -- Cinderbrew Meadery
    [507] = 445424,  -- Grim Batol
    [525] = 1216786, -- Operation: Floodgate
    -- Midnight Season 1
    [542] = 1237215, -- Eco-Dome Al'dani
    [556] = 1254555, -- Pit of Saron
    [557] = 1254400, -- Windrunner Spire
    [558] = 1254572, -- Magisters' Terrace
    [559] = 1254563, -- Nexus-Point Xenas
    [560] = 1254559, -- Maisara Caverns
    [161] = 1254557, -- Skyreach
    [239] = 1254551, -- Seat of the Triumvirate
}

local function IsSpellKnownAndReady(spellID)
    if not spellID or spellID == 0 then return false end
    return C_SpellBook.IsSpellInSpellBook(spellID, Enum.SpellBookSpellBank.Player, false)
end

-- Pending LFG search, fired from a clean frame via OnUpdate to fully escape taint
local pendingLFG = nil
local lfgRunner = CreateFrame("Frame")
lfgRunner:SetScript("OnUpdate", function(self)
    if not pendingLFG then return end
    local mapName = pendingLFG
    pendingLFG = nil

    if not PVEFrame or not PVEFrame:IsShown() then
        PVEFrame_ShowFrame("GroupFinderFrame")
    end
    -- Walk the LFG frame children to find the search box
    if LFGListFrame then
        local panel = LFGListFrame.SearchPanel or LFGListFrame.searchPanel
        if panel then
            local box = panel.SearchBox or panel.searchBox
            if box then
                box:SetText(mapName)
                box:SetFocus()
            end
        end
    end
    print("|cffffff00MythicQuickAction:|r LFG: " .. mapName)
end)

local function OpenLFGForDungeon(mapID)
    local mapName = C_ChallengeMode.GetMapUIInfo and C_ChallengeMode.GetMapUIInfo(mapID) or ""
    pendingLFG = mapName
end

local frameSetAttribute = GetFrameMetatable().__index.SetAttribute

local function ProcessIcon(icon)
    if icon.__mqaHooked then return end
    icon.__mqaHooked = true

    local mapID = icon.mapID
    local spellID = DUNGEON_TELEPORTS[mapID]

    local button = CreateFrame("Button", nil, icon, "InsecureActionButtonTemplate")
    button:SetAllPoints()
    button:SetFrameLevel(999)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    frameSetAttribute(button, "type", "spell")
    frameSetAttribute(button, "spell", spellID)

    -- Right click: set pending LFG (just stores a string, no protected calls)
    -- Left click: spell fires via InsecureActionButtonTemplate
    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            OpenLFGForDungeon(mapID)
        end
    end)

    local highlight = button:CreateTexture(nil, "OVERLAY")
    highlight:SetTexture("Interface\\EncounterJournal\\UI-EncounterJournalTextures")
    highlight:SetTexCoord(0.34570313, 0.68554688, 0.33300781, 0.42675781)
    highlight:SetAllPoints()
    button.highlight = highlight

    local function UpdateHighlight()
        highlight:SetShown(spellID ~= nil and IsSpellKnownAndReady(spellID))
    end
    UpdateHighlight()
    button.UpdateHighlight = UpdateHighlight
    icon.__mqaButton = button
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
        if icon.__mqaButton then icon.__mqaButton.UpdateHighlight() end
    end
end

local challengesHooked = false
local function SetupChallengesHook()
    if not ChallengesFrame or challengesHooked then return end
    challengesHooked = true
    hooksecurefunc(ChallengesFrame, "Update", OnChallengesFrameUpdate)
    OnChallengesFrameUpdate()
end

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

print("|cffffff00MythicQuickAction|r loaded. Left click = teleport, Right click = LFG.")