local mod = ...

----------------------------------------------------------------
-- Active game version
----------------------------------------------------------------

local GameVersion =
    require(
        "src.core.GameVersion"
    )


----------------------------------------------------------------
-- Load a Lua file belonging to this mod.
----------------------------------------------------------------

local function loadLocalModule(
    path,
    ...
)

    local src, err =
        mod:read(path)

    if not src then
        mod.log:error(
            "Could not read local module %s: %s",
            path,
            tostring(err)
        )
        return nil
    end


    local loader =
        loadstring or load


    local chunk, loadErr =
        loader(
            src,
            "@" .. mod.path .. "/" .. path
        )


    if not chunk then
        mod.log:error(
            "Could not load local module %s: %s",
            path,
            tostring(loadErr)
        )
        return nil
    end


    local ok, result =
        pcall(
            chunk,
            ...
        )


    if not ok then
        mod.log:error(
            "Error executing local module %s: %s",
            path,
            tostring(result)
        )
        return nil
    end


    return result
end


----------------------------------------------------------------
-- Configure Porygonal version identity
----------------------------------------------------------------

local Version =
    loadLocalModule(
        "game_version_profile.lua"
    )

if not Version then
    return
end


local gameVersion =
    GameVersion.get()


local versionGroup =
    nil


if gameVersion == "red"
    or gameVersion == "blue" then

    versionGroup =
        Version.RED_BLUE

elseif gameVersion == "yellow" then

    versionGroup =
        Version.YELLOW

else

    mod.log:error(
        "Unsupported Porygonal game version: %s",
        tostring(gameVersion)
    )

    return
end


Version.configure(
    versionGroup
)


----------------------------------------------------------------
-- Load persistent attributes tuning
----------------------------------------------------------------

local Tuning =
    loadLocalModule(
        "character_tuning.lua"
    )

if not Tuning then
    return
end


----------------------------------------------------------------
-- Load Character Core
--
-- Registry receives Tuning as an injected dependency.
-- This keeps all mod-local file loading centralized in main.lua.
----------------------------------------------------------------

local Registry =
    loadLocalModule(
        "character_registry.lua",
        Tuning,
        Version
    )

if not Registry then
    return
end


----------------------------------------------------------------
-- Initialize renderer-independent character runtime
----------------------------------------------------------------

local CharacterRuntimeModule =
    loadLocalModule(
        "character_runtime.lua"
    )

if not CharacterRuntimeModule
    or type(CharacterRuntimeModule.create)
        ~= "function" then

    mod.log:error(
        "Porygonal character_runtime.lua could not be loaded"
    )

    return
end


local CharacterRuntime =
    CharacterRuntimeModule.create(
        mod,
        loadLocalModule,
        Version.group()
    )

if not CharacterRuntime then

    mod.log:error(
        "Porygonal character runtime could not be initialized"
    )

    return
end


----------------------------------------------------------------
-- Load renderer manager
----------------------------------------------------------------

local RendererManager =
    loadLocalModule(
        "renderers/renderer_manager.lua"
    )


if not RendererManager then
    return
end


----------------------------------------------------------------
-- Initialize compatible renderer
----------------------------------------------------------------

local ok =
    RendererManager.initialize(
        mod,
        loadLocalModule,
        Registry,
        CharacterRuntime
    )


if ok then

    ----------------------------------------------------------------
    -- Install Porygonal OPTION menu
    ----------------------------------------------------------------

    local PorygonalOptions =
        loadLocalModule(
            "ui/porygonal_options.lua"
        )

    if PorygonalOptions
        and type(PorygonalOptions.install)
            == "function" then

        local uiOk,
              uiResult =
            pcall(
                PorygonalOptions.install,
                mod,
                RendererManager
            )

        if not uiOk
            or not uiResult then

            mod.log:warn(
                "Porygonal options UI could not be initialized: %s",
                tostring(uiResult)
            )
        end
    end


    mod.log:info(
        "Porygonal_Overworld_Characters loaded"
    )

else

    mod.log:warn(
        "No compatible 3D renderer was initialized"
    )

end

