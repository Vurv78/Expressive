--- Extern Pass
local ELib = require("expressive/library")

-- First pass of the analyzer.
-- Just gather any data that can be gathered without any other variables in context.
local Analyzer = ELib.Analyzer
local makeSignature = ELib.Analyzer.makeSignature
local NODE_KINDS = ELib.Parser.KINDS

local Var = ELib.Var
local Type = ELib.Type
local Namespace = ELib.Namespace

local ExternHandlers
ExternHandlers = {
	---@param self Analyzer
	---@param name string
	---@param data table
	---@param namespace Namespace
	["namespace"] = function(self, name, data, namespace)
		---@type table<number, Node>
		local nodes = data[3]
		local mod = Namespace.new(name, namespace)

		for _, node in ipairs(nodes) do
			ExternHandlers[node[1]](self, node[2], node, mod)
		end

		namespace.namespaces[name] = mod
	end,

	--- Primitive type decl
	---@param self Analyzer
	---@param name string
	---@param data table
	---@param namespace Namespace
	["type"] = function(self, name, data, namespace)
		namespace:registerType(name, Type.new(name))
	end,

	---@param self Analyzer
	---@param name string
	---@param data table
	---@param namespace Namespace
	["var"] = function(self, name, data, namespace)
		local mutability = data[3] -- "var" or "const"
		local type = data[4]
		namespace:registerVar(name, Var.new(type, nil, mutability))
		-- self.externs[name] = Var.new(type, mutability == "const")
	end,

	---@param self Analyzer
	---@param name string
	---@param data table
	---@param namespace Namespace
	["function"] = function(self, name, data, namespace)
		-- Should create a proper function signature with this in the future.
		local params, ret = data[3], data[4]

		if not params then debug.Trace() end

		-- Extract types from params
		---@type table<number, TypeSig>
		local fn_params = {}
		for k, v in ipairs(params) do fn_params[k] = v[2] end
		local type_sig = makeSignature(fn_params, ret)

		-- Cannot modify externs
		local var = Var.new(type_sig, nil, false)
		namespace:registerVar(name, var)
	end,
}

local Handlers = {
	---@param self Analyzer
	---@param node Node
	[NODE_KINDS.Declare] = function(self, node)
		assert(self.configs.AllowDeclare, "Declare statements are not allowed in regular code")

		local type, var_name = node.data[1], node.data[2]
		local handler = ExternHandlers[type]
		if handler then
			ExternHandlers[type](self, var_name, node.data, self.ctx)
		end
	end
}

--- Runs first pass on the analyzer
---@param ast table<number, Node>
function Analyzer:externPass(ast)
	if not ast then return end -- Empty block
	for _, node in ipairs(ast) do
		local handler = Handlers[node.kind]
		if handler then
			handler(self, node)
		end
	end
end