SWEP.PrintName      = "Separator"
SWEP.Author         = "Balamut"
SWEP.Category       = "PVP"
SWEP.Instructions   = "LMB - Energy bolt | RMB - Triple burst (ULT)"

SWEP.Spawnable      = true
SWEP.AdminOnly      = false

SWEP.ViewModel      = "models/weapons/c_irifle.mdl"
SWEP.WorldModel     = "models/weapons/w_irifle.mdl"
SWEP.UseHands       = true
SWEP.HoldType       = "ar2"
SWEP.ViewModelFOV   = 60

SWEP.Primary.ClipSize      = -1
SWEP.Primary.DefaultClip   = -1
SWEP.Primary.Automatic     = true
SWEP.Primary.Ammo          = "none"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"

local FIRE_DELAY     = 0.6
local ULT_COOLDOWN   = 4
local ULT_SHOT_COUNT = 3
local ULT_SHOT_DELAY = 0.1
local ULT_SPREAD     = 2.5  -- degrees of random spread per shot

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
    self.UltReady = 0
end

-- Get muzzle position from AR2 viewmodel attachment
function SWEP:GetMuzzlePos()
    local owner = self:GetOwner()
    if not IsValid(owner) then return owner:EyePos(), owner:EyeAngles() end

    local vm = owner:GetViewModel()
    if IsValid(vm) then
        local att = vm:GetAttachment(1)
        if att then
            return att.Pos, att.Ang
        end
    end

    -- Fallback: eye position + forward offset
    local shootDir = owner:EyeAngles():Forward()
    return owner:EyePos() + shootDir * 40, owner:EyeAngles()
end

function SWEP:FireBeam(spreadDeg)
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    if SERVER then
        local eyeAng = owner:EyeAngles()
        local eyePos = owner:GetShootPos()
        local eyeFwd = eyeAng:Forward()
        local spawnPos = eyePos + eyeFwd * 40 + eyeAng:Right() * 8 + eyeAng:Up() * -4

        -- Trace to find where crosshair points
        local tr = util.TraceLine({
            start = eyePos,
            endpos = eyePos + eyeFwd * 50000,
            filter = owner,
            mask = MASK_SHOT,
        })
        local aimPoint = tr.HitPos

        -- Direction from muzzle to crosshair target
        local shootDir = (aimPoint - spawnPos):GetNormalized()

        -- Apply spread if specified
        if spreadDeg and spreadDeg > 0 then
            local right = eyeAng:Right()
            local up = eyeAng:Up()
            local spreadRad = math.rad(spreadDeg)
            local rx = math.Rand(-spreadRad, spreadRad)
            local ry = math.Rand(-spreadRad, spreadRad)
            shootDir = (shootDir + right * rx + up * ry):GetNormalized()
        end

        local beam = ents.Create("pvp_energy_beam")
        if IsValid(beam) then
            beam:SetPos(spawnPos)
            beam:SetAngles(shootDir:Angle())
            beam:SetOwner(owner)
            beam:Spawn()
            beam:Activate()
        end
    end
end

function SWEP:PrimaryAttack()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    self:SetNextPrimaryFire(CurTime() + FIRE_DELAY)

    self:SendWeaponAnim(ACT_VM_SECONDARYATTACK)
    owner:SetAnimation(PLAYER_ATTACK1)

    self:EmitSound("ambient/energy/zap7.wav", 80, 70, 1.0)
    self:EmitSound("weapons/ar2/npc_ar2_altfire.wav", 75, 100, 0.7)

    util.ScreenShake(owner:GetPos(), 8, 15, 0.4, 200)

    self:FireBeam(0)
end

function SWEP:SecondaryAttack()
    if (self.UltReady or 0) > CurTime() then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    self.UltReady = CurTime() + ULT_COOLDOWN
    self:SetNextSecondaryFire(CurTime() + ULT_COOLDOWN)
    self:SetNextPrimaryFire(CurTime() + ULT_SHOT_COUNT * ULT_SHOT_DELAY + 0.3)

    self:SetNWFloat("pvp_separator_ult_ready", self.UltReady)

    -- Knockback on start
    local shootDir = owner:EyeAngles():Forward()
    owner:SetVelocity(shootDir * -350)

    -- Initial animation (client prediction)
    self:SendWeaponAnim(ACT_VM_SECONDARYATTACK)
    owner:SetAnimation(PLAYER_ATTACK1)
    self:EmitSound("ambient/energy/zap7.wav", 85, 60, 0.9)
    self:EmitSound("weapons/ar2/npc_ar2_altfire.wav", 80, 90, 0.7)

    if SERVER then
        util.ScreenShake(owner:GetPos(), 6, 15, 0.25, 200)

        -- All 3 shots via server timers (SendWeaponAnim networks to client)
        for i = 0, ULT_SHOT_COUNT - 1 do
            timer.Simple(i * ULT_SHOT_DELAY, function()
                if not IsValid(self) or not IsValid(owner) or not owner:Alive() then return end

                self:SendWeaponAnim(ACT_VM_SECONDARYATTACK)
                owner:SetAnimation(PLAYER_ATTACK1)

                self:EmitSound("ambient/energy/zap7.wav", 85, 60 + i * 10, 0.9)
                self:EmitSound("weapons/ar2/npc_ar2_altfire.wav", 80, 90 + i * 10, 0.7)

                util.ScreenShake(owner:GetPos(), 6, 15, 0.25, 200)

                self:FireBeam(ULT_SPREAD)
            end)
        end
    end
end

function SWEP:Reload() end
