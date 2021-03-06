-- -----------------------------------------------------------------------------
-- Earthgore Cooldown
-- Author:  g4rr3t
-- Created: May 5, 2018
--
-- Tracking.lua
-- -----------------------------------------------------------------------------

EGC.Tracking = {}

local updateIntervalMs = 100

-- ACTION_RESULT_POWER_ENERGIZE = 128
-- ACTION_RESULT_HEAL = 16
-- ACTION_RESULT_EFFECT_GAINED = 2240
-- ACTION_RESULT_EFFECT_GAINED_DURATION = 2245

EGC.Tracking.Sets = {
    Trappings = {
        name = "Trappings of Invigoration",
        id = 101970,
        enabled = false,
        result = ACTION_RESULT_POWER_ENERGIZE,
        cooldownDurationMs = 60000,
        onCooldown = false,
        timeOfProc = 0,
        context = nil,
        texture = "/esoui/art/champion/champion_points_stamina_icon-hud.dds",
    },
    Lich = {
        name = "Shroud of the Lich",
        id = 57164,
        enabled = false,
        result = ACTION_RESULT_EFFECT_GAINED,
        cooldownDurationMs = 60000,
        onCooldown = false,
        timeOfProc = 0,
        context = nil,
        texture = "/esoui/art/champion/champion_points_magicka_icon-hud.dds",
    },
    Earthgore = {
        name = "Earthgore",
        id = 97855,
        enabled = false,
        result = ACTION_RESULT_EFFECT_GAINED,
        cooldownDurationMs = 35000,
        onCooldown = false,
        timeOfProc = 0,
        context = nil,
        texture = "/esoui/art/icons/gear_undaunted_ironatronach_head_a.dds",
    },
    Olorime = {
        name = "Vestment of Olorime",
        id = 107141,
        enabled = false,
        result = ACTION_RESULT_EFFECT_GAINED,
        cooldownDurationMs = 10000,
        onCooldown = false,
        timeOfProc = 0,
        context = nil,
        texture = "/esoui/art/icons/placeholder/icon_health_major.dds",
    },
}

EGC.Tracking.ITEM_SLOTS = {
    EQUIP_SLOT_HEAD,
    EQUIP_SLOT_NECK,
    EQUIP_SLOT_CHEST,
    EQUIP_SLOT_SHOULDERS,
    EQUIP_SLOT_MAIN_HAND,
    EQUIP_SLOT_OFF_HAND,
    EQUIP_SLOT_WAIST,
    EQUIP_SLOT_LEGS,
    EQUIP_SLOT_FEET,
    EQUIP_SLOT_RING1,
    EQUIP_SLOT_RING2,
    EQUIP_SLOT_HAND,
    EQUIP_SLOT_BACKUP_MAIN,
    EQUIP_SLOT_BACKUP_OFF,
}

EGC.Tracking.ITEM_SLOT_NAMES = {
    "Head",
    "Neck",
    "Chest",
    "Shoulders",
    "Main-Hand Weapon",
    "Off-Hand Weapon",
    "Waist",
    "Legs",
    "Feet",
    "Ring 1",
    "Ring 2",
    "Hands",
    "Backup Main-Hand Weapon",
    "Backup Off-Hand Weapon",
}

function EGC.Tracking.DidEventCombatEvent(setKey, _, result, _, abilityName, _, _, _, _, _, _, _, _, _, _, _, _, abilityId)

    local set = EGC.Tracking.Sets[setKey]

    if result == ACTION_RESULT_ABILITY_ON_COOLDOWN then
        EGC:Trace(1, zo_strformat("<<1>> (<<2>>) on Cooldown", abilityName, abilityId))
    elseif result == set.result then
        EGC:Trace(1, zo_strformat("Name: <<1>> ID: <<2>> with result <<3>>", abilityName, abilityId, result))
        set.onCooldown = true
        set.timeOfProc = GetGameTimeMilliseconds()
        -- TODO: Get sound from preferences
        PlaySound(SOUNDS.TELVAR_LOST)
        EVENT_MANAGER:RegisterForUpdate(EGC.name .. setKey .. "Count", updateIntervalMs, function(...) EGC.UI.Update(setKey) return end)
    else
        EGC:Trace(1, zo_strformat("Name: <<1>> ID: <<2>> with result <<3>>", abilityName, abilityId, result))
    end

end

function EGC.Tracking.RegisterWornSlotUpdate()
    CALLBACK_MANAGER:RegisterCallback("WornSlotUpdate", EGC.Tracking.WornSlotUpdate)
    EGC:Trace(2, "Registering Worn Slot Update")
end

function EGC.Tracking.WornSlotUpdate(slotControl)
    -- Ignore costume updates
    if slotControl.slotIndex == EQUIP_SLOT_COSTUME then return end

    -- Provide changed slot to check function
    EGC.Tracking.CheckEquippedSet()
end

function EGC.Tracking.CheckEquippedSet()

    -- Check every slot for sets
    for index, slot in pairs(EGC.Tracking.ITEM_SLOTS) do
        local itemLink = GetItemLink(BAG_WORN, slot)
        local slotName = EGC.Tracking.ITEM_SLOT_NAMES[index]

        -- If slot is empty
        if itemLink == "" then
            EGC:Trace(2, zo_strformat("<<1>>: Not Equipped", slotName))

        -- Non-empty slot
        else
            local hasSet, setName, numBonuses, numEquipped, maxEquipped = GetItemLinkSetInfo(itemLink, true)

            -- Set item equipped
            if hasSet then
                EGC:Trace(2, zo_strformat("<<1>>: <<2>> (<<3>> of <<4>>)", slotName, setName, numEquipped, maxEquipped))

                -- Check if we should enable tracking
                EGC.Tracking.EnableTrackingForSet(setName, numEquipped, maxEquipped)

            -- Not a set item, ignore
            else
                EGC:Trace(2, zo_strformat("<<1>>: No Set", slotName))
            end
        end

    end

end

function EGC.Tracking.EnableTrackingForSet(setName, numEquipped, maxEquipped)

    -- Compared equipped sets to sets we should track
    for key, set in pairs(EGC.Tracking.Sets) do

        -- If a set we should track
        if setName == set.name then

            -- Full bonus active
            if numEquipped == maxEquipped then
                EGC:Trace(1, zo_strformat("Full set for: <<1>>, registering events", setName))
                EVENT_MANAGER:RegisterForEvent(EGC.name .. "_" .. set.id, EVENT_COMBAT_EVENT, function(...) EGC.Tracking.DidEventCombatEvent(key, ...) end)
                EVENT_MANAGER:AddFilterForEvent(EGC.name .. "_" .. set.id, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, set.id)
                EVENT_MANAGER:AddFilterForEvent(EGC.name .. "_" .. set.id, EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
                set.enabled = true
                EGC.UI.Draw(key)

            -- Full bonus not active
            else
                EGC:Trace(1, zo_strformat("Not active for: <<1>>, unregistering events", setName))
                EVENT_MANAGER:UnregisterForEvent(EGC.name .. "_" .. set.id, EVENT_COMBAT_EVENT)
                set.enabled = false
                EGC.UI.Draw(key)
            end

        end
    end

end




