AddCSLuaFile()
DEFINE_BASECLASS("base_light")

local ELN_Distance_Convar = CreateConVar("Expensive_light_new_distance","500",FCVAR_SERVER_CAN_EXECUTE + FCVAR_ARCHIVE,"Distance before light disables for performance.")
local ELN_Max_Convar = CreateConVar("Expensive_light_new_max","3",FCVAR_SERVER_CAN_EXECUTE + FCVAR_ARCHIVE,"Max light entities allowed.")
local ELN_LightLevel_Convar = CreateConVar("Expensive_light_new_lightlevel","188",FCVAR_SERVER_CAN_EXECUTE + FCVAR_ARCHIVE,"Ambient light threshold.")
local ELN_Filter_Convar = CreateConVar("Expensive_light_new_filter","1",FCVAR_SERVER_CAN_EXECUTE + FCVAR_ARCHIVE,"Shadow filter quality.")

function ENT:SetupDataTables()
	self:NetworkVar("Bool",0,"ActiveState",{ KeyName = "activestate",Edit = { type = "Boolean",title = "Enable",order = 1,category = "Main" } })
	self:NetworkVar("Bool",1,"DrawHelper",{ KeyName = "drawhelper",Edit = { type = "Boolean",title = "Draw Helper",order = 8,category = "Render" } })
	self:NetworkVar("Bool",2,"DrawSprite",{ KeyName = "drawsprite",Edit = { type = "Boolean",title = "Draw Sprite",order = 7,category = "Render" } })
	self:NetworkVar("Bool",3,"Shadows",   { KeyName = "shadows",  Edit = { type = "Boolean",title = "Shadows",order = 6,category = "Effect" } })
	self:NetworkVar("Bool",4,"Horizontal",{ KeyName = "horizontal",Edit = { type = "Boolean",title = "Horizontal",order = 9,category = "Light" } })
	self:NetworkVar("Float",0,"Brightness",{ KeyName = "brightness",Edit = { type = "Float",min = 0.01,max = 15,title = "Brightness",order = 3,category = "Light" } })
	self:NetworkVar("Float",1,"FarZ",      { KeyName = "farz",     Edit = { type = "Float",min = 32,max = 2048,title = "Size",order = 5,category = "Light" } })
	self:NetworkVar("Float",2,"NearZ",     { KeyName = "nearz",    Edit = { type = "Float",min = 2,max = 16,title = "Near Z",order = 4,category = "Light" } })
	self:NetworkVar("Vector",0,"LightColor",{ KeyName = "lightcolor",Edit = { type = "RGBColor",title = "Color",order = 2,category = "Light" } })

	if SERVER then
		self:SetActiveState(true)
		self:SetHorizontal(false)
		self:SetDrawHelper(true)
		self:SetDrawSprite(true)
		self:SetShadows(true)
		self:SetBrightness(0.25)
		self:SetFarZ(512)
		self:SetNearZ(4)
		self:SetLightColor(Vector(255,255,255))
	end
end

if SERVER then
	function ENT:Initialize()
		BaseClass.Initialize(self)
	end

	function ENT:SpawnFunction(ply,tr,ClassName)
		if !tr.Hit then return end
		local ent = ents.Create(ClassName)
		ent:SetPos(tr.HitPos + tr.HitNormal * 32)
		ent:Spawn()
		ent:Activate()
		ent:SpawnedInSandbox(ply)
		return ent
	end
end

