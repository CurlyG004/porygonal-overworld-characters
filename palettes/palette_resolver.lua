----------------------------------------------------------------
-- Porygonal - palette resolver
--
-- Dispatches Gen 1 overworld palette resolution to the policy
-- associated with the active Porygonal version group.
--
-- This module does NOT detect the ROM.
-- It receives an explicit version group from its caller.
--
-- Porygonal-local palette modules are loaded through loadLocalModule().
----------------------------------------------------------------

local PaletteResolver = {}


----------------------------------------------------------------
-- Create resolver
----------------------------------------------------------------

function PaletteResolver.create(
    loadLocalModule
)

    assert(
        type(loadLocalModule) == "function",
        "palette_resolver.lua expected loadLocalModule"
    )


    local RedBlue =
        loadLocalModule(
            "palettes/red_blue_palette.lua"
        )


    local Yellow =
        loadLocalModule(
            "palettes/yellow_palette.lua"
        )


    assert(
        RedBlue
            and type(RedBlue.resolve) == "function",
        "Could not load Red/Blue palette resolver"
    )


    assert(
        Yellow
            and type(Yellow.resolve) == "function",
        "Could not load Yellow palette resolver"
    )


    local resolvers = {

        redBlue =
            RedBlue,

        yellow =
            Yellow
    }


    local Resolver = {}


    ----------------------------------------------------------------
    -- Resolve palette through explicit version group
    ----------------------------------------------------------------

    function Resolver.resolve(
        versionGroup,
        PaletteFX,
        sprite,
        colors
    )

        local resolver =
            resolvers[
                versionGroup
            ]


        assert(
            resolver
                and type(resolver.resolve) == "function",
            "No Porygonal palette resolver for version group: "
                .. tostring(versionGroup)
        )


        return resolver.resolve(
            PaletteFX,
            sprite,
            colors
        )
    end


    return Resolver
end


return PaletteResolver
