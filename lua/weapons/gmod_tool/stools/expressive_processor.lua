local ELib = require("expressive/library")

---@type GTool
local TOOL = _G.TOOL

TOOL.GhostEntity = nil

TOOL.Category		= "Expressive"
TOOL.Name			= "Expressive - Processor"
TOOL.Command		= nil
TOOL.ConfigName		= ""


local ENT_NAME = "expressive_processor"
local DEF_MODEL = "models/bull/gates/processor.mdl"
local GateModels = {DEF_MODEL}

local Factory

TOOL.ClientConVar = {
	["model"] = DEF_MODEL
}

if SERVER then
	ELib.AddNetworkString("OpenEditor")
	CreateConVar("sbox_max" .. ENT_NAME, 20, { FCVAR_REPLICATED, FCVAR_NOTIFY, FCVAR_ARCHIVE })

	---@param ply GPlayer
	---@param pos GVector
	---@param ang GAngle
	---@param model string
	---@param inputs table
	---@param outputs table
	---@return ExpressiveProcessor
	function Factory(ply, pos, ang, model, inputs, outputs)
		if ply and not ply:CheckLimit(ENT_NAME) then return false end

		local chip = ents.Create(ENT_NAME)
		if not IsValid(chip) then return false end
		if not (util.IsValidModel(model) and util.IsValidProp(model)) then
			model = DEF_MODEL
		end

		chip:SetAngles(ang)
		chip:SetPos(pos)
		chip:SetModel(model)
		chip:Spawn()

		if WireLib and inputs and inputs[1] and inputs[2] then
			chip.Inputs = WireLib.AdjustSpecialInputs(chip, inputs[1], inputs[2])
		end
		if WireLib and outputs and outputs[1] and outputs[2] then
			-- Initialize wirelink and entity outputs if present
			for _, iname in pairs(outputs[1]) do
				if iname == "entity" then
					WireLib.CreateEntityOutput( nil, chip, {true} )
				elseif iname == "wirelink" then
					WireLib.CreateWirelinkOutput( nil, chip, {true} )
				end
			end

			chip.Outputs = WireLib.AdjustSpecialOutputs(chip, outputs[1], outputs[2])
		end

		if ply then
			ply:AddCount(ENT_NAME, chip)
			ply:AddCleanup(ENT_NAME, chip)
		end

		return chip
	end

	duplicator.RegisterEntityClass(ENT_NAME, Factory, "Pos", "Ang", "Model", "_inputs", "_outputs")
	-- END SERVER
else
	duplicator.RegisterEntityClass(ENT_NAME, nil, "Pos", "Ang", "Model", "_inputs", "_outputs")
	-- CLIENT

	language.Add("Tool." .. ENT_NAME .. ".name", "Expressive Processor")
	language.Add("Tool." .. ENT_NAME .. ".desc", "Spawns a processor.")
	language.Add("Tool." .. ENT_NAME .. ".left", "Spawn a processor / upload code")
	language.Add("Tool." .. ENT_NAME .. ".right", "Open editor")
	language.Add("Tool." .. ENT_NAME .. ".reload", "Restart processor")
	language.Add("sboxlimit_" .. ENT_NAME, "You've hit the Expressive processor limit!")
	language.Add("undone_Expressive Processor", "Undone Expressive Processor")
	language.Add("Cleanup_" .. ENT_NAME, "Expressive Processors")

	TOOL.Information = { "left", "right", "reload" }

	-- END CLIENT
end

function TOOL:CheckHitOwnClass(trace)
	return trace.Entity:IsValid() and trace.Entity.Expressive
end

function TOOL:LeftClick_Update(trace)
	--EXPR_UPLOADER.RequestFromClient(self:GetOwner(), trace.Entity)
end

