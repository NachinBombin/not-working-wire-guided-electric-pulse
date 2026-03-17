AddCSLuaFile()
DEFINE_BASECLASS("base_light")

local PLN_Distance_Convar = CreateConVar("Projected_light_new_distance","500",FCVAR_SERVER_CAN_EXECUTE + FCVAR_ARCHIVE,"Distance between entity && player before entity turns off to save performance.")
local PLN_Max_Convar = CreateConVar("Projected_light_new_max","18",FCVAR_SERVER_CAN_EXECUTE + FCVAR_ARCHIVE,"Max amount of entities.")
local PLN_LightLevel_Convar = CreateConVar("Projected_light_new_lightlevel","175",FCVAR_SERVER_CAN_EXECUTE + FCVAR_ARCHIVE,"Lighlevel at which entity turns on.")
local PLN_Filter_Convar = CreateConVar("Projected_light_new_filter","1",FCVAR_SERVER_CAN_EXECUTE + FCVAR_ARCHIVE,"Filter of entity light.")

function ENT:SetupDataTables()
	self:NetworkVar("Bool",	0,	"ActiveState",		{ KeyName = "activestate",	Edit = { type = "Boolean",					title = "Enable",		order = 1,	category = "Main" } })
	self:NetworkVar("Bool",	1,	"DrawHelper",		{ KeyName = "drawhelper",	Edit = { type = "Boolean",					title = "Draw Helper",		order = 15,	category = "Render" } })
	self:NetworkVar("Bool",	2,	"DrawSprite",		{ KeyName = "drawsprite",	Edit = { type = "Boolean",					title = "Draw Sprite",		order = 14,	category = "Render" } })
	self:NetworkVar("Bool",	3,	"Orthographic",		{ KeyName = "orthographic",	Edit = { type = "Boolean",					title = "Orthographic",		order = 7,	category = "Light" } })
	self:NetworkVar("Bool",	4,	"Shadows",		{ KeyName = "shadows",		Edit = { type = "Boolean",					title = "Shadows",		order = 13,	category = "Effect" } })
	self:NetworkVar("Float",	0,	"Brightness",		{ KeyName = "brightness",	Edit = { type = "Float",	min = 0.01,	max = 15,	title = "Brightness",		order = 4,	category = "Light" } })
	self:NetworkVar("Float",	1,	"FarZ",			{ KeyName = "farz",		Edit = { type = "Float",	min = 32,	max = 2048,	title = "Far Z",		order = 6,	category = "Light" } })
	self:NetworkVar("Float",	2,	"LightFOV",		{ KeyName = "lightfov",		Edit = { type = "Float",	min = 1,	max = 179,	title = "FOV",			order = 12,	category = "Light" } })
	self:NetworkVar("Float",	3,	"NearZ",		{ KeyName = "nearz",		Edit = { type = "Float",	min = 2,	max = 16,	title = "Near Z",		order = 5,	category = "Light" } })
	self:NetworkVar("Float",	4,	"OrthoBottom",		{ KeyName = "orthobottom",	Edit = { type = "Float",	min = 1,	max = 1024,	title = "Bottom Plane",		order = 11,	category = "Light" } })
	self:NetworkVar("Float",	5,	"OrthoLeft",		{ KeyName = "ortholeft",	Edit = { type = "Float",	min = 1,	max = 1024,	title = "Left Plane",		order = 8,	category = "Light" } })
	self:NetworkVar("Float",	6,	"OrthoRight",		{ KeyName = "orthoright",	Edit = { type = "Float",	min = 1,	max = 1024,	title = "Right Plane",		order = 9,	category = "Light" } })
	self:NetworkVar("Float",	7,	"OrthoTop",		{ KeyName = "orthotop",		Edit = { type = "Float",	min = 1,	max = 1024,	title = "Top Plane",		order = 10,	category = "Light" } })
	self:NetworkVar("String",	0,	"LightTexture",		{ KeyName = "lighttexture",	Edit = { type = "Generic",	waitforenter = true,		title = "Texture",		order = 2,	category = "Light" } })
	self:NetworkVar("Vector",	0,	"LightColor",		{ KeyName = "lightcolor",	Edit = { type = "RGBColor",					title = "Color",		order = 3,	category = "Light" } })

	if SERVER then
		self:SetActiveState(true)
		self:SetDrawHelper(true)
		self:SetDrawSprite(true)
		self:SetOrthographic(false)
		self:SetShadows(true)
		self:SetBrightness(1)
		self:SetFarZ(1024)
		self:SetLightFOV(90)
		self:SetNearZ(4)
		self:SetOrthoBottom(128)
		self:SetOrthoLeft(128)
		self:SetOrthoRight(128)
		self:SetOrthoTop(128)
		self:SetLightTexture("effects/flashlight001")
		self:SetLightColor(Vector(255,255,255))
	end
