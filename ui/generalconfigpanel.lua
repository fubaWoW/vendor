local Addon, L, Config = _G[select(1,...).."_GET"]()

local SETTING_AUTOSELL = Addon.c_Config_AutoSell
local SETTING_TOOLTIP = Addon.c_Config_Tooltip
local SETTING_TOOLTIP_RULE = Addon.c_Config_Tooltip_Rule
local SETTING_MAX_ITEMS_TO_SELL = "max_items_to_sell";
local MAX_ITEMS_TO_SELL = 144;
local MIN_ITEMS_TO_SELL = 1;

Addon.ConfigPanel = Addon.ConfigPanel or {}
Addon.ConfigPanel.General = {

    --*****************************************************************************
    -- Called when the enabled state of "auto-repair" to keep the state
    -- of hte sub-options in sync.
    --*****************************************************************************
    updateTooltipRule = function(self, repairState)
        if (not repairState) then
            self.TooltipRule.State:Disable();
        else
            self.TooltipRule.State:Enable()
        end
    end,

    --*****************************************************************************
    -- Called to handle a click on the "open rules" dialog
    --*****************************************************************************
    OnOpenRules = function()
        Addon:Debug("Showing rules dialog")
        Addon.RulesDialog.Toggle()
    end,

    --*****************************************************************************
    -- Called to handle a click on the "open bindings" button
    --*****************************************************************************
    OnOpenBindings = function()
        Addon:Debug("Showing key bindings")
        Vendor.OpenKeybindings_Cmd()
    end,

    --*****************************************************************************
    -- Called to push the settings from our page into the addon
    --*****************************************************************************
    Apply = function(self)
        Addon:Debug("Applying sell panel configuration")
        Config:SetValue(SETTING_AUTOSELL, self.AutoSell.State:GetChecked())
        Config:SetValue(SETTING_TOOLTIP, self.Tooltip.State:GetChecked())
        Config:SetValue(SETTING_TOOLTIP_RULE, self.Tooltip.State:GetChecked() and self.TooltipRule.State:GetChecked())
        Config:SetValue(SETTING_MAX_ITEMS_TO_SELL, self.maxItems.Value:GetValue());
    end,

    --*****************************************************************************
    -- Pull the value from the config into the panel.
    --*****************************************************************************
    Set = function(self)
        Addon:Debug("Setting sell panel config")
        self.AutoSell.State:SetChecked(not not Config:GetValue(SETTING_AUTOSELL))
        self.Tooltip.State:SetChecked(not not Config:GetValue(SETTING_TOOLTIP))
        self.TooltipRule.State:SetChecked(not not Config:GetValue(SETTING_TOOLTIP_RULE))

        local maxItems = math.max(MIN_ITEMS_TO_SELL, math.min(MAX_ITEMS_TO_SELL, Config:GetValue(SETTING_MAX_ITEMS_TO_SELL) or 0))
        self.maxItems.Value:SetValue(maxItems)
        self.maxItems.DisplayValue:SetFormattedText("%0d", maxItems)

        Addon.ConfigPanel.SetSliderEnable(self.maxItems, self.AutoSell.State:GetChecked()); 
        Addon.ConfigPanel.General.updateTooltipRule(self, self.Tooltip.State:GetChecked())        
    end,

    --*****************************************************************************
    -- Called to sync the values on our page with the config.
    --*****************************************************************************
    Init = function(self)
        self.Title:SetText(L["OPTIONS_HEADER_SELLING"]);
        self.HelpText:SetText(L["OPTIONS_DESC_SELLING"]);

        self.AutoSell.Text:SetText(L["OPTIONS_SETTINGDESC_AUTOSELL"]);
        self.AutoSell.Label:SetText(L["OPTIONS_SETTINGNAME_AUTOSELL"]);
        self.AutoSell.OnStateChange = 
            function(checkbox, state)
                Addon.ConfigPanel.SetSliderEnable(self.maxItems, state);
            end,

        self.Tooltip.Text:SetText(L["OPTIONS_SETTINGDESC_TOOLTIP"]);
        self.Tooltip.Label:SetText(L["OPTIONS_SETTINGNAME_TOOLTIP"]);
        self.TooltipRule.Label:SetText(L["OPTIONS_SETTINGNAME_RULE_ON_TOOLTIP"]);
        self.Tooltip.OnStateChange =
            function(checkbox, state)
               Addon.ConfigPanel.General.updateTooltipRule(self, state);
            end

        self.maxItems.Label:SetText(L["OPTIONS_SETTINGNAME_MAXITEMS"]);
        self.maxItems.Text:SetText(L["OPTIONS_SETTINGDESC_MAXITEMS"]);
        self.maxItems.Value:SetMinMaxValues(MIN_ITEMS_TO_SELL, MAX_ITEMS_TO_SELL);
        self.maxItems.Max:SetFormattedText("%d", MAX_ITEMS_TO_SELL);
        self.maxItems.Min:SetFormattedText("%d", MIN_ITEMS_TO_SELL);
        self.maxItems.Value:SetValueStep(1);
        self.maxItems.OnValueChanged =
            function(self, value)
                self.DisplayValue:SetFormattedText("%0d", value);
            end
                    
        self.OpenBindings:SetText(L["OPTIONS_SHOW_BINDINGS"]);
        self.OpenRules:SetText(L["OPTIONS_OPEN_RULES"]);
    end,
}
