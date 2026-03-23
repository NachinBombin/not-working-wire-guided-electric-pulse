-- lua/entities/wire_electric_missile/cl_init.lua
include("shared.lua")

local cableMat = Material("cable/cable_lit")

function ENT:Initialize()
    self.WireSubdivs = self.WireSegments or 16
end

function ENT:Draw()
    self:DrawModel()

    local startPos = self:GetWireStart()
    if not startPos then return end

    local endPos   = self:GetPos()
    local segments = self.WireSubdivs or 16

    render.SetMaterial(cableMat)
    render.StartBeam(segments + 1)

    local time = CurTime()

    for i = 0, segments do
        local t = i / segments
        local pos = LerpVector(t, startPos, endPos)

        -- Add some procedural noise so the cable looks alive
        local offset = VectorRand() * 3 * math.sin(time * 6 + t * math.pi * 4)
        pos = pos + offset

        local r = 120 + 80 * (1 - t)
        local g = 200 + 55 * t
        local b = 255
        local a = 255

        -- Beam width reduced from 6 -> 3 to make cable thinner
        render.AddBeam(pos, 3, t * 2, Color(r, g, b, a))
    end

    render.EndBeam()
end
