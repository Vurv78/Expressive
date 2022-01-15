local settings = ExpressiveEditor.Settings.settings
----------------------------------------
local TextEntry = {}

function TextEntry:Paint(w, h)
	surface.SetDrawColor(self:HasFocus() and settings.style_data.ide_ui_accent or settings.style_data.ide_ui_dark)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(settings.style_data.ide_ui_light)
	surface.DrawRect(1, 1, w - 2, h - 2)
	self:DrawTextEntryText(settings.style_data.ide_foreground, settings.style_data.ide_ui_accent, settings.style_data.ide_foreground)

	return true
end

function TextEntry:OnKeyCodeTyped(key)
	self:OnKeyCode(key)

	if key == KEY_ENTER and not self:IsMultiline() and self:GetEnterAllowed() then
		if IsValid(self.Menu) then
			self.Menu:Remove()

			if not self:KeepFocusOnAutoComplete() then
				self:FocusNext()
			end
		else
			self:FocusNext()
		end

		self:OnEnter(self:GetText())
		self.HistoryPos = 0
	end

	if self.m_bHistory or IsValid(self.Menu) then
		if key == KEY_UP then
			self.HistoryPos = self.HistoryPos - 1
			self:UpdateFromHistory()
		elseif key == KEY_DOWN or key == KEY_TAB then
			self.HistoryPos = self.HistoryPos + 1
			self:UpdateFromHistory()
		end
	end
end

function TextEntry:OnTextChanged(keep_menu)
	self.HistoryPos = 0

	if self:GetUpdateOnType() then
		self:UpdateConvarValue()
		self:OnValueChange(self:GetText())
	end

	if not keep_menu then
		self.nact = self:GetText()

		if IsValid(self.Menu) then
			self.Menu:Remove()
		end
	end

	local tbl = self:GetAutoComplete(self.nact)

	if tbl then
		self:OpenAutoComplete(tbl)
	end

	self:OnChange()
end

function TextEntry:OnGetFocus()
	local tbl = self:GetAutoComplete(self.nact or "")

	if tbl then
		self:OpenAutoComplete(tbl)
	end
end

function TextEntry:UpdateFromMenu()
	local pos = self.HistoryPos
	local num = self.Menu:ChildCount()
	self.Menu:ClearHighlights()

	if pos < 0 then
		pos = num
	end

	if pos > num then
		pos = 0
	end

	local item = self.Menu:GetChild(pos)

	if not item then
		self:SetText("")
		self.HistoryPos = pos

		return
	end

	self.Menu:HighlightItem(item)
	self:AutoCompleteSelect(item:GetText())
	self:OnTextChanged(true)
	self.HistoryPos = pos
end

function TextEntry:OpenAutoComplete(tbl)
	if not tbl or #tbl == 0 then return end
	self.Menu = ExpressiveEditor.Menu()

	for _, str in ipairs(tbl) do
		self.Menu:AddOption(str, function()
			self:AutoCompleteSelect(str)
		end)
	end

	local x, y = self:LocalToScreen(0, self:GetTall())
	self.Menu:SetMinimumWidth(self:GetWide())
	self.Menu:Open(x, y, true, self)
	self.Menu:SetPos(x, y)
	self.Menu:SetMaxHeight(ScrH() - y - 10)
end

function TextEntry:AutoCompleteSelect(str)
	self:SetText(str)
	self:SetCaretPos(#str)
end

function TextEntry:KeepFocusOnAutoComplete()
	return self.keepFocusOnAutoComplete
end

function TextEntry:SetKeepFocusOnAutoComplete(state)
	self.keepFocusOnAutoComplete = state
end

vgui.Register("E4SyperTextEntry", TextEntry, "DTextEntry")