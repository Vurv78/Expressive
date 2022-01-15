local settings = ExpressiveEditor.Settings.settings
----------------------------------------
local Divider = {}

function Divider:Init()
	self.div_size = 6
	self.div_pos = 0
	self.left = nil
	self.right = nil
	self.holding = false
	self.hold_offset = 0
	self.min_size = 50
	self.stick = 1
	self:SetCursor("sizewe")
end

function Divider:Paint(w, h)
	surface.SetDrawColor(settings.style_data.ide_background)
	surface.DrawRect(self.div_pos, 0, self.div_size, h)
end

function Divider:PerformLayout(w, h)
	if not self.left then return end
	if not self.right then return end

	if self.last_w then
		local div = self.last_w - w

		if self.stick == 0 then
			-- nothing, dont move
		elseif self.stick == 1 then
			self.div_pos = self.div_pos - div * (self.left:GetWide() / self.last_w)
		elseif self.stick == 2 then
			self.div_pos = self.div_pos - div
		end

		self.div_pos = math.Clamp(self.div_pos, self.min_size, w - self.min_size - self.div_size)
	end

	if self.first ~= nil then
		self.last_w = w
	else
		self.first = true
	end

	self.left:SetPos(0, 0)
	self.left:SetSize(self.div_pos, h)
	self.left:InvalidateLayout()
	self.right:SetPos(self.div_pos + self.div_size, 0)
	self.right:SetSize(w - self.div_pos - self.div_size, h)
	self.right:InvalidateLayout()
end

function Divider:FocusPreviousChild(cur_focus)
	if cur_focus == nil then
		return self.right
	elseif cur_focus == self.right then
		return self.left
	end
end

function Divider:FocusNextChild(cur_focus)
	if cur_focus == nil then
		return self.left
	elseif cur_focus == self.left then
		return self.right
	end
end

function Divider:OnCursorMoved(x, y)
	if not self.holding then return end
	self.div_pos = x - self.hold_offset
	self:InvalidateLayout()
end

function Divider:OnMousePressed(key)
	if key ~= MOUSE_LEFT then return end
	local x = self:LocalCursorPos()

	if x >= self.div_pos and x <= self.div_pos + self.div_size then
		self.holding = true
		self.hold_offset = x - self.div_pos
		self:MouseCapture(true)
	end
end

function Divider:OnMouseReleased(key)
	if key ~= MOUSE_LEFT then return end
	self.holding = false
	self:MouseCapture(false)
	ExpressiveEditor.IDE:SaveSession()
end

function Divider:SetColor(clr)
	self.clr = clr
end

function Divider:SetLeft(panel)
	self.left = panel
	panel:SetParent(self)
end

function Divider:SetRight(panel)
	self.right = panel
	panel:SetParent(self)
end

function Divider:CenterDiv()
	self:GetParent():InvalidateLayout(true)
	self.div_pos = self:GetWide() / 2 - self.div_size / 2
end

function Divider:SetDivSize(size)
	local dif = size - self.div_size
	self.div_size = size
	self.div_pos = self.div_pos - dif / 2
end

function Divider:StickLeft()
	self.stick = 0
end

function Divider:StickCenter()
	self.stick = 1
end

function Divider:StickRight()
	self.stick = 2
end

function Divider:GetSessionState()
	return {
		pos = self.div_pos,
		left = self.left.ClassName,
		left_state = self.left:GetSessionState(),
		right = self.right.ClassName,
		right_state = self.right:GetSessionState()
	}
end

function Divider:SetSessionState(state)
	self.div_pos = state.pos
	local left = vgui.Create(state.left)
	left:SetSessionState(state.left_state)
	self:SetLeft(left)
	local right = vgui.Create(state.right)
	right:SetSessionState(state.right_state)
	self:SetRight(right)
end

vgui.Register("E4SyperHDivider", Divider, "E4SyperBase")