local settings = ExpressiveEditor.Settings.settings
----------------------------------------
local Tab = {}

function Tab:Init()
	self.handler = nil
	self.name = nil
	self.panel = nil
	self.active = false
end

function Tab:Setup(handler, name, panel)
	self.handler = handler
	self.name = name
	self.panel = panel
	self.width = handler.tab_size
end

function Tab:OnMousePressed(key)
	if key == MOUSE_LEFT then
		self.handler:SetActivePanel(self.panel)

		if self.handler.OnTabPress then
			self.handler:OnTabPress(self)
		end

		local tab = self.handler.tabs[self.handler.active_tab > 1 and self.handler.active_tab - 1 or self.handler.active_tab + 1]
		if not tab then return end
		self.handler.hold_layout_main = tab
		self.handler:PerformLayoutTab(tab, self.handler:GetSize())
		self.handler:PerformLayoutTab(self, self.handler:GetSize())
		self.handler.holding = self

		self.handler.hold_offset = {self:LocalCursorPos()}

		self:MouseCapture(true)
		self:SetVisible(false)
		self.handler.hold_layout = {}

		local function populateLayout(panel)
			local cc = 0

			for i, child in ipairs(panel:GetChildren()) do
				if child.SyperBase then
					cc = cc + 1
					populateLayout(child)
				end
			end

			if cc == 0 then
				local x, y = panel:PosGlobal()
				local w, h = panel:GetSize()

				self.handler.hold_layout[#self.handler.hold_layout + 1] = {
					panel = panel,
					x = x,
					y = y,
					x2 = x + w,
					y2 = y + h,
					w = w,
					h = h
				}
			end
		end

		populateLayout(tab.panel)
	elseif key == MOUSE_RIGHT then
		-- TODO: make close check if it should prompt save first
		local menu = ExpressiveEditor.Menu()

		menu:AddOption("Close", function()
			self.handler:RemoveTab(self.handler:GetIndex(self.panel:FindTillParent("E4SyperTabHandler")))
		end)

		menu:AddOption("Close Others", function()
			local s = self.handler:GetIndex(self.panel:FindTillParent("E4SyperTabHandler")) + 1

			for _ = s, #self.handler.tabs do
				self.handler:RemoveTab(s)
			end

			for _ = 1, #self.handler.tabs - 1 do
				self.handler:RemoveTab(1)
			end
		end)

		menu:AddOption("Close To Right", function()
			local s = self.handler:GetIndex(self.panel:FindTillParent("E4SyperTabHandler")) + 1

			for _ = s, #self.handler.tabs do
				self.handler:RemoveTab(s)
			end
		end)

		menu:AddOption("Close To Left", function()
			for _ = 1, self.handler:GetIndex(self.panel:FindTillParent("E4SyperTabHandler")) - 1 do
				self.handler:RemoveTab(1)
			end
		end)

		menu:Open()
	end
end

