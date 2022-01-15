-- TODO: make look even nicer
-- TODO: make tab closing use this
local settings = ExpressiveEditor.Settings.settings
----------------------------------------
local Browser = {}

function Browser:Init()
	self.path = "/"
	self.mode_save = true
	self.allow_folders = true
	self.allow_files = true
	self.top = self:Add("Panel")
	self.top:SetHeight(20)
	self.top:Dock(TOP)
	self.moveup = self.top:Add("E4SyperButton")
	self.moveup:SetWide(20)
	self.moveup:Dock(LEFT)
	self.moveup:SetText("^")
	self.moveup:SetFont("syper_ide")
	self.moveup:SetDoubleClickingEnabled(false)

	self.moveup.DoClick = function()
		if self.path == "/" then return end
		self:SetPath(string.sub(self.path, 1, string.match(self.path, "()[^/]*/?$") - 1))
	end

	self.path_entry = self.top:Add("E4SyperTextEntry")
	self.path_entry:Dock(FILL)
	self.path_entry:SetFont("syper_ide")
	self.path_entry:SetKeepFocusOnAutoComplete(true)

	self.path_entry.OnEnter = function(_, path)
		if not file.Exists(path, "DATA") then
			_:SetText(self.path)
		elseif file.IsDir(path, "DATA") then
			self:SetPath(path)
		else
			self:SetPath(string.sub(path, 1, string.match(path, "()[^/]+/$") - 1))
		end
	end

	self.path_entry.OnLoseFocus = function(_)
		_:OnEnter(_:GetText())
	end

	self.path_entry.GetAutoComplete = function(_, str)
		local path = string.sub(_:GetText(), 1, string.match(_:GetText(), "()[^/]*$") - 1)
		if not file.IsDir(path, "DATA") then return end
		str = string.match(str, "/?([^/]*)$")
		local tbl = {}
		local len = #str

		for _, s in ipairs(select(2, file.Find(path .. "*", "DATA"))) do
			if string.sub(s, 1, len) == str then
				tbl[#tbl + 1] = s
			end
		end

		return tbl
	end

	self.path_entry.AutoCompleteSelect = function(_, str)
		str = string.sub(_:GetText(), 1, string.match(_:GetText(), "()[^/]*$") - 1) .. str
		_:SetText(str)
		_:SetCaretPos(#str)
	end

	self.bottom = self:Add("Panel")
	self.bottom:SetHeight(20)
	self.bottom:Dock(BOTTOM)
	self.confirm = self.bottom:Add("E4SyperButton")
	self.confirm:SetWide(80)
	self.confirm:Dock(RIGHT)
	self.confirm:SetFont("syper_ide")
	self.confirm:SetDoubleClickingEnabled(false)
	self.cancel = self.bottom:Add("E4SyperButton")
	self.cancel:SetWide(80)
	self.cancel:Dock(RIGHT)
	self.cancel:SetText("Cancel")
	self.cancel:SetFont("syper_ide")
	self.cancel:SetDoubleClickingEnabled(false)

	self.cancel.DoClick = function()
		self:Remove()

		if self.OnCancel then
			self:OnCancel()
		end
	end

	self.name_entry_autocomplete = {}
	self.name_entry = self.bottom:Add("E4SyperTextEntry")
	self.name_entry:Dock(FILL)
	self.name_entry:SetFont("syper_ide")

	self.name_entry.OnChange = function(_)
		self.confirm:SetEnabled(ExpressiveEditor.validFileName(_:GetText()))
	end

	self.name_entry.GetAutoComplete = function(_, str)
		local tbl = {}
		local len = #str

		for _, s in ipairs(self.name_entry_autocomplete) do
			if string.sub(s, 1, len) == str then
				tbl[#tbl + 1] = s
			end
		end

		return tbl
	end

	self.holder = self:Add("DScrollPanel")
	self.holder:Dock(FILL)

	self.holder.Paint = function(_, w, h)
		surface.SetDrawColor(settings.style_data.ide_ui_light)
		surface.DrawRect(0, 0, w, h)

		return true
	end

	self:ModeSave()
end

function Browser:Paint(w, h)
	surface.SetDrawColor(settings.style_data.ide_ui)
	surface.DrawRect(0, 0, w, h)

	return true
end

function Browser:ModeSave()
	self:SetTitle("Save")
	self.mode_save = true
	self.name_entry:SetVisible(true)
	self.confirm:SetText("Save")
	self.confirm:SetEnabled(ExpressiveEditor.validFileName(self.name_entry:GetText()))

	self.confirm.DoClick = function()
		self:Remove()

		if self.OnConfirm then
			self:OnConfirm(self.path .. self.name_entry:GetText())
		end
	end
end

function Browser:ModeOpen()
	self:SetTitle((self.allow_folders and self.allow_files) and "Open" or (self.allow_folders and "Open Folder" or "Open File"))
	self.mode_save = false
	self.name_entry:SetVisible(true)
	self.confirm:SetText("Open")

	self.confirm.DoClick = function()
		self:Remove()

		if self.OnConfirm then
			self:OnConfirm(self.path .. self.name_entry:GetText())
		end
	end
end

function Browser:SetPath(path)
	path = string.sub(path, -1, -1) == "/" and path or path .. "/"
	path = string.sub(path, 1, 1) == "/" and string.sub(path, 2) or path
	local name

	if not file.IsDir(path, "DATA") then
		local s, n = string.match(path, "/?()([^/]+)/?$")
		path = string.sub(path, 1, s - 1)
		name = n
	end

	self.path = path
	self.path_entry:SetText(path)

	for _, node in ipairs(self.holder.pnlCanvas:GetChildren()) do
		node:Remove()
	end

	local moveup = self.holder.pnlCanvas:Add("DButton")
	moveup:SetHeight(20)
	moveup:Dock(TOP)
	moveup:SetText("../")
	moveup.DoClick = self.moveup.DoClick

	moveup.Paint = function(_, w, h)
		if _.Hovered then
			surface.SetDrawColor(settings.style_data.ide_ui_dark)
			surface.DrawRect(0, 0, w, h)
		end

		surface.SetTextColor(settings.style_data.ide_foreground)
		surface.SetFont("syper_ide")
		local str = _:GetText()
		local tw, th = surface.GetTextSize(str)
		surface.SetTextPos((h - th) / 2, (h - th) / 2)
		surface.DrawText(str)

		return true
	end

	local selected = nil
	local files, dirs = file.Find(self.path .. "*", "DATA")

	for _, dir in ipairs(dirs) do
		local node = self.holder.pnlCanvas:Add("DButton")
		node:SetHeight(20)
		node:Dock(TOP)
		node:SetText("[DIR] " .. dir)

		node.DoClick = function(_)
			selected = _
			self.name_entry:SetText(dir)

			if not self.mode_save then
				self.confirm:SetEnabled(self.allow_folders)
			end
		end

		node.DoDoubleClick = function()
			self:SetPath(path .. dir .. "/")
		end

		node.Paint = function(_, w, h)
			if _.Hovered then
				surface.SetDrawColor(settings.style_data.ide_ui_dark)
				surface.DrawRect(0, 0, w, h)
			end

			if selected == _ then
				surface.SetDrawColor(settings.style_data.ide_ui_accent)
				surface.DrawRect(1, 1, w - 2, h - 2)
			end

			surface.SetTextColor(settings.style_data.ide_foreground)
			surface.SetFont("syper_ide")
			local str = _:GetText()
			local tw, th = surface.GetTextSize(str)
			surface.SetTextPos((h - th) / 2, (h - th) / 2)
			surface.DrawText(str)

			return true
		end
	end

	self.name_entry_autocomplete = files

	for _, file in ipairs(files) do
		local node = self.holder.pnlCanvas:Add("DButton")
		node:SetHeight(20)
		node:Dock(TOP)
		node:SetText("[FILE] " .. file)

		node.DoClick = function(_)
			selected = _
			self.name_entry:SetText(file)
			self.name_entry:OnTextChanged()

			if not self.mode_save then
				self.confirm:SetEnabled(self.allow_files)
			end
		end

		node.Paint = function(_, w, h)
			if _.Hovered then
				surface.SetDrawColor(settings.style_data.ide_ui_dark)
				surface.DrawRect(0, 0, w, h)
			end

			if selected == _ then
				surface.SetDrawColor(settings.style_data.ide_ui_accent)
				surface.DrawRect(1, 1, w - 2, h - 2)
			end

			surface.SetTextColor(settings.style_data.ide_foreground)
			surface.SetFont("syper_ide")
			local str = _:GetText()
			local tw, th = surface.GetTextSize(str)
			surface.SetTextPos((h - th) / 2, (h - th) / 2)
			surface.DrawText(str)

			return true
		end

		if name == file then
			node:DoClick()
		end
	end
end

vgui.Register("E4SyperBrowser", Browser, "DFrame")