include("shared.lua")

-- Custom crosshair: energy slash reticle
function SWEP:DrawHUD()
    local cx = ScrW() / 2
    local cy = ScrH() / 2

    surface.SetDrawColor(100, 200, 255, 200)

    -- Horizontal line (wide)
    surface.DrawRect(cx - 28, cy - 1, 56, 2)

    -- Vertical ticks
    surface.DrawRect(cx - 1, cy - 10, 2, 8)
    surface.DrawRect(cx - 1, cy + 2, 2, 8)

    -- Corner brackets
    local s = 8
    -- Top-left
    surface.DrawRect(cx - 22, cy - 9, s, 2)
    surface.DrawRect(cx - 22, cy - 9, 2, s)
    -- Top-right
    surface.DrawRect(cx + 14, cy - 9, s, 2)
    surface.DrawRect(cx + 20, cy - 9, 2, s)
    -- Bottom-left
    surface.DrawRect(cx - 22, cy + 7, s, 2)
    surface.DrawRect(cx - 22, cy - 1, 2, s)
    -- Bottom-right
    surface.DrawRect(cx + 14, cy + 7, s, 2)
    surface.DrawRect(cx + 20, cy - 1, 2, s)

    -- Ultimate cooldown HUD
    local ultReady = self:GetNWFloat("pvp_separator_ult_ready", 0)
    local now = CurTime()
    local remaining = ultReady - now
    local ultCooldown = 10

    local barW = 180
    local barH = 20
    local barX = 460
    local barY = ScrH() - 60

    -- Background
    surface.SetDrawColor(0, 0, 0, 180)
    surface.DrawRect(barX - 2, barY - 2, barW + 4, barH + 4)

    if remaining > 0 then
        local frac = math.Clamp(1 - remaining / ultCooldown, 0, 1)

        surface.SetDrawColor(20, 50, 70, 200)
        surface.DrawRect(barX, barY, barW, barH)

        surface.SetDrawColor(100, 200, 255, 220)
        surface.DrawRect(barX, barY, barW * frac, barH)

        draw.SimpleText(string.format("ULT: %.1fs", remaining), "DermaDefaultBold", barX + barW / 2, barY + barH / 2, Color(255, 255, 255, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    else
        local pulse = 160 + math.sin(CurTime() * 4) * 95
        surface.SetDrawColor(40, math.floor(pulse * 0.7), pulse, 220)
        surface.DrawRect(barX, barY, barW, barH)

        draw.SimpleText("ULT READY [RMB]", "DermaDefaultBold", barX + barW / 2, barY + barH / 2, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    surface.SetDrawColor(100, 200, 255, 150)
    surface.DrawOutlinedRect(barX - 2, barY - 2, barW + 4, barH + 4, 1)
end

function SWEP:DrawWeaponSelection(x, y, wide, tall, alpha)
    draw.SimpleText(self.PrintName, "DermaLarge", x + wide / 2, y + tall / 2, Color(100, 200, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end
