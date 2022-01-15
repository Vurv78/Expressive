do
	local add = ExpressiveEditor.include
	add("scrollbar_h.lua", true)
	add("base.lua", true)
	add("base_textentry.lua", true)
	add("divider_h.lua", true)
	add("divider_v.lua", true)
	add("textentry.lua", true)
	add("button.lua", true)
	add("tabhandler.lua", true)
	add("tree.lua", true)
	add("editor.lua", true)
	add("html.lua", true)
	add("browser.lua", true)
	add("menu.lua", true)
	-- E4 Additions
	add("console.lua", true)
	add("helper.lua", true)
end

if SERVER then return end
local Settings = ExpressiveEditor.Settings
local settings = Settings.settings
local FT = ExpressiveEditor.FILETYPE
----------------------------------------
local Act = {}

function Act.save(self, force_browser)
	local panel = vgui.GetKeyboardFocus()
	if not panel or not IsValid(panel) or panel.ClassName ~= "E4SyperEditor" then return end
	self:Save(panel, force_browser)
end

function Act.command_overlay(self, str)
	if self.active_menu then
		self.active_menu:Hide()
		self.active_menu:Dock(NODOCK)
		self:InvalidateLayout(true)
		self.old_focus:RequestFocus()
	else
		self.old_focus = vgui.GetKeyboardFocus()
	end

	if self.active_menu ~= self.menu_command then
		self.menu_command.entry:SetText(str)
		self.menu_command.entry:SetCaretPos(#str)
		self.menu_command.entry:RequestFocus()
		self.menu_command:Show()
		self.menu_command:Dock(BOTTOM)
		self.active_menu = self.menu_command
	else
		self.active_menu = nil
	end
end

function Act.find(self)
	if self.active_menu then
		self.active_menu:Hide()
		self.active_menu:Dock(NODOCK)
		self:InvalidateLayout(true)
		self.old_focus:RequestFocus()
	else
		self.old_focus = vgui.GetKeyboardFocus()
	end

	if self.active_menu ~= self.menu_find then
		self.menu_find:Show()
		self.menu_find:Dock(BOTTOM)
		self.active_menu = self.menu_find
		self.menu_find.find:RequestFocus()
		self.menu_find.find:OnTextChanged()
	else
		if self.old_focus.ClassName == "E4SyperEditor" then
			self.old_focus:ClearHighlight()
		end

		self.active_menu = nil
	end
end

function Act.replace(self)
	if self.active_menu then
		self.active_menu:Hide()
		self.active_menu:Dock(NODOCK)
		self:InvalidateLayout(true)
		self.old_focus:RequestFocus()
	else
		self.old_focus = vgui.GetKeyboardFocus()
	end

	if self.active_menu ~= self.menu_replace then
		self.menu_replace:Show()
		self.menu_replace:Dock(BOTTOM)
		self.active_menu = self.menu_replace
		self.menu_replace.regex:SetToggle(self.menu_find.regex:GetToggle())
		self.menu_replace.case:SetToggle(self.menu_find.case:GetToggle())
		self.menu_replace.whole:SetToggle(self.menu_find.whole:GetToggle())
		-- self.menu_replace.selection:SetToggle(self.menu_find.selection:GetToggle())
		self.menu_replace.wrap:SetToggle(self.menu_find.wrap:GetToggle())
		self.menu_replace.find:SetValue(self.menu_find.find:GetValue())
		self.menu_replace.find:SetCaretPos(self.menu_find.find:GetCaretPos())
		self.menu_replace.find:RequestFocus()
		self.menu_replace.find:OnTextChanged()
	else
		if self.old_focus.ClassName == "E4SyperEditor" then
			self.old_focus:ClearHighlight()
		end

		self.active_menu = nil
	end
end

function Act.focus(self, typ, index)
	local panel = vgui.GetKeyboardFocus()
	if not panel.SyperBase then return end

	if typ == "prev" then
		local panel = vgui.GetKeyboardFocus()
		if not panel.SyperBase then return end
		panel:FocusPrevious()
	elseif typ == "next" then
		local panel = vgui.GetKeyboardFocus()
		if not panel.SyperBase then return end
		panel:FocusNext()
	elseif typ == "tab" then
		local th = panel:FindTabHandler()
		if index < 1 or index > th:GetTabCount() then return end
		th:SetActive(index)
	end
end

----------------------------------------
local DFrame

local IDE = {
	Act = Act
}

function IDE:Init()
	DFrame = DFrame or vgui.GetControlTable("DFrame")
	self.last_save = CurTime()
	self:SetSizable(true)
	self:SetTitle("Syper")
	self:SetMinWidth(640)
	self:SetMinWidth(480)

	do
		self.bar = self:Add("DMenuBar")
		self.bar:Dock(TOP)
		local file = self.bar:AddMenu("File")

		do
			file:AddOption("New File", function()
				local editor = self:Add("E4SyperEditor")
				editor:SetSyntax("text")
				editor:SetContent("")
				self:AddTab(nil, editor)
			end)

			file:AddOption("Open File", function()
				local browser = vgui.Create("E4SyperBrowser")
				local x, y = self:LocalToScreen(self:GetWide() / 2, self:GetTall() / 2)
				browser:SetPos(x - 240, y - 180)
				browser:SetSize(480, 360)
				browser:MakePopup()
				browser.allow_folders = false
				browser:ModeOpen()
				browser:SetPath("/")

				browser.OnConfirm = function(_, path)
					local editor = self:Add("E4SyperEditor")
					editor:SetSyntax(ExpressiveEditor.SyntaxFromPath(path))
					editor:SetPath(path)
					editor:ReloadFile()
					self:AddTab(string.match(path, "([^/]*)$"), editor)
				end
			end)

			file:AddOption("Open Folder", function()
				local browser = vgui.Create("E4SyperBrowser")
				local x, y = self:LocalToScreen(self:GetWide() / 2, self:GetTall() / 2)
				browser:SetPos(x - 240, y - 180)
				browser:SetSize(480, 360)
				browser:MakePopup()
				browser.allow_files = false
				browser:ModeOpen()
				browser:SetPath("/")

				browser.OnConfirm = function(_, path)
					self.filetree:AddDirectory(path)
					self.filetree:InvalidateLayout()
				end
			end)

			file:AddOption("Open GitHub", function()
				self:TextEntry("Enter GitHub Link", "", function(path)
					self.filetree:AddDirectory(path, "GITHUB")
					self.filetree:InvalidateLayout()
				end, function(path) return string.find(path, "github%.com/([^/]+)/([^/]+)") end)
			end)
		end

		local config = self.bar:AddMenu("Config")

		do
			config:AddOption("Keybinds", function()
				local def = self:Add("E4SyperEditor")
				def:SetSyntax("json")
				def:SetContent(include("syper/default_binds.lua"))
				def:SetEditable(false)
				local conf = self:Add("E4SyperEditor")
				conf:SetSyntax("json")
				conf:SetPath("syper/keybinds.json")
				conf:ReloadFile()
				local div = self:Add("E4SyperHDivider")
				div:SetLeft(def)
				div:SetRight(conf)
				self:AddTab("Keybinds", div)
				div:CenterDiv()
			end)

			config:AddOption("Settings", function()
				local def = self:Add("E4SyperEditor")
				def:SetSyntax("json")
				def:SetContent(include("syper/default_settings.lua"))
				def:SetEditable(false)
				local conf = self:Add("E4SyperEditor")
				conf:SetSyntax("json")
				conf:SetPath("syper/settings.json")
				conf:ReloadFile()
				local div = self:Add("E4SyperHDivider")
				div:SetLeft(def)
				div:SetRight(conf)
				self:AddTab("Settings", div)
				div:CenterDiv()
			end)
		end
	end

	local E4HelperBtn = self.bar:Add("DButton")

	do
		E4HelperBtn:Dock(RIGHT)

		E4HelperBtn.DoClick = function()
			if not self.e4helper then
				local E4Helper = self:Add("E4Helper")
				self.e4helper = E4Helper
			end
		end

		E4HelperBtn.Paint = function()
			surface.SetDrawColor(Color(0, 0, 0, 0))
			surface.DrawRect(0, 0, E4HelperBtn:GetWide(), E4HelperBtn:GetTall())
		end
	end

	do
		self.tabhandler = self:Add("E4SyperTabHandler")
	end

	do
		self.filetree = self:Add("E4SyperTree")

		self.filetree.OnNodePress = function(_, node)
			local tabhandler = self:GetActiveTabHandler()

			for i, tab in ipairs(tabhandler.tabs) do
				if tab.panel.path == node.path then
					tabhandler:SetActive(i)

					return
				end
			end

			local typ = ExpressiveEditor.FILEEXTTYPE[ExpressiveEditor.getExtension(node.path)]

			if not typ or typ == FT.Generic or typ == FT.Code then
				local editor = self:Add("E4SyperEditor")
				editor:SetSyntax(ExpressiveEditor.SyntaxFromPath(node.path))

				if node.root_path == "GITHUB" then
					editor.loading = true

					ExpressiveEditor.fetchGitHubFile(node.path, function(content)
						editor.loading = false
						editor:SetContent(content)
					end)
				else
					editor:SetPath(node.path, node.root_path)
					editor:ReloadFile()
				end

				self:AddTab(node.name, editor)
			elseif typ == FT.Image then
				local viewer = self:Add("E4SyperHTML")
				viewer:OpenImg(node.root_path == "GITHUB" and ExpressiveEditor.getGitHubRaw(node.path) or node.path)
				self:AddTab(node.name, viewer)
			elseif typ == FT.Video then
				local viewer = self:Add("E4SyperHTML")
				viewer:OpenVideo(node.root_path == "GITHUB" and ExpressiveEditor.getGitHubRaw(node.path) or node.path)
				self:AddTab(node.name, viewer)
			elseif typ == FT.Audio then
				local viewer = self:Add("E4SyperHTML")
				viewer:OpenAudio(node.root_path == "GITHUB" and ExpressiveEditor.getGitHubRaw(node.path) or node.path)
				self:AddTab(node.name, viewer)
			end
		end
	end

	local function validFocus()
		if self.old_focus.ClassName ~= "E4SyperEditor" then return false end
		if not self.old_focus.highlight_bounds then return false end
		if #self.old_focus.highlight_bounds == 0 then return false end

		return true
	end

	do
		self.menu_command = self:Add("Panel")
		self.menu_command:DockPadding(0, 4, 0, 0)
		self.menu_command:SetHeight(30)
		local entry = self.menu_command:Add("E4SyperTextEntry")
		entry:Dock(FILL)
		entry:SetFont("syper_ide")

		entry.OnKeyCodeTyped = function(_, key)
			if key == KEY_ENTER then
				self.menu_command:Hide()
				self.menu_command:Dock(NODOCK)
				self:InvalidateLayout(true)
				self.old_focus:RequestFocus()
				self.active_menu = nil
				local str = entry:GetText()
				local c = string.sub(str, 1, 1)
				str = string.sub(str, 2)

				if c == ":" then
					local num = tonumber(string.match(str, "(%-?%d+)"))

					if num and self.old_focus.ClassName == "E4SyperEditor" then
						self.old_focus.Act.goto_line(self.old_focus, num)
					end
				end
			end

			return self:OnKeyCodeTyped(key)
		end

		self.menu_command.entry = entry
		self.menu_command:Hide()
	end

	do
		self.menu_find = self:Add("Panel")
		self.menu_find:DockPadding(0, 4, 0, 0)
		self.menu_find:SetHeight(30)
		-- TODO: better looking tooltips
		local regex = self.menu_find:Add("E4SyperButton")
		regex:DockMargin(0, 0, 2, 0)
		regex:SetWidth(30)
		regex:Dock(LEFT)
		regex:SetIsToggle(true)
		regex:SetFont("syper_ide")
		regex:SetText(".*")
		regex:SetTooltip("Patterns")

		regex.OnToggled = function()
			self.menu_find.find:OnTextChanged()
		end

		self.menu_find.regex = regex
		local case = self.menu_find:Add("E4SyperButton")
		case:DockMargin(0, 0, 2, 0)
		case:SetWidth(30)
		case:Dock(LEFT)
		case:SetIsToggle(true)
		case:SetFont("syper_ide")
		case:SetText("Aa")
		case:SetTooltip("Case Sensitive")

		case.OnToggled = function()
			self.menu_find.find:OnTextChanged()
		end

		self.menu_find.case = case
		local whole = self.menu_find:Add("E4SyperButton")
		whole:DockMargin(0, 0, 2, 0)
		whole:SetWidth(30)
		whole:Dock(LEFT)
		whole:SetIsToggle(true)
		whole:SetFont("syper_ide")
		whole:SetText("\" \"")
		whole:SetTooltip("Whole Word")

		whole.OnToggled = function()
			self.menu_find.find:OnTextChanged()
		end

		self.menu_find.whole = whole
		-- local selection = self.menu_find:Add("E4SyperButton")
		-- selection:DockMargin(0, 0, 2, 0)
		-- selection:SetWidth(30)
		-- selection:Dock(LEFT)
		-- selection:SetIsToggle(true)
		-- selection:SetFont("syper_ide")
		-- selection:SetText("[ ]")
		-- selection:SetTooltip("In Selection")
		-- selection.OnToggled = function()
		-- 	self.menu_find.find:OnTextChanged()
		-- end
		-- self.menu_find.selection = selection
		local wrap = self.menu_find:Add("E4SyperButton")
		wrap:DockMargin(0, 0, 2, 0)
		wrap:SetWidth(30)
		wrap:Dock(LEFT)
		wrap:SetIsToggle(true)
		wrap:SetFont("syper_ide")
		wrap:SetText("^")
		wrap:SetTooltip("Wrap")
		self.menu_find.wrap = wrap
		local all = self.menu_find:Add("E4SyperButton")
		all:DockMargin(2, 0, 0, 0)
		all:SetWidth(100)
		all:Dock(RIGHT)
		all:SetFont("syper_ide")
		all:SetText("Find All")

		all.DoClick = function()
			if not validFocus() then return end
			self.old_focus.carets = {}

			for i, find in ipairs(self.old_focus.highlight_bounds) do
				self.old_focus:AddCaret(find.ex + 1, find.ey, find.sx + 1, find.sy)
				self.old_focus:UpdateCaretInfo(1)
			end

			self.menu_find:Hide()
			self.menu_find:Dock(NODOCK)
			self:InvalidateLayout(true)
			self.old_focus:RequestFocus()
			self.old_focus:ClearHighlight()
			self.active_menu = nil
		end

		local prv = self.menu_find:Add("E4SyperButton")
		prv:DockMargin(2, 0, 0, 0)
		prv:SetWidth(100)
		prv:Dock(RIGHT)
		prv:SetFont("syper_ide")
		prv:SetText("Find Prev")

		prv.DoClick = function()
			if not validFocus() then return end

			for i = 2, #self.old_focus.carets do
				self.old_focus.carets[i] = nil
			end

			local caret = self.old_focus.carets[1]

			for i = #self.old_focus.highlight_bounds, 1, -1 do
				local bounds = self.old_focus.highlight_bounds[i]

				if bounds.ey < caret.y or (bounds.ey == caret.y and bounds.ex < caret.x - 1) then
					caret.x = bounds.ex + 1
					caret.y = bounds.ey
					caret.select_x = bounds.sx + 1
					caret.select_y = bounds.sy
					self.old_focus:UpdateCaretInfo(1)
					self.old_focus:MarkScrollToCaret()

					return
				end
			end

			if wrap:GetToggle() then
				local bounds = self.old_focus.highlight_bounds[#self.old_focus.highlight_bounds]
				caret.x = bounds.ex + 1
				caret.y = bounds.ey
				caret.select_x = bounds.sx + 1
				caret.select_y = bounds.sy
				self.old_focus:UpdateCaretInfo(1)
				self.old_focus:MarkScrollToCaret()
			end
		end

		local nxt = self.menu_find:Add("E4SyperButton")
		nxt:DockMargin(2, 0, 0, 0)
		nxt:SetWidth(100)
		nxt:Dock(RIGHT)
		nxt:SetFont("syper_ide")
		nxt:SetText("Find")

		nxt.DoClick = function()
			if not validFocus() then return end

			for i = 2, #self.old_focus.carets do
				self.old_focus.carets[i] = nil
			end

			local caret = self.old_focus.carets[1]

			for i = 1, #self.old_focus.highlight_bounds do
				local bounds = self.old_focus.highlight_bounds[i]

				if bounds.ey > caret.y or (bounds.ey == caret.y and bounds.ex >= caret.x) then
					caret.x = bounds.ex + 1
					caret.y = bounds.ey
					caret.select_x = bounds.sx + 1
					caret.select_y = bounds.sy
					self.old_focus:UpdateCaretInfo(1)
					self.old_focus:MarkScrollToCaret()

					return
				end
			end

			if wrap:GetToggle() then
				local bounds = self.old_focus.highlight_bounds[1]
				caret.x = bounds.ex + 1
				caret.y = bounds.ey
				caret.select_x = bounds.sx + 1
				caret.select_y = bounds.sy
				self.old_focus:UpdateCaretInfo(1)
				self.old_focus:MarkScrollToCaret()
			end
		end

		local find = self.menu_find:Add("E4SyperTextEntry")
		find:Dock(FILL)
		find:SetFont("syper_ide")

		find.OnKeyCodeTyped = function(_, key)
			if key == KEY_ENTER then
				nxt:DoClick()
			end

			return self:OnKeyCodeTyped(key)
		end

		find.OnTextChanged = function()
			if self.old_focus.ClassName ~= "E4SyperEditor" then return end
			local str = find:GetValue()

			if #str == 0 then
				self.old_focus:ClearHighlight()

				return
			end

			self.old_focus:Highlight(ExpressiveEditor.HandleStringEscapes(str), regex:GetToggle(), case:GetToggle(), whole:GetToggle(), nil)
		end

		self.menu_find.find = find
		self.menu_find:Hide()
	end

	do
		self.menu_replace = self:Add("Panel")
		self.menu_replace:DockPadding(0, 4, 0, 0)
		self.menu_replace:SetHeight(66)
		local top = self.menu_replace:Add("Panel")
		top:SetHeight(30)
		top:Dock(TOP)
		local regex = top:Add("E4SyperButton")
		regex:DockMargin(0, 0, 2, 0)
		regex:SetWidth(30)
		regex:Dock(LEFT)
		regex:SetIsToggle(true)
		regex:SetFont("syper_ide")
		regex:SetText(".*")
		regex:SetTooltip("Patterns")

		regex.OnToggled = function()
			self.menu_find.regex:Toggle()
		end

		self.menu_replace.regex = regex
		local case = top:Add("E4SyperButton")
		case:DockMargin(0, 0, 2, 0)
		case:SetWidth(30)
		case:Dock(LEFT)
		case:SetIsToggle(true)
		case:SetFont("syper_ide")
		case:SetText("Aa")
		case:SetTooltip("Case Sensitive")

		case.OnToggled = function()
			self.menu_find.case:Toggle()
		end

		self.menu_replace.case = case
		local find_text = top:Add("Panel")
		find_text:DockMargin(0, 0, 2, 0)
		find_text:SetWidth(80)
		find_text:Dock(LEFT)

		find_text.Paint = function(self, w, h)
			surface.SetTextColor(settings.style_data.ide_foreground)
			surface.SetFont("syper_ide")
			local str = "Find:"
			local tw, th = surface.GetTextSize(str)
			surface.SetTextPos(w - tw, (h - th) / 2)
			surface.DrawText(str)

			return true
		end

		local all = top:Add("E4SyperButton")
		all:DockMargin(2, 0, 0, 0)
		all:SetWidth(100)
		all:Dock(RIGHT)
		all:SetFont("syper_ide")
		all:SetText("Find All")

		all.DoClick = function()
			if not validFocus() then return end
			self.old_focus.carets = {}

			for i, find in ipairs(self.old_focus.highlight_bounds) do
				self.old_focus:AddCaret(find.ex + 1, find.ey, find.sx + 1, find.sy)
				self.old_focus:UpdateCaretInfo(1)
			end

			self.menu_find:Hide()
			self.menu_find:Dock(NODOCK)
			self:InvalidateLayout(true)
			self.old_focus:RequestFocus()
			self.old_focus:ClearHighlight()
			self.active_menu = nil
		end

		local nxt = top:Add("E4SyperButton")
		nxt:DockMargin(2, 0, 0, 0)
		nxt:SetWidth(100)
		nxt:Dock(RIGHT)
		nxt:SetFont("syper_ide")
		nxt:SetText("Find")

		nxt.DoClick = function()
			if not validFocus() then return end

			for i = 2, #self.old_focus.carets do
				self.old_focus.carets[i] = nil
			end

			local caret = self.old_focus.carets[1]

			for i = 1, #self.old_focus.highlight_bounds do
				local bounds = self.old_focus.highlight_bounds[i]

				if bounds.ey > caret.y or (bounds.ey == caret.y and bounds.ex >= caret.x) then
					caret.x = bounds.ex + 1
					caret.y = bounds.ey
					caret.select_x = bounds.sx + 1
					caret.select_y = bounds.sy
					self.old_focus:UpdateCaretInfo(1)
					self.old_focus:MarkScrollToCaret()

					return
				end
			end

			if self.menu_replace.wrap:GetToggle() then
				local bounds = self.old_focus.highlight_bounds[1]
				caret.x = bounds.ex + 1
				caret.y = bounds.ey
				caret.select_x = bounds.sx + 1
				caret.select_y = bounds.sy
				self.old_focus:UpdateCaretInfo(1)
				self.old_focus:MarkScrollToCaret()
			end
		end

		local find = top:Add("E4SyperTextEntry")
		find:Dock(FILL)
		find:SetFont("syper_ide")
		find.OnKeyCodeTyped = self.menu_find.find.OnKeyCodeTyped

		find.OnTextChanged = function()
			self.menu_find.find:SetValue(find:GetValue())
			self.menu_find.find:OnTextChanged()
		end

		self.menu_replace.find = find
		local bottom = self.menu_replace:Add("Panel")
		bottom:SetHeight(30)
		bottom:Dock(BOTTOM)
		local whole = bottom:Add("E4SyperButton")
		whole:DockMargin(0, 0, 2, 0)
		whole:SetWidth(30)
		whole:Dock(LEFT)
		whole:SetIsToggle(true)
		whole:SetFont("syper_ide")
		whole:SetText("\" \"")
		whole:SetTooltip("Whole Word")

		whole.OnToggled = function()
			self.menu_find.whole:Toggle()
		end

		self.menu_replace.whole = whole
		-- local selection = bottom:Add("E4SyperButton")
		-- selection:DockMargin(0, 0, 2, 0)
		-- selection:SetWidth(30)
		-- selection:Dock(LEFT)
		-- selection:SetIsToggle(true)
		-- selection:SetFont("syper_ide")
		-- selection:SetText("[ ]")
		-- selection:SetTooltip("In Selection")
		-- selection.DoClick = self.menu_find.selection.DoClick
		-- self.menu_replace.selection = selection
		local wrap = bottom:Add("E4SyperButton")
		wrap:DockMargin(0, 0, 2, 0)
		wrap:SetWidth(30)
		wrap:Dock(LEFT)
		wrap:SetIsToggle(true)
		wrap:SetFont("syper_ide")
		wrap:SetText("^")
		wrap:SetTooltip("Wrap")

		wrap.OnToggled = function()
			self.menu_find.wrap:Toggle()
		end

		self.menu_replace.wrap = wrap
		local replace_text = bottom:Add("Panel")
		replace_text:DockMargin(0, 0, 2, 0)
		replace_text:SetWidth(80)
		replace_text:Dock(LEFT)

		replace_text.Paint = function(self, w, h)
			surface.SetTextColor(settings.style_data.ide_foreground)
			surface.SetFont("syper_ide")
			local str = "Replace:"
			local tw, th = surface.GetTextSize(str)
			surface.SetTextPos(w - tw, (h - th) / 2)
			surface.DrawText(str)

			return true
		end

		local repl_all = bottom:Add("E4SyperButton")
		repl_all:DockMargin(2, 0, 0, 0)
		repl_all:SetWidth(100)
		repl_all:Dock(RIGHT)
		repl_all:SetFont("syper_ide")
		repl_all:SetText("Replace All")

		repl_all.DoClick = function()
			if not validFocus() then return end
			self.old_focus:Replace(self.menu_replace.replace:GetValue())
			self.menu_find:Hide()
			self.menu_find:Dock(NODOCK)
			self:InvalidateLayout(true)
			self.old_focus:RequestFocus()
			self.old_focus:ClearHighlight()
			self.active_menu = nil
		end

		local repl_nxt = bottom:Add("E4SyperButton")
		repl_nxt:DockMargin(2, 0, 0, 0)
		repl_nxt:SetWidth(100)
		repl_nxt:Dock(RIGHT)
		repl_nxt:SetFont("syper_ide")
		repl_nxt:SetText("Replace")

		repl_nxt.DoClick = function()
			if not validFocus() then return end
			nxt:DoClick()
			self.old_focus:RemoveSelection(true)
			self.old_focus:InsertStr(self.menu_replace.replace:GetValue())
			local caret = self.old_focus.carets[1]
			caret.select_x = nil
			caret.select_y = nil
			self.old_focus:UpdateCaretInfo(1)
			find:OnTextChanged()
		end

		local replace = bottom:Add("E4SyperTextEntry")
		replace:Dock(FILL)
		replace:SetFont("syper_ide")

		replace.OnKeyCodeTyped = function(_, key)
			if key == KEY_ENTER then
				repl_nxt:DoClick()
			end

			return self:OnKeyCodeTyped(key)
		end

		self.menu_replace.replace = replace
		self.menu_replace:Hide()
	end

	self.filetree_div = self:Add("E4SyperHDivider")
	self.filetree_div:Dock(FILL)
	self.filetree_div:StickLeft()
	self.filetree_div:SetLeft(self.filetree)
	self.filetree_div:SetRight(self.tabhandler)
end

function IDE:Paint(w, h)
	local time = CurTime()

	if self.save_session_time and (self.save_session_time < time or self.last_save < time - 300) then
		Settings.saveSession(self)
		self.save_session_time = nil
		self.last_save = time
	end

	surface.SetDrawColor(settings.style_data.ide_ui)
	surface.DrawRect(0, 0, w, h)

	return true
end

function IDE:OnKeyCodeTyped(key)
	local bind = Settings.lookupBind(input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL), input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT), input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT), key)

	if bind then
		local act = self.Act[bind.act]

		if act then
			act(self, unpack(bind.args or {}))

			return true
		end
	end
