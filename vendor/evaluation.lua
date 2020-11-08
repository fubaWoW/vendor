-- Item cache used to store results of scans and track item state for efficient retrieval. This is for bags only, not tooltips.
local AddonName, Addon = ...
local L = Addon:GetLocale()

-- This is a wrapper for Evaluate Item that takes GetItemProperties parameters as input.
-- This is for use cases where you do not need the item itself and just want to know
-- the result. This is also the public api implementaion.
function Addon:EvaluateSource(arg1, arg2)
    return Addon:EvaluateItem(Addon:GetItemProperties(arg1, arg2))
end

-- Evaluating items.
-- This is only used for the 'real' rules evaluation, not rules evaluation in the rules editor.
-- Rules for determining if an item should be sold.
-- Retval meanings:
-- 0 = No action
-- 1 = Item will be sold
-- 2 = Item will be deleted
-- Both 1 and 2 will evaluate to True, so you can still use this function as a boolean.
-- The itemCount is returned separately since it depends on the source and is not used
-- for rule evaluations.
-- This method always returns a number as the first parameter, but the others may be nil.
function Addon:EvaluateItem(item)

    -- Check some cases where we know we should never ever sell the item
    if not item then
        return 0, nil, nil
    end

    -- See if this item is already in the cache.
    local retval, ruleid, rule, ruletype = Addon:GetCachedResult(item.GUID)
    if retval and type(retval) == "number" then
        self:Debug("items", "Retrieved %s from cache with result: %d - [%s] %s", item.Link, retval, tostring(ruletype), tostring(rule))
        return retval, ruleid, rule, ruletype
    end

    if (not self.ruleManager) then
        self.ruleManager = Addon.RuleManager:Create();
    end
    local result = nil
    result, ruleid, rule, ruletype = self.ruleManager:Run(item)
    retval = 0
    if result then
        if Addon.RuleType.SELL == ruletype then
            -- Only items explicitly in the always sell list are considered for deletion if unsellable.
            if item.IsUnsellable then
                if Addon:GetList(Addon.c_AlwaysSellList):Contains(item.Id) then
                    retval = 2
                else
                    -- If it's to be sold but is unsellable and not in the Always Sell List, then
                    -- we ignore it completely.
                    ruleid = nil
                    rule = nil
                    ruletype = nil
                    retval = 0
                end
            else
                retval = 1
            end
        elseif Addon.RuleType.DELETE == ruletype then
            retval = 2
        elseif Addon.RuleType.KEEP == ruletype then
            retval = 0
        else
            error("Unknown ruletype: "..tostring(ruletype))
        end
    end

    -- Add item to cache
    self:Debug("items", "Adding %s to cache with result: %d - [%s] %s", item.Link, retval, tostring(ruletype), tostring(rule))
    Addon:AddResultToCache(item.GUID, retval, ruleid, rule, ruletype)
    
    return retval, ruleid, rule, ruletype
end

-- Results are cached by guid.
local resultCache = {}
function Addon:GetCachedResult(guid)
    assert(guid)
    result = resultCache[guid]
    if result then
        return result.Result, result.RuleId, result.Rule, result.RuleType
    else
        return nil, nil, nil, nil
    end
end

function Addon:ClearResultCache(arg)
    if not arg then
        resultCache = {}
        self:Debug("items", "Result Cache cleared.")
    else
        resultCache[arg] = nil
    end
    self:ClearTooltipResultCache()
end

Addon.Profile:RegisterForChanges(function() Addon:ClearResultCache() end, 10)

function Addon:AddResultToCache(guid, result, ruleid, rule, ruletype)
    assert(type(guid) == "string" and type(result) == "number")

    local cacheEntry = {}
    cacheEntry.Result = result
    cacheEntry.RuleId = ruleid
    cacheEntry.Rule = rule
    cacheEntry.RuleType = ruletype

    assert(guid ~= "")
    self:Debug("items", "Cached result: %s = %s", guid, tostring(result))
    resultCache[guid] = cacheEntry
end

function Addon:GetEvaluationStatus()
    local count = 0
    local value = 0
    local tosell = 0
    local todelete = 0
    for bag=0, NUM_BAG_SLOTS do
        for slot=1, GetContainerNumSlots(bag) do
            local item, itemCount = Addon:GetItemPropertiesFromBag(bag, slot)
            result = Addon:EvaluateItem(item)
            
            if result > 0 then
                count = count + 1
            end

            if result == 1 then
                value = value + item.UnitValue * itemCount
                tosell = tosell + 1
            elseif result == 2 then
                todelete = todelete + 1
            end
        end
    end
    return count, value, tosell, todelete
end

-- This is a bit of a hack to do a call for blizzard to fetch all the item links in our bags to populate the item links.
function Addon:LoadAllBagItemLinks()
    for bag=0, NUM_BAG_SLOTS do
        for slot=1, GetContainerNumSlots(bag) do
            GetContainerItemInfo(bag, slot)
        end
    end
end

-- Placeholder for now
function Addon:OnBagUpdate(event, bag)
end