function Tab:OnMouseReleased(key)
	if key == MOUSE_LEFT then
		self:MouseCapture(false)

		if not self.handler.holding then
			self.handler:SetActivePanel(self.panel)

			return
		end

		local pnl = self.handler.holding.panel
		self.handler.holding = nil

		if self.handler.hold_dir and self.handler.hold_hover then
			local dir = self.handler.hold_dir
			local hvr = self.handler.hold_hover.panel
			hvr.OnNameChange = nil
			local p = hvr:GetParent()
			local div

			if dir == 1 then
				div = vgui.Create("E4SyperVDivider")
				div:SetTop(pnl)
				div:SetBottom(hvr)
			elseif dir == 2 then
				div = vgui.Create("E4SyperVDivider")
				div:SetTop(hvr)
				div:SetBottom(pnl)
			elseif dir == 3 then
				div = vgui.Create("E4SyperHDivider")
				div:SetLeft(pnl)
				div:SetRight(hvr)
			elseif dir == 4 then
				div = vgui.Create("E4SyperHDivider")
				div:SetLeft(hvr)
				div:SetRight(pnl)
			end

			self.handler:RemoveTab(self.handler:GetIndex(self.panel), true)

			if p.ClassName == "E4SyperTabHandler" then
				local i = p:GetIndex(hvr)
				p.tabs[i].panel = div
				p.tabs[i].tab.panel = div
				div:SetParent(p)
			elseif p.ClassName == "E4SyperVDivider" then
				if p.top == hvr then
					p:SetTop(div)
				else
					p:SetBottom(div)
				end
			elseif p.ClassName == "E4SyperHDivider" then
				if p.left == hvr then
					p:SetLeft(div)
				else
					p:SetRight(div)
				end
			end

			div:CenterDiv()
			pnl:SetVisible(true)
			p:InvalidateChildren(true)
		else
			self.handler:SetActivePanel(self.panel)
			self:SetVisible(true)
			local lx = self.handler:LocalCursorPos() - self.handler.hold_offset[1]
			local cur = self.handler:GetIndex(self.panel)
			if not cur then return end

			for i, tab in ipairs(self.handler.tabs) do
				if tab.tab:GetX() > lx then
					if cur == i then
						self.handler:InvalidateLayout()

						return
					end

					self.handler:MoveTab(cur, i)

					return
				end
			end

			self.handler:MoveTab(cur, #self.handler.tabs + 1)
		end
	end
end

function Tab:OnMouseWheeled(delta)
	self.handler.scroll = self.handler.scroll - delta * self.handler.scroll_mul
	self.handler:InvalidateLayout()
end

function Tab:Paint(w, h)
	if self.active then
		draw.NoTexture()
		surface.SetDrawColor(settings.style_data.gutter_background)

		surface.DrawPoly({
			{
				x = 0,
				y = h
			},
			{
				x = 5,
				y = 0
			},
			{
				x = w - 5,
				y = 0
			},
			{
				x = w,
				y = h
			},
		})

		surface.SetTextColor(settings.style_data.ide_foreground)
	else
		surface.SetDrawColor(settings.style_data.ide_background)
		surface.DrawRect(0, 0, w, h)
		local prev = self.handler.tabs[self.handler.active_tab - 1]

		if prev and prev.tab ~= self then
			surface.SetDrawColor(settings.style_data.gutter_background)
			surface.DrawRect(w - 1, 3, 1, h - 6)
		end

		surface.SetTextColor(settings.style_data.ide_disabled)
	end

	surface.SetFont(self.handler.tab_font)
	local tw, th = surface.GetTextSize(self.name)
	local o = (h - th) / 2
	surface.SetTextPos(5 + o, o)
	surface.DrawText(self.name)
	local dw = math.max(self.handler.tab_size, tw + 10 + o * 2)

	if self.width ~= dw then
		self.width = dw
		self:InvalidateParent()
	end

	return true
end

function Tab:SetActive(state)
	self.active = state
end

vgui.Register("E4SyperTab", Tab, "Panel")
----------------------------------------
local TabHandler = {}

function TabHandler:Init()
	self.bar_size = 25
	self.tab_size = 100
	self.tab_font = "syper_ide"
	self.scroll_mul = 20
	self.scroll = 0
	self.active_tab = 0
	self.tabs = {}
end

function TabHandler:Paint(w, h)
	surface.SetDrawColor(settings.style_data.ide_background)
	surface.DrawRect(0, 0, w, self.bar_size - 4)
	surface.SetDrawColor(settings.style_data.gutter_background)
	surface.DrawRect(0, self.bar_size - 4, w, 4)
	surface.SetDrawColor(settings.style_data.background)
	surface.DrawRect(0, self.bar_size, w, h - self.bar_size)
end

function TabHandler:PaintOver()
	if not self.holding then return end

	if self.hold_dir and self.hold_hover then
		local x, y = self.hold_hover.x, self.hold_hover.y
		local w, h = self.hold_hover.w, self.hold_hover.h
		local pnl = self.holding.panel
		local hvr = self.hold_hover.panel

		if self.hold_dir == 1 then
			pnl:SetSize(w, h / 2)
			pnl:InvalidateChildren(true)
			pnl:PaintAt(x, y)
			hvr:SetSize(w, h / 2)
			hvr:InvalidateChildren(true)
			hvr:PaintAt(x, y + h / 2)
		elseif self.hold_dir == 2 then
			pnl:SetSize(w, h / 2)
			pnl:InvalidateChildren(true)
			pnl:PaintAt(x, y + h / 2)
			hvr:SetSize(w, h / 2)
			hvr:InvalidateChildren(true)
			hvr:PaintAt(x, y)
		elseif self.hold_dir == 3 then
			pnl:SetSize(w / 2, h)
			pnl:InvalidateChildren(true)
			pnl:PaintAt(x, y)
			hvr:SetSize(w / 2, h)
			hvr:InvalidateChildren(true)
			hvr:PaintAt(x + w / 2, y)
		elseif self.hold_dir == 4 then
			pnl:SetSize(w / 2, h)
			pnl:InvalidateChildren(true)
			pnl:PaintAt(x + w / 2, y)
			hvr:SetSize(w / 2, h)
			hvr:InvalidateChildren(true)
			hvr:PaintAt(x, y)
		end
	end

	local x, y = input.GetCursorPos()
	local lx, ly = self:ScreenToLocal(x, y)
	self.holding:PaintAt(x - self.hold_offset[1], ly > self.bar_size * 1.2 and y - self.hold_offset[2] or y - ly)
end

function TabHandler:Think()
	if not self.holding then return end
	self.hold_dir = nil
	local x, y = self:LocalCursorPos()
	if #self.tabs < 2 then return end

	if y <= self.bar_size * 1.2 then
		self.hold_layout_main.panel:SetVisible(false)
		self.holding.panel:SetVisible(true)
		self.holding.panel:SetSize(self:GetWide(), self:GetTall() - self.bar_size)
		self.holding.panel:InvalidateChildren(true)

		return
	end

	self.hold_layout_main.panel:SetVisible(true)
	self.holding.panel:SetVisible(false)
	local oldhold = self.hold_hover
	self.hold_hover = nil
	local x, y = input.GetCursorPos()

	for _, data in ipairs(self.hold_layout) do
		if x > data.x and x < data.x2 and y > data.y and y < data.y2 then
			self.hold_hover = data
			break
		end
	end

	if self.hold_hover then
		local x, y = x - self.hold_hover.x, y - self.hold_hover.y
		local w, h = self.hold_hover.w, self.hold_hover.h
		local ud = (y - h / 2) / (h / 2)
		local lr = (x - w / 2) / (w / 2)
		self.hold_dir = math.abs(ud) > math.abs(lr) and (ud < 0 and 1 or 2) or (lr < 0 and 3 or 4)
	end
end

function TabHandler:ScrollBounds(w)
	-- local max = #self.tabs * self.tab_size - w
	local max = -w

	for i, tab in ipairs(self.tabs) do
		max = max + tab.tab.width
	end

	self.scroll = math.Clamp(self.scroll, 0, math.max(0, max))
end

function TabHandler:PerformLayout(w, h)
	if self.holding then return end
	self:ScrollBounds(w)
	local offset = 0

	for i, tab in ipairs(self.tabs) do
		local x = math.Clamp(offset - self.scroll, 0, w - tab.tab.width)
		tab.tab:SetPos(x, 0)
		tab.tab:SetSize(tab.tab.width, self.bar_size - 4)
		tab.tab:SetZPos(tab.tab.active and 1000 or -math.abs(w / 2 - (offset - self.scroll) + tab.tab.width / 2))
		offset = offset + tab.tab.width
	end

	self:PerformLayoutTab(self:GetActivePanel(), w, h)
end

function TabHandler:PerformLayoutTab(tab, w, h, now)
	if not tab then return end
	tab.panel:SetPos(0, self.bar_size)
	tab.panel:SetSize(w, h - self.bar_size)

	if now then
		tab.panel:InvalidateChildren(true)
	else
		tab.panel:InvalidateLayout()
	end
end

function TabHandler:FocusPreviousChild(cur_focus)
	local allow = cur_focus == nil and true or false

	for i = #self.tabs, 1, -1 do
		local tab = self.tabs[i]

		if tab.panel == cur_focus then
			allow = true
		elseif allow then
			self:SetActivePanel(tab.panel)

			return tab.panel
		end
	end
end

function TabHandler:FocusNextChild(cur_focus)
	local allow = cur_focus == nil and true or false

	for i = 1, #self.tabs do
		local tab = self.tabs[i]

		if tab.panel == cur_focus then
			allow = true
		elseif allow then
			self:SetActivePanel(tab.panel)

			return tab.panel
		end
	end
end

function TabHandler:AddTab(name, panel, index, dont_active)
	local tab = self:Add("E4SyperTab")
	tab:Setup(self, name, panel)

	if index then
		index = math.Clamp(index, 1, #self.tabs + 1)
	else
		index = #self.tabs + 1
	end

	panel:SetParent(self)

	table.insert(self.tabs, index, {
		name = name,
		tab = tab,
		panel = panel
	})

	if not dont_active then
		self:SetActive(index)
	end

	ExpressiveEditor.IDE:SaveSession()

	return self.tabs[index]
end

function TabHandler:RemoveTab(index, keep_panel)
	local tab = self.tabs[index]
	tab.tab:Remove()

	if not keep_panel then
		tab.panel:Remove()
	end

	table.remove(self.tabs, index)

	if tab.tab.active then
		self:SetActive(math.max(1, index - 1))

		if self.OnTabPress then
			self:OnTabPress(self.tabs[self.active_tab])
		end
	end

	ExpressiveEditor.IDE:SaveSession()
end

function TabHandler:RenameTab(index, name)
	self.tabs[index].name = name
	self.tabs[index].tab.name = name
	ExpressiveEditor.IDE:SaveSession()
end

function TabHandler:MoveTab(old, new)
	local t = self.tabs[old]
	table.insert(self.tabs, new, t)
	table.remove(self.tabs, old + (old > new and 1 or 0))
	self:InvalidateLayout()
	ExpressiveEditor.IDE:SaveSession()
end

function TabHandler:GetIndex(panel)
	for i, tab in ipairs(self.tabs) do
		if tab.panel == panel then return i end
	end
end

function TabHandler:SetActive(index)
	self.active_tab = index

	for i, tab in ipairs(self.tabs) do
		if i == index then
			tab.panel:SetVisible(true)
			tab.panel:RequestFocus()
			tab.tab:SetActive(true)
		else
			tab.panel:SetVisible(false)
			tab.tab:SetActive(false)
		end
	end

	self:InvalidateLayout()
	ExpressiveEditor.IDE:SaveSession()
end

function TabHandler:GetActive()
	return self.active_tab
end

function TabHandler:SetActivePanel(panel)
	for i, tab in ipairs(self.tabs) do
		if tab.panel == panel then
			tab.panel:SetVisible(true)
			tab.panel:RequestFocus()
			tab.tab:SetActive(true)
			self.active_tab = i
		else
			tab.panel:SetVisible(false)
			tab.tab:SetActive(false)
		end
	end

	self:InvalidateLayout()
	ExpressiveEditor.IDE:SaveSession()
end

function TabHandler:GetActivePanel()
	return self.tabs[self.active_tab]
end

function TabHandler:GetTabCount()
	return #self.tabs
end

function TabHandler:SetBarSize(size)
	self.bar_size = size
	self:InvalidateLayout()
end

function TabHandler:SetTabSize(size)
	self.tab_size = size
	self:InvalidateLayout()
end

function TabHandler:GetSessionState()
	local tabs = {}

	for i, tab in ipairs(self.tabs) do
		tabs[i] = {
			name = tab.name,
			type = tab.panel.ClassName,
			state = tab.panel:GetSessionState()
		}
	end

	return {
		tabs = tabs,
		active_tab = self:GetActive()
	}
end

function TabHandler:SetSessionState(state)
	local x, y = self:GetPos()
	y = y + self.bar_size
	local w, h = self:GetSize()

	for i, tab in ipairs(state.tabs or {}) do
		local panel = vgui.Create(tab.type)
		local t = self:AddTab(tab.name, panel, i, true)
		self:PerformLayoutTab(t, w, h, true)
		panel:SetSessionState(tab.state)
	end

	self:SetActive(state.active_tab)
end

function TabHandler:ForceMovePanel(panel)
	local tab = self:AddTab(panel.GetName and panel:GetName() or "untitled", panel, self.active_tab + 1, true).tab
	-- local tab = self:Add("E4SyperTab")
	-- tab:Setup(self, panel.GetName and panel:GetName() or "Untitled", panel)
	-- tab:SetParent(self)
	tab:OnMousePressed(MOUSE_LEFT)

	self.hold_offset = {tab:GetWide() / 2, tab:GetTall() / 2}
end

vgui.Register("E4SyperTabHandler", TabHandler, "Panel")