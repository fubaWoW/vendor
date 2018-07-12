
Vendor = Vendor or {}
local L = Vendor:GetLocalizedStrings()

Vendor.SystemRules = 
{
    --*****************************************************************************
    -- 
    -- 
    --*****************************************************************************
    Sell = 
    {
        alwayssell = 
        {
            Name = L["SYSRULE_SELL_ALWAYSSELL"],
            Description = L["SYSRULE_SELL_ALWAYSSELL_DESC"],
            Script = 
            	function() 
            		if IsAlwaysSellItem() then
            			return SELL
            		end
            	end,
            Locked = true,
            Order = -2000,
        },

        poor = 
        {
            Name = L["SYSRULE_SELL_POORITEMS"],
            Description = L["SYSRULE_SELL_POORITEMS_DESC"],
            Script = "Quality() == 0",
        },

        artifactpower =
        {
            Name = L["SYSRULE_SELL_ARTIFACTPOWER"],
            Description = L["SYSRULE_SELL_ARTIFACTPOWER_DESC"],
            Script = "IsArtifactPower() and IsFromExpansion(6) and (PlayerLevel() >= 110)",
        },      

        uncommongear =
        {
            Name = L["SYSRULE_SELL_UNCOMMONGEAR"],
            Description = L["SYSRULE_SELL_UNCOMMONGEAR_DESC"],
            Script = "IsEquipment() and Quality() == 2 and Level() < {itemlevel}",
            InsetsNeeded = { "itemlevel" },
        },
        
        raregear =
        {
            Name = L["SYSRULE_SELL_RAREGEAR"],
            Description = L["SYSRULE_SELL_RAREGEAR_DESC"],
            Script = "IsEquipment() and Quality() == 3 and Level() < {itemlevel}",
            InsetsNeeded = { "itemlevel" },
        },

        epicgear =
        {
            Name = L["SYSRULE_SELL_EPICGEAR"],
            Description = L["SYSRULE_SELL_EPICGEAR_DESC"],
            Script = "IsEquipment() and IsSoulbound() and Quality() == 4 and Level() < {itemlevel}",
            InsetsNeeded = { "itemlevel" },
        },
        
        knowntoys =
        {
            Name = L["SYSRULE_SELL_KNOWNTOYS"],
            Description = L["SYSRULE_SELL_KNOWNTOYS_DESC"],
            Script = "IsSoulbound() and IsToy() and IsAlreadyKnown()",
        },
    },

    --*****************************************************************************
    -- 
    -- 
    --*****************************************************************************
    Keep =
    {
        -- Item is in the Never Sell list.
        neversell =
        {
            Name = L["SYSRULE_KEEP_NEVERSELL"],
            Description = L["SYSRULE_KEEP_NEVERSELL_DESC"],
            Script = 
            	function()
    				if IsNeverSellItem() then
				        return KEEP
				    end
            	end,
            Locked = true,
            Order = -1000,
        },
        
        -- This is an unsellable item if value is 0
        unsellable =
        {
            Name = L["SYSRULE_KEEP_UNSELLABLE"],
            Description = L["SYSRULE_KEEP_UNSELLABLE_DESC"],
            Script = "UnitValue() == 0",
            Locked = true,
            Order = -9999,
        },

        -- Safeguard rule - Common items are usually important and useful.
        common =
        {
            Name = L["SYSRULE_KEEP_COMMON"],
            Description = L["SYSRULE_KEEP_COMMON_DESC"],
            Script = "Quality() == 1",
        },

        -- Safeguard rule - Keep soulbound equipment.
        soulboundgear =
        {
            Name = L["SYSRULE_KEEP_SOULBOUNDGEAR"],
            Description = L["SYSRULE_KEEP_SOULBOUNDGEAR_DESC"],
            Script = "IsEquipment() and IsSoulbound()",
        },

        -- Safeguard rule - Protect those transmogs!
        unknownappearance =
        {
            Name = L["SYSRULE_KEEP_UNKNOWNAPPEARANCE"],
            Description = L["SYSRULE_KEEP_UNKNOWNAPPEARANCE_DESC"],
            Script = "IsUnknownAppearance()",
        },

        -- Safeguard rule - Legendary and higher are very rare and should probably never be worthy of a sell rule, but just in case...
        legendaryandup =
        {
            Name = L["SYSRULE_KEEP_LEGENDARYANDUP"],
            Description = L["SYSRULE_KEEP_LEGENDARYANDUP_DESC"],
            Script = "Quality() >= 5",
        },

        -- Optional Safeguard - Might be useful for leveling.
        uncommongear =
        {
            Name = L["SYSRULE_KEEP_UNCOMMONGEAR"],
            Description = L["SYSRULE_KEEP_UNCOMMONGEAR_DESC"],
            Script = "IsEquipment() and Quality() == 2",
        },

        -- Optional Safeguard - Might be useful for leveling or early max-level.
        raregear =
        {
            Name = L["SYSRULE_KEEP_RAREGEAR"],
            Description = L["SYSRULE_KEEP_RAREGEAR_DESC"],
            Script = "IsEquipment() and Quality() == 3",
        },

        -- Optional Safeguard - If you're a bit paranoid.
        epicgear =
        {
            Name = L["SYSRULE_KEEP_EPICGEAR"],
            Description = L["SYSRULE_KEEP_EPICGEAR_DESC"],
            Script = "IsEquipment() and Quality() == 4",
        },
    }
}

