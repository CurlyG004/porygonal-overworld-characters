----------------------------------------------------------------
-- Porygonal - PotatoVoxelAdapter renderer adapter
--
-- FIRST VISIBLE 3D COMPATIBILITY PASS
--
-- Proven PotatoVoxelAdapter seam:
--   SpriteBillboards.mesh -> Voxel3D.draw
--
-- This version:
--   * detects PotatoVoxelAdapter through its exported module API
--   * observes PotatoVoxelAdapter's own pose() calls (never calls pose twice)
--   * associates visible billboard submissions with captured poses
--   * resolves Porygonal identity through CharacterRuntime + Registry
--   * loads/caches Porygonal meshes and palette textures lazily
--   * replaces ordinary visible character billboards with true 3D meshes
--   * replaces PotatoVoxelAdapter character shadow cards with Porygonal 3D casters
--   * forwards the player's Fishing state to Registry lookup
--   * suppresses only the native fishing-rod image during ctx.drawFx
--   * runs Porygonal's authored 3D Fly choreography across map transition
--   * renders bird + mounted rider Fly composites with 3D shadow casters
--   * suppresses only the native 2D Fly bird while Porygonal Fly is active
--   * preserves the original billboard whenever Porygonal cannot replace it
--
-- Also supported:
--   * authored Pokémon Center seated FIGURE replacement
--
-- Deliberately deferred:
--   * first-person/free-camera refinements
----------------------------------------------------------------

local PotatoVoxelAdapter = {}

PotatoVoxelAdapter.info = {
    adapterVersion = "1.0.0",

    targetMod = {
        id = "potato_voxel",
        name = "PotatoVoxel",
        validatedVersion = "1.9.6",
    },
}


----------------------------------------------------------------
-- Detection: side-effect free
----------------------------------------------------------------

function PotatoVoxelAdapter.detect(
    mod
)

    local potato =
        mod.find(
            "potato_voxel"
        )

    if not potato
        or not potato.exports
        or not potato.exports.lib then

        return false
    end

    local V =
        potato.exports.lib

    if type(V.require) ~= "function" then
        return false
    end

    local okScene,
          VoxelScene =
        pcall(
            V.require,
            "VoxelScene"
        )

    local okVoxel3D,
          Voxel3D =
        pcall(
            V.require,
            "Voxel3D"
        )

    local okBillboards,
          SpriteBillboards =
        pcall(
            V.require,
            "SpriteBillboards"
        )

    local okMat4,
          Mat4 =
        pcall(
            V.require,
            "Mat4"
        )

    if not (
        okScene
        and type(VoxelScene) == "table"
        and type(VoxelScene.render) == "function"
    ) then
        return false
    end

    if not (
        okVoxel3D
        and type(Voxel3D) == "table"
        and type(Voxel3D.draw) == "function"
        and type(Voxel3D.newMesh) == "function"
    ) then
        return false
    end

    if not (
        okBillboards
        and type(SpriteBillboards) == "table"
        and type(SpriteBillboards.mesh) == "function"
    ) then
        return false
    end

    if not (
        okMat4
        and type(Mat4) == "table"
        and type(Mat4.translate) == "function"
        and type(Mat4.rotateY) == "function"
        and type(Mat4.mul) == "function"
    ) then
        return false
    end

    return true
end


----------------------------------------------------------------
-- Initialization
----------------------------------------------------------------

