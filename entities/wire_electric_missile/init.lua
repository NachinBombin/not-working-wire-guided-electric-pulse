AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

local ORB_CLASS = "orb"

local SOUND_DANGER         = (SOUND and SOUND.DANGER) or 8
local SOUND_PHYSICS_DANGER = (SOUND and SOUND.PHYSICS_DANGER) or 1024

ENT.SideArcCountPerTick      = 3
ENT.SideArcSpawnChance       = 0.4
ENT.ChargePointLifetimeMin   = 0.06
ENT.ChargePointLifetimeMax   = 0.16
ENT.FloorChargeChance        = 0.35
ENT.CableChargeCountPerZap   = 2
ENT.OrbSpawnChancePerSegment = 0.02
ENT.OrbMinSpeed              = 150
ENT.OrbMaxSpeed              = 280
ENT.MaxOrbsPerMissile        = 4
ENT.SafeDuration             = 4
ENT.MaxSpeed                 = 1800
ENT.GroundTraceLen           = 18

-- -------------------------------------------------------
-- Electric color / light helpers
-- -------------------------------------------------------

local ElectricPalette = {
    Vector(120, 200, 255),
    Vector( 90, 180, 255),
    Vector( 80, 220, 255),
    Vector(120, 255, 210),
}

local function RandomElectricColor()
    return ElectricPalette[math.random(#ElectricPalette)]
end

local function RandomBrightness()
    return math.Rand(0.2, 0.9)
end

local function RandomFarZ()
    return math.Rand(220, 600)
end

local function RandomChargeLifetime(self)
    return math.Rand(self.ChargePointLifetimeMin or 0.06,
                     self.ChargePointLifetimeMax or 0.16)
end

-- -------------------------------------------------------
-- Lazy safety initialiser
-- Called at the top of Think and DoElectricity to guarantee
-- all fields exist even if Initialize() was skipped.
-- -------------------------------------------------------

local function EnsureFields(ent)
    local now = CurTime()
    if not ent.DieTime         then ent.DieTime         = now + (ent.WireLifetime or 60) end
    if not ent.SafeUntil       then ent.SafeUntil       = now + (ent.SafeDuration or 4)  end
    if ent.Armed        == nil  then ent.Armed           = false                           end
    if not ent.NextZap          then ent.NextZap         = now + 0.06                      end
    if not ent.LastGroundFlash  then ent.LastGroundFlash = 0                               end
    if ent.HasImpacted  == nil  then ent.HasImpacted     = false                           end
    if not ent.TickInterval     then ent.TickInterval    = 0.1                             end
    if not ent.SpawnedOrbs      then ent.SpawnedOrbs     = {}                              end
end

-- -------------------------------------------------------
-- Damage helpers
-- -------------------------------------------------------

local function DoShockDamage(attacker, inflictor, pos, radius, dmgAmount)
    local entities = ents.FindInSphere(pos, radius)
    for _, ent in ipairs(entities) do
        if IsValid(ent) and (ent:IsPlayer() or ent:IsNPC()) then
            local dmg = DamageInfo()
            dmg:SetDamage(dmgAmount)
            dmg:SetDamageType(DMG_SHOCK)
            dmg:SetAttacker(IsValid(attacker) and attacker or inflictor or game.GetWorld())
            dmg:SetInflictor(IsValid(inflictor) and inflictor or game.GetWorld())
            dmg:SetDamagePosition(pos)
            ent:TakeDamageInfo(dmg)
        end
    end
end

local function SpawnGroundFlash(pos, normal)
    local l = ents.Create("projected_light_new")
    if not IsValid(l) then return end
    normal = normal or Vector(0, 0, 1)
    l:SetPos(pos + normal * 8)
    l:SetAngles(normal:Angle())
    l:Spawn()
    l:Activate()
    if l.SetLightColor then l:SetLightColor(RandomElectricColor()) end
    if l.SetBrightness then l:SetBrightness(RandomBrightness() * 0.7) end
    if l.SetFarZ       then l:SetFarZ(RandomFarZ() * 0.7) end
    if l.SetLightFOV   then l:SetLightFOV(math.Rand(60, 85)) end
    if l.SetShadows    then l:SetShadows(false) end
    timer.Simple(0.18, function()
        if IsValid(l) then l:Remove() end
    end)
end

local function SpawnChargePoint(self, pos, normal, airborne)
    if not self then return end
    local e = ents.Create("expensive_light_new")
    if not IsValid(e) then return end
    local baseRadius = self.PoolRadius or 90
    if airborne then
        local offsetDir = VectorRand():GetNormalized()
        offsetDir.z = offsetDir.z * 0.5
        e:SetPos(pos + offsetDir * math.Rand(0, baseRadius * 0.4))
        e:SetAngles(AngleRand())
    else
        normal = normal or Vector(0, 0, 1)
        local lateral
        if math.abs(normal.z) > 0.7 then
            lateral = VectorRand()
            lateral.z = 0
        else
            lateral = normal:Cross(Vector(0, 0, 1))
            if lateral:LengthSqr() == 0 then lateral = Vector(1, 0, 0) end
        end
        lateral:Normalize()
        local fwd2 = Vector(lateral.y, -lateral.x, 0)
        fwd2:Normalize()
        e:SetPos(pos + normal * 6
            + lateral * math.Rand(-baseRadius * 0.7, baseRadius * 0.7)
            + fwd2    * math.Rand(-baseRadius * 0.3, baseRadius * 0.3))
        e:SetAngles(normal:Angle())
    end
    e:Spawn()
    e:Activate()
    local sizeMul = math.Rand(0.5, 1.3)
    if e.SetLightColor then e:SetLightColor(RandomElectricColor()) end
    if e.SetBrightness then e:SetBrightness(RandomBrightness() * sizeMul) end
    if e.SetFarZ       then e:SetFarZ(RandomFarZ() * sizeMul) end
    if e.SetShadows    then e:SetShadows(true) end
    if e.SetDrawSprite then e:SetDrawSprite(true) end
    timer.Simple(RandomChargeLifetime(self), function()
        if IsValid(e) then e:Remove() end
    end)
end

local function SpawnCableLightning(startPos, endPos)
    local ed = EffectData()
    ed:SetStart(startPos)
    ed:SetOrigin(endPos)
    util.Effect("mg_lightbolt", ed, true, true)
end

local function SpawnCableToGroundLightning(cablePos, groundPos, radius)
    local lateral = VectorRand()
    lateral.z = 0
    if lateral:LengthSqr() < 0.01 then lateral = Vector(1, 0, 0) end
    lateral:Normalize()
    local ed = EffectData()
    ed:SetStart(cablePos)
    ed:SetOrigin(groundPos + lateral * math.Rand(0, radius or 64))
    util.Effect("mg_lightbolt", ed, true, true)
end

local function SpawnRadialOrb(self, owner, centerPos)
    self.SpawnedOrbs = self.SpawnedOrbs or {}
    local alive = {}
    for _, orb in ipairs(self.SpawnedOrbs) do
        if IsValid(orb) then table.insert(alive, orb) end
    end
    self.SpawnedOrbs = alive
    if #self.SpawnedOrbs >= (self.MaxOrbsPerMissile or 4) then return end

    local orb = ents.Create(ORB_CLASS)
    if not IsValid(orb) then return end
    orb:SetPos(centerPos)
    if IsValid(owner) then orb:SetOwner(owner) end
    orb:Spawn()
    table.insert(self.SpawnedOrbs, orb)

    local phys = orb:GetPhysicsObject()
    if IsValid(phys) then
        local dir = VectorRand()
        dir.z = dir.z * 0.4
        if dir:LengthSqr() < 0.01 then dir = Vector(1, 0, 0) end
        dir:Normalize()
        phys:SetVelocity(dir * math.Rand(self.OrbMinSpeed or 150, self.OrbMaxSpeed or 280))
    end

    timer.Simple(1.5, function()
        if IsValid(orb) then orb:Remove() end
    end)
end

local function RandomAroundNormal(baseDir, spreadDeg)
    baseDir = baseDir:GetNormalized()
    local ang = baseDir:Angle()
    ang:RotateAroundAxis(ang:Right(),   math.Rand(-spreadDeg, spreadDeg))
    ang:RotateAroundAxis(ang:Up(),      math.Rand(-spreadDeg, spreadDeg))
    ang:RotateAroundAxis(ang:Forward(), math.Rand(-spreadDeg, spreadDeg))
    return ang:Forward()
end

-- -------------------------------------------------------
-- Entity lifecycle
-- -------------------------------------------------------

function ENT:Initialize()
    self:SetModel("models/props_junk/garbage_metalcan001a.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_PROJECTILE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:SetMass(10)
        phys:EnableGravity(true)
        -- NOTE: EnableContinuousCollisionDetection does NOT exist in GMod Lua.
        -- Tunneling is handled by the per-think trace (Layer 2) and speed
        -- clamp (Layer 3) in Think() instead.

        local ang = self:GetForward():Angle()
        local spread = 6
        ang:RotateAroundAxis(ang:Up(),      math.Rand(-spread, spread))
        ang:RotateAroundAxis(ang:Right(),   math.Rand(-spread * 0.5, spread * 0.5))
        ang:RotateAroundAxis(ang:Forward(), math.Rand(-spread * 0.5, spread * 0.5))

        local dir = ang:Forward()
        self.LaunchDir = dir
        phys:SetVelocity(dir * self.InitialSpeed)
    end

    self:SetWireStart(self:GetPos())

    -- Initialise all runtime fields here AND via EnsureFields so
    -- both spawn paths (normal + conv/sh.lua) are always covered.
    EnsureFields(self)

    util.SpriteTrail(
        self, 0, Color(120, 200, 255),
        false, 12, 0, 0.4, 1 / 16, "trails/laser.vmt"
    )

    self.DynamicLightEnt = nil
end

function ENT:Arm()
    if self.Armed then return end
    self.Armed = true

    local dyn = ents.Create("expensive_light_new")
    if IsValid(dyn) then
        dyn:SetPos(self:GetPos())
        dyn:SetAngles(self:GetAngles())
        dyn:Spawn()
        dyn:Activate()
        dyn:SetParent(self)
        local sizeMul = math.Rand(0.8, 1.3)
        if dyn.SetLightColor then dyn:SetLightColor(RandomElectricColor()) end
        if dyn.SetBrightness then dyn:SetBrightness(RandomBrightness() * sizeMul) end
        if dyn.SetFarZ       then dyn:SetFarZ(RandomFarZ() * sizeMul) end
        if dyn.SetShadows    then dyn:SetShadows(true) end
        if dyn.SetDrawSprite then dyn:SetDrawSprite(true) end
    end
    self.DynamicLightEnt = dyn
end

function ENT:DoElectricity()
    -- Guarantee fields even if Initialize() was bypassed
    EnsureFields(self)

    local startPos = self:GetWireStart()
    if not startPos then return end

    local endPos   = self:GetPos()
    local segments = self.WireSegments or 12

    local cableChargeSegments = {}
    for n = 1, math.min(self.CableChargeCountPerZap or 0, segments + 1) do
        cableChargeSegments[math.random(0, segments)] = true
    end

    local arcSegments = {}
    for n = 1, math.min(self.SideArcCountPerTick, segments + 1) do
        arcSegments[math.random(0, segments)] = true
    end

    local owner = IsValid(self:GetOwner()) and self:GetOwner() or self

    for i = 0, segments do
        local t       = i / segments
        local linePos = LerpVector(t, startPos, endPos)

        local tr = util.TraceLine({
            start  = linePos,
            endpos = linePos - Vector(0, 0, 512),
            mask   = MASK_SOLID_BRUSHONLY
        })

        local groundPos, normal
        if tr.Hit then
            groundPos = tr.HitPos + tr.HitNormal * 4
            normal    = tr.HitNormal
        else
            groundPos = linePos
            normal    = Vector(0, 0, 1)
        end

        DoShockDamage(owner, self, groundPos, self.PoolRadius, self.DamagePerTick)

        local ed = EffectData()
        ed:SetOrigin(groundPos)
        ed:SetNormal(normal)
        ed:SetMagnitude(2)
        ed:SetScale(2.5)
        ed:SetRadius(self.PoolRadius)
        util.Effect("ElectricSpark", ed, true, true)

        if math.Rand(0, 1) < 0.9 then
            sound.EmitHint(
                bit.bor(SOUND_DANGER, SOUND_PHYSICS_DANGER),
                groundPos, self.PoolRadius * 2.0, 0.25, owner
            )
        end

        if math.Rand(0, 1) < 0.15 and CurTime() - self.LastGroundFlash > 0.2 then
            self.LastGroundFlash = CurTime()
            SpawnGroundFlash(groundPos, normal)
        end

        local nearRags = ents.FindInSphere(groundPos, self.PoolRadius * 0.6)
        for _, rag in ipairs(nearRags) do
            if IsValid(rag) and rag:GetClass() == "prop_ragdoll" then
                local pos2 = rag:WorldSpaceCenter()
                local ed2  = EffectData()
                ed2:SetOrigin(pos2)
                ed2:SetNormal(VectorRand())
                ed2:SetMagnitude(1.2)
                ed2:SetScale(1.2)
                ed2:SetRadius(48)
                util.Effect("ElectricSpark", ed2, true, true)
            end
        end

        if arcSegments[i] and math.Rand(0, 1) < (self.SideArcSpawnChance or 0.4) then
            local baseDir = (endPos - startPos)
            if baseDir:LengthSqr() == 0 then baseDir = VectorRand() end
            local arcDir = RandomAroundNormal(baseDir, 45)
            local arc = ents.Create("wire_electric_arc")
            if IsValid(arc) then
                arc:SetPos(linePos + VectorRand() * 10)
                arc:SetOwner(owner)
                if arc.SetArcDir then arc:SetArcDir(arcDir) end
                arc:SetAngles(arcDir:Angle())
                arc:Spawn()
            end
        end

        if cableChargeSegments[i] and math.Rand(0, 1) < 0.8 then
            SpawnChargePoint(self, linePos, nil, true)
        end

        if math.Rand(0, 1) < (self.FloorChargeChance or 0.35) then
            SpawnChargePoint(self, groundPos, normal, false)
        end

        if math.Rand(0, 1) < 0.15 then
            local t2 = math.Clamp(t + math.Rand(0.05, 0.25), 0, 1)
            SpawnCableLightning(linePos, LerpVector(t2, startPos, endPos))
        end

        if math.Rand(0, 1) < 0.25 then
            SpawnCableToGroundLightning(linePos, groundPos, self.PoolRadius or 90)
        end

        if math.Rand(0, 1) < (self.OrbSpawnChancePerSegment or 0.02) then
            SpawnRadialOrb(self, owner, linePos)
        end
    end

    for n = 1, 2 do
        local t   = math.Rand(0, 1)
        local pos = LerpVector(t, startPos, endPos)
        local ed2 = EffectData()
        ed2:SetOrigin(pos)
        ed2:SetNormal(VectorRand())
        ed2:SetMagnitude(1.4)
        ed2:SetScale(1.0)
        ed2:SetRadius(80)
        util.Effect("TeslaHitBoxes", ed2, true, true)
    end
end

-- -------------------------------------------------------
-- Impact handler (idempotent, shared by PhysicsCollide
-- and the per-think ground trace)
-- -------------------------------------------------------

function ENT:DoImpact(hitPos, hitNormal, hitEnt)
    if self.HasImpacted then return end
    self.HasImpacted = true

    hitPos    = hitPos    or self:GetPos()
    hitNormal = hitNormal or Vector(0, 0, 1)

    if IsValid(hitEnt) and (hitEnt:IsPlayer() or hitEnt:IsNPC()) then
        local dmg = DamageInfo()
        dmg:SetDamage(self.ImpactDamage)
        dmg:SetDamageType(DMG_CLUB)
        dmg:SetAttacker(IsValid(self:GetOwner()) and self:GetOwner() or self)
        dmg:SetInflictor(self)
        dmg:SetDamagePosition(hitPos)
        hitEnt:TakeDamageInfo(dmg)
    end

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
        phys:Sleep()
    end

    local ed = EffectData()
    ed:SetOrigin(hitPos)
    ed:SetNormal(hitNormal)
    util.Effect("cball_explode", ed, true, true)

    self:EmitSound("ambient/energy/zap" .. math.random(1, 9) .. ".wav", 80, 120)
end

-- -------------------------------------------------------
-- Main Think loop
-- -------------------------------------------------------

function ENT:Think()
    local now = CurTime()

    -- Guarantee all fields exist regardless of spawn path
    EnsureFields(self)

    if now >= self.DieTime then
        self:Remove()
        return
    end

    if not self.Armed and now >= self.SafeUntil then
        self:Arm()
    end

    -- LAYER 2: Per-think ground trace (replaces the removed CCD call)
    if not self.HasImpacted then
        local pos  = self:GetPos()
        local phys = self:GetPhysicsObject()

        -- LAYER 3: Velocity clamp — prevent large per-frame overshoots
        if IsValid(phys) then
            local vel   = phys:GetVelocity()
            local speed = vel:Length()
            if speed > (self.MaxSpeed or 1800) then
                phys:SetVelocity(vel:GetNormalized() * (self.MaxSpeed or 1800))
            end
        end

        local traceLen = self.GroundTraceLen or 18
        local trDown = util.TraceLine({
            start  = pos,
            endpos = pos - Vector(0, 0, traceLen),
            filter = { self },
            mask   = MASK_SOLID,
        })

        if trDown.Hit and not trDown.HitSky then
            local vel2   = IsValid(phys) and phys:GetVelocity() or Vector(0, 0, 0)
            local velDir = vel2:GetNormalized()
            local trFwd  = util.TraceLine({
                start  = pos,
                endpos = pos + velDir * traceLen,
                filter = { self },
                mask   = MASK_SOLID,
            })

            if trFwd.Hit and not trFwd.HitSky then
                self:DoImpact(trFwd.HitPos, trFwd.HitNormal, trFwd.Entity)
            elseif trDown.Fraction < 0.5 then
                self:DoImpact(trDown.HitPos, trDown.HitNormal, trDown.Entity)
            end
        end
    end

    -- Electricity only after safe phase
    if now >= self.SafeUntil then
        if now >= self.NextZap then
            self.NextZap = now + self.TickInterval
            self:DoElectricity()
        end
    end

    self:NextThink(now)
    return true
end

function ENT:PhysicsCollide(data, physobj)
    self:DoImpact(data.HitPos, data.HitNormal, data.HitEntity)
end

function ENT:OnRemove()
    if IsValid(self.DynamicLightEnt) then
        self.DynamicLightEnt:Remove()
        self.DynamicLightEnt = nil
    end
end