end

function IDE:OnMousePressed(key)
	local bind = Settings.lookupBind(input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL), input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT), input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT), key)

	if bind then
		local act = self.Act[bind.act]

		if act then
			act(self, unpack(bind.args or {}))

			return true
		end
	end

	DFrame.OnMousePressed(self, key)
end

function IDE:GetActiveTabHandler()
	return self.tabhandler
end

function IDE:AddTab(name, panel)
	local tabhandler = self:GetActiveTabHandler()
	tabhandler:AddTab(name or "untitled", panel, tabhandler:GetActive() + 1)

	if panel.SetName then
		panel:SetName(name)

		panel.OnNameChange = function(_, name)
			tabhandler:RenameTab(tabhandler:GetIndex(panel), name)
		end
	end

	self.filetree:Select((panel.root_path and panel.path) and self.filetree.nodes_lookup[panel.root_path] and self.filetree.nodes_lookup[panel.root_path][panel.path], true)
end

function IDE:Save(panel, force_browser)
	surface.PlaySound("ambient/water/drip3.wav")

	local function browser(relative_path)
		local save_panel = vgui.Create("E4SyperBrowser")
		local x, y = self:LocalToScreen(self:GetWide() / 2, self:GetTall() / 2)
		save_panel:SetPos(x - 240, y - 180)
		save_panel:SetSize(480, 360)
		save_panel:MakePopup()

		if relative_path then
			save_panel:SetPath(panel.path)
		else
			save_panel:SetPath("/")
		end

		save_panel.OnConfirm = function(_, path)
			local selected = panel.root_path and panel.path and self.filetree.nodes_lookup[panel.root_path][panel.path]
			panel:SetPath(path)
			local th = self:GetActiveTabHandler()
			th:RenameTab(th:GetIndex(panel), string.match(path, "([^/]+)/?$"))
			self.filetree:Refresh(panel.path, panel.root_path)

			if selected and selected.selected then
				self.filetree:Select(self.filetree.nodes_lookup[panel.root_path][panel.path], true)
			end
		end
	end

	if force_browser then
		browser(panel.root_path == "DATA" and panel.path)

		return
	end

	local saved, err = panel:Save()

	if not saved then
		browser(err == 4)
	else
		self.filetree:Refresh(panel.path, panel.root_path)

		if panel.root_path == "DATA" then
			if panel.path == "syper/keybinds.json" then
				Settings.loadBinds()
			elseif panel.path == "syper/settings.json" then
				Settings.loadSettings()
			end
		end
	end