end


if SERVER then
	function ENT:Initialize()
		BaseClass.Initialize(self)
	end
end

if CLIENT then
	function ENT:UpdateProjectedTexture(L)
		L:SetPos(self:GetPos())
		L:SetAngles(self:GetAngles())
		L:SetEnableShadows(self:GetShadows())
		L:SetFarZ(self:GetFarZ())
		L:SetNearZ(self:GetNearZ())
		L:SetFOV(self:GetLightFOV())
		L:SetOrthographic(self:GetOrthographic(),self:GetOrthoLeft(),self:GetOrthoTop(),self:GetOrthoRight(),self:GetOrthoBottom())
		L:SetColor(self:VectorToColor(self:GetLightColor()))
		L:SetBrightness(self:GetBrightness())
		L:SetTexture(self:GetLightTexture())
		L:SetShadowFilter(PLN_Filter_Convar:GetInt())
		L:Update()
	end
	local countThreshold = PLN_Max_Convar:GetInt()

	function ENT:Initialize()
		self.PixVis = util.GetPixelVisibleHandle()
		if self:GetActiveState() then
			self.WasActive = true
			local allEntities = ents.FindByClass(self:GetClass())
			if #allEntities > countThreshold then return end
			local L = ProjectedTexture()
			if IsValid(L) then
				self.PT = L
				self:UpdateProjectedTexture(L)
			end
		else
			self.WasActive = false
		end
	end

	local lightThreshold = PLN_LightLevel_Convar:GetInt() / 100

	function ENT:Think()
		local player = LocalPlayer()
		local playerPos = IsValid(player) && player:GetPos() or Vector(0,0,0)
		local lightcol = render.GetLightColor(self:WorldSpaceCenter())
		local brightness = (lightcol.x + lightcol.y + lightcol.z) / 3
		local inLowLight = brightness > lightThreshold
		local inSolid = (bit.band(util.PointContents(self:GetPos()),CONTENTS_SOLID) == CONTENTS_SOLID)
		local distanceExceed = self:GetPos():DistToSqr(playerPos) > PLN_Distance_Convar:GetInt() ^ 2
		local lightopt = inSolid or (distanceExceed or inLowLight)
	
		if lightopt then
			if self.WasActive then
				self.WasActive = false
	
				local L = self.PT
				if IsValid(L) then
					L:Remove()
					self.PT = NULL
				end
			end
		else
			if !self.WasActive then
				self.WasActive = true
	
				local L = ProjectedTexture()
				if IsValid(L) then
					self.PT = L
					self:UpdateProjectedTexture(L)
				end
			else
				local L = self.PT
				if IsValid(L) then
					self:UpdateProjectedTexture(L)
				end
			end
		end
		self:NextThink(CurTime() + 1)
		return true
	end
	
	function ENT:OnRemove()
		local L = self.PT
		if IsValid(L) then
			L:Remove()
			self.PT = NULL
		end
	end

	local spritemat = Material("sprites/light_ignorez")
	local helpermat = Material("sprites/helper_tri")
	function ENT:Draw()
		if ((halo.RenderedEntity() ~= self) && self:GetActiveState() && self:GetDrawSprite()) then
			local pos = self:GetPos()
			local Visible = util.PixelVisible(pos,4,self.PixVis)
			if (Visible && (Visible > 0.1)) then
				local fw = self:GetAngles():Forward()
				local view = EyePos() - pos
				view:Normalize()
				local viewdot = view:Dot(fw)
				if viewdot > 0 then
					Visible = Visible * viewdot
					local c = self:GetLightColor()
					local i = self:GetBrightness()
					local s = i ^ 0.5 * 128
					s = s * Visible
					render.SetMaterial(spritemat)
					render.DrawSprite(pos,s,s,Color(self:ColorC(c.x),self:ColorC(c.y),self:ColorC(c.z),math.Round(Visible * 169)))
				end
			end
		end
	end
end