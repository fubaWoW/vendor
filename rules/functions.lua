local Addon, L = _G[select(1,...).."_GET"]()
Addon.RuleFunctions = {}
Addon.RuleFunctions.CURRENT_EXPANSION = LE_EXPANSION_BATTLE_FOR_AZEROTH;
Addon.RuleFunctions.BATTLE_FOR_AZEROTH = LE_EXPANSION_BATTLE_FOR_AZEROTH;
Addon.RuleFunctions.POOR = LE_ITEM_QUALITY_POOR;
Addon.RuleFunctions.COMMON = LE_ITEM_QUALITY_COMMON;
Addon.RuleFunctions.UNCOMMON = LE_ITEM_QUALITY_UNCOMMON;
Addon.RuleFunctions.RARE = LE_ITEM_QUALITY_RARE;
Addon.RuleFunctions.EPIC = LE_ITEM_QUALITY_EPIC;
Addon.RuleFunctions.LEGENDARY = LE_ITEM_QUALITY_LEGENDARY;
Addon.RuleFunctions.ARTIFACT = LE_ITEM_QUALITY_ARTIFACT;
Addon.RuleFunctions.HEIRLOOM = LE_ITEM_QUALITY_HEIRLOOM;
Addon.RuleFunctions.TOKEN = LE_ITEM_QUALITY_TOKEN;

--*****************************************************************************
-- Helper function which given a value, will search the map for the value
-- and return  the value contained in the map.
--*****************************************************************************
local function getValueFromMap(map, value)
    if (type(map) ~= "table") then
        return nil;
    end
    
    local mapValue = value;
    if (type(mapValue) == "string") then
            mapValue = string.lower(mapValue);
    end

    return map[mapValue];
end

--*****************************************************************************
-- Given a set of values this searches for them in the map to see if they map
-- the expected value which is passed in.
--*****************************************************************************
local function checkMap(map, expectedValue, values)
    for i=1,table.getn(values) do
        local value = values[i]
        if (type(value) == "number") then
            if (value == expectedValue) then
                return true
            end
        elseif (type(value) == "string") then
            local mapVal = map[string.lower(value)]
            if (mapVal and (type(mapVal)  == "number") and (mapVal == expectedValue)) then
                return true
            end
        end
    end
    return false
end

--*****************************************************************************
-- Matches the item quality (or item qualities) this accepts multiple arguments
-- which can be either strings or numbers.
--*****************************************************************************
function Addon.RuleFunctions.ItemQuality(...)
    return checkMap(Addon.Maps.Quality, Quality, {...})
end

--*****************************************************************************
-- Rule function which match the item type against the list of arguments
-- which can either be numeric or strings which are mapped with the table
-- above.
--*****************************************************************************
function Addon.RuleFunctions.ItemType(...)
    return checkMap(Addon.Maps.ItemType, TypeId, {...})
end

--*****************************************************************************
-- Rule function which matches of the item is from a particular expansion
-- these can either be numeric or you can use a value from the table above
-- NOTE: If the expansion pack id is zero, it can belong to any or none,
--       this will always evaluate to false.
--*****************************************************************************
function Addon.RuleFunctions.IsFromExpansion(...)
    local xpackId = ExpansionPackId;
    if (xpackId ~= 0) then
        return checkMap(Addon.Maps.Expansion, xpackId, {...})
    end
end

--*****************************************************************************
-- Rule function which checks if the specified item is present in the
-- list of items which should never be sold.
--*****************************************************************************
function Addon.RuleFunctions.IsNeverSellItem()
    if Addon:IsItemIdInNeverSellList(Id) then
        return true
    end
end

--*****************************************************************************
-- Rule function which chceks if the item is in the list of items which
-- should always be sold.
--*****************************************************************************
function Addon.RuleFunctions.IsAlwaysSellItem()
    if Addon:IsItemIdInAlwaysSellList(Id) then
        return true
    end
end

--*****************************************************************************
-- Rule function which returns the level of the player.
--*****************************************************************************
function Addon.RuleFunctions.PlayerLevel()
    return tonumber(UnitLevel("player"))
end

--*****************************************************************************
-- Rule function which returns the localized class of the player.
--*****************************************************************************
function Addon.RuleFunctions.PlayerClass()
    local localizedClassName = UnitClass("player")
    return localizedClassName --This is intentional to avoid passing back extra args
end

--[[============================================================================
    | Rule function which returns the average item level of the players 
	| equipped gear, in classic this just sums all your equipped items and 
	| divides it by the number of item of equipped.
    ==========================================================================]]
function Addon.RuleFunctions.PlayerItemLevel()
	if (not Addon.IsClassic) then
		local _, itemLevel, _ = GetAvergeItemLevel();
		return itemLevel;
	end

	-- What should we do here?
	return 400;
end

--*****************************************************************************
-- This function checks if the specified item is a member of an item set.
--*****************************************************************************
function Addon.RuleFunctions.IsInEquipmentSet(...)
    -- Checks the item set for the specified item
    local function check(itemId, setId)
        itemIds = C_EquipmentSet.GetItemIDs(setId);
        for _, setItemId in pairs(itemIds) do
            if ((setItemId ~= -1) and (setItemId == itemId)) then
                return true
            end
        end
    end

    local sets = { ... };
    local itemId = Id;
    if (#sets == 0) then
        -- No sets provied, so enumerate and check all of the characters item sets
        local itemSets = C_EquipmentSet.GetEquipmentSetIDs();
        for _, setId in pairs(itemSets) do
            if (check(itemId, setId)) then
                return true;
            end
        end
    else
        -- Check against the specific item set/sets provided.
        for _, set in ipairs(sets) do
            local setId = C_EquipmentSet.GetEquipmentSetID(set)
            if (setId and check(itemId, setId)) then
                return true
            end
        end
    end
end

--@do-not-package@
--*****************************************************************************
-- Debug only functions for testing functions in extensions
--*****************************************************************************
function Addon.RuleFunctions.tostring(...)
    return tostring(...)
end

function Addon.RuleFunctions.print(...)
    return Addon:DebugRules(...)
end
--@end-do-not-package@

--*****************************************************************************
-- This function allows testing the tooltip text for string values
--*****************************************************************************
function Addon.RuleFunctions.TooltipContains(...)
    local str, side, line = ...
    assert(str and type(str) == "string", "Text must be specified.")
    assert(not side or (side == "left" or side == "right"), "Side must be 'left' or 'right' if present.")
    assert(not line or type(line) == "number", "Line must be a number if present.")

    local function checkSide(textSide, textTable)
        if not side or side == textSide then
            for lineNumber, text in ipairs(textTable) do
                if not line or line == lineNumber then
                    if text and string.find(text, str) then
                        return true
                    end
                end
            end
        end
    end

    return checkSide("left", OBJECT.TooltipLeft) or checkSide("right", OBJECT.TooltipRight)
end

--*****************************************************************************
-- Checks if the item contains a particular stat.
--*****************************************************************************
function Addon.RuleFunctions.HasStat(...)
    local stats = {...};
    local itemStats = {};

    -- build a table of the stats this item has
    for st, sv in pairs(GetItemStats(Link)) do
        if (sv ~= 0) then
            itemStats[_G[st]] = true;
        end
    end

    if (not itemStats or not table.getn(itemStats)) then
        return false;
    end
    
    local n = table.getn(stats);
    for _, iStat in ipairs({...}) do
        local stat = getValueFromMap(Addon.Maps.Stats, iStat)
        if (stat and 
            (type(stat) == "string") and 
            string.len(stat) and 
            itemStats[stat]) then
            return true;
        end
    end

    return false;
end