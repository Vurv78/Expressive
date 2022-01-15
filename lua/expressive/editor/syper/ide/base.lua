local Base = {
	SyperBase = true,
	SyperFocusable = true
}

function Base:Init()
end

function Base:OnFocusChanged(gained)
	if gained then
		local panel = self.refocus_panel

		while IsValid(panel) do
			local npanel = panel.refocus_panel

			if not IsValid(npanel) then
				panel:RequestFocus()
			end

			panel = npanel
		end
	else
		local parent = self:GetParent()

		while IsValid(parent) and parent.SyperFocusable do
			parent.refocus_panel = self
			parent = parent:GetParent()
		end
	end
end

function Base:FocusPreviousChild(cur_focus)
	local allow = cur_focus == nil and true or false
	local children = self:GetChildren()

	for i = #children, 1, -1 do
		local panel = children[i]

		if panel == cur_focus then
			allow = true
		elseif allow and panel.SyperFocusable then
			panel.refocus_panel = nil
			panel:RequestFocus()

			return panel
		end
	end
end

function Base:FocusPrevious()
	local parent = self:GetParent()
	local new = parent:FocusPreviousChild(self)

	if not new then
		if parent.SyperFocusable then
			-- move up in parent hierarchy
			parent:FocusPrevious()
		else
			-- loop around
			new = parent:FocusPreviousChild()
		end
	end

	-- move as far down in parent hierarchy
	while IsValid(new) do
		if not new.SyperFocusable then break end
		new.refocus_panel = nil
		new:RequestFocus()
		new = new:FocusPreviousChild()
	end
end

function Base:FocusNextChild(cur_focus)
	local allow = cur_focus == nil and true or false
	local children = self:GetChildren()

	for i = 1, #children do
		local panel = children[i]

		if panel == cur_focus then
			allow = true
		elseif allow and panel.SyperFocusable then
			panel.refocus_panel = nil
			panel:RequestFocus()

			return panel
		end
	end
end

function Base:FocusNext()
	local parent = self:GetParent()
	local new = parent:FocusNextChild(self)

	if not new then
		if parent.SyperFocusable then
			-- move up in parent hierarchy
			parent:FocusNext()
		else
			-- loop around
			new = parent:FocusNextChild()
		end
	end

	-- move as far down in parent hierarchy
	while IsValid(new) do
		if not new.SyperFocusable then break end
		new.refocus_panel = nil
		new:RequestFocus()
		new = new:FocusNextChild()
	end
end

function Base:Replace(panel)
	local parent = self:GetParent()
	self:SetParent()

	if parent.ClassName == "E4SyperHDivider" then
		if parent.left == self then
			parent:SetLeft(panel)
		else
			parent:SetRight(panel)
		end
	elseif parent.ClassName == "E4SyperVDivider" then
		if parent.top == self then
			parent:SetTop(panel)
		else
			parent:SetBottom(panel)
		end
	elseif parent.ClassName == "E4SyperTabHandler" then
		for i, tab in ipairs(parent.tabs) do
			if tab.panel == self then
				tab.panel = panel
				tab.tab.panel = panel
				panel:SetParent(parent)
				break
			end
		end
	else
		panel:SetParent(parent)
	end

	self:Remove()
end

function Base:SafeUnparent()
	local parent = self:GetParent()
	self:SetParent()

	if parent.ClassName == "E4SyperHDivider" then
		parent:Replace(parent.left == self and parent.right or parent.left)
	elseif parent.ClassName == "E4SyperVDivider" then
		parent:Replace(parent.top == self and parent.bottom or parent.top)
	elseif parent.ClassName == "E4SyperTabHandler" then
		parent:RemoveTab(parent:GetIndex(self), true)
		parent:PerformLayoutTab(parent.tabs[parent.active_tab], parent:GetWide(), parent:GetTall(), true)
	end
end

-- cuz LocalToScreen is garbage
function Base:PosGlobal()
	local x, y = self:GetPos()
	local parent = self:GetParent()

	while parent do
		local lx, ly = parent:GetPos()
		x = x + lx
		y = y + ly
		parent = parent:GetParent()
	end

	return x, y
end

function Base:FindTillParent(name)
	local parent = self

	while true do
		local p = parent:GetParent()
		if p.ClassName == name then return parent end
		parent = p
	end
end

function Base:FindParent(name)
	local p = self:GetParent()

	while IsValid(p) do
		if p.ClassName == name then return p end
		p = p:GetParent()
	end
end

function Base:FindTabHandler()
	return self:FindParent("E4SyperTabHandler")
end

function Base:FindIDE()
	local p = self:GetParent()

	while IsValid(p) do
		p = p:GetParent()
	end

	return self:FindParent("E4SyperIDE")
end

vgui.Register("E4SyperBase", Base, "Panel")