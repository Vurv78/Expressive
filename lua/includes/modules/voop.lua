--- Completely unnecessary OOP Library by yours truly

---@class Object
local Object = {}
Object.__index = Object
Object.__metatable = "Object"

---@param name "gc"|"tostring"|"eq"|"len"|"unm"|"add"|"sub"|"mul"|"div"|"mod"|"pow"|"concat"|"call"|"index"|"newindex"
---@param fn function
function Object:meta(name, fn)
	-- Compat for Lua 5.1 / LuaJIT
	if name == "gc" then
		local proxy = newproxy(true)
		debug.setmetatable(proxy, {
			__gc = function()
				fn(self)
			end
		})
	end
	self["__" .. name] = fn
end

function Object:__tostring()
	return "Object"
end

---@generic T
---@param self T
---@return boolean
function Object:instanceof(x)
	return (type(x) == "table") and getmetatable(x).__name__ == self.__name__
end

---@generic T
---@return T
function Object:new(...)
	return setmetatable({}, self)
end

---@param name string
---@param extends Object?
---@generic T : Object
---@return T
local function class(name, extends)
	local t = { __name__ = name }
	t.__index = t

	extends = extends or Object

	return setmetatable(t, {
		__tostring = function() return name end,
		__metatable = name,
		__index = extends
	})
end

--[[
local A = class("foo")
function A.new()
	return setmetatable({}, A)
end

function A:bar()
	MsgN("Bar")
end

local B = class("bar", A)

B.new():bar()

MsgN(A.new(), A, A.bar, A:instanceof(A.new()), A.new():bar())
]]

return class