if CLIENT then
	function TOOL.BuildCPanel(CPanel)
		local PropList = vgui.Create("PropSelect")
		PropList:SetConVar(ENT_NAME .. "_model")

		for _, Model in pairs(GateModels) do
			PropList:AddModel(Model, false)
		end

		CPanel:AddItem(PropList)
	end

	hook.Add("Expressive.CloseEditor", "Expressive.Tool.ChooseModel", function()
		--local model = ExpressiveEditor.GetDirective("model") or ""
		local model = ""
		RunConsoleCommand(ENT_NAME .. "_script_model", model)
	end)

	function TOOL:UpdateGhostEntity(ent, ply)
		if not IsValid(ent) then return end

		local trace = ply:GetEyeTrace()
		if not trace.Hit or IsValid( trace.Entity ) and ( trace.Entity:GetClass() == "gmod_button" or trace.Entity:IsPlayer() ) then
			ent:SetNoDraw( true )
			return
		end

		local ang = trace.HitNormal:Angle()
		ang.pitch = ang.pitch + 90

		local min = ent:OBBMins()
		ent:SetPos( trace.HitPos - trace.HitNormal * min.z )
		ent:SetAngles( ang )

		ent:SetNoDraw( false )
	end
end

local ToolgunScreen
if CLIENT then
	ToolgunScreen = include("expressive/toolscreen.lua")

	function TOOL:DrawToolScreen(width, height)
		ToolgunScreen.render(width, height)
	end
end

function TOOL:Think()
	if CLIENT then
		ToolgunScreen.think()
	end
	local mdl = self:GetClientInfo("model")
	if not IsValid(self.GhostEntity) or self.GhostEntity:GetModel() ~= mdl then
		self:MakeGhostEntity(mdl, vector_origin, angle_zero)
	end

	self:UpdateGhostEntity(self.GhostEntity, self:GetOwner())
end

function TOOL:RightClick(Trace)
	if SERVER then
		local loadScript = self:CheckHitOwnClass(Trace)
		ELib.StartNet("OpenEditor")
		net.WriteBool(loadScript)

		if loadScript then
			net.WriteEntity(Trace.Entity)
		end

		net.Send(self:GetOwner())
	end
end

function TOOL:LeftClick(trace)
	if not trace.HitPos then return false end
	if trace.Entity:IsPlayer() then return false end
	if CLIENT then return true end

	local ply = self:GetOwner()

	local ent = trace.Entity
	local chip

	---@return GEntity
	local function doWeld()
		if chip == ent then return end
		local ret
		if ent:IsValid() then
			if self:GetClientNumber( "parent", 0 ) ~= 0 then
				chip:SetParent(ent)
			else
				local const = constraint.Weld(chip, ent, 0, trace.PhysicsBone, 0, true, true)
				ret = const
			end
			local phys = chip:GetPhysicsObject()
			if phys:IsValid() then phys:EnableCollisions(false) chip.nocollide = true end
		else
			local phys = chip:GetPhysicsObject()
			if phys:IsValid() then phys:EnableMotion(false) end
		end
		return ret
	end

	-- request code
	if not ELib.RequestCode(ply, function(data)
		print("reqcode", chip, data)
		if not IsValid(chip) then return end -- Removed while transmitting
		chip:SetupFiles(data)
	end) then
		ELib.Notify(ply, 1, "Cannot upload code, please wait for the current upload to finish.")
		return false
	end

	if ent:IsValid() and ent:GetClass() == ENT_NAME then
		chip = ent
	else
		local model = self:GetClientInfo("Model")
		if not self:GetSWEP():CheckLimit(ENT_NAME) then return false end

		local Ang = trace.HitNormal:Angle()
		Ang.pitch = Ang.pitch + 90

		chip = Factory(ply, trace.HitPos, Ang, model)
		if not chip then return false end

		local min = chip:OBBMins()
		chip:SetPos(trace.HitPos - trace.HitNormal * min.z)
		local const = doWeld()

		undo.Create("Expressive Processor")
			undo.AddEntity(chip)
			undo.AddEntity(const)
			undo.SetPlayer(ply)
		undo.Finish()
	end

	return true
end