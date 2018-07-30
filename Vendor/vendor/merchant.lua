-- Merchant event handling.
local Addon, L, Config = _G[select(1,...).."_GET"]()

local threadName = "ItemSeller"

-- When the merchant window is opened, we will attempt to auto repair and sell.
function Addon:OnMerchantShow()
    self:Debug("Merchant opened.")

    -- Do auto-repair if enabled
    if Config:GetValue(Addon.c_Config_AutoRepair) then
        self:AutoRepair()
    end

    -- Do auto-selling if enabled
    if Config:GetValue(Addon.c_Config_AutoSell) then
        self:AutoSell()
    end
end

-- For checking to make sure merchant window is open prior to selling anything.
function Addon:IsMerchantOpen()
    if MerchantFrame and MerchantFrame.IsVisible then
        return MerchantFrame:IsVisible()
    else
        self:Debug("MerchantFrame not found! Assuming it is not visible.")
        return false
    end
end

-- Do Autorepair. If using guild funds and guild funds don't cover the repair, we will use our own funds.
function Addon:AutoRepair()
    local cost, canRepair = GetRepairAllCost()
    if canRepair then
        if Config:GetValue(Addon.c_Config_GuildRepair) and CanGuildBankRepair() and GetGuildBankWithdrawMoney() >= cost then
            -- use guild repairs
            RepairAllItems(true)
            self:Print(string.format(L["MERCHANT_REPAIR_FROM_GUILD_BANK"], self:GetPriceString(cost)))
        else
            -- use own funds
            RepairAllItems()
            self:Print(string.format(L["MERCHANT_REPAIR_FROM_SELF"], self:GetPriceString(cost)))
        end
    end
end

-- This returns true if we are in the middle of autoselling.
function Addon:IsAutoSelling()
    -- We are selling if we have a thread active.
    return not not self:GetThread(threadName)
end

local function PrintSellSummary(num, value)
    if num > 0 then
        Addon:Print(L["MERCHANT_SOLD_ITEMS"], tostring(num), Addon:GetPriceString(value))
    end
end

-- Selling happens on a thread (coroutine) for UI responsiveness and to avoid being throttled by Blizzard.
-- We have to be careful of two scenarios when selling:
-- 1) The user is moving things around in the bag. This can mess up our selling. The mitigation is to wait anytime something
--    is being held by the cursor.
-- 2) As a result of #1, this can change what needs to be sold. Therefore we will evaluate every item just-in time to eliminate
--    Each sell cycle will go through every bag slot once and evaluate it for selling. If the user moves an item, it may be
--    skipped from the sell if it moved from a yet-to-be-checked slot to an already-checked slot. We could be more robust here
--    and watch for these events and re-scan, but that's making things significantly more complex for an edge case that doesnt
--    really matter. Worst-case, the user re-opens the merchant window.
-- Tiggered manually flag is to give additional feedback during the auto-selling.
function Addon:AutoSell()
    -- Start selling on a thread.
    -- If coroutine already exists no need to create another one.
    if self:GetThread(threadName) then
        return
    end

    -- Create the coroutine.
    local thread = coroutine.create( function ()
        local numSold = 0
        local totalValue = 0
        local sellLimitEnabled = Config:GetValue(Addon.c_Config_SellLimit)
        local sellLimitMaxItems = Config:GetValue(Addon.c_Config_MaxSellItems)
        local sellThrottle = Config:GetValue(Addon.c_Config_SellThrottle)
        
        -- Loop through every bag slot once.
        for bag=0, NUM_BAG_SLOTS do
            for slot=1, GetContainerNumSlots(bag) do

                -- If the cursor is holding anything then we cant' sell. Yield and check again next cycle.
                -- We must do this before we get the item info, since the user may have changed what item is in this slot.
                while GetCursorInfo() do

                    -- It is possible the merchant window closes while the user is holding an item, so check for termination condition before yielding.
                    if not self:IsMerchantOpen() then
                        PrintSellSummary(numSold, totalValue)
                        return
                    end

                    self:Debug("Cursor is holding something; waiting to sell..")
                    coroutine.yield()
                end

                -- Get Item properties and run sell rules.
                local item = self:GetBagItemFromCache(bag, slot)
                if item then
                    self:Debug("Evaluated: "..tostring(item.Properties.Link).." = "..tostring(item.Sell))
                end

                -- Determine if it is to be sold
                if item and item.Sell then

                    -- UseContainerItem is really just a limited auto-right click, and it will equip/use the item if we are not in a merchant window!
                    -- So before we do this, make sure the Merchant frame is still open. If not, terminate the coroutine.
                    if not self:IsMerchantOpen() then
                        PrintSellSummary(numSold, totalValue)
                        return
                    end

                    -- Still open, so OK to sell it.
                    UseContainerItem(bag, slot)
                    self:Print(L["MERCHANT_SELLING_ITEM"], tostring(item.Properties.Link), self:GetPriceString(item.Properties.NetValue))
                    numSold = numSold + 1
                    totalValue = totalValue + item.Properties.NetValue
                    
                    -- Check for sell limit
                    if sellLimitEnabled and sellLimitMaxItems <= numSold then
                        self:Print(L["MERCHANT_SELL_LIMIT_REACHED"], sellLimitMaxItems)
                        PrintSellSummary(numSold, totalValue)
                        return
                    end

                    -- Yield per throttling setting.
                    if numSold % sellThrottle == 0 then
                        coroutine.yield()
                    end
                end
            end
        end

        PrintSellSummary(numSold, totalValue)
    end)  -- Coroutine end

    -- Add thread to the thread queue and start it.
    self:AddThread(thread, threadName)
end

-- Confirms the popup if an item will be non-tradeable when sold, but only when we are auto-selling it.
function Addon:AutoConfirmSellTradeRemoval(link)
    if self:IsAutoSelling() then
        self:Print(L["MERCHANT_AUTO_CONFIRM_SELL_TRADE_REMOVAL"], link)
        SellCursorItem()
    end
end

-- Convert price to a pretty string
-- To reduce spam we don't show copper unless it is the only unit of measurement (i.e. < 1 silver)
-- Gold:    FFFFFF00
-- Silver:  FFFFFFFF
-- Copper:  FFAE6938
function Addon:GetPriceString(price)
    if not price then
        return "<missing>"
    end

    local copper, silver, gold, str
    copper = price % 100
    price = math.floor(price / 100)
    silver = price % 100
    gold = math.floor(price / 100)

    str = {}
    if gold > 0 then
        table.insert(str, "|cFFFFD100")
        table.insert(str, gold)
        table.insert(str, "|r|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:4:0|t  ")

        table.insert(str, "|cFFE6E6E6")
        table.insert(str, string.format("%02d", silver))
        table.insert(str, "|r|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:4:0|t  ")

    elseif silver > 0 then
        table.insert(str, "|cFFE6E6E6")
        table.insert(str, silver)
        table.insert(str, "|r|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:4:0|t  ")

    else
        -- Show copper if that is the only unit of measurement.
        table.insert(str, "|cFFC8602C")
        table.insert(str, copper)
        table.insert(str, "|r|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:4:0|t")
    end

    -- Return the concatenated string using the efficient function for it
    return table.concat(str)
end