if CLIENT then
	local fov = math.deg(math.atan(512 / 511)) * 2
	local texName = "effects/lx"
	local function SetupAngle(baseAng,axis,degrees)
		local ang = Angle()
		ang:Set(baseAng)
		ang:RotateAroundAxis(Vector(axis),degrees)
		return ang
	end
	local function RemoveTexture(t)
		if IsValid(t) then t:Remove() end
	end
	function ENT:UpdateProjectedTexture(tex,pos,ang,shadows,farZ,nearZ,color,brightness)
		tex:SetPos(pos)
		tex:SetAngles(ang)
		tex:SetEnableShadows(shadows)
		tex:SetFarZ(farZ)
		tex:SetNearZ(nearZ)
		tex:SetFOV(fov)
		tex:SetOrthographic(false)
		tex:SetColor(color)
		tex:SetBrightness(brightness)
		tex:SetTexture(texName)
		tex:SetShadowFilter(ELN_Filter_Convar:GetInt())
		tex:Update()
	end
	local sides = {
		{"FR",0},
		{"BK",180},
		{"RI",90},
		{"LF",270},
	}
	function ENT:CreateAllProjectedTextures()
		if #ents.FindByClass(self:GetClass()) > ELN_Max_Convar:GetInt() then return end
		local pos = self:GetPos()
		local ang = self:GetAngles()
		local up, ri = ang:Up(), ang:Right()
		local col = self:VectorToColor(self:GetLightColor())
		local bright = self:GetBrightness()
		local shadows = self:GetShadows()
		local farZ, nearZ = self:GetFarZ(), self:GetNearZ()

		for _,side in ipairs(sides) do
			local name,deg = side[1],side[2]
			local tex = ProjectedTexture()
			if IsValid(tex) then
				self[name] = tex
				self:UpdateProjectedTexture(tex,pos,SetupAngle(ang,up,deg),shadows,farZ,nearZ,col,bright)
			end
		end

		if !self:GetHorizontal() then
			for _,data in ipairs({{"UP",90},{"DN",270}}) do
				local name,deg = data[1],data[2]
				local tex = ProjectedTexture()
				if IsValid(tex) then
					self[name] = tex
					self:UpdateProjectedTexture(tex,pos,SetupAngle(ang,ri,deg),shadows,farZ,nearZ,col,bright)
				end
			end
		end
	end

	function ENT:UpdateAllProjectedTextures()
		local pos = self:GetPos()
		local ang = self:GetAngles()
		local up, ri = ang:Up(), ang:Right()
		local col = self:VectorToColor(self:GetLightColor())
		local bright = self:GetBrightness()
		local shadows = self:GetShadows()
		local farZ, nearZ = self:GetFarZ(), self:GetNearZ()

		for name,deg in pairs({BK = 180,RI = 90,LF = 270}) do
			local tex = self[name]
			if IsValid(tex) then
				self:UpdateProjectedTexture(tex,pos,SetupAngle(ang,up,deg),shadows,farZ,nearZ,col,bright)
			end
		end

		for _,name in ipairs({"FR","UP","DN"}) do
			local tex = self[name]
			if IsValid(tex) then
				local axis = name == "UP" && ri or (name == "DN" && ri or ang)
				local deg = name == "UP" && 90 or (name == "DN" && 270 or 0)
				self:UpdateProjectedTexture(tex,pos,SetupAngle(ang,axis,deg),shadows,farZ,nearZ,col,bright)
			end
		end
	end

	function ENT:RemoveAllProjectedTextures()
		for _,name in ipairs({ "FR","BK","RI","LF","UP","DN" }) do
			local tex = self[name]
			if IsValid(tex) then tex:Remove() self[name] = nil end
		end
	end

	function ENT:Initialize()
		self.PixVis = util.GetPixelVisibleHandle()
		self.WasActive = self:GetActiveState()
		if self.WasActive then self:CreateAllProjectedTextures() end
	end

	local lightThreshold = ELN_LightLevel_Convar:GetInt() / 100
	local distanceSq = ELN_Distance_Convar:GetInt() ^ 2

	function ENT:Think()
		local player = LocalPlayer()
		local pos = self:GetPos()
		local playerDist = IsValid(player) && pos:DistToSqr(player:GetPos()) or math.huge
		local ambient = render.GetLightColor(self:WorldSpaceCenter())
		local brightness = (ambient.x + ambient.y + ambient.z) / 3
		local tooBright = brightness > lightThreshold
		local inSolid = bit.band(util.PointContents(pos),CONTENTS_SOLID) == CONTENTS_SOLID
		local shouldDisable = inSolid or playerDist > distanceSq or tooBright

		if shouldDisable then
			if self.WasActive then
				self.WasActive = false
				self:RemoveAllProjectedTextures()
			end
		else
			if !self.WasActive then
				self.WasActive = true
				self:CreateAllProjectedTextures()
			else
				self:UpdateAllProjectedTextures()
			end
		end

		self:NextThink(CurTime() + 0.8)
		return true
	end

	local spriteMat = Material("sprites/light_ignorez")
	function ENT:Draw()
		if halo.RenderedEntity() == self or !self:GetActiveState() or !self:GetDrawSprite() then return end

		local pos = self:GetPos()
		local visible = util.PixelVisible(pos,4,self.PixVis)
		if !visible or visible < 0.1 then return end

		local c = self:GetLightColor()
		local brightness = self:GetBrightness()
		local size = ((brightness / 0.25) ^ 0.5 * 32) * visible

		render.SetMaterial(spriteMat)
		render.DrawSprite(pos,size,size,Color(c.x,c.y,c.z,math.Round(visible * 255)))
	end

	function ENT:OnRemove()
		self:RemoveAllProjectedTextures()
	end
end