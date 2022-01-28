---@class ExpressiveProcessor : GEntity
---@field owner GEntity
---@field chip_data table
---@field send_data table
---@field author string
---@field instance Instance
local ENT = _G.ENT

ENT.Type            = "anim"
ENT.Base            = "base_gmodentity"

ENT.PrintName       = "Expressive"
ENT.Author          = "Vurv"
ENT.Contact         = "vurvdevelops@gmail.com"
ENT.Purpose         = "To program in a strictly typed, safe and sandboxed environment."
ENT.Instructions    = ""

ENT.Spawnable       = false

ENT.States = {
	Normal = 1,
	Error = 2,
	None = 3,
}

ENT.Expressive = true

local ELib = require("expressive/library")
require("expressive/startup")

function ENT:Compile()
	if self.instance then
		print("no instance")
		self:Destroy()
	end

	self.error = nil

	local data = self.chip_data
	if not (data and data.modules and data.modules[data.main]) then
		print("no main")
		return
	end


	local lua_modules = {}
	local success, why = xpcall(function()
		for name, code in pairs(data.modules) do
			local Tokenizer = ELib.Tokenizer.new()
			local Parser = ELib.Parser.new()
			local Transpiler = ELib.Transpiler.new()
			local Analyzer = ELib.Analyzer.new()

			local tokens = Tokenizer:parse(code)
			local ast = Parser:parse(tokens)
			local new_ast = Analyzer:process(ELib.ExtensionCtx, ast)

			local lua = Transpiler:process(ELib.ExtensionCtx, new_ast)
			lua_modules[name] = lua
		end
	end, debug.traceback)

	if not success then
		self:Error("Failed to compile: " .. why)
	end

	local instance = ELib.Instance.from(ELib.ExtensionCtx, data.main, lua_modules, self, self.owner)
	self.name = "Generic (None)"

	self.instance = instance
	function instance.runOnError(err)
		-- Have to make sure it's valid because the chip can be deleted before deinitialization and trigger errors
		if IsValid(self) then
			self:Error(err)
		end
	end

	local ok, msg, traceback = instance:init()
	if not ok then return end

	if SERVER then
		self.ErroredPlayers = {}
		local clr = self:GetColor()
		self:SetColor(Color(255, 255, 255, clr.a))
		self:SetNWInt("State", self.States.Normal)

		if self.Inputs then
			for k, v in pairs(self.Inputs) do
				self:TriggerInput(k, v.Value)
			end
		end
	else
		ELib.StartNet("Processor.ClientReady")
			net.WriteEntity(self)
		net.SendToServer()
	end
end

function ENT:Destroy()
	if self.instance then
		self.instance:runEvent("removed")
		-- removed hook can cause instance to become nil
		if self.instance then
			self.instance:destroy()
			self.instance = nil
		end
	end
end

---@param data ProcessorData
function ENT:SetupFiles(data)
	self.chip_data = data
	self.owner = data.owner
	data.chip = self

	self:Compile()
	if SERVER then
		---@type ProcessorData
		local send_data = {
			owner = data.owner,
			owner_id = data.owner:EntIndex(),

			chip = self,
			chip_id = self:EntIndex(),

			modules = {},
			main = data.main,
		}

		self.send_data = send_data

		for k, v in pairs(data.modules) do
			send_data.modules[k] = v
		end

		send_data.compressed = ELib.CompressFiles(data.modules)

		self:SendCode()
	end
end

function ENT:GetGateName()
	return self.name
end

function ENT:Error(err)
	self.error = err

	if SERVER then
		self:SetNWInt("State", self.States.Error)
		self:SetColor(Color(255, 0, 0, 255))
		self:SetDTString(0, err)
	end

	if self.owner:IsValid() then
		ELib.Notify(self.owner, 1, err)
	end

	if self.instance then
		self.instance:destroy()
		self.instance = nil
	end

	if CLIENT then
		if self.owner ~= LocalPlayer() and self.owner:IsValid() and GetConVarNumber("es_timebuffer_cl")>0 then
			ELib.StartNet("Processor.Errored")
				net.WriteEntity(self)
				net.WriteString(err)
			net.SendToServer()
		end
	end
end