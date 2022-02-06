-- Toolgun screen for Expression4.
local class = require("voop")

local Res = Vector(256, 256)
local Offset = Vector(0, 0)
local ResScale = Res / 256

local HexSize = Vector(50, 50) * ResScale

local HexMesh = Mesh()
HexMesh:BuildFromTriangles({
	{pos = Vector(1,1 / 4), u = 1, v = 1 / 4}, -- right up
	{pos = Vector(1,3 / 4), u = 1, v = 3 / 4}, -- right down
	{pos = Vector(0,3 / 4), u = 0, v = 3 / 4}, -- left down
	{pos = Vector(0,3 / 4), u = 0, v = 3 / 4}, -- left down
	{pos = Vector(0,1 / 4), u = 0, v = 1 / 4}, -- left up
	{pos = Vector(1,1 / 4), u = 1, v = 1 / 4}, -- right up
	{pos = Vector(0,1 / 4), u = 0, v = 1 / 4}, -- left up
	{pos = Vector(0.5, 0), u = 0.5, v = 0}, -- top middle
	{pos = Vector(1,1 / 4), u = 1, v = 1 / 4}, -- right up
	{pos = Vector(0,3 / 4), u = 0, v = 3 / 4}, -- left down
	{pos = Vector(1,3 / 4), u = 1, v = 3 / 4}, -- right down
	{pos = Vector(0.5,1), u = 0.5, v = 1}, -- bottom middle
})

--- Hexagon object on the toolgun
---@class Hex: Object
---@field ang GAngle
---@field angvel GAngle
---@field pos GVector
---@field vel GVector
---@field color GVector
---@field last_think number
---@field alpha number
---@field matrix GVMatrix
local Hex = class("Hexagon")

local ObjectMat = CreateMaterial("Expression4.Gear", "UnlitGeneric")
ObjectMat:SetInt("$flags", 32816)

function Hex.new(pos, velocity, color, ang, angvel)
	pos = pos or Vector( 128 + math.Rand( 0, Res[1] ), 128 + math.Rand( 0, Res[2] ) )
	ang = ang or Angle(0, 0)

	local matrix = Matrix()

	matrix:SetScale(HexSize)
	matrix:SetTranslation(pos)
	matrix:SetAngles(ang)

	local rngfactor = math.Rand(-5, 5)

	return setmetatable({
		matrix = matrix,
		pos = pos,
		velocity = velocity or Vector(rngfactor * 5, rngfactor * 5),
		color = color or Vector( CurTime() % 25 * 1 / 25 + 0.15 , 0, 0),
		alpha = 0.5,

		ang = ang,
		angvel = angvel or Angle(0, math.Rand(-1, 1) * 4 * rngfactor),

		last_think = CurTime()
	}, Hex)
end

local Hexagons
function Hex:think()
	local now = CurTime()
	local dt = now - self.last_think
	self.last_think = now

	for _, hex in pairs(Hexagons) do
		if self.pos:Distance(hex.pos) <= HexSize[1] then
			self.velocity = -self.velocity
			hex.velocity = -hex.velocity
		end
	end

	-- pf = p0 + vt
	local next = self.pos + self.velocity * dt

	local nextbound = next - Offset
	local offset_bounds = Offset - HexSize

	if self.velocity:Length2DSqr() > 100 then
		return false
	end

	if nextbound[1] > Res[1] or nextbound[2] > Res[2] or next[1] < offset_bounds[1] or next[2] < offset_bounds[2] then
	--if nextbound[1] > Res[1] or nextbound[2] > Res[2] or next[1] < offset_bounds[1] or next[2] < offset_bounds[2] then
		self.velocity = -self.velocity * 2
	end

	self:setAngles(self.ang + self.angvel * dt)
	self:setPos(next)
	return true
end

function Hex:setAngles(a)
	self.ang = a
	self.matrix:SetAngles(a)
end

function Hex:setPos(v)
	self.pos = v
	self.matrix:SetTranslation(v)
end

function Hex:draw()
	ObjectMat:SetVector("$color", self.color)
	ObjectMat:SetFloat("$alpha", self.alpha)

	surface.SetMaterial(ObjectMat)

	surface.DrawTexturedRectRotated( self.pos[1], self.pos[2], HexSize[1], HexSize[2], self.ang[2] )
end

surface.CreateFont("Expression4_ToolgunTitle", {
	font = "Arial",
	size = 40 * Res[1] / 256,
	weight = 400,
	antialias = true,
	additive = false,
	shadow = true,
	outline = false,
	blur = true,
	extended = true,
})

surface.CreateFont("Expression4_ToolgunSubtitle", {
	font = "Arial",
	size = 36 * Res[1] / 256,
	underline = true,
	weight = 400,
	antialias = true,
	additive = false,
	shadow = true,
	outline = false,
	blur = true,
	extended = true,
})

local ToolgunScreen = {}

Hexagons = {}
for i = 1, 10 do
	Hexagons[i] = Hex.new(nil, nil, Vector( math.Rand(0, 1), 0, 0 ))
end

function ToolgunScreen.render(width, height)
	if width ~= Res[1] then
		--  I don't think the toolgun screen will ever change size, but w/e
		Res[1] = width
		Res[2] = height

		ResScale = Res / 256
		HexScale = Vector(50, 50) * ResScale
	end

	render.Clear(0, 0, 0, 255)

	surface.SetDrawColor(40, 40, 40, 200)
	surface.DrawRect(Offset[1], Offset[2], Res[1], Res[2])

	surface.SetDrawColor(255, 255, 255, 255)
	surface.DrawOutlinedRect(Offset[1], Offset[2], Res[1], Res[2], 1 * ResScale[1])

	render.SetMaterial(ObjectMat)

	for _, hex in pairs(Hexagons) do
		hex:draw()
	end

	surface.SetFont("Expression4_ToolgunTitle")
	draw.SimpleText("Expression4", "Expression4_ToolgunTitle", Offset[1] + Res[1] / 10 + Res[1] * 3 / 4 * 1 / 2, Offset[2] + Res[2] / 3 + 10 * ResScale[1], Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)


	surface.SetFont("Expression4_ToolgunSubtitle")
	draw.SimpleText("generic.txt", "Expression4_ToolgunSubtitle", Offset[1] + Res[1] / 10 + Res[1] * 3 / 4 * 1 / 2, Offset[2] + Res[2] / 3 + 10 * ResScale[1] + 30 * ResScale[1] + 10 * ResScale[1], Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function ToolgunScreen.think()
	for k, hex in pairs(Hexagons) do
		local ok = hex:think()
		if not ok then
			local vel = Vector(math.Rand(-1, 1), math.Rand(-1, 1))
			local origin = Offset + Res / 2
			Hexagons[k] = Hex.new( origin + vel * Res, -vel * 10 )
		end
	end
end

return ToolgunScreen