AddCSLuaFile()
DEFINE_BASECLASS("base_anim")

ENT.RenderGroup =	RENDERGROUP_TRANSLUCENT
util.PrecacheModel("models/error.mdl")

function ENT:ColorC(val)
	return math.Clamp(math.Round(val),0,255)
end

function ENT:ColorToString(rgb)
	return tostring(self:ColorC(rgb.r)).." "..tostring(self:ColorC(rgb.g)).." "..tostring(self:ColorC(rgb.b))
end

function ENT:ColorIntensityToString(rgb,i)
	local i_int = math.Round(i)
	if (i_int < 1) then return "0 0 0 0" end
	return self:ColorToString(rgb).." "..tostring(i_int)
end

function ENT:BoolToString(b)
	if b then
		return "1"
	else
		return "0"
	end
end

function ENT:VectorToColor(vec)
	return Color(self:ColorC(vec.x),self:ColorC(vec.y),self:ColorC(vec.z))
end

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/error.mdl")
		self:SetRenderMode(RENDERMODE_TRANSALPHA)
		self:DrawShadow(false)
		self:SetMoveType(MOVETYPE_NOCLIP)
	end
end

if CLIENT then
	ENT.c_r = Color(255,0,0,255)
	ENT.c_c = Color(0,255,255,255)

	ENT.c_g = Color(0,255,0,255)
	ENT.c_m = Color(255,0,255,255)

	ENT.c_b = Color(0,0,255,255)
	ENT.c_y = Color(255,255,0,255)
end