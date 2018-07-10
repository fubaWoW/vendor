-- Yeah I know util is bad naming, but it fits. If something fits better elsewhere I'll move it out before this gets into a steaming pile.
local L = Vendor:GetLocalizedStrings()

-- Gets item ID from an itemstring or item link
-- If a number is passed in it assumes that is the ID
function Vendor:GetItemId(str)
	-- extract the id
	if type(str) == "number" or tonumber(str) then
		return tonumber(str)
	elseif type(str) == "string" then
		return tonumber(string.match(str, "item:(%d+):"))
	else
		return nil
	end
end

-- Assumes link
function Vendor:GetLinkString(link)
	if link and type(link) == "string" then
		local _, _, lstr = link:find('|H(.-)|h')
		return lstr
	else
		return nil
	end
end

-- Returns table of link properties
function Vendor:GetLinkProperties(link)
	local lstr = self:GetLinkString(link)
	if lstr then
		return {strsplit(':', lstr)}
	else
		return {}
	end
end

-- dumps the contents of the table
function Vendor:DumpTable(t)
	for k, v in pairs(t) do
		self:Debug("K = "..tostring(k).."   V = "..tostring(v))
		--if type(v) == "table" and v ~= t then
		--	self:DumpTable(v)
		--end
	end
end

-- Simplified print to DEFAULT_CHAT_FRAME. Replaces need for AceConsole with 9 lines. Thanks AceConsole for the inspiriation and color code.
-- Assume if multiple arguments it is a format string.
local printPrefix = string.format("%s%s%s", "|cff33ff99", L["ADDON_NAME"], "|r:")
function Vendor:Print(msg, ...)
	msg = printPrefix..msg
    if (table.getn({...}) ~= 0) then
        DEFAULT_CHAT_FRAME:AddMessage(string.format(msg, ...))
    else
        DEFAULT_CHAT_FRAME:AddMessage(msg)
    end
end

-- Debug print
function Vendor:Debug(msg, ...)
	if not self.db.profile.debug then return end
	self:Print(msg, ...)
end

-- Counts size of the table
function Vendor:TableSize(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

-- Convert price to a pretty string
-- Gold:	FFFFFF00
-- Silver:	FFFFFFFF
-- Copper:	FFAE6938
function Vendor:GetPriceString(price)
	if not price then
		return "<missing>"
	end

	local copper, silver, gold, str
	copper = price % 100
	price = math.floor(price / 100)
	silver = price % 100
	gold = math.floor(price / 100)
	
	-- Absolutely avoiding concatenating the same string, huge memory waste. Building a table and concat it at the end.
	str = {}
	-- use highest currency present
	if gold > 0 then
		table.insert(str, "|cFFFFD100")
		table.insert(str, gold)
		table.insert(str, "|r|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:4:0|t  ")

		table.insert(str, "|cFFE6E6E6")
		table.insert(str, string.format("%02d", silver))
		table.insert(str, "|r|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:4:0|t  ")
		
		if self.db.profile.showcopper then
			table.insert(str, "|cFFC8602C")
			table.insert(str, string.format("%02d", copper))
			table.insert(str, "|r|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:4:0|t")
		end
		
	elseif silver > 0 or not self.db.profile.showcopper then
		table.insert(str, "|cFFE6E6E6")
		table.insert(str, silver)
		table.insert(str, "|r|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:4:0|t  ")
		
		if self.db.profile.showcopper then
			table.insert(str, "|cFFC8602C")
			table.insert(str, string.format("%02d", copper))
			table.insert(str, "|r|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:4:0|t")
		end
	else
		-- Show copper if that is the only unit of measurement.
		table.insert(str, "|cFFC8602C")
		table.insert(str, copper)
		table.insert(str, "|r|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:4:0|t")
	end
	
	-- Return the concatenated string using the efficient function for it
	return table.concat(str)
end
