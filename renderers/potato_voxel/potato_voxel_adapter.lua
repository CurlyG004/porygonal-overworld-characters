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

    local function observeBillboard(original)
        return
        function(
            def,
            frame
        )

            local mesh =
                original(
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
    end

    SpriteBillboards.mesh = observeBillboard(originalBillboardMesh)
    -- shadowQuad is an alias captured before OWC installs its mesh observer.
    if type(SpriteBillboards.shadowQuad) == "function" then
        SpriteBillboards.shadowQuad = observeBillboard(SpriteBillboards.shadowQuad)
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
        setmetatable({}, {__mode = "k"})


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
                        observedNpc = self,
                        sourceMap = map,

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

                    local motionKey = self.def and self.def.owner == "porygonal_ecosystem"
                        and self or capturedPose.entityKey
                    local previousMotion =
                        idleMotionHistory[
                            motionKey
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

                    local motion = {
                        x = capturedPose.px,
                        z = capturedPose.py,
                        sprite = sprite,
                        mapId = map and map.id,
                        viewMapId = ctx.state.map and ctx.state.map.id
                    }
                    -- Reuse per-entity presentation history, never an ID-only
                    -- association. A new body, appearance or map drops the yaw.
                    if previousMotion and previousMotion.sprite == sprite
                        and previousMotion.mapId == motion.mapId
                        and previousMotion.viewMapId == motion.viewMapId then
                        motion.flightYaw = previousMotion.flightYaw
                    end
                    local segment = self.directMovement
                    if self.def and self.def.owner == "porygonal_ecosystem"
                        and self.moving and type(segment) == "table" then
                        local dx, dz = segment.dx, segment.dy
                        if type(dx) == "number" and type(dz) == "number"
                            and dx == dx and dz == dz
                            and math.abs(dx) < math.huge and math.abs(dz) < math.huge
                            and math.max(math.abs(dx), math.abs(dz)) > 0.000001 then
                            -- NPC:update follows this segment, not a final
                            -- destination guess. Local +Z maps to (sin Y,cos Y).
                            motion.flightYaw = math.atan2(dx, dz)
                        end
                    end
                    capturedPose.flightYaw = motion.flightYaw
                    idleMotionHistory[
                        motionKey
                    ] = motion

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

        if facing == "NE" then return math.rad(135) end
        if facing == "NW" then return math.rad(-135) end
        if facing == "SE" then return math.rad(45) end
        if facing == "SW" then return math.rad(-45) end

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

        local ecosystemOwned = p.observedNpc and p.observedNpc.def
            and p.observedNpc.def.owner == "porygonal_ecosystem"
        local tcgOwned = p.observedNpc and p.observedNpc.def
            and p.observedNpc.def.tcgNpcId == 0x27
        local replacement, colors, diagonalAppearance
        local appearanceId = spriteId
        if p.isPlayer and p.observedNpc
            and type(p.observedNpc.hasAppearanceOverride) == "function" then
            local active, token = p.observedNpc:hasAppearanceOverride()
            if active and token and token.sprite == p.sprite then
                appearanceId = token.spriteId
                if type(Registry.lookupDiagonalAppearance) == "function" then
                    diagonalAppearance = Registry.lookupDiagonalAppearance(appearanceId)
                end
            end
        end
        local playerAppearance = CharacterRuntime.playerAppearanceReplacementFor(
            appearanceId, mirror, p.facing, p.isPlayer
        )
        if diagonalAppearance then
            replacement, colors = diagonalAppearance, p.colors
        elseif playerAppearance then
            replacement, colors = playerAppearance, p.colors
        elseif tcgOwned then
            replacement, colors = CharacterRuntime.tcgReplacementFor(
                p.observedNpc, p.phase, mirror, p.facing, p.sprite, p.colors
            )
        elseif ecosystemOwned then
            -- No body association survives a frame or bypasses the public API.
            replacement, colors = CharacterRuntime.ecosystemReplacementFor(
                p.observedNpc, p.phase, mirror, p.facing, p.sprite
            )
        else
            replacement = Registry.lookup(
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
            colors = p.colors
        end

        if not replacement then
            return nil
        end

        local y =
            (p.gh or 0)
            + (p.lift or 0)
            + (replacement.offsetY or 0)

        local yaw =
            facingToYaw(
                replacement.facing
                or p.facing
            )
        if replacement.flight_heading and p.flightYaw ~= nil then
            yaw = p.flightYaw
        end

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

        local loaded
        if ecosystemOwned or playerAppearance or diagonalAppearance or tcgOwned then
            -- Recover only asset preparation failures. Draw/structural errors
            -- still propagate through the adapter's normal render boundary.
            if p.ecosystemPrepared ~= nil then
                loaded = p.ecosystemPrepared or nil
            else
                local ok, result = pcall(loadAsset, replacement.asset, p.sprite, colors)
                loaded = ok and result or nil
                p.ecosystemPrepared = loaded or false
            end
        else
            loaded = loadAsset(replacement.asset, p.sprite, colors)
        end

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
            model = baseModel,
            cast_shadow = replacement.cast_shadow
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

        -- Only suppress a native caster after the replacement has prepared
        -- successfully; missing meshes/GPU resources retain the 2D fallback.
        if data.cast_shadow == false then return true end

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


    -- A billboard is cached by image/frame, not by NPC. Match the submitted
    -- card's foot center to the observed native pose instead of counting draws
    -- (sun refreshes, reflections and first-person passes can skip/repeat them).
    -- Ambiguous overlapping cards retain their native representation.
    local function poseForBillboard(info, ctx, model, shadow)
        if type(model) ~= "table" then return nil end
        local x = model[4] + 8 * model[1]
        local y = model[8] + 8 * model[5]
        local z = model[12] + 8 * model[9]
        local match
        for _, p in ipairs(ctx.poses) do
            if p.sprite.def.image == info.def.image then
                local expected = Mat4.translate(p.px + 8,
                    (p.gh or 0) + (p.lift or 0), p.py + 8)
                if shadow then expected = ShadowMap.snug(expected) end
                if math.abs(x - expected[4]) < 0.001
                    and math.abs(y - expected[8]) < 0.001
                    and math.abs(z - expected[12]) < 0.001 then
                    if match then return nil end
                    match = p
                end
            end
        end
        return match
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

            if info and ctx and type(model) == "table" then
                -- ShadowMap.snug returns a shared scratch matrix. Matching
                -- calls snug again; retain the original fallback transform.
                local copy = {}
                for i = 1, 16 do copy[i] = model[i] end
                model = copy
            end

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

                local p = poseForBillboard(info, ctx, model, true)
                if p then
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
    -- Match each submitted card to its observed native pose and position.
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

                local p = poseForBillboard(info, ctx, model, false)
                if p then
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
    -- Native presentations are not included in VoxelScene.posesOf().
    -- endScene is reached once per successfully opened view, after the
    -- world's depth-writing passes. Never use beginScene or another canvas.
    ----------------------------------------------------------------
    if type(Voxel3D.endScene) == "function"
        and type(Voxel3D.beginOverlay) == "function"
        and type(Voxel3D.project) == "function" then
        local PresentationEntries = require("src.render.PresentationEntries")
        local originalEndScene = Voxel3D._owcPresentationEndScene or Voxel3D.endScene
        Voxel3D._owcPresentationEndScene = originalEndScene

        local function presentationSource(state, entry)
            local actor = entry.actor
            local map = state.map
            if entry.neighbor then
                map = nil
                for _, neighbor in ipairs(state.neighbors or {}) do
                    if neighbor.map.id == actor.mapId
                        and neighbor.ox == entry.ox and neighbor.oy == entry.oy then
                        map = neighbor.map
                        break
                    end
                end
            end
            if not map or actor.mapId ~= map.id then return nil end
            for _, observed in ipairs(state.presentations and state.presentations[map.id] or {}) do
                if observed == actor then return map end
            end
        end

        local function groundFor(map, actor)
            return VoxelScene.groundAt(map, math.floor(actor.px / 16),
                math.floor(actor.py / 16)) or 0
        end

        local ballOrigins = setmetatable({}, {__mode = "k"})

        local function prepareBall(map, entry, replacement, colors, castingBall, facing)
            if entry.layer or not replacement then return nil end
            local actor = entry.actor
            local geometry = actor.sprite:getFrameGeometry(actor.frameIndex or 0)
            local loaded = loadAsset(replacement.asset, actor.sprite, colors)
            if not loaded then return nil end
            if replacement.shakeOffsetXByFrame then
                -- Use only the native logical frame, including SUCCESS's held
                -- final right pose. No projectile history or local clock.
                local dx = replacement.shakeOffsetXByFrame[actor.frameIndex]
                if dx == nil or #loaded.package.vertices == 0 then return nil end
                local angle = -dx / 3.097192
                local c, s = math.cos(angle), math.sin(angle)
                -- Support the rotated mesh on the source terrain. Its authored
                -- central pivot is retained; the small faceted support-height
                -- adjustment avoids sinking either tilted pose into the floor.
                local minY = math.huge
                for _, vertex in ipairs(loaded.package.vertices) do
                    minY = math.min(minY, s * vertex[1] + c * vertex[2])
                end
                -- Native px/py is the cell origin. Center the ground Ball's
                -- pivot on that cell, independently of the 2D sprite anchor.
                local model = Mat4.mul(Mat4.translate(
                    actor.px + entry.ox + 8 + dx,
                    groundFor(map, actor) + actor.visualElevation * 16 - minY,
                    actor.py + entry.oy + 8), {
                        c, -s, 0, 0,
                        s, c, 0, 0,
                        0, 0, 1, 0,
                        0, 0, 0, 1})
                return {mesh = loaded.gpu.mesh, texture = loaded.texture, model = model}
            end
            -- SpriteRenderer's world anchor is (px+8, py+12). Align the
            -- centered Maya mesh with the native frame CENTER, not its feet.
            -- No mesh-minY offset, trajectory or native mutation.
            local model = Mat4.translate(
                actor.px + entry.ox + 8 + geometry.width / 2 - geometry.anchorX,
                groundFor(map, actor) + actor.visualElevation * 16
                    + geometry.anchorY - geometry.height / 2,
                actor.py + entry.oy + 12)
            -- Held X/Z already include Ecosystem's directional hand offsets
            -- (left +4px, right -4px). Mirroring again would swap hands twice.
            -- Apply the registry's visual calibration in world axes; native
            -- position/elevation and 2D fallback remain untouched.
            if not castingBall then
                local offsetX = replacement.offsetXByFacing and replacement.offsetXByFacing[facing] or 0
                local offsetZ = replacement.offsetZByFacing and replacement.offsetZByFacing[facing] or 0
                model = Mat4.mul(model, Mat4.translate(offsetX, replacement.offsetY or 0, offsetZ))
                return {mesh = loaded.gpu.mesh, texture = loaded.texture, model = model}
            end
            local origin = ballOrigins[actor]
            if not origin then
                origin = {x = actor.px, z = actor.py}
                ballOrigins[actor] = origin
            end
            -- ThrowController's horizontal path is linear. Distance from the
            -- first observed position gives a sampling-independent roll, with
            -- no wall clock (so pause and stereo views cannot advance it).
            local dx, dz = actor.px - origin.x, actor.py - origin.z
            local distance = math.sqrt(dx * dx + dz * dz)
            if distance > 0 then
                -- Authored Maya radius, world pixels; visual rolling rate only.
                local angle = -distance / 3.097192
                local x, z = dz / distance, -dx / distance
                local c, s = math.cos(angle), math.sin(angle)
                local t = 1 - c
                -- Right-handed axis = up cross travel, reversed angular sign.
                -- T * R leaves its authored central origin fixed.
                model = Mat4.mul(model, {
                    c + x*x*t, -z*s, x*z*t, 0,
                    z*s, c, -x*s, 0,
                    z*x*t, x*s, c + z*z*t, 0,
                    0, 0, 0, 1})
            end
            return {mesh = loaded.gpu.mesh, texture = loaded.texture, model = model}
        end

        local function ballPresentations(ctx)
            if ctx.ballItems then return ctx.ballItems end
            local before, spatial, after = PresentationEntries.collect(ctx.state)
            local items, active, aims = {}, {}, {}
            for _, list in ipairs({before, spatial, after}) do
                for _, source in ipairs(list) do
                    local map = presentationSource(ctx.state, source)
                    if map then
                        -- PresentationEntries uses a shared pool. Keep our own
                        -- frame snapshot across shadow, eye and recovery draws.
                        local entry = {}
                        for k, v in pairs(source) do entry[k] = v end
                        local actor = entry.actor
                        local aim = aims[actor]
                        if not aim and entry.layer
                            and type(CharacterRuntime.captureAimReplacementFor) == "function" then
                            local recognized, replacement, colors = pcall(
                                CharacterRuntime.captureAimReplacementFor, map.id, actor.id, actor,
                                colorsForMap(ctx.paletteFor, map))
                            if recognized and replacement then
                                local prepared, data = pcall(function()
                                    local loaded = loadAsset(replacement.asset, actor.sprite, colors)
                                    if not loaded or #loaded.package.vertices == 0
                                        or #loaded.package.indices == 0 then return nil end
                                    -- Native XY is a 16px cell origin. The aim's
                                    -- centered X/Z pivot belongs at its center,
                                    -- not SpriteRenderer's py+12 draw anchor.
                                    return {mesh = loaded.gpu.mesh, texture = loaded.texture,
                                        model = Mat4.translate(actor.px + entry.ox + 8,
                                            groundFor(map, actor) + actor.visualElevation * 16
                                                + replacement.offsetY,
                                            actor.py + entry.oy + 8)}
                                end)
                                aim = {data = prepared and data or nil}
                                aims[actor] = aim
                            end
                        end
                        local selected, replacement, colors, castingBall = false
                        if type(CharacterRuntime.captureBallReplacementFor) == "function" then
                            selected, replacement, colors, castingBall = pcall(
                                CharacterRuntime.captureBallReplacementFor, map.id, actor.id, actor)
                        end
                        local prepared, data = pcall(prepareBall, map, entry,
                            selected and replacement or nil, colors, selected and castingBall,
                            ctx.state.player and ctx.state.player.facing)
                        items[#items + 1] = {map = map, entry = entry,
                            castingBall = selected and castingBall,
                            aim = aim,
                            data = prepared and data or nil}
                        if prepared and data then active[actor] = ballOrigins[actor] end
                    end
                end
            end
            ballOrigins = setmetatable(active, {__mode = "k"})
            ctx.ballItems = items
            return items
        end

        -- Both native aim layers share one replacement and one solar caster.
        local function presentationCaster(item, seen)
            if item.aim then
                if seen[item.aim] then return nil end
                seen[item.aim] = true
                return item.aim.data
            end
            return item.castingBall and item.data or nil
        end

        local function ballSignature(ctx, sig)
            local parts, seen = {}, {}
            for _, item in ipairs(ballPresentations(ctx)) do
                local data = presentationCaster(item, seen)
                if data then
                    parts[#parts + 1] = tostring(data.mesh)
                    parts[#parts + 1] = tostring(data.texture)
                    for i = 1, 16 do parts[#parts + 1] = tostring(data.model[i]) end
                end
            end
            -- No suffix when absent: retain PotatoVoxel's original cache keys.
            return #parts == 0 and sig or sig .. "|owc-balls:" .. table.concat(parts, ",")
        end

        -- Store dispatch on this PotatoVoxel module instance: repeated OWC
        -- initialization replaces callbacks, never stacks these two wrappers.
        -- A full mod reload creates fresh module tables and fresh dispatch.
        if type(ShadowMap.stale) == "function" and type(ShadowMap.finish) == "function" then
            local hooks = ShadowMap._owcCaptureBalls
            if not hooks then
                hooks = {stale = ShadowMap.stale, finish = ShadowMap.finish}
                ShadowMap._owcCaptureBalls = hooks
                ShadowMap.stale = function(sig, sprites)
                    return hooks.stale(sprites and hooks.signature(sig) or sig, sprites)
                end
                ShadowMap.finish = function(sig, sprites)
                    if sprites then
                        hooks.cast()
                        sig = hooks.signature(sig)
                    end
                    return hooks.finish(sig, sprites)
                end
            end
            hooks.signature = function(sig)
                return renderContext and ballSignature(renderContext, sig) or sig
            end
            hooks.cast = function()
                if not renderContext then return end
                -- VoxelScene reaches finish only inside its open actor pass.
                -- Its caller owns begin/finish/abort and the light rig.
                local casting, seen = false, {}
                for _, item in ipairs(ballPresentations(renderContext)) do
                    local data = presentationCaster(item, seen)
                    if data then
                        if not casting then ShadowMap.sprites(true); casting = true end
                        if not pcall(originalShadowDraw, data.mesh, data.texture, data.model) then
                            item.data = nil
                            if item.aim then item.aim.data = nil end
                        end
                    end
                end
                if casting then ShadowMap.sprites(false) end
            end
        end

        local function projectedDraw(map, entry, shadow)
            local actor = entry.actor
            local offsetX = shadow and (actor.groundShadowOffsetX or 0) or 0
            local offsetY = shadow and (actor.groundShadowOffsetY or 0) or 0
            local elevation = shadow and 0 or actor.visualElevation * 16
            local x, y, scale = Voxel3D.project(
                actor.px + entry.ox + 8 + offsetX,
                groundFor(map, actor) + elevation,
                actor.py + entry.oy + 12 + offsetY)
            if not x then return end
            love.graphics.push("all")
            local ok, err = pcall(function()
                love.graphics.translate(x, y)
                local pixels = (Voxel3D.cell or 1) * (scale or 1)
                love.graphics.scale(pixels, pixels)
                local camX = actor.px + 8 + offsetX
                local camY = actor.py + 12 + offsetY - elevation
                if shadow then actor:drawGroundShadow(camX, camY)
                elseif entry.layer then actor:drawLayer(entry.layer, camX, camY)
                else actor:draw(camX, camY) end
            end)
            love.graphics.pop()
            if not ok then error(err) end
        end

        Voxel3D.endScene = function(...)
            local ctx = renderContext
            if ctx and ctx.state.presentations then
                local items = ballPresentations(ctx)
                local fallback, shadows, seen, drawnAims = {}, {}, {}, {}
                love.graphics.push("all")
                local ok, err = pcall(function()
                    Voxel3D.depth("test")
                    Voxel3D.seams(false)
                    Voxel3D.glass(false)
                    for _, item in ipairs(items) do
                        local map, entry = item.map, item.entry
                        local actor = entry.actor
                        if actor.groundShadow and not item.castingBall
                            and not seen[actor] then
                            shadows[#shadows + 1] = {map, entry}
                            seen[actor] = true
                        end
                        -- Preparation failures leave the native draw available.
                        local data = item.aim and item.aim.data or item.data
                        local drawn = item.aim and drawnAims[actor] or false
                        if data and not drawn then
                            beginBackCull()
                            drawn = pcall(originalVoxelDraw, data.mesh, data.texture,
                                data.model, 0, data.model)
                            endBackCull()
                            if not drawn then
                                -- The sun may already contain this mesh.
                                -- Discard this view and retry the existing
                                -- scene with this replacement excluded.
                                item.data = nil
                                if item.aim then item.aim.data = nil end
                                ctx.ballRetry = true
                            end
                        end
                        if item.aim then drawnAims[actor] = drawn end
                        if not drawn then
                            fallback[#fallback + 1] = {map, entry}
                        end
                    end
                    -- Same projected 2D policy as WorldFeature's native FX.
                    -- Only successfully submitted meshes omit their native sprite.
                    -- Identified projectile/shake Balls never restore the old 2D shadow.
                    if #fallback > 0 or #shadows > 0 then
                        if not Voxel3D.beginOverlay() then
                            error("Could not restore native presentation overlay")
                        end
                        for _, item in ipairs(shadows) do projectedDraw(item[1], item[2], true) end
                        for _, item in ipairs(fallback) do
                            projectedDraw(item[1], item[2], false)
                        end
                    end
                end)
                Voxel3D.seams(true)
                Voxel3D.glass(true)
                love.graphics.pop()
                if not ok then
                    -- Structural native/scene failures must not become a
                    -- successful canvas with silently missing presentations.
                    pcall(originalEndScene)
                    error(err)
                end
            end
            return originalEndScene(...)
        end
    end

    ----------------------------------------------------------------
    -- Frame boundary / pose observation.
    ----------------------------------------------------------------

    local function visibleEcosystemActors(list, ghosts)
        local filtered
        for i, entry in ipairs(list or {}) do
            local actor = ghosts and entry.npc or entry
            local hidden = actor and actor.def
                and actor.def.owner == "porygonal_ecosystem"
                and actor.visible == false
            if hidden and not filtered then
                filtered = {}
                for j = 1, i - 1 do filtered[j] = list[j] end
            elseif not hidden and filtered then
                filtered[#filtered + 1] = entry
            end
        end
        return filtered or list
    end

    local function visibleScene(state)
        if not state then return state end
        local entities = visibleEcosystemActors(state.entities, false)
        local ghosts = visibleEcosystemActors(state.ghosts, true)
        if entities == state.entities and ghosts == state.ghosts then return state end
        -- PotatoVoxel 1.9.6 collects NPC:pose() even when visible is false.
        -- Supply a render-only view before collection, so every pass (including
        -- fallback cards and shadows) respects the exact native actor's flag.
        -- Never edit the gameplay lists, NPC visibility, or capture lifecycle.
        return setmetatable({entities = entities, ghosts = ghosts}, {__index = state})
    end

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
            state = visibleScene(state)
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

            -- Retire history as soon as a native body leaves the scene, even
            -- if another owner still retains its table for later reuse.
            for key in pairs(idleMotionHistory) do
                if type(key) == "table" and not alreadyWrapped[key] then
                    idleMotionHistory[key] = nil
                end
            end

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

            -- A late GPU draw error must not publish a canvas containing a
            -- ball's shadow alongside its 2D fallback. Re-enter only the
            -- existing scene renderer, with failed replacements removed from
            -- both its actor signature and visible draws. Each retry removes
            -- at least one replacement; ordinary frames never take this path.
            while ok and ctx.ballRetry do
                ctx.ballRetry = false
                ctx.poses = {}
                ctx.flyVisibleDrawn, ctx.flyShadowDrawn = false, false
                ok, resultA, resultB, resultC = pcall(originalVoxelRender,
                    state, w, h, vw, vh, paletteFor, eyes)
            end


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
