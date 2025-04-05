
local Details = Details
local detailsFramework = DetailsFramework
local _

local CONST_MAX_LOGLINES = 100

---@type string, private
local tocFileName, private = ...

--localization
local L = detailsFramework.Language.GetLanguageTable(tocFileName)

---@type profile
local defaultSettings = {
    when_to_automatically_open_scoreboard = "LOOT_CLOSED",
    delay_to_open_mythic_plus_breakdown_big_frame = 3,
    show_column_summary_in_tooltip = true,
    show_remaining_timeline_after_finish = true,
    show_time_sections = true,
    saved_runs = {},
    saved_runs_limit = 10,
    saved_runs_selected_index = 1,
    scoreboard_scale = 1.0,
    translit = GetLocale() ~= "ruRU",
    keep_information_for_debugging = false,
    migrations_done = {},
    logs = {},
    font = {
        row_size = 12,

        regular_color = "white",
        regular_outline = "NONE",

        hover_color = "orange",
        hover_outline = "NONE",

        standout_color = {230/255, 204/255, 128/255},
        standout_outline = "NONE",
    },
    logout_logs = {},
    last_run_data = {},
}

private.addon = detailsFramework:CreateNewAddOn(tocFileName, "Details_MythicPlusDB", defaultSettings)
local addon = private.addon

addon.activityTimeline = {}

function addon.OnLoad(self, profile) --ADDON_LOADED
    --added has been loaded
end

function addon.GetVersionString()
    return C_AddOns.GetAddOnMetadata("Details_MythicPlus", "Version")
end

function addon.GetFullVersionString()
    return Details.GetVersionString() .. " | " .. addon.GetVersionString()
end

function addon.OnInit(self, profile) --PLAYER_LOGIN
    --logout logs register what happened to the addon when the player logged out
    if (not profile.logout_logs) then
        profile.logout_logs = {}
    end
    self:SetLogoutLogTable(profile.logout_logs)

    addon.data = {}

    local detailsEventListener = Details:CreateEventListener()
    addon.detailsEventListener = detailsEventListener

    function private.log(...)
        local str = ""
        for i = 1, select("#", ...) do
            str = str .. tostring(select(i, ...)) .. " "
        end

        --insert year month day and hour min sec into str
        local date = date("%Y-%m-%d %H:%M:%S")
        str = date .. "| " .. str

        table.insert(profile.logs, 1, str)

        --limit to 50 entries, removing the oldest
        table.remove(profile.logs, CONST_MAX_LOGLINES+1)
    end

    --register details! events
    detailsEventListener:RegisterEvent("COMBAT_MYTHICDUNGEON_START")
    detailsEventListener:RegisterEvent("COMBAT_MYTHICDUNGEON_END")
    detailsEventListener:RegisterEvent("COMBAT_MYTHICPLUS_OVERALL_READY")
    detailsEventListener:RegisterEvent("COMBAT_ENCOUNTER_START")
    detailsEventListener:RegisterEvent("COMBAT_ENCOUNTER_END")
    detailsEventListener:RegisterEvent("COMBAT_PLAYER_ENTER")
    detailsEventListener:RegisterEvent("COMBAT_PLAYER_LEAVE")

    --initialize enums
    addon.Enum = {
        --used to identify the type of run
        CombatType = {
            RunRime = 1,
            CombatTime = 2,
        },
        --used to identify the type of event
        ScoreboardEventType = {
            EncounterStart = "EncounterStart",
            EncounterEnd = "EncounterEnd",
            Death = "Death",
            KeyFinished = "KeyFinished",
        },
    }

    addon.InitializeEvents()

    AddonCompartmentFrame:RegisterAddon({
        text = L["ADDON_MENU_ADDONS_TITLE"],
        icon = "4352494",
        notCheckable = true,
        func = Details.OpenMythicPlusBreakdownBigFrame,
        funcOnEnter = function(button)
            MenuUtil.ShowTooltip(button, function(tooltip)
                tooltip:SetText(L["ADDON_MENU_ADDONS_TOOLTIP"])
            end)
        end,
        funcOnLeave = function(button)
            MenuUtil.HideTooltip(button)
        end,
    })

    -- always show the last run first
    addon.profile.saved_runs_selected_index = 1

    -- try to yeet broken saves and shrink history if the setting is lowered
    local newRuns = {}
    local corruptRuns = 0
    local removedRuns = 0
    for i = 1, #addon.profile.saved_runs do
        local run = addon.profile.saved_runs[i]
        local newRunCount = #newRuns
        if (newRunCount >= addon.profile.saved_runs_limit) then
            removedRuns = removedRuns + 1
        elseif (not run or not run.completionInfo or run.completionInfo.mapChallengeModeID == 0) then
            corruptRuns = corruptRuns + 1
        else
            newRuns[newRunCount + 1] = run
        end
    end

    if (corruptRuns > 0) then
        print("Details! Mythic+: " .. string.format(L["ADDON_STARTUP_REMOVED_CORRUPT_HISTORY"], corruptRuns))
    end

    if (removedRuns > 0) then
        print("Details! Mythic+: " .. string.format(L["ADDON_STARTUP_REMOVED_TOO_MANY_HISTORY"], removedRuns))
    end

    addon.profile.saved_runs = newRuns

    -- ensure people don't break the scale
    addon.profile.scoreboard_scale = math.max(0.6, math.min(1.6, addon.profile.scoreboard_scale))

    -- required to create early due to the frame events
    local scoreboard = addon.CreateBigBreakdownFrame()
    scoreboard:SetScale(addon.profile.scoreboard_scale)

    -- run migrations
    for i, migration in pairs(addon.Migrations) do
        if (not addon.profile.migrations_done[i]) then
            migration()
            addon.profile.migrations_done[i] = time()
        end
    end

    private.log("addon loaded")
end


function addon.ShowLogs()
    --dumpt is a function from details!
    dumpt(addon.profile.logs)
end
