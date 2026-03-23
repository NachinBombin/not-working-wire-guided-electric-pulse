-- lua/entities/wire_electric_arc/init.lua
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

function ENT:Initialize()
    -- Invisible tiny model; visuals are purely clientside beams
    self:SetModel("models/hunter/plates/plate.mdl")
    self:SetModelScale(0.001)
    self:SetSolid(SOLID_NONE)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetCollisionGroup(COLLISION_GROUP_NONE)

    local dir = self:GetArcDir()
    if dir == vector_origin or dir:LengthSqr() == 0 then
        dir = self:GetAngles():Forward()
    else
        dir = dir:GetNormalized()
    end

    self.MoveDir   = dir
    self.SpawnTime = CurTime()
    self.HitEnts   = {}

    -- expose dir + spawn time to client for trail animation
    self:SetArcDir(dir)
    self:SetNWVector("WireArcDir", dir)
    self:SetNWFloat("WireArcSpawn", CurTime())
end

-- very small shock hit: zap sound + Tesla, no DOT/freeze
local function DoArcHitDamage(pos, owner, inflictor, radius, dmgAmount)
    local entsInSphere = ents.FindInSphere(pos, radius)

    for _, ent in ipairs(entsInSphere) do
        if not (ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot()) then continue end

        -- basic low damage
        local dmg = DamageInfo()
        dmg:SetDamage(dmgAmount)
        dmg:SetDamageType(DMG_SHOCK)
        dmg:SetAttacker(IsValid(owner) and owner or (IsValid(inflictor) and inflictor or game.GetWorld()))
        dmg:SetInflictor(IsValid(inflictor) and inflictor or game.GetWorld())
        dmg:SetDamagePosition(ent:GetPos())
        ent:TakeDamageInfo(dmg)

        -- Tesla effect hugging hitboxes (copied logic style)
        local ef = EffectData()
        ef:SetEntity(ent)
        ef:SetOrigin(ent:GetPos())
        ef:SetMagnitude(2)
        ef:SetScale(2)
        util.Effect("TeslaHitboxes", ef, true, true)

        -- zap sound logic from PVP beam
        ent:EmitSound("ambient/energy/zap" .. math.random(5, 9) .. ".wav",
            70, math.random(100, 130), 0.6)
    end
end

function ENT:Think()
    local now = CurTime()
    if now - self.SpawnTime > self.ArcLifetime then
        self:Remove()
        return
    end

    local dt     = FrameTime()
    local pos    = self:GetPos()
    local dir    = self.MoveDir
    local speed  = self.ArcSpeed or 900
    local newPos = pos + dir * speed * dt

    -- world collision (optional – we just fizzle when we hit solids)
    local tr = util.TraceLine({
        start  = pos,
        endpos = newPos + dir * 20,
        filter = { self, self:GetOwner() },
        mask   = MASK_SOLID_BRUSHONLY
    })

    if tr.Hit then
        -- impact zap on world
        local ef = EffectData()
        ef:SetOrigin(tr.HitPos)
        ef:SetStart(tr.HitPos + tr.HitNormal * 30)
        ef:SetScale(4)
        util.Effect("TeslaZap", ef, true, true)

        self:EmitSound("ambient/energy/zap9.wav", 75, 100, 0.7)

        DoArcHitDamage(tr.HitPos, self:GetOwner(), self, self.ArcHitRadius, self.ArcHitDamage)
        self:Remove()
        return
    end

    -- soft entity hit-through: it can hit something once then keep going
    local owner = self:GetOwner()
    local hitPos = newPos

    for _, ent in ipairs(ents.FindInSphere(hitPos, self.ArcHitRadius)) do
        if ent == self then continue end
        if IsValid(owner) and ent == owner then continue end
        if not (ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot()) then continue end
        if self.HitEnts[ent:EntIndex()] then continue end

        self.HitEnts[ent:EntIndex()] = true

        -- small zap on this entity
        DoArcHitDamage(ent:WorldSpaceCenter(), owner, self, self.ArcHitRadius, self.ArcHitDamage)
    end

    self:SetPos(newPos)
    self:NextThink(CurTime())
    return true
end
