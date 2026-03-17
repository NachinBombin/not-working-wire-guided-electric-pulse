include("shared.lua")

function ENT:Initialize()
    self.Path = {}
end


function ENT:Think()

    -- Sparks
    local effect = EffectData()
    effect:SetOrigin(self:GetPos())
    util.Effect("ManhackSparks",effect)

    -- Path buffer
    table.insert(self.Path,self:GetPos())
    if #self.Path > 25 then
        table.remove(self.Path,1)
    end

    -- Lightning trail
    if #self.Path >= 5 and math.random(1,3) == 1 then

        local a = table.Random(self.Path)
        local b = table.Random(self.Path)

        local fx = EffectData()
        fx:SetStart(a)
        fx:SetOrigin(b)

        util.Effect("ToolTracer",fx)

    end

end


function ENT:Draw()
    self:DrawModel()
end