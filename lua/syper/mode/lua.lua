local TOKEN = Syper.TOKEN

local ignore = {"mcomment", "mstring", "string"}

return {
	name = "Lua",
	ext = {"lua"},
	indent = {
		{"function", ignore},
		{"then", ignore},
		{"else", ignore},
		{"do", ignore},
		{"repeat", ignore},
		{"{", ignore},
		{"(", ignore},
	},
	outdent = {
		{"elseif", ignore},
		{"else", ignore},
		{"end", ignore},
		{"until", ignore},
		{"}", ignore},
		{")", ignore},
	},
	pair = {
		["function"] = {
			token = TOKEN.Keyword_Modifier,
			open = {"function", "then", "else", "do"}
		},
		["then"] = {
			token = TOKEN.Keyword,
			open = {"function", "then", "else", "do"}
		},
		["else"] = {
			token = TOKEN.Keyword,
			open = {"function", "then", "else", "do"}
		},
		["do"] = {
			token = TOKEN.Keyword,
			open = {"function", "then", "else", "do"}
		},
		["repeat"] = {
			token = TOKEN.Keyword,
			open = {"repeat"}
		},
		["{"] = {
			token = TOKEN.Punctuation,
			open = {"{"}
		},
		["("] = {
			token = TOKEN.Punctuation,
			open = {"("}
		},
		["["] = {
			token = TOKEN.Punctuation,
			open = {"["}
		},
	},
	pair2 = {
		["elseif"] = {
			token = TOKEN.Keyword,
			open = {"function", "then", "else", "do"}
		},
		["else"] = {
			token = TOKEN.Keyword,
			open = {"function", "then", "else", "do"}
		},
		["end"] = {
			token = TOKEN.Keyword,
			open = {"function", "then", "else", "do"}
		},
		["until"] = {
			token = TOKEN.Keyword,
			open = {"repeat"}
		},
		["}"] = {
			token = TOKEN.Punctuation,
			open = {"{"}
		},
		[")"] = {
			token = TOKEN.Punctuation,
			open = {"("}
		},
		["]"] = {
			token = TOKEN.Punctuation,
			open = {"["}
		},
	},
	bracket = {
		["{"] = {"}", ignore},
		["("] = {")", ignore},
		["["] = {"]", ignore},
		["'"] = {
			"'", ignore, {"\\"}
		},
		["\""] = {
			"\"", ignore, {"\\"}
		},
	},
	comment = "-- ",
	env = _G,
	env_populator = function(str)
		local lcal = string.match(str, "local()")
		local e = lcal or 1
		local stacks = {}

		for _ = 1, 16 do
			local stack = {}

			for i = 1, 16 do
				local s, e2 = string.match(string.sub(str, e), (i == 1 and "^%s*" or "^%s*[%.:]%s*") .. "([%a_][%w_]*)()")

				if not s then
					if i == 1 then break end
					s, e2 = string.match(string.sub(str, e), "^%s*%[%s*\"(.*)\"%s*%]()")

					if not s then
						s, e2 = string.match(string.sub(str, e), "^%s*%[%s*'(.*)'%s*%]()")
						if not s then break end
					end
				end

				e = e + e2 - 1
				stack[#stack + 1] = s
			end

			stacks[#stacks + 1] = stack
			local e2 = string.match(string.sub(str, e), "^%s*,%s*()")
			if not e2 then break end
			e = e + e2 - 1
		end

		if string.match(str, "%s*=", e) and #stacks > 0 and #stacks[1] > 0 then return lcal ~= nil, stacks end
	end,
	autocomplete_stack = function(str)
		local e = #str
		local stack = {}

		for i = 1, 16 do
			local e2, s

			if i == 1 then
				e2, s = string.match(string.sub(str, 1, e), "()([%a_][%w_]*)$")

				if not e2 then
					e2, s = string.match(string.sub(str, 1, e), "[%.:]%s*()(_?)$")
				end
			else
				e2, s = string.match(string.sub(str, 1, e), "()([%a_][%w_]*)%s*[%.:]?%s*$")
			end

			if not e2 then
				e2, s = string.match(string.sub(str, 1, e), "()%[(%d*%.?x?%d*)%]%s*[%.:]?%s*$")

				if s then
					s = tonumber(s)
				end
			end

			if not e2 then
				e2, s = string.match(string.sub(str, 1, e), "()%[\"(.*)\"%]%s*[%.:]?%s*$")
			end

			if not e2 then
				e2, s = string.match(string.sub(str, 1, e), "()%['(.*)'%]%s*[%.:]?%s*$")
			end

			if not e2 then break end
			e = e2 - 1
			stack[#stack + 1] = s
		end

		if #stack > 0 then return table.Reverse(stack) end
	end,
	autocomplete = function(pre, key)
		local typ = type(key)
		if typ == "string" and string.match(string.sub(key, 1, 1), "[%a_]") then return key, 0 end
		local rem = #string.match(pre, "([^%.%[]*)$")
		if typ == "number" then return "[" .. tostring(key) .. "]", rem end

		return "[\"" .. tostring(key) .. "\"]", rem
	end,
	livevalue = function(value)
		local typ = type(value)
		local val = tostring(value)

		if typ == "table" then
			val = table.Count(value) .. " entries"
		elseif typ == "function" then
			return val
		end

		return typ .. ": " .. val
	end
}