function PotatoVoxelAdapter.initialize(
    mod,
    loadLocalModule,
    Registry,
    CharacterRuntime
)

    if not PotatoVoxelAdapter.detect(mod) then

        mod.log:error(
            "PotatoVoxelAdapter compatibility API unavailable"
        )

        return false
    end

    if not CharacterRuntime
        or type(CharacterRuntime.getSpritePose) ~= "function"
        or type(CharacterRuntime.loadAsset) ~= "function"
        or type(CharacterRuntime.textureDataFor) ~= "function" then

        mod.log:error(
            "Porygonal CharacterRuntime API unavailable for PotatoVoxelAdapter"
        )

        return false
    end


    ----------------------------------------------------------------
    -- PotatoVoxelAdapter modules
    ----------------------------------------------------------------

    local potato =
        mod.find(
            "potato_voxel"
        )

    local V =
        potato.exports.lib

    local VoxelScene =
        V.require(
            "VoxelScene"
        )

    local Voxel3D =
        V.require(
            "Voxel3D"
        )

    local SpriteBillboards =
        V.require(
            "SpriteBillboards"
        )

    local ShadowMap =
        V.require(
            "ShadowMap"
        )

    local Mat4 =
        V.require(
            "Mat4"
        )

    local WorldFeature =
        V.require(
            "WorldFeature"
        )

    local ChunkMesher =
        V.require(
            "ChunkMesher"
        )

    local TileShape =
        V.require(
            "TileShape"
        )

    local MeshCache =
        V.require(
            "MeshCache"
        )

    local PaletteFX =
        require(
            "src.render.PaletteFX"
        )


    ----------------------------------------------------------------
    -- PotatoVoxelAdapter 1.9.6 authored POKECENTER figure repair.
    --
    -- Exact 1.9.6 source has a malformed POKECENTER figure profile:
    --   6 tiles, but only 4 `under` entries.
    -- TileShape.authoredMasks() deliberately rejects that record because
    -- #under ~= #tiles.  Dramaless carries the corrected six-entry mapping.
    --
    -- PREBUILD workers run in their own Lua VM, so a main-thread monkeypatch
    -- cannot repair the package they already wrote.  For POKECENTER maps we
    -- therefore reject the PREBUILD terrain/aux reads and let Potato rebuild
    -- through the live VM, where the corrected semantic figure is supplied.
    ----------------------------------------------------------------

    local function isPokecenterMap(
        map
    )

        if not map then
            return false
        end

        local tilesetId =
            map.tileset
            and map.tileset.id
            or nil

        return tilesetId ~= nil
            and string.upper(
                tostring(tilesetId)
            ) == "POKECENTER"
    end


    local originalTileShapeFigures =
        TileShape.figures

    local correctedPokecenterFigures =
        nil

    local function correctedPokecenterFigureProfile()

        if correctedPokecenterFigures then
            return correctedPokecenterFigures
        end

        ------------------------------------------------------------
        -- Same authored mask as PotatoVoxelAdapter 1.9.6, with the corrected
        -- six-tile `under` mapping used by the working Dramaless profile.
        ------------------------------------------------------------

        local rows = {
            "..........XXXXX.........",
            "........XXXXXXXX........",
            ".......XXXXXXXXXX.......",
            "......XXXXXXXXXXXX......",
            "......XXXXXXXXXXXX......",
            "......XXXXXXXXXXX.......",
            "......XXXXXXXXXXX.......",
            "......XXXXXXXXXXX.......",
            "........XXXXXXXXX.......",
            "........XXXXXXXX........",
            "........XXXXXXXX........",
            "........XXXXXXXX........",
            "........XXXXXXXXX.......",
            ".........XXXXXXXXX......",
            "...........XXXXXX.......",
            "..............XX........",
        }

        local w =
            3

        local h =
            2

        local mask =
            {}

        local n =
            0

        for ly = 0, h * 8 - 1 do

            local row =
                rows[
                    ly + 1
                ]

            for lx = 0, w * 8 - 1 do

                if row:sub(
                    lx + 1,
                    lx + 1
                ) ~= "." then

                    mask[
                        ly * (w * 8) + lx
                    ] =
                        true

                    n =
                        n + 1
                end
            end
        end

        correctedPokecenterFigures = {
            {
                w = 3,
                h = 2,
                n = n,
                mask = mask,

                tiles = {
                    36, 37, 57,
                    52, 53, 60,
                },

                under = {
                    52, 39, 1,
                    52, 39, 26,
                },
            },
        }

        return correctedPokecenterFigures
    end


    if type(originalTileShapeFigures) == "function" then

        TileShape.figures =
            function(
                tilesetId
            )

                if string.upper(
                    tostring(
                        tilesetId
                        or ""
                    )
                ) == "POKECENTER" then

                    return correctedPokecenterFigureProfile()
                end

                return originalTileShapeFigures(
                    tilesetId
                )
            end
    end


    local originalLoadAuxPacked =
        MeshCache.loadAuxPacked

    local originalLoadTerrainPacked =
        MeshCache.loadTerrainPacked

    if type(originalLoadAuxPacked) == "function" then

        MeshCache.loadAuxPacked =
            function(
                map,
                ...
            )

                if isPokecenterMap(
                    map
                ) then

                    return nil
                end

                return originalLoadAuxPacked(
                    map,
                    ...
                )
            end
    end


    if type(originalLoadTerrainPacked) == "function" then

        MeshCache.loadTerrainPacked =
            function(
                map,
                ...
            )

                if isPokecenterMap(
                    map
                ) then

                    return nil
                end

                return originalLoadTerrainPacked(
                    map,
                    ...
                )
            end
    end


    ----------------------------------------------------------------
    -- Original renderer surfaces
    ----------------------------------------------------------------

    local originalVoxelRender =
        VoxelScene.render

    local originalVoxelDraw =
        Voxel3D.draw

    local metalRenderer = nil

    local function rendersOnMetal()

        if metalRenderer ~= nil then
            return metalRenderer
        end

        metalRenderer =
            false

        local ok,
              info =

            pcall(
                love.graphics.getRendererInfo
            )

        if ok then

            local name =
                type(info) == "table"
                and info.name
                or info

            if type(name) == "string"
                and name:lower():find(
                    "metal",
                    1,
                    true
                ) then

                metalRenderer =
                    true
            end
        end

        return metalRenderer
    end


    local function beginBackCull()

        if rendersOnMetal() then
            love.graphics.setFrontFaceWinding(
                "cw"
            )
        end

        love.graphics.setMeshCullMode(
            "back"
        )
    end


    local function endBackCull()

        love.graphics.setMeshCullMode(
            "none"
        )

        if rendersOnMetal() then
            love.graphics.setFrontFaceWinding(
                "ccw"
            )
        end
    end

    local originalBillboardMesh =
        SpriteBillboards.mesh

    local originalShadowDraw =
        ShadowMap.draw

    local originalWorldRender =
        WorldFeature.render


    ----------------------------------------------------------------
    -- Porygonal Fly state
    --
    -- PotatoVoxelAdapter removes the normal player pose while Gen1Recomp's native
    -- Fly animation is active. Porygonal therefore owns a separate visual
    -- state machine that survives the map transition.
    --
    -- The action timing / trajectory is authored by character_tuning.lua
    -- and exposed through Registry.fly_animation.  Gen1Recomp only tells
    -- us WHEN Fly starts and when the destination map/player position has
    -- changed; it does not dictate Porygonal's 3D choreography.
    ----------------------------------------------------------------

    local flyState = {
        mode = "normal",

        startedAt = 0,
        landingAt = 0,

        startMap = nil,

        startPx = 0,
        startPy = 0,
        startGround = 0,

        targetPx = 0,
        targetPy = 0,
        targetGround = 0,

        playerSprite = nil,
        colors = nil,

        birdImage = nil,
        captureBird = false
    }


    local function flyAnimationConfig()

        return Registry.fly_animation
            or {}
    end


    local FLY_POSE_STEP =
        0.05


    local function flyNowSeconds()

        if love.timer
            and love.timer.getTime then

            local ok,
                  t =
                pcall(
                    love.timer.getTime
                )

            if ok
                and type(t) == "number" then

                return t
            end
        end

        return 0
    end


    local function flyObjectLike(
        value
    )

        local t =
            type(value)

        return t == "userdata"
            or t == "table"
    end


    local function flySafeDimensions(
        drawable
    )

        if not flyObjectLike(
            drawable
        ) then

            return nil,
                   nil
        end

        local okMethod,
              method =
            pcall(
                function()

                    return drawable.getDimensions
                end
            )

        if not okMethod
            or type(method) ~= "function" then

            return nil,
                   nil
        end

        local ok,
              w,
              h =
            pcall(
                method,
                drawable
            )

        if ok then

            return w,
                   h
        end

        return nil,
               nil
    end


    local function flySafeViewport(
        quad
    )

        if not flyObjectLike(
            quad
        ) then

            return nil,
                   nil,
                   nil,
                   nil
        end

        local okMethod,
              method =
            pcall(
                function()

                    return quad.getViewport
                end
            )

        if not okMethod
            or type(method) ~= "function" then

            return nil,
                   nil,
                   nil,
                   nil
        end

        local ok,
              x,
              y,
              w,
              h =
            pcall(
                method,
                quad
            )

        if ok then

            return x,
                   y,
                   w,
                   h
        end

        return nil,
               nil,
               nil,
               nil
    end


    ----------------------------------------------------------------
    -- Fishing rod + native Fly FX suppression
    --
    -- Gen1Recomp's ctx.drawFx closes directly over fxRod, so replacing
    -- ctx.fx.rod does NOT suppress the rod.  Instead, keep the native
    -- drawFx intact and scope a love.graphics.draw filter to that call.
    --
    -- The filter rejects only the exact cached fishing-rod Image object
    -- (state.rodImg), and only while the player is fishing.  Every other
    -- field FX continues through the original ctx.drawFx unchanged.
    ----------------------------------------------------------------

    WorldFeature.render =
        function(
            ctx,
            ...
        )
            local originalDrawFx =
                ctx
                and ctx.drawFx
                or nil

            local state =
                ctx
                and ctx.state
                or nil

            if type(originalDrawFx) == "function" then

                ctx.drawFx =
                    function(
                        ...
                    )
                        local fishing =
                            state
                            and state.fishing
                            and true
                            or false

                        local flyActive =
                            flyState.mode ~= "normal"
                            or (
                                state
                                and (
                                    state.flyAnim
                                    or state.flyArrive
                                )
                            )

                        if not fishing
                            and not flyActive then

                            return originalDrawFx(
                                ...
                            )
                        end

                        local originalLoveDraw =
                            love.graphics.draw

                        love.graphics.draw =
                            function(
                                drawable,
                                ...
                            )
                                ------------------------------------------------
                                -- Fishing: exact cached rod Image identity.
                                ------------------------------------------------

                                local rodImage =
                                    fishing
                                    and state
                                    and state.rodImg
                                    or nil

                                if rodImage
                                    and drawable == rodImage then

                                    return
                                end


                                ------------------------------------------------
                                -- Fly: identify the native bird sheet once,
                                -- then suppress only that exact Image's Fly
                                -- frame draws. This interception exists only
                                -- inside the official ctx.drawFx call.
                                ------------------------------------------------

                                if flyActive then

                                    local imageW,
                                          imageH =
                                        flySafeDimensions(
                                            drawable
                                        )

                                    if imageW == 16
                                        and imageH == 96 then

                                        local args =
                                            {...}

                                        local qx,
                                              qy,
                                              qw,
                                              qh =
                                            flySafeViewport(
                                                args[1]
                                            )

                                        local isFlyingFrame =
                                            qx == 0
                                            and qw == 16
                                            and qh == 16
                                            and (
                                                qy == 32
                                                or qy == 80
                                            )

                                        if flyState.captureBird
                                            and not flyState.birdImage
                                            and isFlyingFrame then

                                            flyState.birdImage =
                                                drawable

                                            flyState.captureBird =
                                                false
                                        end

                                        local isNativeBird =
                                            flyState.birdImage
                                            and drawable
                                                == flyState.birdImage
                                            and qx == 0
                                            and qw == 16
                                            and qh == 16
                                            and (
                                                qy == 0
                                                or qy == 32
                                                or qy == 80
                                            )

                                        if isNativeBird then

                                            return
                                        end
                                    end
                                end

                                return originalLoveDraw(
                                    drawable,
                                    ...
                                )
                            end

                        local ok,
                              resultA,
                              resultB,
                              resultC =
                            pcall(
                                originalDrawFx,
                                ...
                            )

                        love.graphics.draw =
                            originalLoveDraw

                        if not ok then

                            error(
                                resultA
                            )
                        end

                        return resultA,
                               resultB,
                               resultC
                    end
            end

            local ok,
                  resultA,
                  resultB,
                  resultC =
                pcall(
                    originalWorldRender,
                    ctx,
                    ...
                )

            if ctx
                and originalDrawFx then

                ctx.drawFx =
                    originalDrawFx
            end

            if not ok then

                error(
                    resultA
                )
            end

            return resultA,
                   resultB,
                   resultC
        end


    ----------------------------------------------------------------
    -- GPU asset cache
    --
    -- CharacterRuntime owns renderer-independent geometry/ImageData.
    -- PotatoVoxelAdapter GPU meshes and Love Images stay in this adapter.
    ----------------------------------------------------------------

    local gpuAssetCache =
        setmetatable(
            {},
            {
                __mode = "k"
            }
        )


    local function prepareGpuAsset(
        assetPackage
    )

        if not assetPackage then
            return nil
        end

        local cached =
            gpuAssetCache[
                assetPackage
            ]

        if cached then
            return cached
        end

        local mesh =
            Voxel3D.newMesh(
                assetPackage.vertices,
                assetPackage.indices
            )

        if not mesh then
            return nil
        end

        local mirroredMesh =
            Voxel3D.newMesh(
                assetPackage.mirroredVertices,
                assetPackage.mirroredIndices
            )

        if not mirroredMesh then
            return nil
        end

        local gpuAsset = {
            mesh = mesh,
            mirroredMesh = mirroredMesh,
            textures = {}
        }

        gpuAssetCache[
            assetPackage
        ] =
            gpuAsset

        return gpuAsset
    end


    local function textureFor(
        assetPackage,
        gpuAsset,
        sprite,
        colors
    )

        local imageData,
              textureKey =

            CharacterRuntime.textureDataFor(
                assetPackage,
                sprite,
                colors
            )

        if not imageData then
            return nil
        end

        textureKey =
            textureKey
            or "raw"

        local cached =
            gpuAsset.textures[
                textureKey
            ]

        if cached then
            return cached
        end

        local image =
            love.graphics.newImage(
                imageData
            )

        image:setFilter(
            "nearest",
            "nearest"
        )

        gpuAsset.textures[
            textureKey
        ] =
            image

        return image
    end


    local function loadAsset(
        definition,
        sprite,
        colors
    )

        local assetPackage =
            CharacterRuntime.loadAsset(
                definition
            )

        if not assetPackage then
            return nil
        end

        local gpuAsset =
            prepareGpuAsset(
                assetPackage
            )

        if not gpuAsset then
            return nil
        end

        local texture =
            textureFor(
                assetPackage,
                gpuAsset,
                sprite,
                colors
            )

        if not texture then
            return nil
        end

        return {
            package = assetPackage,
            gpu = gpuAsset,
            texture = texture
        }
    end


    ----------------------------------------------------------------
    -- Billboard identity
    ----------------------------------------------------------------

    local billboardInfo =
        setmetatable(
            {},
            {
                __mode = "k"
            }
        )

    SpriteBillboards.mesh =
        function(
            def,
            frame
        )

            local mesh =
                originalBillboardMesh(
                    def,
                    frame
                )

            if mesh then

                billboardInfo[
                    mesh
                ] = {
                    def = def,
                    frame = frame
                }
            end

            return mesh
        end


    ----------------------------------------------------------------
    -- Frame context
    ----------------------------------------------------------------

    local renderContext =
        nil

    local lastPlayerSprite =
        nil

    local lastPlayerColors =
        nil

    ----------------------------------------------------------------
    -- Per-entity motion history for procedural idle.
    --
    -- PotatoVoxelAdapter entity movement flags are not treated as authoritative
    -- here. We compare one captured world position to the next, matching
    -- the Dramaless adapter's validated idle behavior.
    ----------------------------------------------------------------

    local idleMotionHistory =
        {}


    ----------------------------------------------------------------
    -- Palette supplied to an entity on the active map.
    ----------------------------------------------------------------

    local function colorsForMap(
        paletteFor,
        map
    )

        if PaletteFX.usesGbcPack() then
            return nil
        end

        if VoxelScene._modeColors then

            return VoxelScene._modeColors(
                paletteFor,
                map
            )
        end

        if paletteFor then
            return paletteFor(map)
        end

        return nil
    end


    local function colorsForAuthoredFigure(
        paletteFor,
        map,
        state
    )

        if PaletteFX.usesGbcPack()
            and state
            and state.player
            and state.player.sprite
            and state.player.sprite.def then

            local colors =
                PaletteFX.spriteObp(
                    state.player.sprite.def,
                    state.player.sprite.seed
                )

            if colors then
                return colors
            end
        end

        if VoxelScene._modeColors then
            local colors =
                VoxelScene._modeColors(
                    paletteFor,
                    map
                )
            if colors then
                return colors
            end
        end

        if paletteFor then
            return paletteFor(map)
        end

        return nil
    end


    ----------------------------------------------------------------
    -- Observe one entity's EXISTING pose() call.
    --
    -- PotatoVoxelAdapter owns the pose call. We only observe its return values.
    ----------------------------------------------------------------

    local function wrapEntityPose(
        entity,
        map,
        offsetX,
        offsetY,
        isPlayer,
        colors,
        restorers,
        alreadyWrapped
    )

        if type(entity) ~= "table"
            or type(entity.pose) ~= "function"
            or alreadyWrapped[entity] then

            return
        end

        alreadyWrapped[entity] =
            true

        local originalPose =
            entity.pose

        local hadOwnPose =
            rawget(
                entity,
                "pose"
            ) ~= nil

        local ownPose =
            rawget(
                entity,
                "pose"
            )

        local wrappedPose

        wrappedPose =
            function(
                self,
                ...
            )

                local sprite,
                      vx,
                      vy,
                      facing,
                      phase,
                      flip =

                    originalPose(
                        self,
                        ...
                    )

                local ctx =
                    renderContext

                if ctx
                    and sprite
                    and sprite.def then

                    local basePy =
                        self.py
                        or vy
                        or 0

                    local ground =
                        0

                    if map
                        and VoxelScene.groundAt
                        and self.cellX ~= nil
                        and self.cellY ~= nil then

                        ground =
                            VoxelScene.groundAt(
                                map,
                                self.cellX,
                                self.cellY
                            )
                            or 0
                    end

                    local visualY =
                        vy
                        or basePy

                    local capturedPose = {
                        sprite = sprite,

                        px =
                            (vx or self.px or 0)
                            + (offsetX or 0),

                        py =
                            basePy
                            + (offsetY or 0),

                        facing = facing,
                        phase = phase,
                        flip = flip,

                        gh = ground,

                        lift =
                            basePy
                            - visualY,

                        colors = colors,

                        isPlayer =
                            isPlayer
                            and true
                            or false,

                        fishing =
                            isPlayer
                            and self.fishing
                            and true
                            or false,

                        entityKey =
                            self.id
                            or (
                                self.def
                                and self.def.name
                            )
                            or tostring(self),

                        isMoving =
                            false
                    }

                    local previousMotion =
                        idleMotionHistory[
                            capturedPose.entityKey
                        ]

                    if previousMotion then

                        local dx =
                            capturedPose.px
                            - previousMotion.x

                        local dz =
                            capturedPose.py
                            - previousMotion.z

                        capturedPose.isMoving =
                            (
                                dx * dx
                                + dz * dz
                            )
                            > 0.0001
                    end

                    idleMotionHistory[
                        capturedPose.entityKey
                    ] = {
                        x =
                            capturedPose.px,

                        z =
                            capturedPose.py
                    }

                    ctx.poses[
                        #ctx.poses + 1
                    ] =
                        capturedPose

                    if isPlayer then

                        lastPlayerSprite =
                            sprite

                        lastPlayerColors =
                            colors
                    end
                end

                return sprite,
                       vx,
                       vy,
                       facing,
                       phase,
                       flip
            end

        entity.pose =
            wrappedPose

        restorers[
            #restorers + 1
        ] =
            function()

                if hadOwnPose then

                    entity.pose =
                        ownPose

                else

                    entity.pose =
                        nil
                end
            end
    end


    ----------------------------------------------------------------
    -- World-space facing -> model yaw
    ----------------------------------------------------------------

    local function facingToYaw(
        facing
    )

        if facing == "left" then
            return math.rad(-90)
        end

        if facing == "up" then
            return math.rad(180)
        end

        if facing == "right" then
            return math.rad(90)
        end

        return 0
    end


    ----------------------------------------------------------------
    -- Procedural idle animation
    --
    -- Same renderer-independent policy already validated by the
    -- Dramaless Shape adapter:
    --   * stationary ordinary characters breathe subtly
    --   * moving characters do not
    --   * Surf/Fly composites do not
    --   * Registry may disable idle per character
    --   * nearby NPCs receive stable per-entity phase offsets
    ----------------------------------------------------------------

    local function idleTimeOffsetForKey(
        key
    )

        local text =
            tostring(
                key
                or ""
            )

        local number =
            tonumber(
                string.match(
                    text,
                    "(%d+)%D*$"
                )
            )

        local unit

        if number then

            unit =
                (
                    number
                    * 0.61803398875
                )
                % 1

        else

            local hash =
                17

            for i = 1, #text do

                hash =
                    (
                        hash * 131
                        + string.byte(
                            text,
                            i
                        )
                    )
                    % 104729
            end

            unit =
                hash
                / 104729
        end

        return
            1.0
            + unit
    end


    local function applyProceduralIdleScale(
        model,
        p,
        replacement
    )

        local cfg =
            Registry.idle_animation
            or {}

        if cfg.enabled == false then
            return model
        end

        if replacement.idle_animation == false
            or p.isMoving
            or replacement.type == "composite"
            or replacement.type == "fly_composite" then

            return model
        end

        local speed =
            cfg.speed
            or 1.15

        local amountY =
            cfg.scale_y
            or 0.012

        local amountXZ =
            cfg.scale_xz
            or 0.003

        local now =
            0

        if love.timer
            and love.timer.getTime then

            local ok,
                  t =
                pcall(
                    love.timer.getTime
                )

            if ok
                and type(t) == "number" then

                now =
                    t
            end
        end

        local timeOffset =
            idleTimeOffsetForKey(
                p.entityKey
            )

        local breath =
            (
                math.sin(
                    (
                        now
                        + timeOffset
                    )
                    * speed
                    * math.pi
                    * 2
                )
                + 1
            )
            * 0.5

        local sy =
            1
            + breath
            * amountY

        local sxz =
            1
            - breath
            * amountXZ

        return Mat4.mul(
            model,
            Mat4.scale(
                sxz,
                sy,
                sxz
            )
        )
    end


    ----------------------------------------------------------------
    -- Authored Pokémon Center seated FIGURE.
    --
    -- PotatoVoxelAdapter owns extraction of the figure from the furniture.
    -- Porygonal only replaces the resulting authored figure mesh.
    -- Resolution is lazy because Potato's auxiliary meshes may become
    -- available during its own render/prefetch lifecycle.
    ----------------------------------------------------------------

    local function pokecenterFigureInfoForMesh(
        mesh,
        ctx
    )

        if not mesh
            or not ctx
            or not ctx.state
            or not Registry.lookupPokecenterSeatedFigure
            or type(ChunkMesher.figures) ~= "function" then
            return nil
        end

        local state = ctx.state

        local function inspectMap(map)

            if not map then
                return nil
            end

            local mapId = map.id or ""

            if not isPokecenterMap(
                map
            ) then
                return nil
            end

            local figures =
                ChunkMesher.figures(map)

            if type(figures) ~= "table"
                or #figures ~= 1 then
                return nil
            end

            local figure = figures[1]

            if not figure
                or figure.mesh ~= mesh then
                return nil
            end

            local replacement =
                Registry.lookupPokecenterSeatedFigure()

            if not replacement
                or not replacement.asset then
                return nil
            end

            return {
                figure = figure,
                replacement = replacement,
                colors =
                    colorsForAuthoredFigure(
                        ctx.paletteFor,
                        map,
                        state
                    ),
                idleKey =
                    tostring(mapId)
                    .. ":pokecenter_seated"
            }
        end

        local current =
            inspectMap(state.map)

        if current then
            return current
        end

        for _, nb in ipairs(state.neighbors or {}) do
            local found =
                inspectMap(nb.map)
            if found then
                return found
            end
        end

        return nil
    end


    local function replacementDataForFigure(info)

        if not info then
            return nil
        end

        local loaded =
            loadAsset(
                info.replacement.asset,
                nil,
                info.colors
            )

        if not loaded then
            return nil
        end

        local figure = info.figure

        local model =
            Mat4.mul(
                Mat4.translate(
                    (figure.wx or 0)
                        + ((figure.w or 16) / 2),
                    figure.y or 0,
                    figure.wz or 0
                ),
                Mat4.rotateY(
                    info.replacement.yaw or 0
                )
            )

        model =
            applyProceduralIdleScale(
                model,
                {
                    entityKey = info.idleKey,
                    isMoving = false
                },
                info.replacement
            )

        return {
            mesh = loaded.gpu.mesh,
            texture = loaded.texture,
            model = model
        }
    end


    ----------------------------------------------------------------
    -- Resolve one captured pose into a Porygonal draw package.
    ----------------------------------------------------------------

    local function replacementDataForPose(
        p
    )

        if not p
            or not p.sprite
            or not p.sprite.def then

            return nil
        end

        local spriteId,
              frame,
              mirror =

            CharacterRuntime.getSpritePose(
                p.sprite,
                p.facing,
                p.phase,
                p.flip
            )

        local replacement =
            Registry.lookup(
                spriteId,
                frame,
                mirror,
                p.facing,
                {
                    isPlayer =
                        p.isPlayer,

                    fishing =
                        p.fishing,

                    spriteDef =
                        p.sprite.def,

                    spriteImage =
                        p.sprite.def.image
                }
            )

        if not replacement then
            return nil
        end

        local y =
            (p.gh or 0)
            + (p.lift or 0)

        local yaw =
            facingToYaw(
                replacement.facing
                or p.facing
            )

        local baseModel =
            Mat4.mul(
                Mat4.translate(
                    p.px + 8,
                    y,
                    p.py + 8
                ),
                Mat4.rotateY(
                    yaw
                )
            )

        baseModel =
            applyProceduralIdleScale(
                baseModel,
                p,
                replacement
            )


        ------------------------------------------------------------
        -- Composite replacement (Surf and future composites).
        ------------------------------------------------------------

        if replacement.type == "composite"
            and replacement.parts then

            local floating =
                replacement.floating_offset
                or {}

            local rider =
                replacement.rider_offset
                or {}

            local mountModel =
                Mat4.mul(
                    baseModel,
                    Mat4.translate(
                        floating.x or 0,
                        floating.y or 0,
                        floating.z or 0
                    )
                )

            local riderModel =
                Mat4.mul(
                    baseModel,
                    Mat4.translate(
                        (floating.x or 0)
                            + (rider.x or 0),

                        (floating.y or 0)
                            + (rider.y or 0),

                        (floating.z or 0)
                            + (rider.z or 0)
                    )
                )

            local draws =
                {}

            for _, part in ipairs(
                replacement.parts
            ) do

                local loaded =
                    loadAsset(
                        part.asset,
                        p.sprite,
                        p.colors
                    )

                if not loaded then
                    return nil
                end

                local mesh =
                    part.mirror
                    and loaded.gpu.mirroredMesh
                    or loaded.gpu.mesh

                draws[
                    #draws + 1
                ] = {
                    mesh = mesh,
                    texture = loaded.texture,

                    model =
                        part.role == "rider"
                        and riderModel
                        or mountModel
                }
            end

            return {
                composite = true,
                draws = draws
            }
        end


        ------------------------------------------------------------
        -- Ordinary single character asset.
        ------------------------------------------------------------

        if not replacement.asset then
            return nil
        end

        local loaded =
            loadAsset(
                replacement.asset,
                p.sprite,
                p.colors
            )

        if not loaded then
            return nil
        end

        local mesh =
            replacement.mirror
            and loaded.gpu.mirroredMesh
            or loaded.gpu.mesh

        return {
            mesh = mesh,
            texture = loaded.texture,
            model = baseModel
        }
    end


    ----------------------------------------------------------------
    -- Draw one Porygonal replacement.
    ----------------------------------------------------------------

    local function drawPorygonal(
        p
    )

        local data =
            replacementDataForPose(
                p
            )

        if not data then
            return false
        end

        beginBackCull()

        if data.composite
            and data.draws then

            for _, draw in ipairs(
                data.draws
            ) do

                originalVoxelDraw(
                    draw.mesh,
                    draw.texture,
                    draw.model,
                    0,
                    draw.model
                )
            end

        else

            originalVoxelDraw(
                data.mesh,
                data.texture,
                data.model,
                0,
                data.model
            )
        end

        endBackCull()

        return true
    end


    ----------------------------------------------------------------
    -- Fly trajectory.
    --
    -- This reproduces the existing authored Porygonal Fly choreography from
    -- character_tuning.lua.  Distances are world-space values.
    ----------------------------------------------------------------

    local function flyTransform()

        if flyState.mode == "normal" then

            return nil
        end

        local cfg =
            flyAnimationConfig()

        local takeoff =
            cfg.takeoff
            or 0.50

        local departureDuration =
            math.max(
                cfg.departure_duration
                or 0.55,
                0.001
            )

        local departureDistance =
            cfg.departure_distance
            or 64

        local departureHeight =
            cfg.departure_height
            or 28

        local offscreen =
            math.max(
                cfg.offscreen
                or 0,
                0
            )

        local returnDuration =
            math.max(
                cfg.return_duration
                or 0.55,
                0.001
            )

        local returnDistance =
            cfg.return_distance
            or departureDistance

        local returnHeight =
            cfg.return_height
            or 45

        local landingDuration =
            math.max(
                cfg.landing_duration
                or 0.80,
                0.001
            )

        local landingDistance =
            cfg.landing_distance
            or departureDistance

        local landingHeight =
            cfg.landing_height
            or departureHeight

        local settle =
            math.max(
                cfg.settle
                or 0.18,
                0
            )

        local now =
            flyNowSeconds()


        if flyState.mode == "departure" then

            local t =
                now
                - flyState.startedAt

            --------------------------------------------------------
            -- Mounted pause at the player's original position.
            --------------------------------------------------------

            if t < takeoff then

                return 0,
                       0,
                       0,
                       math.rad(90),
                       true
            end

            t =
                t - takeoff


            --------------------------------------------------------
            -- First pass: player anchor -> +X / +Y.
            --------------------------------------------------------

            if t < departureDuration then

                local p =
                    math.max(
                        0,
                        math.min(
                            1,
                            t / departureDuration
                        )
                    )

                return
                    departureDistance * p,
                    departureHeight * p,
                    0,
                    math.rad(90),
                    true
            end

            t =
                t - departureDuration


            --------------------------------------------------------
            -- Hold at the end of the first pass.
            --------------------------------------------------------

            if t < offscreen then

                return departureDistance,
                       departureHeight,
                       0,
                       math.rad(90),
                       true
            end

            t =
                t - offscreen


            --------------------------------------------------------
            -- Second pass: +X -> -X, rising toward return_height.
            --------------------------------------------------------

            if t < returnDuration then

                local p =
                    math.max(
                        0,
                        math.min(
                            1,
                            t / returnDuration
                        )
                    )

                return
                    returnDistance
                    - (
                        returnDistance
                        * 2
                        * p
                    ),

                    departureHeight
                    + (
                        (
                            returnHeight
                            - departureHeight
                        )
                        * p
                    ),

                    0,
                    math.rad(-90),
                    true
            end

            return 0,
                   0,
                   0,
                   0,
                   false
        end


        if flyState.mode == "landing" then

            local t =
                now
                - flyState.landingAt

            --------------------------------------------------------
            -- Destination: +X/+Y -> exact player anchor.
            --------------------------------------------------------

            if t < landingDuration then

                local p =
                    math.max(
                        0,
                        math.min(
                            1,
                            t / landingDuration
                        )
                    )

                local ease =
                    1
                    - (
                        (1 - p)
                        * (1 - p)
                    )

                return
                    landingDistance
                    * (
                        1 - ease
                    ),

                    landingHeight
                    * (
                        1 - ease
                    ),

                    0,
                    math.rad(-90),
                    true
            end

            if t
                < (
                    landingDuration
                    + settle
                ) then

                return 0,
                       0,
                       0,
                       math.rad(-90),
                       true
            end

            return 0,
                   0,
                   0,
                   0,
                   false
        end

        return 0,
               0,
               0,
               0,
               false
    end


    local function flyPoseName()

        local baseTime =
            flyState.mode == "landing"
            and flyState.landingAt
            or flyState.startedAt

        local elapsed =
            math.max(
                0,
                flyNowSeconds()
                - (baseTime or 0)
            )

        local frame =
            math.floor(
                elapsed
                / FLY_POSE_STEP
            )

        if frame % 2 == 0 then

            return "idle"
        end

        return "walk"
    end


    local function flyReplacementData()

        local pose =
            flyPoseName()

        local definition =
            Registry.lookupFly
            and Registry.lookupFly(
                pose
            )
            or nil

        if not definition
            or not definition.parts then

            return nil
        end

        local ox,
              oy,
              oz,
              yaw,
              visible =
            flyTransform()

        if not visible then

            return nil
        end

        local basePx =
            flyState.mode == "landing"
            and flyState.targetPx
            or flyState.startPx

        local basePy =
            flyState.mode == "landing"
            and flyState.targetPy
            or flyState.startPy

        local ground =
            flyState.mode == "landing"
            and flyState.targetGround
            or flyState.startGround

        local floating =
            definition.flying_offset
            or {}

        local rider =
            definition.rider_offset
            or {}

        local baseModel =
            Mat4.mul(
                Mat4.translate(
                    basePx
                        + 8
                        + (ox or 0),

                    ground
                        + (oy or 0),

                    basePy
                        + 8
                        + (oz or 0)
                ),
                Mat4.rotateY(
                    yaw or 0
                )
            )

        local mountModel =
            Mat4.mul(
                baseModel,
                Mat4.translate(
                    floating.x or 0,
                    floating.y or 0,
                    floating.z or 0
                )
            )

        local riderModel =
            Mat4.mul(
                baseModel,
                Mat4.translate(
                    (floating.x or 0)
                        + (rider.x or 0),

                    (floating.y or 0)
                        + (rider.y or 0),

                    (floating.z or 0)
                        + (rider.z or 0)
                )
            )

        local draws =
            {}

        for _, part in ipairs(
            definition.parts
        ) do

            local loaded =
                loadAsset(
                    part.asset,
                    flyState.playerSprite,
                    flyState.colors
                )

            if not loaded then

                return nil
            end

            draws[
                #draws + 1
            ] = {
                mesh = loaded.gpu.mesh,
                texture = loaded.texture,

                model =
                    part.role == "rider"
                    and riderModel
                    or mountModel
            }
        end

        return draws
    end


    local function drawFlyVisible()

        local draws =
            flyReplacementData()

        if not draws then

            return false
        end

        beginBackCull()

        for _, draw in ipairs(
            draws
        ) do

            originalVoxelDraw(
                draw.mesh,
                draw.texture,
                draw.model,
                0,
                draw.model
            )
        end

        endBackCull()

        return true
    end


    local function drawFlyShadow()

        local draws =
            flyReplacementData()

        if not draws then

            return false
        end

        for _, draw in ipairs(
            draws
        ) do

            originalShadowDraw(
                draw.mesh,
                draw.texture,
                draw.model
            )
        end

        return true
    end


    ----------------------------------------------------------------
    -- Porygonal 3D shadow caster.
    --
    -- PotatoVoxelAdapter's character shadow pass uses the same billboard mesh
    -- identity captured above. Replace only that caster with the same
    -- Porygonal mesh/model used by the visible pass.
    ----------------------------------------------------------------

    local function drawPorygonalShadow(
        p
    )

        local data =
            replacementDataForPose(
                p
            )

        if not data then
            return false
        end

        if data.composite
            and data.draws then

            for _, draw in ipairs(
                data.draws
            ) do

                originalShadowDraw(
                    draw.mesh,
                    draw.texture,
                    draw.model
                )
            end

        else

            originalShadowDraw(
                data.mesh,
                data.texture,
                data.model
            )
        end

        return true
    end


    ShadowMap.draw =
        function(
            mesh,
            texture,
            model
        )

            local info =
                billboardInfo[
                    mesh
                ]

            local ctx =
                renderContext

            if ctx
                and ctx.flyActive
                and not ctx.flyShadowDrawn then

                ctx.flyShadowDrawn =
                    true

                drawFlyShadow()
            end

            if ctx then
                local figureInfo =
                    pokecenterFigureInfoForMesh(
                        mesh,
                        ctx
                    )

                if figureInfo then
                    local data =
                        replacementDataForFigure(
                            figureInfo
                        )

                    if data then
                        originalShadowDraw(
                            data.mesh,
                            data.texture,
                            data.model
                        )
                        return
                    end
                end
            end

            if info
                and ctx then

                local count =
                    #ctx.poses

                if count > 0 then

                    ctx.shadowDrawIndex =
                        (ctx.shadowDrawIndex or 0)
                        + 1

                    local poseIndex =
                        (
                            (
                                ctx.shadowDrawIndex
                                - 1
                            )
                            % count
                        )
                        + 1

                    local p =
                        ctx.poses[
                            poseIndex
                        ]

                    if p
                        and p.sprite
                        and p.sprite.def
                        and p.sprite.def == info.def then

                        if ctx.flyActive
                            and p.isPlayer then

                            return
                        end

                        if drawPorygonalShadow(
                            p
                        ) then

                            return
                        end
                    end
                end
            end

            return originalShadowDraw(
                mesh,
                texture,
                model
            )
        end


    ----------------------------------------------------------------
    -- Visible character interception.
    --
    -- The diagnostic proved that ordinary PotatoVoxelAdapter character cards:
    --   * are meshes produced by SpriteBillboards.mesh
    --   * reach Voxel3D.draw with a non-nil sunModel
    --
    -- PotatoVoxelAdapter calls these visible characters in pose order. We use
    -- the captured pose sequence and verify sprite.def before replacing.
    ----------------------------------------------------------------

    Voxel3D.draw =
        function(
            mesh,
            texture,
            model,
            pull,
            sunModel,
            receiveSun
        )

            local info =
                billboardInfo[
                    mesh
                ]

            local ctx =
                renderContext

            if ctx
                and ctx.flyActive
                and not ctx.flyVisibleDrawn then

                ctx.flyVisibleDrawn =
                    true

                drawFlyVisible()
            end

            if ctx
                and sunModel ~= nil then

                local figureInfo =
                    pokecenterFigureInfoForMesh(
                        mesh,
                        ctx
                    )

                if figureInfo then
                    local data =
                        replacementDataForFigure(
                            figureInfo
                        )

                    if data then
                        beginBackCull()

                        originalVoxelDraw(
                            data.mesh,
                            data.texture,
                            data.model,
                            0,
                            data.model,
                            receiveSun
                        )

                        endBackCull()

                        return
                    end
                end
            end

            if info
                and ctx
                and sunModel ~= nil then

                local count =
                    #ctx.poses

                if count > 0 then

                    ctx.characterDrawIndex =
                        (ctx.characterDrawIndex or 0)
                        + 1

                    local poseIndex =
                        (
                            (
                                ctx.characterDrawIndex
                                - 1
                            )
                            % count
                        )
                        + 1

                    local p =
                        ctx.poses[
                            poseIndex
                        ]

                    if p
                        and p.sprite
                        and p.sprite.def
                        and p.sprite.def == info.def then

                        if ctx.flyActive
                            and p.isPlayer then

                            return
                        end

                        if drawPorygonal(
                            p
                        ) then

                            return
                        end
                    end
                end
            end

            return originalVoxelDraw(
                mesh,
                texture,
                model,
                pull,
                sunModel,
                receiveSun
            )
        end


    ----------------------------------------------------------------
    -- Frame boundary / pose observation.
    ----------------------------------------------------------------

    VoxelScene.render =
        function(
            state,
            w,
            h,
            vw,
            vh,
            paletteFor,
            eyes
        )

            ------------------------------------------------------------
            -- Porygonal Fly state machine.
            ------------------------------------------------------------

            local now =
                flyNowSeconds()

            local player =
                state
                and state.player
                or nil

            local flyNativeActive =
                state
                and state.flyAnim
                ~= nil

            local playerPx =
                player
                and player.px
                or 0

            local playerPy =
                player
                and player.py
                or 0

            local playerGround =
                0

            if player
                and state
                and state.map
                and VoxelScene.groundAt
                and player.cellX ~= nil
                and player.cellY ~= nil then

                playerGround =
                    VoxelScene.groundAt(
                        state.map,
                        player.cellX,
                        player.cellY
                    )
                    or 0
            end


            ------------------------------------------------------------
            -- Departure begins when the native Fly action begins.
            ------------------------------------------------------------

            if flyState.mode == "normal"
                and flyNativeActive
                and player then

                flyState.mode =
                    "departure"

                flyState.startedAt =
                    now

                flyState.startMap =
                    state.map

                flyState.startPx =
                    playerPx

                flyState.startPy =
                    playerPy

                flyState.startGround =
                    playerGround

                flyState.playerSprite =
                    player.sprite
                    or lastPlayerSprite

                flyState.colors =
                    colorsForMap(
                        paletteFor,
                        state.map
                    )
                    or lastPlayerColors

                flyState.birdImage =
                    nil

                flyState.captureBird =
                    true
            end


            ------------------------------------------------------------
            -- Destination detection.
            --
            -- Prefer map identity change. The position fallback handles
            -- a destination represented by the same map object.
            ------------------------------------------------------------

            if flyState.mode == "departure"
                and player then

                local mapChanged =
                    state.map
                    ~= flyState.startMap

                local dx =
                    playerPx
                    - flyState.startPx

                local dz =
                    playerPy
                    - flyState.startPy

                local movedFar =
                    (
                        dx * dx
                        + dz * dz
                    )
                    > (
                        16 * 16
                    )

                if mapChanged
                    or (
                        not flyNativeActive
                        and movedFar
                    ) then

                    flyState.mode =
                        "landing"

                    flyState.landingAt =
                        now

                    flyState.targetPx =
                        playerPx

                    flyState.targetPy =
                        playerPy

                    flyState.targetGround =
                        playerGround

                    flyState.playerSprite =
                        player.sprite
                        or lastPlayerSprite
                        or flyState.playerSprite

                    flyState.colors =
                        colorsForMap(
                            paletteFor,
                            state.map
                        )
                        or lastPlayerColors
                        or flyState.colors
                end
            end


            ------------------------------------------------------------
            -- After authored landing + settle, hand the player back to
            -- PotatoVoxelAdapter's ordinary character path.
            ------------------------------------------------------------

            if flyState.mode == "landing" then

                local flyCfg =
                    flyAnimationConfig()

                local landingDuration =
                    flyCfg.landing_duration
                    or 0.80

                local settle =
                    flyCfg.settle
                    or 0.18

                if (
                    now
                    - flyState.landingAt
                ) >= (
                    landingDuration
                    + settle
                ) then

                    flyState.mode =
                        "normal"

                    flyState.captureBird =
                        false

                    flyState.birdImage =
                        nil
                end
            end


            local previousContext =
                renderContext

            local ctx = {
                poses = {},
                characterDrawIndex = 0,
                shadowDrawIndex = 0,

                state = state,
                paletteFor = paletteFor,

                flyActive =
                    flyState.mode
                    ~= "normal",

                flyVisibleDrawn =
                    false,

                flyShadowDrawn =
                    false
            }

            renderContext =
                ctx

            local restorers =
                {}

            local alreadyWrapped =
                setmetatable(
                    {},
                    {
                        __mode = "k"
                    }
                )


            ------------------------------------------------------------
            -- Ghosts first, matching PotatoVoxelAdapter's pose collection order.
            ------------------------------------------------------------

            for _, ghost in ipairs(
                state.ghosts
                or {}
            ) do

                local npc =
                    ghost.npc

                local map =
                    ghost.map
                    or state.map

                wrapEntityPose(
                    npc,
                    map,
                    ghost.ox or 0,
                    ghost.oy or 0,
                    false,
                    colorsForMap(
                        paletteFor,
                        map
                    ),
                    restorers,
                    alreadyWrapped
                )
            end


            ------------------------------------------------------------
            -- Current-map entities.
            ------------------------------------------------------------

            local mapColors =
                colorsForMap(
                    paletteFor,
                    state.map
                )

            for _, entity in ipairs(
                state.entities
                or {}
            ) do

                wrapEntityPose(
                    entity,
                    state.map,
                    0,
                    0,
                    entity == state.player,
                    mapColors,
                    restorers,
                    alreadyWrapped
                )
            end


            ------------------------------------------------------------
            -- Run PotatoVoxelAdapter normally.
            ------------------------------------------------------------

            local ok,
                  resultA,
                  resultB,
                  resultC =

                pcall(
                    originalVoxelRender,
                    state,
                    w,
                    h,
                    vw,
                    vh,
                    paletteFor,
                    eyes
                )


            ------------------------------------------------------------
            -- Always restore observed pose methods.
            ------------------------------------------------------------

            for i =
                #restorers,
                1,
                -1 do

                pcall(
                    restorers[i]
                )
            end

            renderContext =
                previousContext

            if not ok then
                error(
                    resultA
                )
            end

            return resultA,
                   resultB,
                   resultC
        end


    mod.log:info(
        "Porygonal PotatoVoxelAdapter visible 3D + special-state compatibility initialized"
    )

    return true
end


return PotatoVoxelAdapter
