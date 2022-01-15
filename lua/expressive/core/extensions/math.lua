local ELib = require("expressive/library")
local Extension = require("expressive/extension")

local Type = ELib.Type
local Math = Extension.new("math", true)

---@param ctx Context
function Math:enable(ctx)
	local DoubleType = Type.new("double")
	DoubleType.instanceof = isnumber

	ctx:registerType("double", DoubleType)

	local IntType = Type.new("int", DoubleType)
	ctx:registerType("int", IntType)

	ctx:registerConstant("add", Function)

	ctx:registerFn("add(int, int): int", function(a, b)
		return a + b
	end)

	ctx:registerConstant("pi", IntType, math.pi)
end

---@param ctx Context
function Math:disable(ctx)
	print("Disabled math extension!")
end

return Math