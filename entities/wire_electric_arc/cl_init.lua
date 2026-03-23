-- lua/entities/wire_electric_arc/cl_init.lua
include("shared.lua")

-- materials from the PVP beam, reused
local matOuter = Material("sprites/physbeam")
local matCore  = Material("cable/blue_elec")
local matGlow  = Material("sprites/light_glow02_add")

function ENT:Initialize()
    self.SpawnTime = CurTime()
end

-- we draw everything in DrawTranslucent so beams render correctly in the world
function ENT:Draw()
    -- no model; everything is beam-based
end

function ENT:DrawTranslucent()
    if not IsValid(self) then return end

    local pos = self:GetPos()
    local dir = self:GetNWVector("WireArcDir", Vector(1, 0, 0))
    if dir:LengthSqr() == 0 then dir = Vector(1, 0, 0) end
    dir = dir:GetNormalized()

    local ang = dir:Angle()
    local rt  = ang:Right()
    local up  = ang:Up()
    local now = CurTime()
    local seed = self:EntIndex() * 137

    local pulse = math.sin(now * 15 + seed) * 0.2 + 0.8

    -- === Wavy electric trail (8 segments) ===
    local TRAIL_LEN  = 220
    local SEG        = 8
    local WAVE_AMP   = 14
    local WAVE_SPEED = 12

    local pts1 = {}
    for i = 0, SEG do
        local t = i / SEG
        local trailPos = pos - dir * (t * TRAIL_LEN)

        local w1 = math.sin(t * math.pi * 2.5 + now * WAVE_SPEED + seed) * WAVE_AMP * t
        local w2 = math.cos(t * math.pi * 3.2 - now * WAVE_SPEED * 1.3 + seed) * WAVE_AMP * 0.5 * t
        pts1[i + 1] = trailPos + rt * w1 + up * w2
    end

    -- outer glow trail
    render.SetMaterial(matOuter)
    for i = 1, SEG do
        local fade = 1 - ((i - 1) / SEG)
        render.DrawBeam(
            pts1[i],
            pts1[i + 1],
            26 * fade,
            0,
            1,
            Color(60, 140, 255, 90 * fade)
        )
    end

    -- core electric trail
    render.SetMaterial(matCore)
    local uvScroll = (now * 5) % 1
    for i = 1, SEG do
        local fade = 1 - ((i - 1) / SEG)
        render.DrawBeam(
            pts1[i],
            pts1[i + 1],
            9 * fade,
            uvScroll,
            uvScroll + 0.5,
            Color(200, 230, 255, 220 * fade)
        )
    end

    -- second tendril, slightly offset / different wave
    local pts2 = {}
    for i = 0, SEG do
        local t = i / SEG
        local trailPos = pos - dir * (t * TRAIL_LEN)

        local w  = math.sin(t * math.pi * 3.5 - now * WAVE_SPEED * 0.9 + seed + 2) * WAVE_AMP * 0.8 * t
        local w2 = math.sin(t * math.pi * 2   + now * WAVE_SPEED * 1.1 + seed) * WAVE_AMP * 0.4 * t
        pts2[i + 1] = trailPos - rt * w + up * w2
    end

    render.SetMaterial(matOuter)
    for i = 1, SEG do
        local fade = 1 - ((i - 1) / SEG)
        render.DrawBeam(
            pts2[i],
            pts2[i + 1],
            14 * fade,
            0,
            1,
            Color(80, 160, 255, 60 * fade)
        )
    end

    -- === Head glow ===
    render.SetMaterial(matGlow)
    render.DrawSprite(pos, 90 * pulse, 90 * pulse, Color(50, 120, 255, 90))
    render.DrawSprite(pos, 36 * pulse, 36 * pulse, Color(160, 210, 255, 210))
    render.DrawSprite(pos, 14 * pulse, 14 * pulse, Color(230, 245, 255, 255))

    -- Dynamic light at the tip
    local dl = DynamicLight(self:EntIndex())
    if dl then
        dl.Pos        = pos
        dl.r          = 80
        dl.g          = 170
        dl.b          = 255
        dl.Brightness = 3 * pulse
        dl.Size       = 230
        dl.Decay      = 800
        dl.DieTime    = now + 0.1
    end
end
