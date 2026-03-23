-- lua/entities/wire_electric_missile/shared.lua
AddCSLuaFile()

ENT.Type        = "anim"
ENT.Base        = "base_anim"

ENT.PrintName   = "Wire-Guided Electric Pulse"
ENT.Author = "Nachin Bombin"
ENT.Category = "Missiles"
ENT.Spawnable = true
ENT.AdminOnly = false


ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

-- Core tuning (shared so both realms can read)
ENT.WireLifetime   = 60         -- seconds cable & ground electricity stay active
ENT.ImpactDamage   = 15         -- small blunt on direct hit
ENT.DamagePerTick  = 8          -- damage dealt per pool sample per tick
ENT.TickInterval   = 0.25       -- seconds between electric pulses
ENT.PoolRadius     = 110        -- radius of the "electric pool" under the cable (buffed)
ENT.WireSegments   = 12         -- samples along the wire for damage & visuals
ENT.HomingStrength = 0.35       -- how aggressively it steers toward target
ENT.InitialSpeed   = 1600       -- initial missile speed

function ENT:SetupDataTables()
    -- Start of the cable in world space (Vector)
    self:NetworkVar("Vector", 0, "WireStart")
end