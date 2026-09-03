----------------------------------------------------------------
-- Porygonal - Renderer manager
--
-- Owns renderer selection only.
--
-- Contract expected from each renderer adapter:
--
--   Renderer.info (optional but recommended)
--       adapterVersion
--       targetMod.id
--       targetMod.name
--       targetMod.validatedVersion
--       porygonalVersion
--
--   Renderer.detect(mod)
--       -> true when the external renderer is present and its
--          required public API is available.
--
--   Renderer.initialize(
--       mod,
--       loadLocalModule,
--       Registry,
--       CharacterRuntime
--   )
--       -> true when the Porygonal compatibility layer was
--          initialized successfully.
--
-- Detection must not install hooks, wrappers, or modify runtime
-- behavior.
----------------------------------------------------------------

local RendererManager = {}


----------------------------------------------------------------
-- Active renderer adapter metadata
----------------------------------------------------------------

RendererManager.active = nil

function RendererManager.getActive()
    return RendererManager.active
end


----------------------------------------------------------------
-- Renderer adapter candidates
----------------------------------------------------------------

local CANDIDATES = {

    {
        name = "PotatoVoxel",
        path = "renderers/potato_voxel/potato_voxel_adapter.lua"
    },

    {
        name = "Dramatic Shape",
        path = "renderers/dramatic_shape/dramatic_shape_adapter.lua"
    },

    {
        name = "Dramaless Shape",
        path = "renderers/dramaless_shape/dramaless_shape_adapter.lua"
    },

    {
        name = "Battle Art Voxel",
        path = "renderers/battle_art_voxel/battle_art_voxel_adapter.lua"
    }

}


----------------------------------------------------------------
-- Initialize one compatible renderer
----------------------------------------------------------------

function RendererManager.initialize(
    mod,
    loadLocalModule,
    Registry,
    CharacterRuntime
)

    local compatible = {}


    ----------------------------------------------------------------
    -- Detect available compatible renderers
    ----------------------------------------------------------------

    for _, candidate in ipairs(
        CANDIDATES
    ) do

        local adapter =
            loadLocalModule(
                candidate.path
            )


        if adapter
            and type(adapter.detect) == "function"
            and type(adapter.initialize) == "function" then

            local ok,
                  detected =
                pcall(
                    adapter.detect,
                    mod
                )


            if ok
                and detected then

                compatible[
                    #compatible + 1
                ] = {
                    name = candidate.name,
                    adapter = adapter,
                    info = adapter.info
                }
            end
        end
    end


    ----------------------------------------------------------------
    -- No compatible renderer
    ----------------------------------------------------------------

    if #compatible == 0 then

        mod.log:warn(
            "No compatible 3D renderer was detected"
        )

        return false
    end


    ----------------------------------------------------------------
    -- Ambiguous renderer selection
    --
    -- Do not initialize multiple renderer adapters at once.
    ----------------------------------------------------------------

    if #compatible > 1 then

        local names = {}


        for _, renderer in ipairs(
            compatible
        ) do

            names[
                #names + 1
            ] = renderer.name
        end


        mod.log:warn(
            "Multiple compatible 3D renderers detected: %s",
            table.concat(
                names,
                ", "
            )
        )

        return false
    end


    ----------------------------------------------------------------
    -- Initialize selected renderer
    ----------------------------------------------------------------

    local selected =
        compatible[1]


    local ok,
          initialized =
        pcall(
            selected.adapter.initialize,
            mod,
            loadLocalModule,
            Registry,
            CharacterRuntime
        )


    if not ok then

        mod.log:error(
            "%s renderer adapter initialization failed: %s",
            selected.name,
            tostring(initialized)
        )

        return false
    end


    if not initialized then

        mod.log:error(
            "%s renderer adapter could not be initialized",
            selected.name
        )

        return false
    end


    RendererManager.active = {
        name = selected.name,
        adapter = selected.adapter,
        info = selected.info
    }


    local info =
        selected.info


    if info
        and type(info) == "table"
        and type(info.targetMod) == "table" then

        local adapterVersion =
            info.adapterVersion
            or "unknown"

        local targetName =
            info.targetMod.name
            or selected.name

        local validatedVersion =
            info.targetMod.validatedVersion
            or "unknown"


        mod.log:info(
            "Porygonal Renderer Adapter: %s | Adapter v%s | Validated with Mod v%s",
            tostring(targetName),
            tostring(adapterVersion),
            tostring(validatedVersion)
        )

    else

        mod.log:info(
            "Porygonal Renderer Adapter initialized: %s",
            selected.name
        )
    end


    return true
end


return RendererManager
