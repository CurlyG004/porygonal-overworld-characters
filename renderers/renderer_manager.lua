----------------------------------------------------------------
-- Porygonal - Renderer manager
--
-- Owns renderer selection only.
--
-- Contract expected from each renderer adapter:
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
-- Renderer adapter candidates
----------------------------------------------------------------

local CANDIDATES = {

    {
        name = "PotatoVoxel",
        path = "renderers/potato_voxel/potato_voxel_renderer.lua"
    },

    {
        name = "Dramatic Shape",
        path = "renderers/dramatic_shape/dramatic_shape_renderer.lua"
    },

    {
        name = "Dramaless Shape",
        path = "renderers/dramaless_shape/dramaless_shape_renderer.lua"
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
                    adapter = adapter
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
            "%s renderer initialization failed: %s",
            selected.name,
            tostring(initialized)
        )

        return false
    end


    if not initialized then

        mod.log:error(
            "%s renderer could not be initialized",
            selected.name
        )

        return false
    end


    mod.log:info(
        "Porygonal renderer initialized: %s",
        selected.name
    )


    return true
end


return RendererManager
