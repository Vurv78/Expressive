local ELib = require("expressive/library")
local Extension = require("expressive/extension")

local Type = ELib.Type
local Base = Extension.new("base", true)

---@param ctx Context
function Base:enable(ctx)
	local DoubleType = Type.new("double")
	local IntType = Type.new("int", DoubleType)
	local StringType = Type.new("string")
	local BooleanType = Type.new("boolean")
	local FunctionType = Type.new("function")
	local ArrayType = Type.new("array") -- TODO: Should be generic

	-- These are compile time checkers to make sure that extensions are being good about what they register as constant values
	-- These will not be used at runtime since they'd be inaccurate and slow down the chip.
	DoubleType.instanceof = isnumber
	function IntType.instanceof(x)
		return isnumber(x) and (x % 1) == 0
	end
	StringType.instanceof = isstring
	BooleanType.instanceof = isbool
	FunctionType.instanceof = isfunction
	ArrayType.instanceof = istable

	ctx:registerType("int", IntType) -- Rounded number type
	ctx:registerType("double", DoubleType) -- Double precision floating point number
	ctx:registerType("string", StringType)
	ctx:registerType("boolean", BooleanType)
	ctx:registerType("function", FunctionType)
	ctx:registerType("array", ArrayType)

	ctx:registerConstant("add", FunctionType, function(a, b)
		return a + b
	end)

	ctx:registerConstant("print", FunctionType, function(...)
		local a = string.format(...)
	end)
end

return Base