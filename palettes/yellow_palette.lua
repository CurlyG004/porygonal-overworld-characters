----------------------------------------------------------------
-- Porygonal - Yellow palette policy
--
-- Version-specific Gen 1 overworld palette policy.
--
-- Gen1Recomp now resolves Pokémon Yellow overworld palettes
-- correctly through the normal sprite definition path.
--
-- Keep this module as the Yellow-specific policy boundary even
-- when its current behavior matches the generic/Red-Blue path.
-- Future Yellow-specific character, Pokémon, species, shiny, or
-- other palette rules can be added here without leaking them into
-- the renderer or shared runtime.
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
