-- lua/entities/wire_electric_arc/shared.lua
AddCSLuaFile()

ENT.Type        = "anim"
ENT.Base        = "base_entity"
ENT.PrintName   = "Wire Electric Arc"
ENT.Spawnable   = false
ENT.AdminOnly   = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

-- Core tuning for the side arcs
ENT.ArcSpeed      = 1300      -- units per second
ENT.ArcLifetime   = 0.6       -- short-lived bursts
ENT.ArcHitDamage  = 2         -- very low damage per arc
ENT.ArcHitRadius  = 18        -- small radius around tip

function ENT:SetupDataTables()
    -- Direction the arc travels in world space
    self:NetworkVar("Vector", 0, "ArcDir")
end
