include('shared.lua')

function ENT:Initialize()
	ParticleEffectAttach( "teslacoil_orb", PATTACH_ABSORIGIN_FOLLOW, self, 0 )
end

function ENT:Draw()
	local dynlight = DynamicLight(self:EntIndex())
		dynlight.Pos = self:GetPos()
		dynlight.Size = 128
		dynlight.Decay = 128
		dynlight.R = 255
		dynlight.G = 255
		dynlight.B = 255
		dynlight.Brightness = 5
		dynlight.DieTime = CurTime()+.05
end