local ELib = require("expressive/library")

--- The context in that an E4 chip runs in.
---@class Context
---@field funcs table<string, fun()>
---@field types table<TypeSig, Type>
---@field constants table<string, {value: any, type: Type}>
---@field extensions table<Extension, boolean>
local Context = {}
Context.__index = Context

function Context.new()
	return setmetatable({
		funcs = {},
		types = {},
		constants = {},
		extensions = {}
	}, Context)
end

--- Returns if ``var`` is a ``Context``
---@return boolean
function Context.instanceof(var)
	return istable(var) and getmetatable(var) == Context
end

-- Todo
function Context:registerFn(signature, fn)
	self.funcs[signature] = fn
end

---@param name string
---@param type Type
function Context:registerType(name, type)
	self.types[name] = type
end

---@param name string
---@param type Type # Type of the constant, note this is NOT the signature. Get the type from ctx:getType(name)
---@param value any # Value of the constant. MUST be of the same type as the given type.
function Context:registerConstant(name, type, value)
	assert( isstring(name), "name must be a string" )
	assert( type and ELib.Type == getmetatable(type), "Tried to register a constant '" .. name .. "' with an invalid type object." )
	assert( type:isReady(), "Tried to register a constant with an invalid type object. Missing functions: TODO" )

	self.constants[name] = {
		["value"] = value,
		["type"] = type
	}
end

function Context:getType(name)
	return assert(self.types[name], "Missing type " .. name)
end

---@param ext Extension
function Context:load(ext)
	self.extensions[ext] = true
	ext:register(self)
end

--- Returns a prepared runtime environment of a context.
---@return table
function Context:getEnv()
	local env = {}

	for name, const in pairs(self.constants) do
		env[name] = const.value
	end

	for name, fn in pairs(self.funcs) do
		env[name] = fn
	end

	return env
end

ELib.Context = Context
return Context