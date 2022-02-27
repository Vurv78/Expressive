-- Tools to interact with the AST generated by the parser
local ELib = require("expressive/library")
local class = require("voop")

---@class Ast: Object
local Ast = class("Ast")
ELib.Ast = Ast

function Ast:__tostring()
	return "Ast: " .. #self
end

function Ast.new(tbl)
	return setmetatable(tbl, Ast)
end

--- Walks an ast, going through every node and calling the callback at it.
---@param callback fun(node: Node, depth: integer)
---@param depth integer?
function Ast:walk(callback, depth)
	depth = depth or 0
	for _, v in ipairs(self) do
		if Ast:instanceof(v) then
			v:walk(callback, depth + 1)
		elseif ELib.Parser.Node:instanceof(v) then
			Ast.walk(v.data, callback, depth)
			--[[for k, v2 in ipairs(v.data) do
				print( string.format("%s[%s (%s: %s)]", string.rep("\t", depth), ELib.Parser.KINDS_INV[v.kind], type(v2), v2))
				if getmetatable(v2) and Ast:instanceof(v2) then
					v2:walk(callback, depth + 1)
				end
			end]]
			---@type Node
			callback(v, depth)
		end
	end
end

return Ast