local ELib = require("expressive/library")
local class = require("voop")

local Var = ELib.Var

--- The context in that an E4 chip runs in.
--- Fields here that namespace doesn't have might be removed.
---@class Context: Namespace
---@field funcs table<string, fun()>
---@field constants table<string, {value: any, type: Type}>
---@field extensions table<Extension, boolean>
local Context = class("Context", ELib.Namespace)

---@return Context
function Context.new()
	return setmetatable({
		name = "global",
		namespaces = {},
		variables = {},
		types = {},

		funcs = {},
		constants = {},
		extensions = {},
	}, Context)
end

--- May be deleted.
---@param name string
---@param ty Type # Type of the constant, note this is NOT the signature. Get the type from ctx:getType(name)
---@param value any # Value of the constant. MUST be of the same type as the given type.
function Context:registerConstant(name, ty, value)
	assert( type(name) == "string", "name must be a string" )
	assert( ty and ELib.Type == getmetatable(ty), "Tried to register a constant '" .. name .. "' with an invalid type object." )
	assert( ty:isReady(), "Tried to register a constant with an invalid type object. Missing functions: TODO" )

	self.constants[name] = {
		["value"] = value,
		["type"] = type
	}
end

--- May be deleted.
---@return Type
function Context:getType(name)
	return assert(self.types[name], "Missing type " .. name)
end

--- May be deleted
---@param ext Extension
function Context:load(ext)
	self.extensions[ext] = true
	ext:register(self)
end

--- Returns a prepared runtime environment of a context.
---@return table
function Context:getEnv()
	local env = {}

	---@param v table # The list of variable nodes to add
	---@param namespace table # Where to put the values. Defaults to env
	---@param from table # Table of where to get the values from. Defaults to _G
	local function addVars(v, namespace, from)
		namespace = namespace or env
		from = from or _G

		-- TODO: Support for beyond just one namespace
		for name, var in pairs(v) do
			if Var:instanceof(var) then
				print("Setting ", name, var.type, from[name])
				namespace[name] = from[name]
			elseif type(var) == "table" then
				-- Namespace.
				namespace[name] = {}
				print("Set namespace ", name)
				addVars(var, namespace[name])
			else
				error("Invalid variable type: " .. type(var))
			end
		end
	end

	addVars(self.variables)

	---@param nm table # Environment to add the variables to
	---@param space Namespace
	local function addNamespace(nm, space)
		nm[space.name] = {}
		addVars(space.variables, nm[space.name], _G[space.name])

		for name, sp in pairs(space.namespaces) do
			addNamespace(sp)
		end
	end

	for name, mod in pairs(self.namespaces) do
		addNamespace(env, mod)
	end

	for name, const in pairs(self.constants) do
		env[name] = const.value
	end

	for name, fn in pairs(self.funcs) do
		env[name] = fn
	end

	PrintTable(env)

	return env
end

ELib.Context = Context
return Context