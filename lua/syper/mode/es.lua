local ELib = require("expressive/library")

local TOKEN = Syper.TOKEN

local ignore = {"mcomment", "string"}

local env = {}

if ExpressiveEditor then
	table.Merge(env, ExpressiveEditor.HelperData.libraries_sig)
	table.Merge(env, ExpressiveEditor.HelperData.constants)
elseif ELib then
	table.Merge(env, ELib.Keywords)
end

return {
	name = "Expressive",
	ext = {"es"},
	indent = {
		{"{", ignore},
		{"(", ignore},
	},
	outdent = {
		{"}", ignore},
		{")", ignore},
	},
	pair = {
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
			open = {"function", "else"}
		},
		["else"] = {
			token = TOKEN.Keyword,
			open = {"function", "else"}
		},
		["end"] = {
			token = TOKEN.Keyword,
			open = {"function", "else"}
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
		["\""] = {
			"\"", ignore, {"\\"}
		},
	},
	comment = "// ",
	env = env,
	env_populator = function(str) end,
	-- TODO -- Most of this is taken from the lua mode. sevii is very cool
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