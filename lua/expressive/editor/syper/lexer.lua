ExpressiveEditor.Lexer = {
	lexers = {}
}

local Lexer = ExpressiveEditor.Lexer
local TOKEN = ExpressiveEditor.TOKEN

if CLIENT then
	----------------------------------------
	function Lexer.prepareLexer(lexer)
		for mode, data in pairs(lexer) do
			for _, v in ipairs(data) do
				if v.list then
					local new = {}

					for _, n in ipairs(v.list) do
						new[n] = true
					end

					v.list = new
				end
			end
		end

		return lexer
	end

	local function find(str, start, patterns, repl)
		local finds = {}

		for i, pattern in ipairs(patterns) do
			local s, _, str, cap = string.find(str, repl and string.gsub(pattern[1], "<CAP>", repl) or pattern[1], start)

			if s and (not pattern.shebang or start == 1) then
				local token = (not pattern.list or pattern.list[str]) and pattern[2] or pattern.list_nomatch

				if token then
					finds[#finds + 1] = {
						s = s,
						e = s + #str - 1,
						str = str,
						cap = cap,
						token = token,
						mode = pattern[3]
					}
				end
			end
		end

		if #finds == 0 then return end
		local s, cur = math.huge, nil

		for _, v in ipairs(finds) do
			if v.s < s then
				s = v.s
				cur = v
			end
		end

		return cur
	end

	local ContentTable = {}
	ContentTable.__index = ContentTable

	function ContentTable:InsertLine(y, str)
		table.insert(self.lines, y, {
			str = str,
			len = self.len(str),
			tokens = {},
			mode = nil,
			mode_repl = nil,
			render = nil,
			fold = y > 1 and self.lines[y - 1].fold,
			folded = false,
		})

		local dirty = {}

		for i, _ in pairs(self.dirty) do
			dirty[i >= y and i + 1 or i] = true
		end

		dirty[y] = true
		self.dirty = dirty
		self:UpdateLineData()
	end

	function ContentTable:RemoveLine(y)
		self:UnfoldLine(y)
		table.remove(self.lines, y)
		local dirty = {}

		for i, _ in pairs(self.dirty) do
			dirty[i >= y and i - 1 or i] = true
		end

		if y <= #self.lines then
			dirty[y] = true
		end

		self.dirty = dirty
		self:UpdateLineData()
	end

	function ContentTable:ModifyLine(y, str)
		if not self.lines[y] then
			self.lines[y] = {
				str = str,
				len = self.len(str),
				tokens = {},
				mode = nil,
				mode_repl = nil,
				render = nil,
				fold = y > 1 and self.lines[y - 1].fold,
				folded = false,
			}

			self:UpdateLineData()
		else
			self.lines[y].str = str
			self.lines[y].len = self.len(str)
		end

		self.dirty[y] = true
	end

	function ContentTable:FoldLine(y)
		local line = self.lines[y]
		local x, pair = nil

		for x2, token in ipairs(line.tokens) do
			if token.foldable and token.pair_main then
				pair = token.pair
				x = x2
				break
			end
		end

		if not pair then return end
		if pair.y <= y + 1 then return end
		line.folded = true

		for y2 = y + 1, pair.y - 1 do
			self.lines[y2].fold = true
			self.lines[y2].folded = false
		end

		self:UpdateLineData()
	end

	function ContentTable:UnfoldLine(y)
		local line = self.lines[y]
		if not line.folded then return end
		line.folded = false

		for y2 = y + 1, #self.lines do
			local line = self.lines[y2]
			if not line.fold then break end
			line.fold = false
		end

		self:UpdateLineData()
	end

	function ContentTable:InsertIntoLine(y, str, x)
		local str = self.sub(self.lines[y].str, 1, x - 1) .. str .. self.sub(self.lines[y].str, x)
		self.lines[y].str = str
		self.lines[y].len = self.len(str)
		self.dirty[y] = true
	end

	function ContentTable:AppendToLine(y, str)
		local str = self.lines[y].str .. str
		self.lines[y].str = str
		self.lines[y].len = self.len(str)
		self.dirty[y] = true
	end

	function ContentTable:PrependToLine(y, str)
		local str = str .. self.lines[y].str
		self.lines[y].str = str
		self.lines[y].len = self.len(str)
		self.dirty[y] = true
	end

	function ContentTable:RemoveFromLine(y, len, x)
		local str = self.sub(self.lines[y].str, 1, x - 1) .. self.sub(self.lines[y].str, x + len)
		self.lines[y].str = str
		self.lines[y].len = self.len(str)
		self.dirty[y] = true
	end

	function ContentTable:GetLineStr(y)
		return self.lines[y].str
	end

	function ContentTable:GetLineLength(y)
		return self.lines[y].len
	end

	function ContentTable:GetLineTokens(y)
		return self.lines[y].tokens
	end

	function ContentTable:GetLineCount()
		return #self.lines
	end

	function ContentTable:LineExists(y)
		return self.lines[y] ~= nil
	end

	function ContentTable:GetRenderString(y, offset)
		local str = self.lines[y].str
		local tabsize = self.settings.tab_size
		local s = ""
		offset = offset or 0

		if self.settings.show_control_characters then
			str = string.gsub(str, "([^%C \t])", function(c) return "<0x" .. string.byte(c) .. ">" end)
			str = string.gsub(str, "( )", "·")

			for i = 1, self.len(str) do
				local c = self.sub(str, i, i)
				s = s .. (c == "\t" and string.rep("-", tabsize - ((self.len(s) + offset) % tabsize)) or c)
			end

			return s
		end

		for i = 1, self.len(str) do
			local c = self.sub(str, i, i)
			s = s .. (c == "\t" and string.rep(" ", tabsize - ((self.len(s) + offset) % tabsize)) or c)
		end

		return s
	end

	function ContentTable:RebuildLine(y, callback)
		local lexer = self.lexer
		local line = self.lines[y]
		local curbyte = 1
		local mode, mode_repl

		if y > 1 then
			local prev = self.lines[y - 1]
			local tok = prev.tokens[#prev.tokens]
			mode = tok.mode
			mode_repl = tok.mode_repl
		else
			mode = "main"
		end

		line.tokens = {}
		line.mode = mode
		line.mode_repl = mode_repl
		line.render_str = self:GetRenderString(y)
		line.render_len = self.len(line.render_str)

		if callback and (SysTime() - self.last_time) > 0.03 then
			coroutine.wait(0.03)
			self.last_time = SysTime()
		end

		if line.len > 2048 then
			line.tokens[#line.tokens + 1] = {
				token = TOKEN.Other,
				str = line.str,
				mode = mode,
				mode_repl = mode_repl,
				s = 1,
				e = line.len - 1
			}
		else
			while true do
				local fdata = find(line.str, curbyte, lexer[mode], mode_repl)
				if not fdata then break end

				if fdata.mode then
					mode = fdata.mode
					mode_repl = fdata.cap
				end

				line.tokens[#line.tokens + 1] = {
					token = fdata.token,
					str = fdata.str,
					mode = mode,
					mode_repl = mode_repl,
					s = fdata.s,
					e = fdata.e
				}

				curbyte = fdata.e + 1
				if fdata.str[#fdata.str] == "\n" then break end
			end
		end

		return mode, mode_repl
	end

	function ContentTable:RebuildLines(y, c, callback)
		for y = y, y + c do
			local mode = self:RebuildLine(y, callback)
			local next_line = self.lines[y + 1]
			if not next_line or next_line.mode == mode then return y end
		end

		return y + c
	end

	function ContentTable:RebuildDirty(max_lines, callback)
		local function cor()
			local dirty = {}

			for y, _ in pairs(self.dirty) do
				dirty[#dirty + 1] = y
			end

			table.sort(dirty, function(a, b) return a < b end)
			local changed = {}

			for i = 1, #dirty do
				local y = dirty[i]

				if self.dirty[y] then
					for y = y, self:RebuildLines(y, max_lines, callback) do
						self.dirty[y] = nil
						changed[y] = true
					end
				end
			end

			return changed
		end

		if callback then
			cor = coroutine.create(cor)
			self.last_time = SysTime()

			hook.Add("Tick", tostring(self), function()
				local _, val = coroutine.resume(cor)

				if val then
					hook.Remove("Tick", tostring(self))
					callback(val)
				end
			end)
		else
			return cor()
		end
	end

	-- TODO: dont rebuild everything every time
	-- after checking performance, its fine for now
	function ContentTable:RebuildTokenPairs()
		local t = SysTime()
		local changed = {}
		local scopes = {}

		for k, _ in pairs(self.mode.pair) do
			scopes[k] = {}
		end

		local indent_level = 0
		local scope_origin = {}

		for y, line in ipairs(self.lines) do
			line.foldable = false
			line.indent_level = indent_level
			local indent_level_sum = 0
			local indent_level_changed = false

			for x, token in ipairs(line.tokens) do
				token.pair = nil
				local token_override = nil
				local pair = self.mode.pair2[token.str]

				if pair and pair.token == token.token then
					local pos, level

					for _, k in ipairs(pair.open) do
						level = #scopes[k]
						pos = scopes[k][level]
						scopes[k][level] = nil
					end

					if pos then
						local l = self.lines[pos.y]
						l.foldable = l.foldable or y > pos.y + 1
						l.scope_level = level
						local t = l.tokens[pos.x]

						t.pair = {
							x = x,
							y = y
						}

						t.pair_main = true
						t.foldable = y > pos.y + 1
						token.pair = pos
						scope_origin[#scope_origin] = nil
					else
						-- mark token error
						token_override = TOKEN.Error
					end
				end

				local pair = self.mode.pair[token.str]

				if pair and pair.token == token.token then
					for _, k in ipairs(pair.open) do
						scopes[k][#scopes[k] + 1] = {
							x = x,
							y = y
						}
					end

					scope_origin[#scope_origin + 1] = y
				end

				local indent = self.mode.indent[token.str]

				if indent and not indent[token.token] then
					indent_level_sum = indent_level_sum + 1
					indent_level_changed = true
				end

				local outdent = self.mode.outdent[token.str]

				if outdent and not outdent[token.token] then
					indent_level_sum = indent_level_sum - 1
					indent_level_changed = true
				end

				if token.token_override ~= token_override then
					changed[y] = true
				end

				token.token_override = token_override
			end

			local scope_origin = scope_origin[#scope_origin] or 0

			if indent_level_sum ~= 0 then
				indent_level = indent_level + (indent_level_sum > 0 and 1 or -1)

				if indent_level_sum < 0 then
					line.indent_level = indent_level
				end
			elseif indent_level_changed and scope_origin == y then
				line.indent_level = indent_level - 1
			end

			line.scope_origin = scope_origin
		end

		-- mark all unfinished error
		for _, v in pairs(scopes) do
			for _, pos in ipairs(v) do
				self.lines[pos.y].tokens[pos.x].token_override = TOKEN.Error
				changed[pos.y] = true
			end
		end

		return changed
	end

	function ContentTable:GetUnfoldedLineCount()
		local c = 0

		for y, line in ipairs(self.lines) do
			if not line.fold then
				c = c + 1
			end
		end

		return c
	end

	-- used for folding stuff
	function ContentTable:UpdateLineData()
		self.visual_lines = {}
		local vy = 1

		for y, line in ipairs(self.lines) do
			if not line.fold then
				self.visual_lines[vy] = y
				line.visual_y = vy
				vy = vy + 1
			else
				line.visual_y = nil
			end
		end
	end

	function ContentTable:GetAsString()
		local str = {}

		for i, line in ipairs(self.lines) do
			str[i] = line.str
		end

		str[#str] = string.sub(str[#str], 1, -2)

		return table.concat(str, "")
	end

	function ContentTable:SetFromString(str)
		local lines, p = {}, 1

		while true do
			local s = string.find(str, "\n", p)
			lines[#lines + 1] = string.sub(str, p, s)
			if not s then break end
			p = s + 1
		end

		self.lines = {}

		for y, str in ipairs(lines) do
			self:ModifyLine(y, str)
		end

		self:AppendToLine(#lines, "\n")
	end

	function ContentTable:Replace(find, replace)
		local content = self:GetAsString()
		local str, s = {}, 1

		for i, v in ipairs(find) do
			str[#str + 1] = string.sub(content, s, v[1])
			local repl = replace

			for j, sub in ipairs(v[3]) do
				repl = string.gsub(repl, "%f[%%]%%" .. j, sub)
			end

			str[#str + 1] = repl
			s = v[2] + 1
		end

		str[#str + 1] = string.sub(content, s, #content)
		self:SetFromString(table.concat(str, ""))
	end

	-- TODO: support bounds
	-- TODO: custom captures dont support capitalization if not case
	function ContentTable:Find(str, pattern, case, whole, bounds)
		local content = self:GetAsString()
		content = case and content or string.lower(content)
		str = case and str or string.lower(str)
		str = pattern and str or string.PatternSafe(str)
		str = whole and "%f[%w_\128-\255]()(" .. str .. ")[^%w_\128-\255]" or "()(" .. str .. ")"
		local finds = {}
		local iter = string.gmatch(content, str)

		while true do
			local vals = {iter()}

			if #vals == 0 then break end

			finds[#finds + 1] = {
				vals[1] - 1, vals[1] - 1 + #vals[2], {unpack(vals, 3)}
			}
		end

		local highlights = {}
		local x, y = 0, 1

		for _, find in ipairs(finds) do
			local bounds = {}
			local x2 = x

			for y2 = y, #self.lines do
				y = y2
				x2 = x2 + #self.lines[y].str

				if not bounds.sx and find[1] < x2 then
					bounds.sx = find[1] - x
					bounds.sy = y
				end

				if bounds.sx and find[2] <= x2 then
					bounds.ex = find[2] - x
					bounds.ey = y
				end

				if bounds.ex then
					break
				else
					x = x2
				end
			end

			highlights[#highlights + 1] = bounds
		end

		return finds, highlights
	end

	function ContentTable:UpdateSettings(settings)
		self.settings = settings
		self.len = settings.utf8 and utf8.len or string.len
		self.sub = settings.utf8 and utf8.sub or string.sub
	end

	function Lexer.createContentTable(lexer, mode, settings)
		settings = settings or ExpressiveEditor.Settings.settings

		return setmetatable({
			lexer = lexer,
			mode = mode,
			lines = {},
			visual_lines = {},
			dirty = {},
			settings = settings,
			len = settings.utf8 and utf8.len or string.len,
			sub = settings.utf8 and utf8.sub or string.sub
		}, ContentTable)
	end
	----------------------------------------
end

for _, name in pairs(file.Find("syper/lexer/*.lua", "LUA")) do
	local path = "syper/lexer/" .. name

	if SERVER then
		AddCSLuaFile(path)
	else
		-- Set 'Syper' to the Editor for compatibility with unforked instances of Syper.
		local old_syper = _G.Syper
		_G.Syper = ExpressiveEditor
		ExpressiveEditor.Lexer.lexers[string.sub(name, 1, -5)] = Lexer.prepareLexer(include(path))
		_G.Syper = old_syper
	end
end