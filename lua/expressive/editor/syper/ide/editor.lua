local ELib = require("expressive/library")

local Lexer = ExpressiveEditor.Lexer
local Mode = ExpressiveEditor.Mode
local Settings = ExpressiveEditor.Settings
local TOKEN = ExpressiveEditor.TOKEN
----------------------------------------
local editors = {}

hook.Add("SyperSettings", "e4_syper_editor", function(s)
	for editor, _ in pairs(editors) do
		editor:UpdateSettings(s)
	end
end)

----------------------------------------
local Act = {}

function Act.highlight(self, str, pattern, case, whole, bounds)
	self:Highlight(str, pattern, case, whole, bounds)
end

function Act.replace_highlight(self, replace)
	self:Replace(replace)
end

function Act.undo(self)
	self:Undo()
	self:CheckNameChanged()
end

function Act.redo(self)
	self:Redo()
	self:CheckNameChanged()
end

function Act.copy(self)
	local str, empty = {}, true

	local function add(s)
		str[#str + 1] = s
		empty = false
	end

	local lines = self.content_data.lines

	for caret_id = #self.carets, 1, -1 do
		local caret = self.carets[caret_id]

		if caret.select_x then
			local sx, sy = caret.x, caret.y
			local ex, ey = caret.select_x, caret.select_y

			if ey < sy or (ex < sx and sy == ey) then
				sx, sy, ex, ey = ex, ey, sx, sy
			end

			add(self.sub(lines[sy].str, sx, sy == ey and ex - 1 or -1))

			for y = sy + 1, ey - 1 do
				add(lines[y].str)
			end

			if sy ~= ey then
				add(self.sub(lines[ey].str, 1, ex - 1))
			end

			if caret_id > 1 then
				add("\n")
			end
		end
	end

	if empty then
		for caret_id = #self.carets, 1, -1 do
			add(lines[self.carets[caret_id].y].str)

			if caret_id > 1 then
				add("\n")
			end
		end
	end

	timer.Simple(0.1, function()
		SetClipboardText(table.concat(str, ""))
	end)
end

function Act.cut(self)
	Act.copy(self)

	if self:HasSelection() then
		self:RemoveSelection()
	else
		for caret_id, caret in ipairs(self.carets) do
			self:RemoveStrAt(1, caret.y, self.content_data:GetLineLength(caret.y), true)
		end

		self:PushHistoryBlock()
		self:Rebuild()
	end

	self:CheckNameChanged()
end

function Act.paste(self)
	self.is_pasted = 1
end

function Act.pasteindent(self)
	self.is_pasted = 2
end

function Act.newline(self)
	if self:HasSelection() then
		self:RemoveSelection()
	end

	-- TODO: fix bug with multiple caret smart auto indent
	for caret_id, caret in ipairs(self.carets) do
		if self.settings.indent_auto then
			local spacer, e = string.match(self.content_data:GetLineStr(caret.y), "^([^\n%S]*)()")
			local move = nil

			if self.settings.indent_smart then
				local tokens = self.content_data:GetLineTokens(caret.y)

				for i = #tokens, 1, -1 do
					local token = tokens[i]

					if caret.x > token.s then
						local indent_sum = 0

						for j = 1, i do
							local token = tokens[j]
							local outdent = self.mode.outdent[token.str]

							if outdent and not outdent[token.mode] then
								indent_sum = math.max(0, indent_sum - 1)
							end

							local indent = self.mode.indent[token.str]

							if indent and not indent[token.mode] then
								indent_sum = indent_sum + 1
							end
						end

						if indent_sum > 0 then
							local token2 = tokens[i + 1]

							if token2 then
								local bracket = self.mode.bracket2[token2.str]

								if bracket and not bracket.ignore_mode[token2.mode] then
									self:InsertStrAt(caret.x, caret.y, "\n" .. spacer .. self.tab_str, true)
									move = -e
								else
									spacer = spacer .. self.tab_str
								end
							else
								spacer = spacer .. self.tab_str
							end
						end

						break
					end
				end
			end

			self:InsertStrAt(caret.x, caret.y, "\n" .. spacer, true)

			if move then
				self:MoveCaret(caret_id, move, nil)
			end
		else
			self:InsertStrAt(caret.x, caret.y, "\n", true)
		end
	end

	self:PushHistoryBlock()
	self:Rebuild()
end

function Act.indent(self)
	for caret_id, caret in ipairs(self.carets) do
		if caret.select_y and caret.select_y ~= caret.y then
			for y = math.min(caret.y, caret.select_y), math.max(caret.y, caret.select_y) do
				self:InsertStrAt(1, y, self.tab_str, true)
			end

			caret.select_x = caret.select_x + self.tab_strsize
		else
			self:InsertStrAt(caret.x, caret.y, self:GetTabStr(caret.x, self.content_data:GetLineStr(caret.y)), true)
		end
	end

	self:PushHistoryBlock()
	self:Rebuild()
end

function Act.outdent(self)
	local lines = self.content_data.lines

	for caret_id, caret in ipairs(self.carets) do
		if caret.select_y and caret.select_y ~= caret.y then
			for y = math.min(caret.y, caret.select_y), math.max(caret.y, caret.select_y) do
				if string.sub(lines[y].str, 1, self.tab_strsize) == self.tab_str then
					self:RemoveStrAt(1, y, self.tab_strsize, true)

					if y == caret.select_y then
						caret.select_x = caret.select_x - self.tab_strsize
					end
				end
			end
		else
			self:InsertStrAt(caret.x, caret.y, self:GetTabStr(caret.x, lines[caret.y].str), true)
		end
	end

	self:PushHistoryBlock()
	self:Rebuild()
end

function Act.reindent_file(self)
	for y, line in ipairs(self.content_data.lines) do
		local cur_level = 0
		local s = 1

		while s do
			s = string.match(line.str, "^" .. self.tab_str .. "()", s)

			if s then
				cur_level = cur_level + 1
			end
		end

		if cur_level > line.indent_level then
			self:RemoveStrAt(1, y, (cur_level - line.indent_level) * self.tab_strsize, true)
		elseif cur_level < line.indent_level then
			self:InsertStrAt(1, y, string.rep(self.tab_str, line.indent_level - cur_level), true)
		end
	end

	self:PushHistoryBlock()
	self:Rebuild()
end

function Act.comment(self)
	local lines = self.content_data.lines

	for caret_id, caret in ipairs(self.carets) do
		local sy = caret.y
		local ey = caret.select_y or caret.y

		if ey < sy then
			ey, sy = sy, ey
		end

		local level = math.huge

		for y = sy, ey do
			level = math.min(level, string.match(lines[y].str, "%s*()"))
		end

		local remove = true
		local cs = #self.mode.comment

		for y = sy, ey do
			if string.sub(lines[y].str, level, level + cs - 1) ~= self.mode.comment then
				remove = false
				break
			end
		end

		if remove then
			for y = sy, ey do
				self:RemoveStrAt(level, y, cs, true)
			end

			if caret.select_x then
				caret.select_x = caret.select_x - cs
			end
		else
			for y = sy, ey do
				self:InsertStrAt(level, y, self.mode.comment, true)
			end

			if caret.select_x then
				caret.select_x = caret.select_x + cs
			end
		end
	end

	self:PushHistoryBlock()
	self:Rebuild()
end

function Act.selectall(self)
	local lines = self.content_data.lines
	self:ClearCarets()
	self:SetCaret(1, lines[#lines].len, #lines)
	self.carets[1].select_x = 1
	self.carets[1].select_y = 1
end

function Act.toggle_insert(self)
	self.caretinsert = not self.caretinsert
end

local lx, ly, stage, last_id

function Act.setcaret(self, new)
	local sx, sy = self:GetCursorAsCaret()
	local caret_id

	if lx == sx and ly == sy then
		caret_id = last_id
	else
		if new then
			caret_id = self:AddCaret(sx, sy)

			for k, v in pairs(self:ClearExcessCarets()) do
				if k == caret_id then
					caret_id = v
				end
			end
		else
			self:ClearCarets()
			caret_id = 1
		end

		stage = 0
	end

	local caret = self.carets[caret_id]

	if RealTime() - self.last_click < 0.5 and stage ~= 0 and lx == sx and ly == sy then
		if stage == 2 then
			caret.select_x = 1
			caret.select_y = sy

			if sy < self.content_data:GetLineCount() then
				self:SetCaret(caret_id, 1, sy + 1)
			else
				self:SetCaret(caret_id, self.content_data:GetLineLength(sy), sy)
			end

			stage = 0
		else
			local s, e = self:MatchWord(self.content_data:GetLineStr(sy), sx)
			caret.select_x = s
			caret.select_y = sy
			self:SetCaret(caret_id, e, sy)
			stage = 2
		end
	else
		caret.select_x = nil
		caret.select_y = nil
		self:SetCaret(caret_id, sx, sy)
		stage = 1
	end

	for k, v in pairs(self:ClearExcessCarets()) do
		if k == caret_id then
			caret_id = v
		end
	end

	last_id = caret_id
	lx, ly = sx, sy
	self:RequestCapture(true)
	local key = Settings.lookupAct("setcaret")

	self.on_mouse_hold[#self.on_mouse_hold + 1] = {
		key, function()
			local caret = self.carets[caret_id]
			if not caret then return end
			local x, y = self:GetCursorAsCaret()
			self:SetCaret(caret_id, x, y)

			if sx ~= x or sy ~= y then
				caret.select_x = sx
				caret.select_y = sy
			else
				caret.select_x = nil
				caret.select_y = nil
			end

			for k, v in pairs(self:ClearExcessCarets()) do
				if k == caret_id then
					caret_id = v
				end
			end
		end
	}

	self.on_mouse_release[#self.on_mouse_release + 1] = {
		key, function()
			self:RequestCapture(false)
		end
	}

	self.caretblink = RealTime()
end

function Act.contextmenu(self, caret)
	local menu = ExpressiveEditor.Menu()

	menu:AddOption("Cut", function()
		Act.cut(self)
	end)

	menu:AddOption("Copy", function()
		Act.copy(self)
	end)

	menu:AddSpacer()

	menu:AddOption("Select All", function()
		Act.selectall(self)
	end)

	menu:AddSpacer()

	menu:AddOption("Comment Lines", function()
		Act.comment(self)
	end)

	menu:AddSpacer()

	menu:AddOption("Indent", function()
		Act.indent(self)
	end)

	menu:AddOption("Outdent", function()
		Act.outdent(self)
	end)

	menu:AddOption("Reindent File", function()
		Act.reindent_file(self)
	end)

	local x, y
	local xg, yg

	if caret then
		x, y = self:CharToRenderPos(self.carets[1].x, self.carets[1].y)
		xg, yg = self:PosGlobal()
		x = x + xg + self.gutter_size
		y = y + yg
	end

	menu:Open(x, y)
end

function Act.writestr(self, str)
	self:InsertStr(str)
	self:CheckNameChanged()
end

function Act.delete(self, typ, count_dir)
	if self:HasSelection() then
		self:RemoveSelection()
	elseif typ == "char" then
		if count_dir == -1 and self.settings.auto_closing_bracket then
			local lines = self.content_data.lines

			for caret_id, caret in ipairs(self.carets) do
				if caret.x > 1 and caret.x <= lines[caret.y].len then
					local bracket = self.mode.bracket[self.sub(lines[caret.y].str, caret.x - 1, caret.x - 1)]

					if bracket and self.sub(lines[caret.y].str, caret.x, caret.x) == bracket.close then
						self:RemoveStrAt(caret.x + 1, caret.y, -2, true)
					else
						self:RemoveStrAt(caret.x, caret.y, -1, true)
					end
				else
					self:RemoveStrAt(caret.x, caret.y, -1, true)
				end
			end

			self:PushHistoryBlock()
			self:Rebuild()
		else
			self:RemoveStr(count_dir)
		end
	elseif typ == "word" then
		local lines = self.content_data.lines

		for caret_id, caret in ipairs(self.carets) do
			if count_dir > 0 then
				local line = lines[caret.y].str
				local ll = lines[caret.y].len

				if caret.x >= ll then
					if caret.y == #lines then
						goto SKIP
					end

					self:RemoveStrAt(caret.x, caret.y, 1, true)
					goto SKIP
				end

				local e = select(2, string.find(self.sub(line, caret.x), "[^%w_]*[%w_]+"))
				self:RemoveStrAt(caret.x, caret.y, e or (ll + 1 - caret.x), true)
			else
				local line = lines[caret.y].str

				if caret.x == 1 then
					if caret.y == 1 then
						goto SKIP
					end

					self:RemoveStrAt(caret.x, caret.y, -1, true)
					goto SKIP
				end

				local s = string.find(self.sub(line, 1, caret.x - 1), "[%w_]*[^%w_]*$")
				self:RemoveStrAt(caret.x, caret.y, s - caret.x, true)
			end

			::SKIP::
		end

		self:PushHistoryBlock()
		self:Rebuild()
	end

	self:CheckNameChanged()
end

function Act.move(self, typ, count_dir, selc)
	local lines = self.content_data.lines

	local function handleSelect(caret)
		if selc then
			if not caret.select_x then
				caret.select_x = caret.x
				caret.select_y = caret.y
			end
		elseif caret.select_x then
			caret.select_x = nil
			caret.select_y = nil
		end
	end

	for caret_id, caret in ipairs(self.carets) do
		if typ == "char" then
			if selc and not caret.select_x then
				caret.select_x = caret.x
				caret.select_y = caret.y
				self:MoveCaret(caret_id, count_dir, nil)
			elseif not selc and caret.select_x then
				local sx, sy = caret.x, caret.y
				local ex, ey = caret.select_x, caret.select_y

				if ey < sy or (ex < sx and sy == ey) then
					sx, sy, ex, ey = ex, ey, sx, sy
				end

				if count_dir < 0 then
					self:SetCaret(caret_id, sx, sy)
				else
					self:SetCaret(caret_id, ex, ey)
				end

				caret.select_x = nil
				caret.select_y = nil
			else
				self:MoveCaret(caret_id, count_dir, nil)
			end
		elseif typ == "word" then
			handleSelect(caret)

			if count_dir > 0 then
				local line = lines[caret.y].str
				local ll = lines[caret.y].len

				if caret.x >= ll then
					if caret.y == #lines then
						goto SKIP
					end

					self:SetCaret(caret_id, 1, caret.y + 1)
					goto SKIP
				end

				local e = select(2, string.find(self.sub(line, caret.x), "[^%w_]*[%w_]+"))
				self:SetCaret(caret_id, e and (e + caret.x) or (ll + 1), nil)
			else
				local line = lines[caret.y].str

				if caret.x == 1 then
					if caret.y == 1 then
						goto SKIP
					end

					self:SetCaret(caret_id, lines[caret.y - 1].len + 1, caret.y - 1)
					goto SKIP
				end

				local s = string.find(self.sub(line, 1, caret.x - 1), "[%w_]*[^%w_]*$")
				self:SetCaret(caret_id, s, nil)
			end

			::SKIP::
		elseif typ == "line" then
			handleSelect(caret)
			self:MoveCaret(caret_id, nil, count_dir)
		elseif typ == "page" then
			handleSelect(caret)
			self:MoveCaret(caret_id, nil, count_dir * self:VisibleLineCount())
			self:DoScroll(count_dir * self:VisibleLineCount() * self.settings.font_size)
		elseif typ == "bol" then
			handleSelect(caret)
			local e = select(2, string.find(lines[caret.y].str, "^%s*")) + 1

			if caret.x ~= e or caret.x ~= 1 then
				self:SetCaret(caret_id, caret.x == e and 1 or e, nil)
			end
		elseif typ == "eol" then
			handleSelect(caret)
			self:SetCaret(caret_id, lines[caret.y].len)
		elseif typ == "bof" then
			handleSelect(caret)
			self:SetCaret(caret_id, 1, 1)
		elseif typ == "eof" then
			handleSelect(caret)
			self:SetCaret(caret_id, lines[#lines].len, #lines)
		end
	end
end

function Act.goto_line(self, line)
	self:ClearCarets()
	self:SetCaret(1, 1, math.Clamp(self.settings.gutter_relative and (self.carets[1].y + line) or line, 1, self.content_data:GetLineCount()))
end

function Act.fold_level(self, level)
	local cd = self.content_data

	for y, line in ipairs(cd.lines) do
		if line.foldable and line.scope_level == level and not line.folded and not line.fold then
			cd:FoldLine(y)
		end
	end

	self:UpdateScrollbar()
end

function Act.unfold_all(self)
	local cd = self.content_data

	for y, line in ipairs(cd.lines) do
		if line.folded then
			cd:UnfoldLine(y)
		end
	end

	self:UpdateScrollbar()
end

function Act.validate(self)
	if self.syntax == "es" then
		self:Validate(nil, true)
	end
end

----------------------------------------
local linefold_down = Material("materials/syper/fa-caret-down.png", "noclamp smooth")
local linefold_right = Material("materials/syper/fa-caret-right.png", "noclamp smooth")

local Editor = {
	Act = Act
}

local Validator = include("expressive/editor/validator.lua")

function Editor:Init()
	self.content_data = nil
	self.history = {}
	self.history_pointer = 0
	self.history_block = {}
	self.carets = {}
	self.caretinsert = false
	self.caretblink = RealTime()
	self.gutter_size = 50
	self.editable = true
	self.path = nil
	self.on_mouse_hold = {}
	self.on_mouse_release = {}
	self.last_click = 0
	self.mouse_captures = 0
	self.content_render_width = 0
	self.highlight = {}
	self:SetAllowNonAsciiCharacters(true)
	self:SetMultiline(true)
	self.infobar = self:Add("Panel")
	self.infobar:SetHeight(20)
	self.infobar:Dock(BOTTOM)

	self.infobar.Paint = function(_, w, h)
		surface.SetDrawColor(self.settings.style_data.ide_background)
		surface.DrawRect(0, 4, w, h - 4)
		surface.SetDrawColor(self.settings.style_data.gutter_background)
		surface.DrawRect(0, 0, w, 4)
		surface.SetFont("syper_ide")
		local str = #self.carets == 1 and string.format("Line %s, Column %s", self.carets[1].y, self:RealToRenderPos(self.content_data:GetLineStr(self.carets[1].y), self.carets[1].x)) or (#self.carets .. " Carets")

		if self:HasSelection() then
			local count = 0

			for caret_id, caret in ipairs(self.carets) do
				if caret.select_x then
					local sx, sy = caret.x, caret.y
					local ex, ey = caret.select_x, caret.select_y

					if ey < sy or (ex < sx and sy == ey) then
						sx, sy, ex, ey = ex, ey, sx, sy
					end

					if sy ~= ey then
						count = count + self.content_data:GetLineLength(sy) - sx + 1
						count = count + ex - 1
					else
						count = count + ex - sx
					end

					for y = sy + 1, ey - 1 do
						count = count + self.content_data:GetLineLength(y)
					end
				end
			end

			if count > 0 then
				str = str .. ", " .. count .. " Selected Characters"
			end
		end

		local tw, th = surface.GetTextSize(str)
		surface.SetTextColor(self.settings.style_data.ide_disabled)
		surface.SetTextPos((h - th) / 2 + 2, h / 2 - th / 2 + 2)
		surface.DrawText(str)
	end

	self.infobar.Think = function(_)
		if not _.holding then return end
		local x, y = _:LocalCursorPos()

		if math.sqrt((_.holding[1] - x) ^ 2 + (_.holding[2] - y) ^ 2) > 20 then
			_.holding = nil
			local parent = self:GetParent()

			while true do
				local p = parent:GetParent()
				if p.ClassName == "E4SyperTabHandler" then break end
				parent = p
			end

			local handler = self:FindTabHandler()
			self:SafeUnparent()
			-- parent:InvalidateChildren(true)
			parent:InvalidateLayout(true)

			timer.Simple(0, function()
				handler:ForceMovePanel(self)
			end)
		end
	end

	self.infobar.OnMousePressed = function(_, key)
		if key ~= MOUSE_LEFT then return end
		if self:GetParent().ClassName == "E4SyperTabHandler" then return end

		_.holding = {_:LocalCursorPos()}
	end

	self.infobar.OnMouseReleased = function(_, key)
		if key ~= MOUSE_LEFT then return end
		_.holding = nil
	end

	self.syntax_button = self.infobar:Add("DButton")
	self.syntax_button:SetWide(100)
	self.syntax_button:Dock(RIGHT)

	self.syntax_button.DoClick = function(_)
		-- TODO: make look better
		local menu = ExpressiveEditor.Menu()

		for syntax, mode in pairs(Mode.modes) do
			menu:AddOption(mode.name, function()
				self:SetSyntax(syntax)
			end)
		end

		menu:Open()
	end

	self.syntax_button.Paint = function(_, w, h)
		surface.SetFont("syper_ide")
		local str = _:GetText()
		local tw, th = surface.GetTextSize(str)
		surface.SetTextColor(self.settings.style_data.ide_disabled)
		surface.SetTextPos(w / 2 - tw / 2, h / 2 - th / 2 + 2)
		surface.DrawText(str)

		return true
	end

	self.gutter = self:Add("Panel")

	-- self.gutter:Dock(LEFT)
	self.gutter.OnMousePressed = function(_, key)
		if key ~= MOUSE_LEFT then return end
		local y = self:GetCursorAsY()
		local line = self.content_data.lines[y]

		if line.foldable or line.folded then
			if line.folded then
				self.content_data:UnfoldLine(y)
			else
				self.content_data:FoldLine(y)
			end

			self:UpdateScrollbar()
		end

		return
	end

	self.gutter.Paint = function(_, w, h)
		if self.loading then return end
		local th = self.settings.font_size
		surface.SetDrawColor(self.settings.style_data.gutter_background)
		surface.DrawRect(0, 0, w, h)
		surface.SetDrawColor(self.settings.style_data.gutter_foreground)
		local y = self:FirstVisibleLine()
		local ye = y + self:VisibleLineCount()

		for ry = self:FirstVisibleLineRender(), self.content_data:GetLineCount() do
			local line = self.content_data.lines[ry]

			if not line.fold then
				local offset_y = y * th - th - self.scrollbar.Scroll
				local linenum = tostring(self.settings.gutter_relative and ry - self.carets[1].y or ry)
				surface.SetTextColor(self.settings.style_data.gutter_foreground)
				surface.SetFont("syper_syntax_1")
				local tw = surface.GetTextSize(linenum)
				surface.SetTextPos(w - tw - self.settings.gutter_margin, offset_y)
				surface.DrawText(linenum)

				if line.foldable or line.folded then
					-- local str = line.folded and "+" or "-"
					-- local tw = surface.GetTextSize(str)
					-- surface.SetTextPos(w - tw - 2, offset_y - 1)
					-- surface.DrawText(str)
					surface.SetMaterial(line.folded and linefold_right or linefold_down)
					surface.DrawTexturedRect(w - th, offset_y, th, th)
				end

				y = y + 1
				if y == ye then break end
			end
		end

		return true
	end

	self.lineholder_dock = self:Add("Panel")
	-- self.lineholder_dock:Dock(FILL)
	self.lineholder_dock:SetMouseInputEnabled(false)
	self.lineholder = self.lineholder_dock:Add("Panel")
	self.lineholder:SetMouseInputEnabled(false)

	self.lineholder.Paint = function(_, w, h)
		if self.loading then return end
		local th = self.settings.font_size
		-- caret select
		surface.SetFont("syper_syntax_1")
		surface.SetDrawColor(self.settings.style_data.highlight)
		surface.SetTextColor(self.settings.style_data.highlight2)
		local sy, ey = self:GetViewBounds()

		for _, caret in ipairs(self.carets) do
			if caret.select_x then
				for y, line in pairs(caret.select_highlight) do
					if y >= sy and y <= ey then
						local ry = self:GetVisualLineY(y)

						if ry then
							surface.DrawRect(line[1], ry * th - th, line[2], th)
							surface.SetTextPos(line[1], ry * th - th)
							surface.DrawText(line[3])
						end
					end
				end
			end
		end

		-- content
		local done = {}
		local y = self:FirstVisibleLine()
		local ye = y + self:VisibleLineCount()

		for ry = self:FirstVisibleLineRender(), self.content_data:GetLineCount() do
			local line = self.content_data.lines[ry]

			if not line.fold then
				local offset_y = y * th - th
				local offset_x = 0
				local render = line.render

				for i, token in ipairs(render) do
					if token[5] then
						surface.SetDrawColor(token[5])
						surface.DrawRect(offset_x + 1, offset_y + 1, i == #render and 9999 or (token[1] - 2), th - 2)
					end

					surface.SetTextColor(token[4])
					surface.SetFont(token[3])
					surface.SetTextPos(offset_x, offset_y)
					surface.DrawText(token[2])
					offset_x = offset_x + token[1]
				end

				if line.folded then
					local fold_count = 0

					for y = ry + 1, self.content_data:GetLineCount() do
						if not self.content_data.lines[y].fold then break end
						fold_count = fold_count + 1
					end

					local fold_text = string.format(self.settings.fold_format, fold_count)
					surface.SetFont("syper_syntax_fold")
					local tw = surface.GetTextSize(fold_text)
					surface.SetDrawColor(self.settings.style_data.fold_background)
					surface.DrawRect(offset_x + 4, offset_y + 3, tw, th - 5)
					surface.SetTextColor(self.settings.style_data.fold_foreground)
					surface.SetTextPos(offset_x + 4, offset_y + 3)
					surface.DrawText(fold_text)
				end

				local highlight = self.highlight[ry]

				if highlight then
					surface.SetDrawColor(255, 255, 255, 255)

					for i, v in ipairs(highlight) do
						if done[v] then break end
						done[v] = true
						-- surface.DrawOutlinedRect(v.x, offset_y, v.w, th, 1)
						surface.DrawLine(v[1], offset_y + v[2] * th, v[3], offset_y + v[4] * th)
					end
				end

				y = y + 1
				if y == ye then break end
			end
		end

		if not self:HasFocus() then return end
		local lines = self.content_data.lines
		local th = self.settings.font_size
		-- carets
		surface.SetFont("syper_syntax_1")
		local clr = self.settings.style_data.caret
		surface.SetDrawColor(clr.r, clr.g, clr.b, math.Clamp(math.cos((RealTime() - self.caretblink) * math.pi * 1.6) * 255 + 128, 0, 255))

		for caret_id, caret in ipairs(self.carets) do
			local x = caret.x
			local y = caret.y
			local vy = self:GetVisualLineY(y)

			if not vy then
				for y2 = y - 1, 1, -1 do
					if not lines[y2].fold then
						x = lines[y2].len
						y = y2
						vy = self:GetVisualLineY(y)
						break
					end
				end
			end

			local offset = surface.GetTextSize(self:GetRenderString(self.sub(self.content_data:GetLineStr(y), 1, x - 1)))

			if self.caretinsert then
				local str = self:GetRenderString(self.sub(self.content_data:GetLineStr(y), x, x))
				local w = surface.GetTextSize(str == "\n" and " " or str)
				surface.DrawRect(offset, vy * th - 2, w, 2)
			else
				surface.DrawRect(offset, vy * th - th, 2, th)
			end
		end

		-- pairs
		surface.SetDrawColor(255, 255, 255, 255)

		for caret_id, caret in ipairs(self.carets) do
			if self:GetVisualLineY(caret.y) then
				local token, x = self:GetToken(caret.x, caret.y)

				if not token or not token.pair then
					token, x = self:GetToken(caret.x - 1, caret.y)
				end

				if token and token.pair then
					local x, y = token.pair.x, token.pair.y
					local offset = surface.GetTextSize(self:GetRenderString(self.sub(lines[caret.y].str, 1, token.s - 1)))
					local tw = surface.GetTextSize(self:GetRenderString(self.sub(lines[caret.y].str, token.s, token.e)))
					surface.DrawRect(offset, self:GetVisualLineY(caret.y) * th - 1, tw, 1)
					local token = lines[y].tokens[x]
					local offset = surface.GetTextSize(self:GetRenderString(self.sub(lines[y].str, 1, token.s - 1)))
					local tw = surface.GetTextSize(self:GetRenderString(self.sub(lines[y].str, token.s, token.e)))
					surface.DrawRect(offset, self:GetVisualLineY(y) * th - 1, tw, 1)
				end
			end
		end

		-- autocomplete
		local ac = self.autocomplete

		if ac and not self.content_data.lines[ac.y].fold then
			local list = ac.list
			local x, y = self:CharToRenderPos(ac.x, ac.y)
			surface.SetDrawColor(self.settings.style_data.gutter_background)
			surface.DrawRect(x, y, 200, self.settings.autocomplete_lines * th)
			surface.SetDrawColor(self.settings.style_data.gutter_foreground)
			surface.DrawRect(x, y + (ac.selected - ac.scroll - 1) * th, 200, th)
			surface.SetFont("syper_syntax_1")
			surface.SetTextColor(self.settings.style_data.caret)

			for i = ac.scroll + 1, math.min(#ac.list, ac.scroll + self.settings.autocomplete_lines) do
				surface.SetTextPos(x, y + (i - ac.scroll - 1) * th)
				surface.DrawText(ac.list[i])
			end
		end

		-- live value
		local lv = self.livevalue

		if lv and not ac and not self.content_data.lines[lv.y].fold then
			local x, y = self:CharToRenderPos(lv.x, lv.y)
			local w = surface.GetTextSize(lv.str)
			x, y = x + th, y - th
			surface.SetDrawColor(self.settings.style_data.gutter_background)
			surface.DrawRect(x, y, w + th * 2, th)
			surface.SetFont("syper_syntax_1")
			surface.SetTextColor(self.settings.style_data.caret)
			surface.SetTextPos(x + th * 1, y)
			surface.DrawText(lv.str)
		end

		return true
	end

	self.scrolltarget = 0
	self.scrollbar = self:Add("DVScrollBar")
	self.scrollbar:SetHideButtons(true)

	self.scrollbar.OnMouseWheeled = function(_, delta)
		self:OnMouseWheeled(delta, false)

		return true
	end

	self.scrollbar.OnMousePressed = function()
		local y = select(2, self.scrollbar:CursorPos())
		self:DoScroll((y > self.scrollbar.btnGrip.y and 1 or -1) * self:VisibleLineCount() * self.settings.font_size)
	end

	self.scrollbar.Paint = function(_, w, h)
		draw.RoundedBox(4, 3, 3, w - 6, h - 6, self.settings.style_data.highlight)
	end

	self.scrollbar.btnGrip.Paint = function(_, w, h)
		draw.RoundedBox(4, 3, 3, w - 6, h - 6, self.settings.style_data.gutter_foreground)
	end

	self.scrolltarget_h = 0
	self.scrollbar_h = self:Add("DHScrollBar")
	self.scrollbar_h:SetHideButtons(true)

	self.scrollbar_h.OnMouseWheeled = function(_, delta)
		self:OnMouseWheeled(delta, true)

		return true
	end

	self.scrollbar_h.OnMousePressed = function()
		local x = self.scrollbar:CursorPos()
		self:DoScrollH((x > self.scrollbar_h.btnGrip.x and 1 or -1) * self.lineholder_dock:GetWide())
	end

	self.scrollbar_h.Paint = function(_, w, h)
		draw.RoundedBox(4, 3, 3, w - 6, h - 6, self.settings.style_data.highlight)
	end

	self.scrollbar_h.btnGrip.Paint = function(_, w, h)
		draw.RoundedBox(4, 3, 3, w - 6, h - 6, self.settings.style_data.gutter_foreground)
	end

	self.content_data = Lexer.createContentTable(self.lexer, self.mode, self.settings)
	self.content_data:ModifyLine(1, "\n")
	self:UpdateSettings(Settings.settings)
	self:SetCursor("beam")
	self:SetSyntax("text")
	self:AddCaret(1, 1)
	editors[self] = true
end

function Editor:ValidationError(err, move_to)
	local line, char, message, location = 0, 0, "", ""
	local file, func

	if type(err) == "table" then
		message = err.msg

		if string.sub(message, -1) == "." then
			message = string.sub(message, 1, -2)
		end

		if err.file then
			File = err.file
		end

		line = err.line or line
		char = err.endchar or char
	end

	if move_to then
		if line and char then
			location = string.format("at line %i char %i", line, char)
		end

		if File then
			location = string.format("%s in %s.txt", location, err.file)
		end

		-- TODO: Move to location here!!
	end

	self.validation_bar:SetColor(Color(255, 100, 100))
	self.validation_bar:SetText(string.format("%s %s", message, location))
	--- self:Warning(1, Color(255, 0, 0), "Interpreter Error", Color(255, 255, 255), ":\n", message, " ", {func, location});
	--self:Warning(2, Color(255, 0, 0), "Interpreter Error", Color(255, 255, 255), ": ", message, " ", {func, location});
end

--- Returns whether code validated successfully
---@param code string
---@param move_to boolean
---@return boolean
function Editor:Validate(code, move_to)
	self.console:Clear()
	return self.validator:Validate(code or self:GetContentStr(), move_to)
end

function Editor:OnRemove()
	editors[self] = nil
end

function Editor:Think()
	for caret_id, caret in ipairs(self.carets) do
		if caret.update_info then
			self:UpdateCaretInfo(caret_id)
		end
	end

	if self.clear_excess_carets then
		self:ClearExcessCarets()
	end

	if self.scroll_to_caret then
		self:ScrollToCaret()
	end

	if self.should_refresh then
		self:Refresh()
	end

	if self.should_rebuild then
		self:Rebuild(true)
	end

	self.key_handled = nil
end

function Editor:Paint(w, h)
	surface.SetDrawColor(self.settings.style_data.background)
	surface.DrawRect(0, 0, w, h)

	if self.loading then
		local p = math.sin(CurTime() * 3) * 50
		surface.SetDrawColor(self.settings.style_data.gutter_foreground)
		surface.DrawRect(w / 2 - 20 + math.max(p, -30), h / 2 - 1, math.min(50 - math.abs(p) + 20, 40), 2)
	end

	return true
end

function Editor:OnKeyCodeTyped(key)
	if key == 0 then return end
	self:FindIDE():SaveSession()
	local bind = Settings.lookupBind(input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL), input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT), input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT), key)

	if key == KEY_TAB then
		self.refocus = true
	end

	local ac = self.autocomplete

	if ac then
		if key == KEY_ESCAPE then
			self.autocomplete = nil
			self.key_handled = true
			-- running cancelselect does nothing if main menu is closed
			-- -- if escape is bound to main menu repress escape
			-- if input.GetKeyCode(input.LookupBinding("cancelselect")) == KEY_ESCAPE then
			-- 	RunConsoleCommand("cancelselect")
			-- end

			return
		elseif key == KEY_UP then
			ac.selected = ((ac.selected - 2) % #ac.list) + 1
			ac.scroll = ac.selected == #ac.list and math.max(#ac.list - self.settings.autocomplete_lines, 0) or math.min(ac.scroll, ac.selected - 1)
			self.key_handled = true

			return
		elseif key == KEY_DOWN then
			ac.selected = (ac.selected % #ac.list) + 1
			ac.scroll = ac.selected == 1 and 0 or math.max(ac.scroll + self.settings.autocomplete_lines, ac.selected) - self.settings.autocomplete_lines
			self.key_handled = true

			return
		elseif ((self.settings.autocomplete_tab and key == KEY_TAB) or (not self.settings.autocomplete_tab and key == KEY_ENTER)) and not self:HasSelection() then
			local caret = self.carets[1]
			local str, len = self.mode.autocomplete(string.sub(self.content_data.lines[caret.y].str, 1, -ac.len - 1), ac.list[ac.selected])
			self:RemoveStrAt(caret.x, caret.y, -ac.len - len, true)
			self:InsertStrAt(caret.x, caret.y, str, true)
			self:PushHistoryBlock()
			self:Rebuild()
			self.autocomplete = nil
			self.key_handled = true
			self:HandleLiveValue()

			return
		end
	end

	if bind then
		local act = self.Act[bind.act]

		if act then
			act(self, unpack(bind.args or {}))
			self.key_handled = true

			return
		end
	end

	if self:FindIDE():OnKeyCodeTyped(key) then
		self.key_handled = true
	end
end

function Editor:OnMousePressed(key)
	local bind = Settings.lookupBind(input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL), input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT), input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT), key)

	if key == MOUSE_LEFT then
		self:RequestFocus()
		ExpressiveEditor.LastEditor = self
		ExpressiveEditor.LastContent = self:GetContentStr()
	end

	if bind then
		local act = self.Act[bind.act]

		if act then
			act(self, unpack(bind.args or {}))
			self.last_click = RealTime()

			return true
		end
	end

	self.last_click = RealTime()

	return self:FindIDE():OnMousePressed(key)
end

function Editor:OnMouseReleased(key)
	local n = {}

	for _, v in ipairs(self.on_mouse_hold) do
		if not v[1] == key then
			n[#n + 1] = v
		end
	end

	self.on_mouse_hold = n
	local n = {}

	for _, v in ipairs(self.on_mouse_release) do
		if not v[1] == key then
			n[#n + 1] = v
		else
			v[2]()
		end
	end

	self.on_mouse_release = n
	self:FindIDE():SaveSession()
end

function Editor:OnCursorMoved(x, y)
	for _, v in ipairs(self.on_mouse_hold) do
		v[2](x, y)
	end
end

function Editor:OnMouseWheeled(delta, horizontal)
	horizontal = horizontal == nil and input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT)

	if horizontal then
		self:DoScrollH(-delta * self.settings.font_size * self.settings.scroll_multiplier)
	else
		self:DoScroll(-delta * self.settings.font_size * self.settings.scroll_multiplier)
	end

	self:FindIDE():SaveSession()
end

function Editor:OnTextChanged()
	local str = self:GetText()
	self:SetText("")
	local bracket, bracket2 = nil, nil

	if not self.is_pasted then
		if self.key_handled then return end

		if self.settings.auto_closing_bracket then
			bracket = self.mode.bracket[str]
			bracket2 = self.mode.bracket2[str]
		end
	end

	if self.ignore_chars[str] then return end
	if #str == 0 then return end

	if self:HasSelection() then
		self:RemoveSelection(true)
	end

	if self.is_pasted then
		-- indent pasted str
		if self.is_pasted == 2 then
			-- create a content table
			local lines, p = {}, 1

			while true do
				local s = string.find(str, "\n", p)
				lines[#lines + 1] = string.sub(str, p, s)
				if not s then break end
				p = s + 1
			end

			local cd = Lexer.createContentTable(self.lexer, self.mode, self.settings)

			for y, str in ipairs(lines) do
				cd:ModifyLine(y, str)
			end

			cd:AppendToLine(#lines, "\n")
			cd:RebuildLines(1, #lines)
			cd:RebuildTokenPairs()
			-- reindent it
			local str_tbl = {}

			for y, line in ipairs(cd.lines) do
				local cur_level = 0
				local s = 1

				while s do
					s = string.match(line.str, "^" .. self.tab_str .. "()", s)

					if s then
						cur_level = cur_level + 1
					end
				end

				if cur_level > line.indent_level then
					str_tbl[#str_tbl + 1] = self.sub(line.str, (cur_level - line.indent_level + 1) * self.tab_strsize)
				elseif cur_level < line.indent_level then
					str_tbl[#str_tbl + 1] = string.rep(self.tab_str, line.indent_level - cur_level) .. line.str
				else
					str_tbl[#str_tbl + 1] = line.str
				end
			end

			str_tbl[#str_tbl] = string.sub(str_tbl[#str_tbl], 1, -2)

			for caret_id, caret in ipairs(self.carets) do
				local spacer = string.match(self.content_data:GetLineStr(caret.y), "^([^\n%S]*)")

				local str_tbl2 = {str_tbl[1]}

				for y = 2, #str_tbl do
					str_tbl2[y] = spacer .. str_tbl[y]
				end

				self:InsertStrAt(caret.x, caret.y, table.concat(str_tbl2, ""), true)
			end

			self:PushHistoryBlock()
		else
			self:InsertStr(str)
		end
	else
		if self.caretinsert then
			local l = self.len(str)

			for caret_id, caret in ipairs(self.carets) do
				if caret.x < self.content_data:GetLineLength(caret.y) then
					self:RemoveStrAt(caret.x, caret.y, l, true)
				end

				self:InsertStrAt(caret.x, caret.y, str, true)
			end
		else
			for caret_id, caret in ipairs(self.carets) do
				local line_str = self.content_data:GetLineStr(caret.y)

				if bracket2 and self.sub(line_str, caret.x, caret.x) == str then
					if not bracket2.ignore_char[self.sub(line_str, caret.x - 1, caret.x - 1)] then
						self:MoveCaret(caret_id, 1, nil)
					else
						self:InsertStrAt(caret.x, caret.y, str, true)
					end
				elseif bracket and not bracket.ignore_mode[self:GetToken(caret.x, caret.y).mode] then
					self:InsertStrAt(caret.x, caret.y, str .. bracket.close, true)
					self:MoveCaret(caret_id, -1, nil)
				else
					self:InsertStrAt(caret.x, caret.y, str, true)
				end
			end
		end

		if self.settings.indent_smart then
			local lines = self.content_data.lines

			for caret_id, caret in ipairs(self.carets) do
				local str = string.match(lines[caret.y].str, "%s*(%a+)[\n%z]")
				local token = self:GetToken(caret.x - 1, caret.y)

				if self.mode.outdent[str] and not self.mode.outdent[str][token.mode] then
					local level, level_origin = 0, 0
					local s = 1

					while s do
						s = string.match(lines[caret.y].str, "^" .. self.tab_str .. "()", s)

						if s then
							level = level + 1
						end
					end

					local s = 1

					while s do
						local sorg = lines[caret.y].scope_origin
						if sorg == 0 then break end
						s = string.match(lines[sorg].str, "^" .. self.tab_str .. "()", s)

						if s then
							level_origin = level_origin + 1
						end
					end

					if level > level_origin then
						self:RemoveStrAt(1, caret.y, self.tab_strsize * (level - level_origin), true)
					end
				end
			end
		end

		self:PushHistoryBlock()
	end

	self:CheckNameChanged()
	ExpressiveEditor.LastEditor = self
	ExpressiveEditor.LastContent = self:GetContentStr()
	self.is_pasted = nil
	self:Rebuild()
end

function Editor:OnLoseFocus()
	if self.refocus then
		self:RequestFocus()
		self.refocus = false
	end
end

function Editor:PerformLayout(w, h)
	if self.scrollbar_h.Enabled then
		self.lineholder_dock:SetPos(self.gutter_size, 0)
		self.lineholder_dock:SetSize(w - self.gutter_size - 12, h - 32)
		self.gutter:SetHeight(h - 32)
		self.scrollbar:SetPos(w - 12, 0)
		self.scrollbar:SetSize(12, h - 32)
		self.scrollbar_h:SetPos(0, h - 32)
		self.scrollbar_h:SetSize(w - 12, 12)
	else
		self.lineholder_dock:SetPos(self.gutter_size, 0)
		self.lineholder_dock:SetSize(w - self.gutter_size - 12, h - 20)
		self.gutter:SetHeight(h - 20)
		self.scrollbar:SetPos(w - 12)
		self.scrollbar:SetSize(12, h - 20)
	end
end

function Editor:RequestCapture(yes)
	self.mouse_captures = self.mouse_captures + (yes and 1 or -1)
	self:MouseCapture(self.mouse_captures > 0)
end

function Editor:UpdateScrollbar()
	if self.loading then return end
	local mw = 0

	for y, line in ipairs(self.content_data.lines) do
		if not line.fold then
			mw = math.max(mw, line.render_w)
		end
	end

	mw = mw + self.settings.font_size * 2
	self.content_render_width = mw
	local s = self.lineholder_dock:GetTall()
	local h = s + self.settings.font_size * (self.content_data:GetUnfoldedLineCount() - 1) + 1
	self.lineholder:SetSize(math.max(self.lineholder_dock:GetWide(), self.content_render_width), h)
	self.scrollbar:SetUp(s, h)
	-- horizontal scrollbar
	local s = self.lineholder_dock:GetWide()
	self.scrollbar_h:SetEnabled(self.content_render_width > s)

	if self.scrollbar_h.Enabled then
		self.scrollbar_h:SetUp(s, self.content_render_width)
		self.scrollbar_h:SetScroll(self.scrollbar_h.Scroll)
	end
end

function Editor:UpdateGutter()
	surface.SetFont("syper_syntax_1")
	local w = self.settings.gutter_margin * 2 + surface.GetTextSize(tostring(-self.content_data:GetLineCount()))
	self.gutter_size = w
	self.gutter:SetWidth(w)
end

function Editor:DoScroll(delta)
	local speed = self.settings.scroll_speed
	self.scrolltarget = math.Clamp(self.scrolltarget + delta, 0, self.scrollbar.CanvasSize)

	if speed == 0 then
		self.scrollbar:SetScroll(self.scrolltarget)
	else
		self.scrollbar:AnimateTo(self.scrolltarget, 0.1 / speed, 0, -1)
	end
end

function Editor:DoScrollH(delta)
	local speed = self.settings.scroll_speed
	self.scrolltarget_h = math.Clamp(self.scrolltarget_h + delta, 0, self.scrollbar_h.CanvasSize)

	if speed == 0 then
		self.scrollbar_h:SetScroll(self.scrolltarget_h)
	else
		self.scrollbar_h:AnimateTo(self.scrolltarget_h, 0.1 / speed, 0, -1)
	end
end

function Editor:OnVScroll(scroll)
	if self.scrollbar.Dragging then
		self.scrolltarget = -scroll
	end

	self.lineholder:SetPos(self.lineholder.x, scroll)
end

function Editor:OnHScroll(scroll)
	if self.scrollbar_h.Dragging then
		self.scrolltarget_h = -scroll
	end

	self.lineholder:SetPos(scroll, self.lineholder.y)
end

function Editor:VisibleLineCount()
	return math.ceil(self.lineholder_dock:GetTall() / self.settings.font_size) + 1
end

function Editor:FirstVisibleLine()
	return math.floor(-select(2, self.lineholder:GetPos()) / self.settings.font_size) + 1
end

function Editor:FirstVisibleLineRender()
	local lines = self.content_data.lines
	local y = 0
	local m = math.floor(-select(2, self.lineholder:GetPos()) / self.settings.font_size) + 1

	for ry = 1, #lines do
		if not lines[ry].fold then
			y = y + 1
		end

		if y == m then return ry end
	end

	return #lines
end

function Editor:GetViewBounds()
	local lines = self.content_data.lines
	local vy, s, m = 0, self:FirstVisibleLineRender(), self:VisibleLineCount()

	for y = s, #lines do
		if not lines[y].fold then
			vy = vy + 1
			if vy == m then return s, y end
		end
	end

	return s, #lines + (m - vy)
end

function Editor:GetVisualLineY(y)
	return self.content_data.lines[y].visual_y
end

function Editor:GetRealLineY(y)
	return self.content_data.visual_lines[y]
end

function Editor:ClearHighlight()
	local ide = self:FindIDE()
	if ide.menu_replace:IsVisible() or ide.menu_find:IsVisible() then return end
	self.highlight_finds = nil
	self.highlight_bounds = nil
	self.highlight = {}
end

function Editor:SimpleHighlight(str)
	if self.highlight_finds then return end
	self.highlight = {}

	local function add(y, t)
		self.highlight[y][#self.highlight[y] + 1] = t
	end

	surface.SetFont("syper_syntax_1")
	local tw = surface.GetTextSize("_")
	local pattern = "%f[%w_\128-\255]()(" .. string.PatternSafe(str) .. ")[^%w_\128-\255]"

	for y, line in ipairs(self.content_data.lines) do
		self.highlight[y] = self.highlight[y] or {}

		for s, st in string.gmatch(line.render_str, pattern) do
			local s = self.len(string.sub(line.render_str, 1, s - 1))
			local e = (s + self.len(st)) * tw
			local s = s * tw

			add(y, {s, 0.1, e, 0.1})

			add(y, {e, 0.1, e, 0.9})

			add(y, {s, 0.1, s, 0.9})

			add(y, {s, 0.9, e, 0.9})
		end
	end
end

function Editor:Highlight(str, pattern, case, whole, bounds)
	local bounds_tbl

	if bounds == true then
		bounds_tbl = {}

		for i, caret in ipairs(self.carets) do
			local sx, sy = caret.x, caret.y
			local ex, ey = caret.select_x, caret.select_y

			if ey < sy or (ex < sx and sy == ey) then
				sx, sy, ex, ey = ex, ey, sx, sy
			end

			bounds_tbl[i] = {
				x = sx,
				y = sy,
				x2 = ex,
				y2 = ey
			}
		end
	elseif type(bounds) == "table" then
		bounds_tbl = bounds
	end

	local finds, highlight = self.content_data:Find(str, pattern, case, whole, bounds_tbl)
	self.highlight_finds = finds
	self.highlight_bounds = highlight
	local lines = self.content_data.lines
	surface.SetFont("syper_syntax_1")
	self.highlight = {}

	local function add(y, t)
		if t[1] == t[3] and t[2] == t[4] then return end
		self.highlight[y] = self.highlight[y] or {}
		self.highlight[y][#self.highlight[y] + 1] = t
	end

	if #highlight > 1024 then return end

	for i, bound in ipairs(highlight) do
		local bounds = {}

		for y = bound.sy, bound.ey do
			local offset = y == bound.sy and surface.GetTextSize(self:GetRenderString(string.sub(lines[y].str, 1, bound.sx))) or 0
			local str = self:GetRenderString(string.sub(lines[y].str, y == bound.sy and bound.sx + 1 or 0, y == bound.ey and bound.ex or #lines[y].str))
			local tw = surface.GetTextSize(str) + (string.sub(str, #str, #str) == "\n" and self.settings.font_size / 3 or 0)

			bounds[#bounds + 1] = {
				x = offset,
				w = tw,
				y = y
			}
		end

		local v = bounds[1]

		add(v.y, {v.x, 0.1, v.x + v.w, 0.1})

		if #bounds == 1 then
			add(v.y, {v.x + v.w, 0.1, v.x + v.w, 0.9})

			add(v.y, {v.x, 0.1, v.x, 0.9})

			add(v.y, {v.x, 0.9, v.x + v.w, 0.9})
		else
			add(v.y, {v.x + v.w, 0.1, v.x + v.w, 1})

			add(v.y, {v.x, 0.1, v.x, 1})

			local s, e = v.x, v.x + v.w

			for y = 1, #bounds - 1 do
				local v = bounds[y + 1]

				add(v.y, {v.x, 0, s, 0})

				add(v.y, {v.x + v.w, 0, e, 0})

				if y == #bounds - 1 then
					add(v.y, {v.x, 0, v.x, 0.9})

					add(v.y, {v.x + v.w, 0, v.x + v.w, 0.9})

					add(v.y, {v.x, 0.9, v.x + v.w, 0.9})
				else
					add(v.y, {v.x, 0, v.x, 1})

					add(v.y, {v.x + v.w, 0, v.x + v.w, 1})
				end

				s, e = v.x, v.x + v.w
			end
		end
	end
end

function Editor:Replace(replace)
	if not self.highlight_finds then return end
	local org = self:GetContentStr()
	self.content_data:Replace(self.highlight_finds, replace)
	self:Rebuild()

	self:AddHistory({Editor.SetContent2, Editor.SetContent2, nil, nil, org, self:GetContentStr()})

	self:PushHistoryBlock()
end

function Editor:PushHistoryBlock()
	self.history_pointer = self.history_pointer + 1

	self.history[self.history_pointer] = {table.Copy(self.carets), self.history_block}

	for i = self.history_pointer + 1, #self.history do
		self.history[i] = nil
	end

	self.history_block = {}
end

function Editor:AddHistory(tbl)
	self.history_block[#self.history_block + 1] = tbl
end

function Editor:Undo()
	if self.history_pointer == 0 then return end
	local his = self.history[self.history_pointer]
	self.carets = his[1]

	for caret_id, caret in ipairs(self.carets) do
		self:SetCaret(caret_id, caret.x, caret.y)
	end

	for i = #his[2], 1, -1 do
		local v = his[2][i]
		v[1](self, v[3], v[4], v[5])
	end

	self.history_pointer = self.history_pointer - 1
	self:Rebuild()
end

function Editor:Redo()
	if self.history_pointer == #self.history then return end
	self.history_pointer = self.history_pointer + 1
	local his = self.history[self.history_pointer]
	self.carets = his[1]

	for caret_id, caret in ipairs(self.carets) do
		self:SetCaret(caret_id, caret.x, caret.y)
	end

	for _, v in ipairs(his[2]) do
		v[2](self, v[3], v[4], v[6])
	end

	self:Rebuild()
end

function Editor:GetSessionState()
	local carets = {}

	for i, caret in ipairs(self.carets) do
		carets[i] = {caret.x, caret.y, caret.select_x, caret.select_y}
	end

	return {
		name = self.name,
		does_name = self.OnNameChange ~= nil,
		path = {self.path, self.root_path},
		syntax = self.syntax,
		editable = self.editable,
		content = self:GetContentStr(),
		scroll = {self.scrollbar_h:GetScroll(), self.scrollbar:GetScroll()},
		carets = carets
	}
end

function Editor:SetSessionState(state)
	self:SetName(state.name)
	self:SetPath(state.path[1], state.path[2])
	self:SetSyntax(state.syntax)
	self:SetEditable(state.editable)
	self:SetContent(state.content)

	if state.does_name then
		self.OnNameChange = function(_, name)
			local handler = self:FindTabHandler()
			handler:RenameTab(handler:GetIndex(self), name)
		end
	end

	-- Doesn't work and i have no clue why, TODO: fix that
	self.scrollbar_h:SetScroll(state.scroll[1])
	self.scrollbar:SetScroll(state.scroll[2])
	self.carets = {}

	for i, caret in ipairs(state.carets) do
		self:AddCaret(unpack(caret))
		self:UpdateCaretInfo(i)
	end

	self.scroll_to_caret = false
end

function Editor:GetName()
	local str = self.sub(string.match(self.content_data:GetLineStr(1), "%s*([^\n]*)"), 1, 24)
	str = #str > 0 and str or nil

	return self.name or str
end

function Editor:SetName(name)
	self.last_name = name
	self.name = name
end

function Editor:CheckNameChanged()
	if not self.OnNameChange then return end
	local name = self:GetName() or "untitled"

	if name ~= self.last_name then
		self:OnNameChange(name)
	end

	self.last_name = name
end

function Editor:Save()
	if not self.path then return false, 1 end
	if self.root_path ~= "DATA" then return false, 2 end
	if string.sub(self.path, -1, -1) == "/" then return false, 4 end
	if file.IsDir(self.path, "DATA") then return false, 3 end
	if not ExpressiveEditor.validPath(self.path) then return false, 5 end
	local dirs, p = {}, 1

	while true do
		local s = string.find(self.path, "/", p)
		dirs[#dirs + 1] = string.sub(self.path, p, s)
		if not s then break end
		p = s + 1
	end

	for i = 1, #dirs - 1 do
		local dir = dirs[i]

		if not file.Exists(dir, "DATA") then
			file.CreateDir(dir)
		end
	end

	file.Write(self.path, self:GetContentStr())

	if self.OnSave then
		self:OnSave()
	end

	return true
end

function Editor:ReloadFile()
	self:SetContent(file.Read(self.path, self.root_path))
end

function Editor:SetPath(path, root_path)
	self.path = path
	self.root_path = root_path or "DATA"
end

function Editor:Refresh()
	local folds = {}

	for y, line in ipairs(self.content_data.lines) do
		if line.folded then
			folds[#folds + 1] = y
		end
	end

	self:SetContent(self:GetContentStr())

	for _, y in ipairs(folds) do
		self.content_data:FoldLine(y)
	end

	self.should_refresh = nil
end

function Editor:Rebuild(threaded)
	self.should_rebuild = false

	local func = function(changes)
		if not self.settings then return end
		local h = self.settings.font_size

		for y, _ in pairs(table.Merge(changes, self.content_data:RebuildTokenPairs())) do
			local line = {}
			local offset = 0
			local line_w = 0

			for i, token in ipairs(self.content_data:GetLineTokens(y)) do
				local text = self:GetRenderString(token.str, offset)
				offset = offset + self.len(text)
				local clr = self.settings.style_data[token.token_override or token.token]
				local font = "syper_syntax_" .. (token.token_override or token.token)
				surface.SetFont(font)
				local w = surface.GetTextSize(text)
				line_w = line_w + w

				line[i] = {w, text, font, clr.f, clr.b}
			end

			local l = self.content_data.lines[y]
			l.render_w = line_w
			l.render = line
		end

		self.loading = false
		self:UpdateScrollbar()
		self:UpdateGutter()
		self:HandleAutocomplete()

		for i = 1, #self.carets do
			self:UpdateCaretInfo(i)
		end
	end

	if threaded then
		self.loading = true
		self.content_data:RebuildDirty(256, func)
	else
		func(self.content_data:RebuildDirty(256))
	end
end

function Editor:GetToken(x, y)
	local tokens = self.content_data:GetLineTokens(y)

	for i = #tokens, 1, -1 do
		local token = tokens[i]
		if x >= token.s then return token, i end
	end
end

function Editor:HasSelection()
	for _, caret in ipairs(self.carets) do
		if caret.select_x then return true end
	end

	return false
end

function Editor:SetSyntax(syntax)
	if syntax == "es" then
		self:AddExpressionAddons()
	else
		self:RemoveExpressionAddons()
	end

	self.syntax = syntax
	self.lexer = Lexer.lexers[syntax]
	self.mode = Mode.modes[syntax]
	self.syntax_button:SetText(Mode.modes[syntax].name)
	local content = self:GetContentStr()
	self.content_data = Lexer.createContentTable(self.lexer, self.mode, self.settings)
	self:SetContent(content)
end

function Editor:SetEditable(state)
	self.editable = state
end

function Editor:ClearCarets()
	self.carets = {self.carets[#self.carets]}

	self:MarkScrollToCaret()
end

function Editor:MarkClearExcessCarets()
	self.clear_excess_carets = true
end

function Editor:ClearExcessCarets()
	local rem = {}

	for i, c in ipairs(self.carets) do
		if not rem[i] then
			for j, c2 in ipairs(self.carets) do
				if i ~= j and not rem[j] then
					if c.x == c2.x and c.y == c2.y then
						rem[j] = i
					elseif c.select_x then
						-- c
						local sx, sy = c.x, c.y
						local ex, ey = c.select_x, c.select_y
						local s = false

						if ey < sy or (ex < sx and sy == ey) then
							sx, sy, ex, ey = ex, ey, sx, sy
							s = true
						end

						-- c2
						local sx2, sy2 = c2.x, c2.y
						local ex2, ey2 = c2.select_x, c2.select_y

						if ex2 and (ey2 < sy2 or (ex2 < sx2 and sy2 == ey2)) then
							sx2, sy2, ex2, ey2 = ex2, ey2, sx2, sy2
						end

						if (sx2 > sx and sy2 == sy and (sy ~= ey or sx2 < ex)) or (sx2 < ex and sy2 == ey and sy ~= ey) or (sy2 > sy and sy2 < ey) or (ex2 and ((ex2 > sx and ey2 == sy and (sy ~= ey or ex2 < ex)) or (ex2 < ey and ey2 == ey and sy ~= ey) or (ey2 > sy and ey2 < ey))) then
							rem[j] = i

							if ex2 then
								if sy2 < sy or (sx2 < sx and sy2 == sy) then
									if s then
										c.select_x = sx2
										c.select_y = sy2
									else
										c.x = sx2
										c.y = sy2
									end
								end

								if ey2 > sy or (ex2 > ex and sy2 == sy) then
									if s then
										c.x = ex2
										c.y = ey2
									else
										c.select_x = ex2
										c.select_y = ey2
									end
								end
							end
						end
					end
				end
			end
		end
	end

	local link = {}
	local new = {}

	for i, c in ipairs(self.carets) do
		if not rem[i] then
			new[#new + 1] = c
			link[i] = #new
		end
	end

	self.carets = new
	self.clear_excess_carets = false
	self:MarkScrollToCaret()
	local link2 = {}

	for k, v in pairs(rem) do
		link2[k] = link[v]
	end

	return link2
end

function Editor:GetCursorAsCaret()
	local x, y = self.lineholder_dock:LocalCursorPos()
	y = math.max(0, y)
	y = math.Clamp(self:GetRealLineY(math.floor((y + self.scrollbar.Scroll) / self.settings.font_size) + 1) or math.huge, 1, self.content_data:GetLineCount())
	surface.SetFont("syper_syntax_1")
	local w = surface.GetTextSize(" ")
	x = self:RenderToRealPos(self.content_data:GetLineStr(y), math.floor(((x + self.scrollbar_h.Scroll) + w / 2) / w) + 1)

	return x, y
end

function Editor:GetCursorAsY()
	return math.Clamp(self:GetRealLineY(math.floor((select(2, self.lineholder_dock:LocalCursorPos()) + self.scrollbar.Scroll) / self.settings.font_size) + 1) or math.huge, 1, self.content_data:GetLineCount())
end

function Editor:AddCaret(x, y, select_x, select_y)
	self.carets[#self.carets + 1] = setmetatable({
		x = x,
		y = y,
		max_x = x,
		select_x = select_x,
		select_y = select_y,
		update_info = false,
		new = true
	}, {
		__newindex = function(caret, k, v)
			if k == "x" then
				rawset(caret, "max_x", x)
			elseif k == "max_x" then
				-- TODO: not have this and just remove all max_x assigns
				return
			end

			rawset(caret, "update_info", true)
			rawset(caret, k, v)
		end
	})

	self:MarkClearExcessCarets()
	self:MarkScrollToCaret()
	table.sort(self.carets, function(a, b) return a.y > b.y or (a.y == b.y and a.x > b.x) end)

	for caret_id, caret in ipairs(self.carets) do
		if caret.new then
			-- caret.new = nil
			rawset(caret, "new", nil)

			return caret_id
		end
	end
end

function Editor:SetCaret(i, x, y)
	local caret = self.carets[i]
	x = x or caret.x
	y = y or caret.y

	if not self:GetVisualLineY(y) then
		local lines = self.content_data.lines
		local b = y < caret.y or (y == caret.y and x < caret.x)

		if b then
			for y2 = y - 1, 1, -1 do
				if not lines[y2].fold then
					x = lines[y2].len
					y = y2
					break
				end
			end
		else
			for y2 = y + 1, #lines do
				if not lines[y2].fold then
					x = 1
					y = y2
					break
				end
			end
		end
	end

	-- caret.x = x
	-- caret.y = y
	-- caret.max_x = x
	rawset(caret, "x", x)
	rawset(caret, "y", y)
	rawset(caret, "max_x", max_x)
	rawset(caret, "update_info", true)
	self.caretblink = RealTime()
	self:MarkClearExcessCarets()
	self:MarkScrollToCaret()
	self:HandleAutocomplete()
	self:ClearHighlight()
end

function Editor:MoveCaret(i, x, y)
	local lines = self.content_data.lines
	local caret = self.carets[i]

	if x and x ~= 0 then
		local xn = x / math.abs(x)

		for _ = xn, x, xn do
			if x > 0 then
				local ll = lines[caret.y].len

				if caret.x < ll or caret.y < #lines then
					-- caret.x = caret.x + 1
					rawset(caret, "x", caret.x + 1)

					if caret.x > ll then
						-- caret.x = 1
						rawset(caret, "x", 1)
						-- caret.y = caret.y + 1
						rawset(caret, "y", caret.y + 1)

						while not self:GetVisualLineY(caret.y) do
							-- caret.y = caret.y + 1
							rawset(caret, "y", caret.y + 1)
						end
					end

					-- caret.max_x = caret.x
					rawset(caret, "max_x", caret.x)
				end
			else
				if caret.x > 1 or caret.y > 1 then
					-- caret.x = caret.x - 1
					rawset(caret, "x", caret.x - 1)

					if caret.x < 1 then
						-- caret.y = caret.y - 1
						rawset(caret, "y", caret.y - 1)

						while not self:GetVisualLineY(caret.y) do
							-- caret.y = caret.y - 1
							rawset(caret, "y", caret.y - 1)
						end

						-- caret.x = lines[caret.y].len
						rawset(caret, "x", lines[caret.y].len)
					end

					-- caret.max_x = caret.x
					rawset(caret, "max_x", caret.x)
				end
			end
		end
	end

	if y and y ~= 0 then
		local yn = y / math.abs(y)

		for _ = yn, y, yn do
			if y > 0 then
				if caret.y < #lines then
					local cy = caret.y
					-- caret.y = caret.y + 1
					rawset(caret, "y", caret.y + 1)

					while not self:GetVisualLineY(caret.y) do
						-- caret.y = caret.y + 1
						rawset(caret, "y", caret.y + 1)
					end

					-- caret.x = self:RenderToRealPos(lines[caret.y].str, self:RealToRenderPos(lines[cy].str, caret.x))
					rawset(caret, "x", self:RenderToRealPos(lines[caret.y].str, self:RealToRenderPos(lines[cy].str, caret.x)))
					if caret.y == #lines then break end
				end
			elseif caret.y > 1 then
				local cy = caret.y
				-- caret.y = caret.y - 1
				rawset(caret, "y", caret.y - 1)

				while not self:GetVisualLineY(caret.y) do
					-- caret.y = caret.y - 1
					rawset(caret, "y", caret.y - 1)
				end

				-- caret.x = self:RenderToRealPos(lines[caret.y].str, self:RealToRenderPos(lines[cy].str, caret.x))
				rawset(caret, "x", self:RenderToRealPos(lines[caret.y].str, self:RealToRenderPos(lines[cy].str, caret.x)))
				if caret.y == 1 then break end
			end
		end
	end

	rawset(caret, "update_info", true)
	self.caretblink = RealTime()
	self:MarkClearExcessCarets()
	self:MarkScrollToCaret()
	self:ClearHighlight()
end

function Editor:UpdateCaretInfo(i)
	local lines = self.content_data.lines
	local caret = self.carets[i]
	-- general
	local x, y = caret.x, caret.y

	if x > lines[y].len and y == #lines then
		rawset(caret, "x", lines[y].len)
	end

	local x, y = caret.select_x, caret.select_y

	if x and x > lines[y].len and y == #lines then
		rawset(caret, "select_x", lines[y].len)
	end

	if caret.x == caret.select_x and caret.y == caret.select_y then
		rawset(caret, "select_x", nil)
		rawset(caret, "select_y", nil)
	end

	-- select highlight
	if caret.select_x then
		local highlight = {}
		local sx, sy = caret.x, caret.y
		local ex, ey = caret.select_x, caret.select_y

		if ey < sy or (ex < sx and sy == ey) then
			sx, sy, ex, ey = ex, ey, sx, sy
		end

		ex = ex - 1
		surface.SetFont("syper_syntax_1")
		local highlight_str

		if sy == ey then
			local offset = surface.GetTextSize(self:GetRenderString(self.sub(lines[sy].str, 1, sx - 1)))
			local substr = self.sub(lines[sy].str, sx, ex)
			local str = self:GetRenderStringSelected(substr)
			local tw = surface.GetTextSize(str) + (string.sub(str, #str, #str) == "\n" and self.settings.font_size / 3 or 0)

			highlight[sy] = {offset, tw, str}

			highlight_str = str

			if #self.carets == 1 and string.match(substr, "^[%w_\128-\255]+$") then
				local y, y2 = self:GetViewBounds()
				self:SimpleHighlight(substr)
				-- self:Highlight(substr, false, true, true, {{
				-- 	x = 1,
				-- 	y = y,
				-- 	x2 = #lines[y2].str,
				-- 	y2 = y2
				-- }})
			end
		else
			local offset = surface.GetTextSize(self:GetRenderString(self.sub(lines[sy].str, 1, sx - 1)))
			local str = self:GetRenderStringSelected(self.sub(lines[sy].str, sx))
			local tw = surface.GetTextSize(str) + (string.sub(str, #str, #str) == "\n" and self.settings.font_size / 3 or 0)

			highlight[sy] = {offset, tw, str}

			highlight_str = str

			for y = sy + 1, ey - 1 do
				local str = self:GetRenderStringSelected(lines[y].str)
				local tw = surface.GetTextSize(str) + (string.sub(str, #str, #str) == "\n" and self.settings.font_size / 3 or 0)

				highlight[y] = {0, tw, str}

				highlight_str = highlight_str .. str
			end

			local str = self:GetRenderStringSelected(self.sub(lines[ey].str, 1, ex))
			local tw = surface.GetTextSize(str) + (string.sub(str, #str, #str) == "\n" and self.settings.font_size / 3 or 0)

			highlight[ey] = {0, tw, str}

			highlight_str = highlight_str .. str
		end

		rawset(caret, "select_highlight", highlight)
		rawset(caret, "select_str", highlight_str)
	else
		rawset(caret, "select_str", nil)
	end

	rawset(caret, "update_info", false)
	self:HandleLiveValue()
end

function Editor:MarkScrollToCaret()
	self.scroll_to_caret = true
end

function Editor:ScrollToCaret()
	self.scroll_to_caret = false
	surface.SetFont("syper_syntax_1")
	local lines = self.content_data.lines
	local sy, ey = self:GetViewBounds()
	sy, ey = sy + 1, ey - 1

	for caret_id, caret in ipairs(self.carets) do
		if caret.y >= sy and caret.y <= ey then
			local x = caret.x
			local y = caret.y
			local vy = self:GetVisualLineY(y)

			if not vy then
				for y2 = y - 1, 1, -1 do
					if not lines[y2].fold then
						x = lines[y2].len
						y = y2
						vy = self:GetVisualLineY(y)
						break
					end
				end
			end

			local px = surface.GetTextSize(self:GetRenderString(self.sub(self.content_data:GetLineStr(y), 1, x - 1)))
			if px >= -self.lineholder.x and px < -self.lineholder.x + self.lineholder_dock:GetWide() - self.settings.font_size * 2 then return end
		end
	end

	local caret = self.carets[1]

	if caret.y <= sy then
		self.scrolltarget = math.Clamp((self:GetVisualLineY(caret.y) - 1) * self.settings.font_size, 0, self.scrollbar.CanvasSize)
		self.scrollbar:SetScroll(self.scrolltarget)
	elseif caret.y > ey then
		self.scrolltarget = math.Clamp(self:GetVisualLineY(caret.y) * self.settings.font_size - self.lineholder_dock:GetTall(), 0, self.scrollbar.CanvasSize)
		self.scrollbar:SetScroll(self.scrolltarget)
	end

	local px = surface.GetTextSize(self:GetRenderString(self.sub(self.content_data:GetLineStr(caret.y), 1, caret.x - 1)))

	if px < -self.lineholder.x then
		self.scrolltarget_h = math.Clamp(px, 0, self.scrollbar_h.CanvasSize)
		self.scrollbar_h:SetScroll(self.scrolltarget_h)
	elseif px >= -self.lineholder_dock.x + self.lineholder_dock:GetWide() - self.settings.font_size * 2 then
		self.scrolltarget_h = math.Clamp(px - self.lineholder_dock:GetWide() + self.settings.font_size * 2, 0, self.scrollbar_h.CanvasSize)
		self.scrollbar_h:SetScroll(self.scrolltarget_h)
	end
end

function Editor:CharToRenderPos(x, y)
	surface.SetFont("syper_syntax_1")

	return surface.GetTextSize(self:GetRenderString(self.sub(self.content_data:GetLineStr(y), 1, x - 1))), self:GetVisualLineY(y) * self.settings.font_size
end

function Editor:HandleAutocomplete()
	local x, y

	if self.autocomplete then
		x, y = self.autocomplete.x, self.autocomplete.y
		self.autocomplete = nil
	end

	if #self.carets > 1 or not self.mode.env then return end
	if not self.settings.autocomplete then return end
	local caret = self.carets[1]
	local lines = self.content_data.lines
	local stack = self.mode.autocomplete_stack(self.sub(lines[caret.y].str, 1, caret.x - 1))

	if stack then
		local tbl = self.mode.env

		for i = 1, #stack - 1 do
			tbl = tbl[stack[i]]
			if not tbl then break end
		end

		if not tbl or type(tbl) ~= "table" then return end
		local list = {}
		local stackn = stack[#stack]
		local stack = string.lower(stackn)
		local len = #stack

		for k, _ in pairs(tbl) do
			if string.lower(string.sub(k, 1, len)) == stack then
				list[#list + 1] = k
			end
		end

		if #list > 0 and not (#list == 1 and list[1] == stackn) then
			self.autocomplete = {
				scroll = 0,
				selected = 1,
				len = len,
				x = x or caret.x - 1,
				y = y or caret.y,
				list = list
			}
		end
	end
end

function Editor:HandleLiveValue()
	self.livevalue = nil
	if #self.carets > 1 or not self.mode.env then return end
	if not self.settings.livevalueview then return end
	local caret = self.carets[1]
	local lines = self.content_data.lines
	local stack = self.mode.autocomplete_stack(self.sub(lines[caret.y].str, 1, caret.x - 1))

	if stack then
		local val = self.mode.env

		for i = 1, #stack do
			if type(val) ~= "table" then return end
			val = val[stack[i]]
			if not val then return end
		end

		if val then
			self.livevalue = {
				x = caret.x,
				y = caret.y,
				str = self.mode.livevalue(val)
			}
		end
	end
end

function Editor:InsertStr(str)
	for _, caret in ipairs(self.carets) do
		self:InsertStrAt(caret.x, caret.y, str, true)
	end

	self:PushHistoryBlock()
	self:Rebuild()
end

function Editor:InsertStrAt(x, y, str, do_history)
	if not self.editable then return end
	self:ClearHighlight()

	if do_history then
		self:AddHistory({Editor.RemoveStrAt, Editor.InsertStrAt, x, y, self.len(str), str})
	end

	local lines, line_count, p = {}, 0, 1

	while true do
		local s = string.find(str, "\n", p)
		lines[#lines + 1] = string.sub(str, p, s)
		if not s then break end
		p = s + 1
		line_count = line_count + 1
	end

	local cd = self.content_data

	if line_count == 0 then
		cd:InsertIntoLine(y, lines[1], x)
	else
		local o = cd:GetLineStr(y)
		cd:ModifyLine(y, self.sub(o, 1, x - 1) .. lines[1])

		for y2 = y + 1, y + line_count - 1 do
			cd:InsertLine(y2, lines[y2 - y + 1])
		end

		cd:InsertLine(y + line_count, lines[line_count + 1] .. self.sub(o, x))
	end

	local length = self.len(str)

	for caret_id, caret in ipairs(self.carets) do
		if caret.y == y and caret.x >= x then
			self:MoveCaret(caret_id, length, nil)
		elseif caret.y > y and line_count > 0 then
			self:MoveCaret(caret_id, nil, line_count)
		end
	end

	self:MarkClearExcessCarets()
	self:FindIDE():SaveSession()
end

function Editor:RemoveStr(length)
	for caret_id, caret in ipairs(self.carets) do
		self:RemoveStrAt(caret.x, caret.y, length, true)
	end

	self:PushHistoryBlock()
	self:Rebuild()
end

function Editor:RemoveSelection(dont_push)
	local cs = self.content_data.lines

	for caret_id, caret in ipairs(self.carets) do
		if caret.select_x then
			local sx, sy = caret.x, caret.y
			local ex, ey = caret.select_x, caret.select_y

			if ey < sy or (ex < sx and sy == ey) then
				sx, sy, ex, ey = ex, ey, sx, sy
			end

			local length = sy == ey and ex - sx or cs[sy].len - sx + 1

			for y = sy + 1, ey - 1 do
				length = length + cs[y].len
			end

			if sy ~= ey then
				length = length + ex - 1
			end

			local rem, x, y, rem_str = self:RemoveStrAt(sx, sy, length, true)
			-- self:SetCaret(caret_id, sx, sy)
			caret.select_x = nil
			caret.select_y = nil
		end
	end

	if not dont_push then
		self:PushHistoryBlock()
	end

	self:Rebuild()
end

-- TODO: removing large chucks with utf8 enabled will result in lag
function Editor:RemoveStrAt(x, y, length, do_history)
	if not self.editable then return end
	self:ClearHighlight()
	local cd = self.content_data
	local rem = {}
	local length_org = length
	local line_count = 0
	local ex, ey = x, y
	length = math.abs(length)

	if length_org < 0 then
		for _ = 1, length do
			x = x - 1

			if x < 1 then
				if y == 1 then
					length = length - 1
				else
					y = y - 1
					x = cd:GetLineLength(y)
					line_count = line_count + 1
				end
			end
		end
	else
		local c = cd:GetLineCount()

		for _ = 1, length do
			ex = ex + 1

			if ex > cd:GetLineLength(ey) then
				if ey ~= c then
					ey = ey + 1
					ex = 1
					line_count = line_count + 1
				end
			end
		end
	end

	for caret_id, caret in ipairs(self.carets) do
		if (caret.x > x and caret.y == y) or caret.y > y then
			if caret.y == y then
				self:MoveCaret(caret_id, -math.min(caret.x - x, length), nil)
			elseif caret.y <= ey then
				self:MoveCaret(caret_id, -length, nil)
			elseif caret.y > ey and line_count > 0 then
				self:MoveCaret(caret_id, nil, -line_count)
			end
		end
	end

	self:MarkClearExcessCarets()
	self:FindIDE():SaveSession()
	local i = 0

	while length > 0 do
		if not cd:LineExists(y) then break end
		local org = cd:GetLineLength(y)
		rem[#rem + 1] = self.sub(cd:GetLineStr(y), x, x + length - 1)
		cd:RemoveFromLine(y, length, x)
		local len = cd:GetLineLength(y)
		length = length - (org - len)

		if len == x - 1 then
			if cd:GetLineCount() == 1 then
				if cd:GetLineLength(1) == 0 then
					cd:ModifyLine(1, "\n")
				end

				break
			end

			if cd:LineExists(y + 1) then
				cd:AppendToLine(y, cd:GetLineStr(y + 1))
				cd:RemoveLine(y + 1)
			end
		end

		i = i + 1

		if i == 4096 then
			MsgN("!!! Syper: Editor:RemoveStrAt")
			break
		end
	end

	rem = table.concat(rem, "")
	length = math.abs(length_org) - length

	if do_history then
		self:AddHistory({Editor.InsertStrAt, Editor.RemoveStrAt, x, y, rem, length})
	end

	return length, x, y, rem
end

function Editor:SetContent(str)
	self:CheckUTF8(str)
	self.content_data:SetFromString(str)
	-- self:Rebuild(true)
	self.should_rebuild = true
	self:MarkClearExcessCarets()
	self:CheckNameChanged()
end

-- Used as history hack
function Editor:SetContent2(_, _, str)
	self:SetContent(str)
end

function Editor:GetContentStr()
	return self.content_data:GetAsString()
end

function Editor:GetRenderString(str, offset)
	local tabsize = self.settings.tab_size
	local s = ""
	offset = offset or 0

	if self.settings.show_control_characters then
		str = string.gsub(str, "([^%C \t])", function(c) return "<0x" .. string.byte(c) .. ">" end)
		str = string.gsub(str, "( )", "·")

		for i = 1, self.len(str) do
			local c = self.sub(str, i, i)
			s = s .. (c == "\t" and string.rep("-", tabsize - ((self.len(s) + offset) % tabsize) - 1) .. ">" or c)
		end

		return s
	end

	for i = 1, self.len(str) do
		local c = self.sub(str, i, i)
		s = s .. (c == "\t" and string.rep(" ", tabsize - ((self.len(s) + offset) % tabsize)) or c)
	end

	return s
end

function Editor:GetRenderStringSelected(str, offset)
	local tabsize = self.settings.tab_size
	local s = ""
	offset = offset or 0
	str = self.settings.show_control_characters and string.gsub(str, "([^%C \t])", function(c) return "<0x" .. string.byte(c) .. ">" end) or str

	for i = 1, self.len(str) do
		local c = self.sub(str, i, i)
		s = s .. (c == "\t" and string.rep("-", tabsize - ((self.len(s) + offset) % tabsize) - 1) .. ">" or (c == " " and "·" or " "))
	end

	return s
end

function Editor:RenderToRealPos(str, pos)
	local tabsize = self.settings.tab_size
	local l = 0

	for i = 1, self.len(str) do
		local t = self.sub(str, i, i) == "\t"
		local c = tabsize - (l % tabsize)
		l = l + (t and c or 1)
		-- if l >= pos then return i end
		if (t and (l - math.floor(c / 2 - 0.5)) or l) >= pos then return i end
	end

	return self.len(str)
end

function Editor:RealToRenderPos(str, pos)
	local tabsize = self.settings.tab_size
	local l = 0

	for i = 1, pos - 1 do
		l = l + (self.sub(str, i, i) == "\t" and tabsize - (l % tabsize) or 1)
	end

	return l + 1
end

function Editor:GetTabStr(x, line)
	if self.settings.tab_spaces then
		return string.rep(" ", self.settings.tab_size - ((x - 1) % self.settings.tab_size))
	elseif self.settings.tab_inline_spaces then
		if string.match(line, "%s*()") - 1 == x then
			return "\t"
		else
			return string.rep(" ", self.settings.tab_size - ((x - 1) % self.settings.tab_size))
		end
	end

	return "\t"
end

function Editor:MatchWord(str, x)
	local s, e = string.match(self.sub(str, 1, x), "()[%w_\128-\255]*$"), string.match(self.sub(str, x), "^[%w_\128-\255]*()") + string.len(self.sub(str, 1, x - 1))

	if not self.settings.utf8 then
		return s, e, self.sub(str, s, e)
	else
		local word = string.sub(str, s, e - 1)
		local s = self.len(string.sub(str, 1, s - 1))

		return s + 1, s + self.len(word) + 1, word
	end
end

function Editor:UpdateSettings(settings)
	settings = table.Copy(settings)
	self.settings = settings
	self:CheckUTF8(self:GetContentStr())
	self.ignore_chars = {}

	if settings.ignore_chars then
		for _, c in ipairs(settings.ignore_chars) do
			self.ignore_chars[c] = true
		end
	end

	if settings.tab_spaces then
		self.tab_str = string.rep(" ", settings.tab_size)
		self.tab_strsize = settings.tab_size
	else
		self.tab_str = "\t"
		self.tab_strsize = 1
	end

	self.should_refresh = true
end

function Editor:CheckUTF8(str)
	if not utf8.len(str) then
		self.settings.utf8 = false
	end

	self.content_data:UpdateSettings(self.settings)
	self.len = self.settings.utf8 and utf8.len or string.len
	self.sub = self.settings.utf8 and utf8.sub or string.sub
end

--- Adds everything like the validate bar and console for Expression scripting.
function Editor:AddExpressionAddons()
	self.expression = true
	self.validator = Validator(self)
	self:AddValidateBar()
	self:AddConsole()
	self:Validate(self:GetContentStr(), false)
end

function Editor:RemoveExpressionAddons()
	if not self.expression then return end
	self.expression = false
	self.validator:Stop()
	self.validator = nil
	self:RemoveValidateBar()
	self:RemoveConsole()
end

--- Adds the bottom console for errors and warnings.
function Editor:AddConsole()
	if self.console then return end
	local console = self:Add("E4Console")
	console:SetHeight(150)
	console:Dock(BOTTOM)
	self.console = console
end

function Editor:RemoveConsole()
	if not self.console then return end
	self.console:Remove()
	self.console = nil
end

function Editor:AddValidateBar()
	self.validation_bar = self:Add("Button")
	self.validation_bar:SetHeight(22)
	self.validation_bar:Dock(BOTTOM)
	self.validation_bar:SetText(" Click to validate...")
	self.validation_bar.UpdateColours = function(button, skin) return button:SetTextStyleColor(skin.Colours.Button.Down) end

	self.validation_bar.SetBGColor = function(button, col)
		self.validation_bar.bgcolor = col
	end

	self.validation_bar.bgcolor = Color(214, 236, 114)

	self.validation_bar.Paint = function(button)
		local w, h = button:GetSize()
		draw.RoundedBox(1, 0, 0, w, h, button.bgcolor)

		if button.Hovered then
			draw.RoundedBox(0, 1, 1, w - 2, h - 2, Color(0, 0, 0, 128))
		end
	end

	self.validation_bar.OnMousePressed = function(panel, btn)
		if btn == MOUSE_RIGHT then
			local menu = DermaMenu()

			menu:AddOption("Copy to clipboard", function()
				--SetClipboardText(self.validation_bar:GetValue())
				SetClipboardText( ExpressiveEditor.GetCode() or self:GetContentStr() )
			end)

			menu:AddOption("Copy Generated Lua", function()
				local code = ExpressiveEditor.GetCode() or self:GetContentStr()
				local success, lua = self:Validate(code)

				if success then
					SetClipboardText(lua)
				end
			end)

			menu:AddOption("Copy AST", function()
				local code = ExpressiveEditor.GetCode() or self:GetContentStr()
				local success, _, ast = self:Validate(code, true)

				if success then
					SetClipboardText( ELib.Inspect(ast) )
				end
			end)

			menu:AddOption("Copy Tokens", function()
				local code = ExpressiveEditor.GetCode() or self:GetContentStr()
				local success, _, _, tokens = self:Validate(code, true)

				if success then
					SetClipboardText( ELib.Inspect(tokens) )
				end
			end)

			menu:Open()
		else
			self:Validate(self:GetContentStr(), true)
		end
	end
end

function Editor:RemoveValidateBar()
	if self.validation_bar then
		self.validation_bar:Remove()
		self.validation_bar = nil
	end
end

vgui.Register("E4SyperEditor", Editor, "E4SyperBaseTextEntry")