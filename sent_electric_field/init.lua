AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

function ENT:Initialize()

    self:SetModel("models/props_junk/PopCan01a.mdl")
    self:SetNoDraw(true)

    self.DieTime = CurTime() + 60
    self.Radius = 260

end


function ENT:Think()

    if CurTime() > self.DieTime then
        self:Remove()
        return
    end

    local pos = self:GetPos()

    for _,ent in pairs(ents.FindInSphere(pos,self.Radius)) do
        if ent:IsNPC() or ent:IsPlayer() then

            local dmg = DamageInfo()
            dmg:SetDamage(10)
            dmg:SetDamageType(DMG_SHOCK)

            ent:TakeDamageInfo(dmg)

        end
    end

    -- Ground lightning arcs
    for i=1,4 do

        local rand = pos + VectorRand()*self.Radius
        rand.z = pos.z + 10

        local effect = EffectData()
        effect:SetStart(pos)
        effect:SetOrigin(rand)

        util.Effect("TeslaHitBoxes",effect)

    end

    self:NextThink(CurTime()+0.5)
    return true

end