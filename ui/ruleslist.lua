local Addon, L = _G[select(1,...).."_GET"]()
Addon.RulesUI = {}

function table.swap(T, i, j)
    local tmp = rawget(T, i)
    rawset(T, i, rawget(T, j))
    rawset(T, j, tmp)
end

Addon.RulesList =
{
    HideMoveButtons = function(rule)
        rule.MoveUp:Hide()
        rule.MoveDown:Hide()
    end,

    --*****************************************************************************
    -- Updates the state of the up/down arrows for the specified rule item
    --*****************************************************************************
    UpdateMoveButtons = function(rule)
        if (rule.first) then
            rule.MoveUp:Hide()
            rule.MoveDown:Show()
        elseif (rule.last) then
            rule.MoveUp:Show()
            rule.MoveDown:Hide()
        else
            rule.MoveUp:Show()
            rule.MoveDown:Show()
        end
    end,

    --*****************************************************************************
    -- Move the rule within the list on spot in the given direction
    --*****************************************************************************
    MoveRule = function(ruleList, rule, direction)
        local newIndex = (rule.index + direction)
        if ((newIndex >= 1) and (newIndex <= #ruleList.Rules)) then
            table.swap(ruleList.Rules, rule.index, newIndex)
            Addon.RulesUI.UpdateRuleList(ruleList)
        end
    end,

    --*****************************************************************************
    -- Searches the given table for the frame represented by the specified rule
    -- config, and if it's found then it returns the index where the item is
    --*****************************************************************************
    findRuleById = function(rules, ruleConfig)
        local ruleId = ruleConfig
        if (type(ruleId) == "table") then
            ruleId = ruleId.rule
        end
        if (rules) then
            for i,rule in ipairs(rules) do
                if (ruleId == rule.RuleId) then
                    return i
                end
            end
        end
        return -1
    end,
}

local function toggleRuleWithItemLevel(frame)
    if (frame.ItemLevel) then
        if (frame.Enabled:GetChecked()) then
            frame.ItemLevel:Enable()
        else
            frame.ItemLevel:Disable()
        end
    end
end

--*****************************************************************************
-- Determines if the specified rule is enabled based on the provied rule
-- list by looking for a match on the ID.
--*****************************************************************************
local function updateRuleEnabledState(ruleFrame, ruleConfig)
    ruleFrame.Enabled:SetChecked(false)
    if (ruleFrame.ItemLevel) then
        ruleFrame.ItemLevel:SetNumber(0)
        ruleFrame.ItemLevel:Disable()
    end

    for _, entry in pairs(ruleConfig) do
        if (type(entry) == "string") then
            if (entry == ruleFrame.RuleId) then
                ruleFrame.Enabled:SetChecked(true)

                if (ruleFrame.ItemLevel) then
                    ruleFrame.ItemLevel:SetNumber(0)
                    ruleFrame.Enabled:SetChecked(false)
                    ruleFrame.ItemLevel:Disable()
                end
            end
        elseif (type(entry) == "table") then
            local ruleId = entry["rule"]
            if (ruleId and (ruleId == ruleFrame.RuleId)) then
                ruleFrame.Enabled:SetChecked(true)

                if (ruleFrame.ItemLevel) then
                    if (type(entry["itemlevel"]) == "number") then
                        ruleFrame.ItemLevel:SetNumber(entry["itemlevel"])
                    else
                        ruleFrame.ItemLevel:SetNumber(0)
                        ruleFrame.Enabled:SetChecked(false)
                        ruleFrame.ItemLevel:Disable()
                    end
                end
            end
        end
    end

    toggleRuleWithItemLevel(ruleFrame)
end

local function ruleNeeds(rule, inset)
    inset = string.lower(inset)
    if (rule.InsetsNeeded) then
        for _, needed in ipairs(rule.InsetsNeeded) do
            if (string.lower(needed) == inset) then
                return true
            end
        end
    end
end

--*****************************************************************************
-- Create a new frame for a rule item in the provided list. This will setup
-- the item for all of the proeprties of the rule
--
--*****************************************************************************
local function createRuleItem(parent, ruleId, rule)
    local template = "VendorSimpleRuleTemplate"
    if ruleNeeds(rule, "itemlevel") then
        template = "VendorRuleTemplateWithItemLevel"
    end

    local frame = CreateFrame("Frame", ("$parent" .. ruleId), parent, template)
    frame.Rule = rule
    frame.RuleId = ruleId
    frame.RuleName:SetText(rule.Name)
    frame.RuleDescription:SetText(rule.Description)

   -- if (parent.Rules and ((#parent.Rules % 2) ~= 0)) then
   --   frame.OddBackground:Show()
   --  end

    if (frame.ItemLevel) then
        frame.ItemLevel.Label:SetText(L["RULEUI_LABEL_ITEMLEVEL"])
        frame.ToggleRuleState = toggleRuleWithItemLevel
    end

    updateRuleEnabledState(frame, parent.RuleConfig)
    return frame
end

--*****************************************************************************
-- Builds a list of rules which shoudl be enalbed based on the state of
-- rules within the list.
--*****************************************************************************
local function getRuleConfigFromList(frame)
    local config = {}
    if (frame.Rules) then
        for _, ruleItem in ipairs(frame.Rules) do
            if (ruleItem.Enabled:GetChecked()) then
                local entry = { rule = ruleItem.RuleId }

                if (ruleItem.ItemLevel) then
                    local ilvl = ruleItem.ItemLevel:GetNumber()
                    if (ilvl ~= 0) then
                        entry.itemlevel = ilvl
                    else
                        entry = nil
                    end
                end

                if (entry) then
                    table.insert(config, entry)
                end
            end
        end
    end
    return config
end

--*****************************************************************************
-- Updates the state of the list based on the config passed in
--*****************************************************************************
local function setRuleConfigFromList(frame, config)
    frame.RuleConfig = config or {}
    if (frame.Rules) then
        local rules = frame.Rules

        -- First update each item in the list
        for _, ruleFrame in ipairs(rules) do
            updateRuleEnabledState(ruleFrame, config)
            ruleFrame.index = -1
        end

        -- Second re-order the list to reflect the order of the rules
        for i, ruleConfig in ipairs(config) do
            local ruleIndex = Addon.RulesList.findRuleById(rules, ruleConfig)
            if (ruleIndex ~= -1) then
                if (ruleIndex ~= i) then
                    table.swap(rules, ruleIndex, i)
                    rules[i].index = 0
                else
                    rules[i].index = 0
                end
            end
        end

        -- Third the remaining rules should be sorted by the order 
        -- of execution (items without an order are pushed to the end)
        if (#config ~= #rules) then
            local start = #config
            local part = { select(start + 1, unpack(rules)) }
            
            table.sort(part,
                function (ruleA, ruleB) 
                    return ((ruleA.Rule.Order or 0) < (ruleB.Rule.Order or 0))
                end)

            for i=1,#part do
                rules[start + i] = part[i]
            end
        end
    end
    Addon.RulesUI.UpdateRuleList(frame)
end

--*****************************************************************************
-- Called when a rules list is loaded in order to populate the list of
-- frames which represent the rules contained in the list.
--*****************************************************************************
function Addon.RulesUI.InitRuleList(frame, ruleType, ruleList, ruleConfig)
    frame.RuleFrameSize = 0
    frame.NumVisible = 0
    frame.GetRuleConfig = getRuleConfigFromList
    frame.SetRuleConfig = setRuleConfigFromList
    frame.RuleConfig = ruleConfig or {}
    frame.RuleList = ruleList
    frame.RuleType = ruleType

    assert(frame.RuleList, "Rule List frame needs to have the rule list set")
    assert(frame.RuleType, "Rule List frame needs to have the rule type set")
    
    -- Create the frame for each of our rules.
    for id, rule in pairs(ruleList) do
        if (not rule.Locked) then
            local rule = createRuleItem(frame, id, rule)
            frame.RuleFrameSize = math.max(frame.RuleFrameSize, rule:GetHeight())
        end
    end

    -- Give an initial update of the view
    Addon.RulesUI.UpdateRuleList(frame)
end

--*****************************************************************************
-- Called when the list is scrolled/created and will iterate through our list
-- of frames an then show/hide and position the frames which should be
-- currently visibile.
--*****************************************************************************
function Addon.RulesUI.UpdateRuleList(frame)
    if (frame.Rules) then
        local offset = FauxScrollFrame_GetOffset(frame.View)
        local ruleHeight = frame.RuleFrameSize
        local previousFrame = nil
        local totalItems = #frame.Rules
        local numVisible = math.floor(frame.View:GetHeight() / frame.RuleFrameSize)
        local startIndex = (1 + offset)
        local endIndex = math.min(totalItems, offset + numVisible)

        FauxScrollFrame_Update(frame.View, totalItems, numVisible, frame.RuleFrameSize, nil, nil, nil, nil, nil, nil, true)
        for ruleIndex=1,#frame.Rules do
            local ruleFrame = frame.Rules[ruleIndex]
            ruleFrame.index = ruleIndex
            ruleFrame.first = (ruleIndex == 1)
            ruleFrame.last = (ruleIndex == totalItems)
            if ((ruleIndex < startIndex) or (ruleIndex > endIndex)) then
                ruleFrame:Hide()
            else
                if (previousFrame) then
                    ruleFrame:SetPoint("TOPLEFT", previousFrame, "BOTTOMLEFT", 0, 0)
                    ruleFrame:SetPoint("TOPRIGHT", previousFrame, "BOTTOMRIGHT", 0, 0)
                else
                    ruleFrame:SetPoint("TOPLEFT", frame.View, "TOPLEFT", 0, 0)
                    ruleFrame:SetPoint("TOPRIGHT", frame.View, "TOPRIGHT", 0, 0)
                end
                if (not ruleFrame:IsShown()) then
                    ruleFrame:Show()
                end

                if (not ruleFrame.last) then
                    ruleFrame.Divider:Show()
                else
                    ruleFrame.Divider:Hide()
                end
                
                if (ruleFrame:IsMouseOver()) then
                    Addon.RulesList.UpdateMoveButtons(ruleFrame)
                else
                    Addon.RulesList.HideMoveButtons(ruleFrame)
                end

                previousFrame = ruleFrame                
            end
        end
    end
end

function Addon.RulesUI.ApplySystemRuleConfig(frame)
    Addon:DebugRules("Applying config for rule type '%s'", frame.RuleType)
    Addon:GetConfig():SetRulesConfig(frame.RuleType, getRuleConfigFromList(frame))
end