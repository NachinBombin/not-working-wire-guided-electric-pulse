AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/XQM/Rails/gumball_1.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_PROJECTILE)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:DrawShadow(false)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:AddGameFlag(FVPHYSICS_NO_IMPACT_DMG)
        phys:Wake()
        phys:EnableDrag(false)
        phys:EnableGravity(false)
        phys:SetBuoyancyRatio(0)
    end

    self.Sparks = ents.Create("prop_physics")
    self.Sparks:SetModel("models/hunter/plates/plate.mdl")
    self.Sparks:SetPos(self:GetPos())
    self.Sparks:SetRenderMode(RENDERMODE_NONE)
    self.Sparks:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
    self.Sparks:SetParent(self, -1)

    self:SetTrigger(true)

    self.HasHit   = false
    self.Charge   = 100
    self.NextHit  = {}   -- per‑target hit cooldown table

    self.teslaorbidle = CreateSound(self, "weapon_teslacoil/teslaorb_idle.wav")
    self.teslaorbidle:Play()
end

function ENT:StartTouch(ent)
    -- each touch also bleeds charge
    self.Charge = self.Charge - 5

    if ent:GetClass() == "phys_bone_follower" then
        -- very small, localized nudge on ragdolls instead of huge damage
        util.BlastDamage(self, self.Owner or self, ent:GetPos(), 0, 25)
        return
    end

    -- direct contact hit: moderate damage, not fatal by itself
    if IsValid(ent) and (ent:IsNPC() or (ent:IsPlayer() and ent ~= self.Owner)) then
        local dmg = DamageInfo()
        dmg:SetDamageType(DMG_DISSOLVE)
        dmg:SetDamage(25)  -- down from 500
        dmg:SetAttacker(self.Owner or self)
        dmg:SetInflictor(self)
        ent:TakeDamageInfo(dmg)
    end
end

function ENT:PhysicsUpdate(phys)
    if phys:GetVelocity():Length() < 10 then
        phys:EnableGravity(false)
    end
end

function ENT:PhysicsCollide(data)
    if self.HasHit then return end

    self.HasHit = true

    self:Remove()
end

function ENT:Think()
    -- no movement, no drain / effects
    if self:GetVelocity():Length() <= 0 then
        return
    end

    -- movement bleeds charge
    self.Charge = self.Charge - 1

    local center = self:GetPos()

    -- interact with nearby entities
    for _, v in ipairs(ents.FindInSphere(center, 160)) do
        if v:GetClass() == "npc_grenade_frag" or v:GetClass() == "prop_combine_ball" then
            -- keep the cool grenade/ball interaction
            local startPos = self:GetChildren()[1]:GetPos()
            local endPos   = v:GetPos()
            util.ParticleTracerEx("teslacoil_orb_beam", startPos, endPos, false, self:GetChildren()[1]:EntIndex(), 1)

            self.dissolver = ents.Create("env_entity_dissolver")
            self.dissolver:SetKeyValue("dissolvetype", 0)
            self.dissolver:SetKeyValue("magnitude", 1)
            self.dissolver:SetPos(v:GetPos())
            self.dissolver:Spawn()
            local name = "Dissolving_" .. math.random(1, 9999)
            v:SetName(name)
            self.dissolver:Fire("Dissolve", name, 0)
            self.dissolver:Fire("kill", "", 0.01)

            self.Charge = self.Charge - 5

        elseif v:GetClass() == "rpg_missile" then
            -- anti‑RPG behavior kept
            v:SetHealth(0)
            local bullet = {}
            bullet.Src    = v:GetPos()
            bullet.Num    = 1
            bullet.Dir    = Vector(0, 0, 0)
            bullet.Damage = 0
            bullet.Force  = 0
            bullet.Tracer = 0
            self:FireBullets(bullet)

            self.Charge = self.Charge - 5

        elseif v:IsNPC() or (v:IsPlayer() and v ~= self.Owner) then
            -- PER‑TARGET COOLDOWN: only hit each actor every 0.35s
            self.NextHit = self.NextHit or {}
            local idx    = v:EntIndex()
            local now    = CurTime()
            local nextT  = self.NextHit[idx] or 0

            if nextT <= now then
                -- much lower tick damage + cooldown = heavily tamed DPS
                local dmg = DamageInfo()
                dmg:SetDamageType(DMG_DISSOLVE)
                dmg:SetAttacker(self.Owner or self)
                dmg:SetInflictor(self)
                dmg:SetDamage(12)  -- was 85; you had 35, this is tamed further
                v:TakeDamageInfo(dmg)

                local startPos = self:GetChildren()[1]:GetPos()
                local endPos   = v:GetPos() + Vector(0, 0, 0.6 * v:OBBMaxs().z)
                util.ParticleTracerEx("teslacoil_orb_beam", startPos, endPos, false, self:GetChildren()[1]:EntIndex(), 1)

                self.Charge = self.Charge - 1

                self.NextHit[idx] = now + 0.35
            end
        end
    end

    -- OverCharge: **purely visual blast now**, no AoE damage
    if self.OverCharge then
        ParticleEffect("teslacoil_orb_blast", self:GetPos(), Angle(0, 0, 0), nil)
        local bData = EffectData()
        bData:SetOrigin(self:GetPos())
        util.Effect("teslacoil_orb_blast", bData)

        self:EmitSound("teslaorb_blast", 75, 100)

        self:Remove()
        return
    end

    -- continuous arcs around the orb body
    local eData = EffectData()
    eData:SetEntity(self:GetChildren()[1])
    eData:SetMagnitude(20)
    util.Effect("TeslaHitBoxes", eData)

    -- remove when out of charge or in water
    if self.Charge >= 0 and self:WaterLevel() < 1 then return end
    self:Remove()
end

function ENT:OnRemove()
    if self.teslaorbidle then
        self.teslaorbidle:Stop()
    end
end

function ENT:OnTakeDamage(dmginfo)
    local attacker = dmginfo:GetAttacker()
    local inflictor = dmginfo:GetInflictor()
    if IsValid(attacker) and IsValid(inflictor)
        and attacker:IsPlayer()
        and (dmginfo:IsDamageType(DMG_SHOCK) or dmginfo:IsDamageType(DMG_DISSOLVE)) then

        self.Charge = self.Charge + 20
        if self.Charge > 200 then
            self.Owner    = attacker
            self.Inflictor = inflictor
            if self.Charge >= 200 then
                self.OverCharge = true
            end
        end
    end
end
