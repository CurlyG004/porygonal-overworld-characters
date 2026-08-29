----------------------------------------------------------------
-- Porygonal - Red / Blue palette policy
--
-- Version-specific Gen 1 overworld palette policy.
--
-- IMPORTANT:
-- This file intentionally reproduces the current V0.3.0 2/3
-- palette behavior exactly. No Yellow-specific correction is
-- implemented yet.
--
-- Future species/shiny palette handling should be layered above or
-- alongside this version policy, not hard-coded into the renderer.
----------------------------------------------------------------

local Palette = {}


----------------------------------------------------------------
-- Resolve active character colors
----------------------------------------------------------------

function Palette.resolve(
    PaletteFX,
    sprite,
    colors
)

    if colors then
        return colors
    end


    if PaletteFX.usesGbcPack()
        and sprite
        and sprite.def then

        local spriteColors =
            PaletteFX.spriteObp(
                sprite.def,
                sprite.seed
            )


        if spriteColors then
            return spriteColors
        end
    end


    return nil
end


return Palette
