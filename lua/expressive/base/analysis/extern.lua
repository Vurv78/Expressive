--- Extern Pass
local ELib = require("expressive/library")

-- First pass of the analyzer.
-- Just gather any data that can be gathered without any other variables in context.
local Analyzer = ELib.Analyzer
local makeSignature = ELib.Analyzer.makeSignature
local NODE_KINDS = ELib.Parser.KINDS

local Var = ELib.Var
local Type = ELib.Type

local ExternHandlers
ExternHandlers = {
	---@param self Analyzer
	---@param name string
	---@param data table
	["namespace"] = function(self, name, data)
		---@type table<number, Node>
		local nodes = data[3]

		local out_nodes = {}
		for k, node in ipairs(nodes) do
			out_nodes[k] = ExternHandlers[node[1]](self, node.data)
		end
		-- TODO
		print("namespace nodes", ELib.Inspect(out_nodes))
		self.externs[name] = out_nodes
	end,

	--- Primitive type decl
	---@param self Analyzer
	---@param name string
	---@param data table
	["type"] = function(self, name, data)
		self.ctx:registerType(name, Type.new(name))
	end,

	---@param self Analyzer
	---@param name string
	---@param data table
	["var"] = function(self, name, data)
		local mutability = data[3] -- "var" or "const"
		local type = data[4]
		self.ctx:registerVar(name, Var.new(type, nil, mutability))
		-- self.externs[name] = Var.new(type, mutability == "const")
	end,

	---@param self Analyzer
	---@param name string
	---@param data table
	["function"] = function(self, name, data)
		-- Should create a proper function signature with this in the future.
		local params, ret = data[3], data[4]

		-- Extract types from params
		---@type table<number, TypeSig>
		local fn_params = {}
		for k, v in ipairs(params) do fn_params[k] = v[2] end
		local type_sig = makeSignature(fn_params, ret)

		-- Cannot modify externs
		local var = Var.new(type_sig, nil, false)
		self.ctx:registerVar(name, var)
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
			ExternHandlers[type](self, var_name, node.data)
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