--*****************************************************************************
-- Gets the rule definitions of the specified type,or returns an empty 
-- table if there aren't any available.
--*****************************************************************************
local function getSystemRuleDefinitons(ruleType)
    return Vendor.SystemRules[ruleType] or {}
end

--*****************************************************************************
-- Subsitutes every instance of "{inset}" with the value specified by 
-- insetValue as a string.
--*****************************************************************************
local function replaceInset(source, inset, insetValue)
    local searchTerm = string.format("{%s}", string.lower(inset))
    local replaceValue = tostring(insetValue)
    return string.gsub(source, searchTerm, replaceValue)
end

--*****************************************************************************
-- Executes a subsitution on all the values within the "insets" table, this table
-- can be null or empty.
--*****************************************************************************
local function replaceInsets(source, insets)
    if (Vendor:TableSize(insets) ~= 0) then
        for inset, value in pairs(insets) do
            source = replaceInset(source, inset, value)
        end
    end
    return source
end

--*****************************************************************************
-- Creates a new id using the rule type and id which is uniuqe for the 
-- given set of insets.  
--
-- Example: makeRuleId("Sell", "Epic", { itemlevel=700 })
--           creates the following "sell.epic(itemlevel:700)"
--*****************************************************************************
local function makeRuleId(ruleType, ruleId, insets)
    local id = string.format("%s.%s", string.lower(ruleType), string.lower(ruleId))
    if (Vendor:TableSize(insets) ~= 0) then
        for inset, value in pairs(insets) do
            if (string.lower(ruleId) ~= string.lower(value)) then
                id  = (id .. string.format("(%s:%s)", string.lower(inset), tostring(value)))
            end
        end
    end
    return id
end

--*****************************************************************************
-- Creates an instance of the rule from the specified definition
--*****************************************************************************
local function createRuleFromDefinition(ruleType, ruleId, ruleDef, insets)
    return {
    			RawId = ruleId,
                Id = makeRuleId(ruleType, ruleId, insets),
                Name =  ruleDef.Name,
                Description = ruleDef.Description,
                Script = replaceInsets(ruleDef.Script, insets),
                InsetsNeeded = ruleDef.InsetsNeeded,
                Locked = ruleDef.Locked,
                Type = ruleType,
                Order = ruleDef.Order,
            }
end

--*****************************************************************************
-- Gets the definition of the specified rule checking the tables of rules 
-- returns the id and the script of the rule. this will format the item level
-- into the rule of needed.
--
-- insets is an optional parameter which is a table of items which shuold
-- be formated into both the ruleId and script.
--*****************************************************************************
function Vendor.SystemRules.GetDefinition(ruleType, ruleId, insets)
    local ruleDef = getSystemRuleDefinitons(ruleType)[string.lower(ruleId)]
    if (ruleDef ~= nil) then
        return createRuleFromDefinition(ruleType, ruleId, ruleDef, insets)
    end
    return nil
end

--*****************************************************************************
--  Gets the list of system rules which are considered locked, meaning they
-- cannot be added/removed by the user as part of the config.
--*****************************************************************************
function Vendor.SystemRules.GetLockedRules()
    lockedRules = {}
    -- Handle sell rules
    for ruleId, ruleDef in pairs(getSystemRuleDefinitons(Vendor.c_RuleType_Sell)) do
        if (ruleDef.Locked) then
            table.insert(lockedRules, createRuleFromDefinition(Vendor.c_RuleType_Sell, ruleId, ruleDef))
        end
    end
    -- Handle keep rules
    for ruleId, ruleDef in pairs(getSystemRuleDefinitons(Vendor.c_RuleType_Keep)) do
        if (ruleDef.Locked) then
            table.insert(lockedRules, createRuleFromDefinition(Vendor.c_RuleType_Keep, ruleId, ruleDef))
        end
    end
    return lockedRules
end