end

function IDE:Delete(path)
	local single = type(path) == "string"

	local paths = single and {path} or path

	self:ConfirmPanel("Are you sure you want to delete\n" .. table.concat(paths, "\n"), function() end, function()
		local function deldir(path)
			path = string.sub(path, -1, -1) == "/" and path or path .. "/"
			path = string.sub(path, 1, 1) == "/" and string.sub(path, 2) or path
			local files, dirs = file.Find(path .. "*", "DATA")

			for _, name in ipairs(files) do
				file.Delete(path .. name)
			end

			for _, name in ipairs(dirs) do
				deldir(path .. name)
			end

			file.Delete(path)
		end

		for _, path in ipairs(paths) do
			if file.IsDir(path, "DATA") then
				deldir(path)
			else
				file.Delete(path)
			end

			self.filetree:Refresh(path, "DATA")
		end
	end)
end

function IDE:TextEntry(title, text, on_confirm, allow)
	local frame = vgui.Create("DFrame")
	local x, y = self:LocalToScreen(self:GetWide() / 2, self:GetTall() / 2)
	frame:SetPos(x - 180, y - 27)
	frame:SetSize(360, 54)
	frame:SetTitle(title)

	frame.Paint = function(_, w, h)
		surface.SetDrawColor(settings.style_data.ide_ui)
		surface.DrawRect(0, 0, w, h)

		return true
	end

	frame.confirm = frame:Add("E4SyperButton")
	frame.confirm:SetWide(80)
	frame.confirm:Dock(RIGHT)
	frame.confirm:SetText("Confirm")
	frame.confirm:SetFont("syper_ide")
	frame.confirm:SetDoubleClickingEnabled(false)
	frame.confirm:SetEnabled(allow(text))

	frame.confirm.DoClick = function(self)
		frame:Remove()
		on_confirm(frame.entry:GetText())
	end

	frame.entry = frame:Add("E4SyperTextEntry")
	frame.entry:Dock(FILL)
	frame.entry:SetFont("syper_ide")
	frame.entry:SetText(text)
	frame.entry:SelectAllOnFocus()

	frame.entry.OnChange = function(self)
		frame.confirm:SetEnabled(allow(self:GetText()))
	end

	frame:MakePopup()
	frame.entry:RequestFocus()
