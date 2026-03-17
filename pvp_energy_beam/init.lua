AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

util.AddNetworkString("pvp_beam_zap")

local PULSE_SPEED    = 1200
local PULSE_LIFETIME = 4
local HIT_DAMAGE     = 10
local DOT_DURATION   = 3       -- shock lasts 3 seconds
local DOT_DPS        = 3       -- 3 damage per second
local DOT_INTERVAL   = 0.5     -- tick every 0.5s
local DOT_DMG_TICK   = DOT_DPS * DOT_INTERVAL  -- 1.5 per tick
local FREEZE_PER_TICK = 0.2    -- freeze 0.2s on each tick
local HIT_RADIUS     = 18      -- small radius like snowball direct hit

function ENT:Initialize()
    self:SetModel("models/hunter/plates/plate.mdl")
    self:SetModelScale(0.001)
    self:SetSolid(SOLID_NONE)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetCollisionGroup(COLLISION_GROUP_NONE)

    local fwd = self:GetAngles():Forward()
    self.MoveDir   = fwd
    self.SpawnTime = CurTime()
    self.HitEnts   = {}

    self.ElecSound = CreateSound(self, "ambient/energy/electric_loop.wav")
    if self.ElecSound then
        self.ElecSound:PlayEx(0.7, 120)
    end

    self:SetNWVector("BeamDir", fwd)
    self:SetNWFloat("BeamSpawn", CurTime())
end

-- Apply electric shock DOT to a target
local function ApplyElectricShock(target, attacker, inflictor)
    if not IsValid(target) then return end

    local hookName = "pvp_shock_" .. target:EntIndex() .. "_" .. CurTime()
    local endTime = CurTime() + DOT_DURATION
    local nextTick = CurTime() + DOT_INTERVAL

    -- Notify clients: full-body shock effect for DOT_DURATION
    net.Start("pvp_beam_zap")
        net.WriteEntity(target)
        net.WriteFloat(DOT_DURATION)
    net.Broadcast()

    -- Zap sound
    target:EmitSound("ambient/energy/zap" .. math.random(5, 9) .. ".wav", 80, math.random(90, 120), 0.8)

    hook.Add("Think", hookName, function()
        if not IsValid(target) then
            hook.Remove("Think", hookName)
            return
        end

        -- Stop DOT if target died (prevents carrying over after respawn)
        if target:IsPlayer() and not target:Alive() then
            hook.Remove("Think", hookName)
            return
        end

        if CurTime() >= endTime then
            hook.Remove("Think", hookName)
            return
        end

        if CurTime() >= nextTick then
            nextTick = CurTime() + DOT_INTERVAL

            -- DOT damage
            local dmg = DamageInfo()
            dmg:SetDamage(DOT_DMG_TICK)
            dmg:SetDamageType(DMG_SHOCK)
            dmg:SetAttacker(IsValid(attacker) and attacker or target)
            dmg:SetInflictor(IsValid(inflictor) and inflictor or target)
            dmg:SetDamagePosition(target:GetPos())
            target:TakeDamageInfo(dmg)

            -- Freeze per tick
            if target:IsPlayer() then
                target:Freeze(true)
                timer.Simple(FREEZE_PER_TICK, function()
                    if IsValid(target) then target:Freeze(false) end
                end)
            elseif target:IsNPC() then
                target:SetMoveType(MOVETYPE_NONE)
                timer.Simple(FREEZE_PER_TICK, function()
                    if IsValid(target) then target:SetMoveType(MOVETYPE_STEP) end
                end)
            end

            -- Tesla arcs on each tick
            local ef = EffectData()
            ef:SetEntity(target)
            ef:SetOrigin(target:GetPos())
            ef:SetMagnitude(3)
            ef:SetScale(2)
            util.Effect("TeslaHitboxes", ef)

            -- Zap sound on each tick
            target:EmitSound("ambient/energy/zap" .. math.random(5, 9) .. ".wav", 70, math.random(100, 130), 0.5)
        end
    end)
end

function ENT:Think()
    if CurTime() - self.SpawnTime > PULSE_LIFETIME then
        self:Remove()
        return
    end

    local dt     = FrameTime()
    local pos    = self:GetPos()
    local dir    = self.MoveDir
    local newPos = pos + dir * PULSE_SPEED * dt

    -- World collision
    local tr = util.TraceLine({
        start  = pos,
        endpos = newPos + dir * 20,
        filter = { self, self:GetOwner() },
        mask   = MASK_SOLID_BRUSHONLY,
    })

    if tr.Hit then
        local ef = EffectData()
        ef:SetOrigin(tr.HitPos)
        ef:SetStart(tr.HitPos + tr.HitNormal * 30)
        ef:SetScale(6)
        util.Effect("TeslaZap", ef)
        self:EmitSound("ambient/energy/zap9.wav", 80, 100, 0.8)
        self:Remove()
        return
    end

    -- Entity hit — passes through, hits each target once
    local owner = self:GetOwner()

    for _, ent in ipairs(ents.FindInSphere(newPos, HIT_RADIUS)) do
        if ent == self then continue end
        if IsValid(owner) and ent == owner then continue end
        if not (ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot()) then continue end
        if self.HitEnts[ent:EntIndex()] then continue end

        self.HitEnts[ent:EntIndex()] = true

        -- Direct hit damage
        local dmg = DamageInfo()
        dmg:SetDamage(HIT_DAMAGE)
        dmg:SetDamageType(DMG_SHOCK)
        dmg:SetAttacker(IsValid(owner) and owner or self)
        dmg:SetInflictor(self)
        dmg:SetDamagePosition(ent:GetPos())
        ent:TakeDamageInfo(dmg)

        -- Tesla arcs on hit (wraps around target hitboxes)
        local ef = EffectData()
        ef:SetEntity(ent)
        ef:SetOrigin(ent:GetPos())
        ef:SetMagnitude(4)
        ef:SetScale(3)
        util.Effect("TeslaHitboxes", ef)

        -- Apply electric shock DOT (3 sec, 3 dps, 0.2s freeze per tick)
        ApplyElectricShock(ent, owner, self)
    end

    self:SetPos(newPos)
    self:NextThink(CurTime())
    return true
end

function ENT:OnRemove()
    if self.ElecSound then
        self.ElecSound:Stop()
        self.ElecSound = nil
    end
end
