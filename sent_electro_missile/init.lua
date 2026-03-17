AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

include("shared.lua")

function ENT:Initialize()

    self:SetModel(self.Model)

    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_FLY)
    self:SetSolid(SOLID_BBOX)

    self:SetCollisionGroup(COLLISION_GROUP_PROJECTILE)

    self.Speed = 2500
    self.DamageRadius = 90

    self.LaunchPos = self:GetPos()

    self.PathBuffer = {}

    self:CreateCable()

    self.SoundLoop = CreateSound(self,"ambient/energy/zap_loop2.wav")
    self.SoundLoop:Play()

end


function ENT:Think()

    local forward = self:GetForward()
    self:SetVelocity(forward * self.Speed)

    self:RecordPath()
    self:UpdateCable()

    self:SparkDamage()
    self:ArcLightning()
    self:ScorchGround()
    self:WireLightning()

    self:NextThink(CurTime())
    return true

end


-- =====================
-- CABLE SYSTEM (SPOOLING)
-- =====================

function ENT:CreateCable()

    self.CableStart = ents.Create("info_target")
    self.CableStart:SetPos(self.LaunchPos)
    self.CableStart:Spawn()

    self.Cable = ents.Create("keyframed_rope")

    self.Cable:SetPos(self.LaunchPos)

    self.Cable:SetKeyValue("NextKey","0")
    self.Cable:SetKeyValue("Slack","0")
    self.Cable:SetKeyValue("Type","0")
    self.Cable:SetKeyValue("Subdiv","2")
    self.Cable:SetKeyValue("Width","2")
    self.Cable:SetKeyValue("TextureScale","1")
    self.Cable:SetKeyValue("Material","cable/cable2")

    self.Cable:Spawn()

end


function ENT:UpdateCable()

    if not IsValid(self.Cable) then return end

    local dist = self:GetPos():Distance(self.LaunchPos)

    self.Cable:SetKeyValue("Slack", tostring(dist))

end


-- =====================
-- PATH BUFFER
-- =====================

function ENT:RecordPath()

    table.insert(self.PathBuffer, self:GetPos())

    if #self.PathBuffer > 20 then
        table.remove(self.PathBuffer, 1)
    end

end


-- =====================
-- DAMAGE + EFFECTS
-- =====================

function ENT:SparkDamage()

    local pos = self:GetPos()

    for _,ent in pairs(ents.FindInSphere(pos,self.DamageRadius)) do
        if ent:IsNPC() or ent:IsPlayer() then

            local dmg = DamageInfo()
            dmg:SetDamage(3)
            dmg:SetDamageType(DMG_SHOCK)
            dmg:SetAttacker(self)
            dmg:SetInflictor(self)

            ent:TakeDamageInfo(dmg)
        end
    end

end


function ENT:ArcLightning()

    local pos = self:GetPos()

    for _,ent in pairs(ents.FindInSphere(pos,200)) do
        if ent:GetMoveType() == MOVETYPE_VPHYSICS then

            local effect = EffectData()
            effect:SetStart(pos)
            effect:SetOrigin(ent:GetPos())

            util.Effect("TeslaHitBoxes",effect,true,true)

            local dmg = DamageInfo()
            dmg:SetDamage(5)
            dmg:SetDamageType(DMG_SHOCK)

            ent:TakeDamageInfo(dmg)
        end
    end

end


function ENT:ScorchGround()

    if math.random(1,4) ~= 1 then return end

    local tr = util.TraceLine({
        start = self:GetPos(),
        endpos = self:GetPos() - Vector(0,0,120),
        mask = MASK_SOLID
    })

    if tr.Hit then
        util.Decal(
            "FadingScorch",
            tr.HitPos + tr.HitNormal,
            tr.HitPos - tr.HitNormal
        )
    end

end


function ENT:WireLightning()

    if not IsValid(self.CableStart) then return end
    if math.random(1,5) ~= 1 then return end

    local effect = EffectData()
    effect:SetStart(self.CableStart:GetPos())
    effect:SetOrigin(self:GetPos())

    util.Effect("ToolTracer",effect)

end


-- =====================
-- COLLISION
-- =====================

function ENT:PhysicsCollide(data,phys)

    local pos = self:GetPos()

    util.BlastDamage(self,self,pos,120,80)

    local effect = EffectData()
    effect:SetOrigin(pos)
    util.Effect("cball_explode",effect)

    local field = ents.Create("sent_electric_field")
    if IsValid(field) then
        field:SetPos(pos)
        field:Spawn()
    end

    if self.SoundLoop then
        self.SoundLoop:Stop()
    end

    self:Remove()

end