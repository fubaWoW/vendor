local _, Addon = ...;
local ItemInfo = {};
local ItemInfoItem = {}

function ItemInfoItem:OnCreated()
    self:SetScript("OnEnter", self.OnEnter)
	self:SetScript("OnLeave", self.OnLeave)
	self:SetScript("OnClick", self.OnClick)
	self:RegisterForClicks("LeftButtonDown", "RightButtonDown")
end

function ItemInfoItem:OnModelChanged(model)
    local t = type(model.Value);
    local value = self.Value;
    self.Name:SetText(model.Name);

    if (model.Value == nil) then
        value:SetText("nil");
        value:SetTextColor(DISABLE_FONT_COLOR:GetRGB());
    elseif (t == "string") then
        value:SetFormattedText("\"%s\"", model.Value);
        value:SetTextColor(GREEN_FONT_COLOR:GetRGB());
    elseif (t == "boolean") then
        value:SetText(tostring(model.Value));
        value:SetTextColor(EPIC_PURPLE_COLOR:GetRGB());
    elseif (t == "number") then
        value:SetText(tostring(model.Value));
        value:SetTextColor(ORANGE_FONT_COLOR:GetRGB());
    else
        value:SetText(tostring(model.Value));
        value:SetTextColor(WHITE_TEXT_COLOR:GetRGB());
    end
end

function ItemInfoItem:OnEnter()
    local model = assert(self:GetModel(), "The item should have a valid model")
    local doc = Addon.ScriptReference.ItemProperties[model.Name]
    if (doc) then
        local text = doc;
        if (type(doc) == "table") then
            text = doc.Text
        end

        if ((type(text) == "string") and (string.len(text) ~= 0)) then
            GameTooltip:SetOwner(self, "ANCHOR_NONE")
            GameTooltip:AddLine(model.Name, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
            GameTooltip:AddLine(text, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, true)
            GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
            GameTooltip:Show()
        end
    end
end

function ItemInfoItem:OnLeave()
    if (GameTooltip:GetOwner() == self) then
        GameTooltip:Hide()
    end
end

function ItemInfoItem:OnClick(button)
    local item = Addon.ItemList.GetCursorItem();
	if (not item) then
		local model = assert(self:GetModel(), "The item should have a valid model")
		Addon.invoke(self:GetList(), "OnItemClicked", button, model)
	else
		Addon.invoke(self:GetList(), "OnDrop", item)
	end
end

function ItemInfoItem:OnUpdate()
    if (self:IsMouseOver()) then
        self.Hover:Show()
    else
        self.Hover:Hide()
    end
end

function ItemInfo:OnLoad()
    self.props = {};
    self:EnableMouse(true);

    self.View.GetItems = function()
        return self.props or  {};
    end;

    self.View.ItemClass = ItemInfoItem	
	self.View.OnItemClicked = function(_, button, item)
		if (button == "LeftButton") then
			Addon.invoke(self, "OnItemClicked", item.Name, item.Value)
		elseif (button == "RightButton") then
			Addon.invoke(self, "OnItemContext", item.Name, item.Value)
		end
	end

	self.View.OnDrop = function(_, item)
		self:Drop(item)
	end
end

function ItemInfo:Drop(item)
    item = item or Addon.ItemList.GetCursorItem();
    if (not item or (type(item) ~= "table") or not item:IsBagAndSlot()) then
        return;
    end

    ClearCursor();
    local itemProps = Addon:GetItemProperties(item:GetBagAndSlot());
    local model = {}
    for name, value in pairs(itemProps) do 
        if (type(value) ~= "table") then
            if ((name ~= "GUID") and (name ~= "Link")) then
                table.insert(model, { Name=name, Value=value });
            end
        end
    end

    table.sort(model, 
        function (a, b)
            return a.Name < b.Name
        end);

    self.props = model;
    self.View:Update();
end

Addon.Panels = Addon.Panels or {}
Addon.Panels.ItemInfo = ItemInfo