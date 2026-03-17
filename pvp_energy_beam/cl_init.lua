include("shared.lua")

-- -------------------------------------------------------
-- Shock overlay on frozen targets
-- -------------------------------------------------------
local ZappedEnts = {}

net.Receive("pvp_beam_zap", function()
    local ent = net.ReadEntity()
    local dur = net.ReadFloat()
    if IsValid(ent) then
        ZappedEnts[ent:EntIndex()] = { ent = ent, endTime = CurTime() + dur }
    end
end)

hook.Add("PostDrawOpaqueRenderables", "pvp_separator_shock", function()
    local now = CurTime()
    for idx, data in pairs(ZappedEnts) do
        if now > data.endTime or not IsValid(data.ent) then
            ZappedEnts[idx] = nil
        else
            local ent = data.ent
            local remaining = data.endTime - now
            local flicker = math.sin(now * 60) > 0 and 1 or 0.3
            local alpha = remaining * 220 * flicker

            render.SetBlend(alpha / 255)
            render.SetColorModulation(0.3, 0.6, 1.0)
            ent:DrawModel()
            render.SetBlend(1)
            render.SetColorModulation(1, 1, 1)
        end
    end
end)

-- -------------------------------------------------------
-- Energy bolt with electric trail
-- -------------------------------------------------------
local matBeam = Material("sprites/physbeam")
local matElec = Material("cable/blue_elec")
local matGlow = Material("sprites/light_glow02_add")

function ENT:Initialize()
    self.SpawnTime = CurTime()
end

function ENT:Draw() end

hook.Add("PostDrawTranslucentRenderables", "pvp_separator_pulse", function()
    local beams = ents.FindByClass("pvp_energy_beam")
    if #beams == 0 then return end

    local now = CurTime()

    for _, beam in ipairs(beams) do
        if not IsValid(beam) then continue end

        local pos = beam:GetPos()
        local dir = beam:GetNWVector("BeamDir", Vector(1, 0, 0))
        local ang = dir:Angle()
        local rt  = ang:Right()
        local up  = ang:Up()
        local seed = beam:EntIndex() * 137
        local pulse = math.sin(now * 15 + seed) * 0.2 + 0.8

        -- === Wavy electric trail (8 segments, 2 layers) ===
        local TRAIL_LEN  = 220
        local SEG         = 8
        local WAVE_AMP    = 14
        local WAVE_SPEED  = 12

        local pts = {}
        for i = 0, SEG do
            local t = i / SEG
            local trailPos = pos - dir * (t * TRAIL_LEN)
            local w1 = math.sin(t * math.pi * 2.5 + now * WAVE_SPEED + seed) * WAVE_AMP * t
            local w2 = math.cos(t * math.pi * 3.2 - now * WAVE_SPEED * 1.3 + seed) * WAVE_AMP * 0.5 * t
            pts[i + 1] = trailPos + rt * w1 + up * w2
        end

        -- Outer glow trail
        render.SetMaterial(matBeam)
        for i = 1, SEG do
            local fade = 1 - ((i - 1) / SEG)
            render.DrawBeam(pts[i], pts[i + 1], 30 * fade, 0, 1, Color(60, 140, 255, 90 * fade))
        end

        -- Core electric trail
        render.SetMaterial(matElec)
        local uvScroll = (now * 5) % 1
        for i = 1, SEG do
            local fade = 1 - ((i - 1) / SEG)
            render.DrawBeam(pts[i], pts[i + 1], 10 * fade, uvScroll, uvScroll + 0.5, Color(200, 230, 255, 220 * fade))
        end

        -- Second tendril (offset)
        local pts2 = {}
        for i = 0, SEG do
            local t = i / SEG
            local trailPos = pos - dir * (t * TRAIL_LEN)
            local w = math.sin(t * math.pi * 3.5 - now * WAVE_SPEED * 0.9 + seed + 2) * WAVE_AMP * 0.8 * t
            local w2 = math.sin(t * math.pi * 2 + now * WAVE_SPEED * 1.1 + seed) * WAVE_AMP * 0.4 * t
            pts2[i + 1] = trailPos - rt * w + up * w2
        end

        render.SetMaterial(matBeam)
        for i = 1, SEG do
            local fade = 1 - ((i - 1) / SEG)
            render.DrawBeam(pts2[i], pts2[i + 1], 16 * fade, 0, 1, Color(80, 160, 255, 60 * fade))
        end

        -- === Head glow ===
        render.SetMaterial(matGlow)
        render.DrawSprite(pos, 100 * pulse, 100 * pulse, Color(50, 120, 255, 90))
        render.DrawSprite(pos, 40 * pulse, 40 * pulse, Color(160, 210, 255, 210))
        render.DrawSprite(pos, 16 * pulse, 16 * pulse, Color(230, 245, 255, 255))

        -- Dynamic light
        local dl = DynamicLight(beam:EntIndex())
        if dl then
            dl.Pos        = pos
            dl.r          = 80
            dl.g          = 170
            dl.b          = 255
            dl.Brightness = 3 * pulse
            dl.Size       = 250
            dl.Decay      = 800
            dl.DieTime    = now + 0.1
        end
    end
end)