end

function IDE:Rename(path)
	local name = string.match(path, "([^/]+)/?$")
	path = string.sub(path, 1, string.match(path, "()[^/]*/?$") - 1)
	local isdir = file.IsDir(path, "DATA")
	local allow = isdir and (function(text) return #text > 0 and not file.Exists(path .. text, "DATA") end) or (function(text) return ExpressiveEditor.validFileName(text) end)

	self:TextEntry("Rename", name, function(nname)
		local tab
		local tabhandler = self:GetActiveTabHandler()

		for i, t in ipairs(tabhandler.tabs) do
			if t.panel.path == path .. name then
				tab = t
				break
			end
		end

		file.Rename(path .. name, path .. nname)
		local node = self.filetree.nodes_lookup.DATA[path .. name] or self.filetree.nodes_lookup.DATA[path .. name .. "/"]

		if node.main_directory then
			self.filetree.nodes_lookup.DATA[path .. name .. "/"] = nil
			self.filetree.nodes_lookup.DATA[path .. nname .. "/"] = node
			node.name = nname
			node.path = path .. nname .. "/"
			self.filetree:Refresh()
		else
			self.filetree:Refresh(path, "DATA")

			if not isdir then
				if node.selected then
					self.filetree:Select(node, true)
				end
			end
		end

		if tab then
			tab.name = nname
			tab.tab.name = nname
			tab.panel:SetPath(path .. nname)
		end
	end, allow)
end

function IDE:ConfirmPanel(text, cancel_func, confirm_func)
	surface.SetFont("syper_ide")
	local tw, th = surface.GetTextSize(text)
	local frame = vgui.Create("DFrame")
	local x, y = self:LocalToScreen(self:GetWide() / 2, self:GetTall() / 2)
	frame:SetPos(x - 180, y - 27)
	frame:SetSize(360, 74 + th)
	frame:SetTitle("Are you sure?")

	frame.Paint = function(_, w, h)
		surface.SetDrawColor(settings.style_data.ide_ui)
		surface.DrawRect(0, 0, w, h)
		draw.DrawText(text, "syper_ide", w / 2, 29, settings.style_data.ide_foreground, 1)

		return true
	end

	frame.cancel = frame:Add("E4SyperButton")
	frame.cancel:SetPos(5, 39 + th)
	frame.cancel:SetSize(175, 30)
	frame.cancel:SetText("Cancel")
	frame.cancel:SetFont("syper_ide")

	frame.cancel.DoClick = function()
		frame:Remove()
		cancel_func()
	end

	frame.confirm = frame:Add("E4SyperButton")
	frame.confirm:SetPos(180, 39 + th)
	frame.confirm:SetSize(175, 30)
	frame.confirm:SetText("Confirm")
	frame.confirm:SetFont("syper_ide")

	frame.confirm.DoClick = function()
		frame:Remove()
		confirm_func()
	end

	frame:MakePopup()
end

function IDE:SaveSession()
	self.save_session_time = CurTime() + 1
end

vgui.Register("E4SyperIDE", IDE, "DFrame")

----------------------------------------
function ExpressiveEditor.OpenIDE()
	if IsValid(ExpressiveEditor.IDE) then
		ExpressiveEditor.IDE:Show()

		return
	end

	local ide = vgui.Create("E4SyperIDE")
	ide:SetDeleteOnClose(false)
	ide:MakePopup()
	ExpressiveEditor.IDE = ide
	Settings.loadSession(ide)
end