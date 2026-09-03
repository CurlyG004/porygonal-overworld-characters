local DramaticShapeAdapter = {}

DramaticShapeAdapter.info = {
    adapterVersion = "1.0.0",

    targetMod = {
        id = "DRAMATIC_SHAPE",
        name = "Dramatic Shape Voxel Mod",
        validatedVersion = "1.8.2",
    },
}


----------------------------------------------------------------
-- Detect Dramatic Shape
--
-- Detection only.
-- No hooks or runtime modifications are installed here.
----------------------------------------------------------------

function DramaticShapeAdapter.detect(
    mod
)

    local ds =
        mod.find(
            "DRAMATIC_SHAPE"
        )


    if not ds then
        return false
    end


    if not (
        ds.exports
        and ds.exports.lib
    ) then

        return false
    end


    return true
end


function DramaticShapeAdapter.initialize(
    mod,
    loadLocalModule,
    Registry,
    CharacterRuntime
)

    ----------------------------------------------------------------
    -- Find Dramatic Shape
    ----------------------------------------------------------------

    local ds =
        mod.find("DRAMATIC_SHAPE")


    if not ds then

        mod.log:info(
            "Dramatic Shape not installed"
        )

        return false
    end


    if not (
        ds.exports
        and ds.exports.lib
    ) then

        mod.log:error(
            "Dramatic Shape API unavailable"
        )

        return false
    end


    ----------------------------------------------------------------
    -- Dramatic Shape modules
    ----------------------------------------------------------------

    local V =
        ds.exports.lib


    local VoxelScene =
        V.require("VoxelScene")


    local Voxel3D =
        V.require("Voxel3D")


    local Mat4 =
        V.require("Mat4")


    local FirstPerson =
        V.require("FirstPerson")


    local SpriteBillboards =
        V.require("SpriteBillboards")


    local ShadowMap =
        V.require("ShadowMap")


    local ChunkMesher =
        V.require("ChunkMesher")


    ----------------------------------------------------------------
    -- Gen1Recomp modules
    ----------------------------------------------------------------


    local PaletteFX =
        require(
            "src.render.PaletteFX"
        )


    ----------------------------------------------------------------
    -- Porygonal character runtime
    --
    -- The runtime interprets character assets into renderer-agnostic
    -- packages (geometry + ImageData + Gen1 pose semantics).
    --
    -- This renderer alone converts those packages into Dramatic Shape
    -- GPU resources.
    ----------------------------------------------------------------

    
    if not CharacterRuntime
        or type(CharacterRuntime.loadAsset) ~= "function"
        or type(CharacterRuntime.textureDataFor) ~= "function"
        or type(CharacterRuntime.getSpritePose) ~= "function" then

        mod.log:error(
            "Porygonal character runtime unavailable"
        )

        return false
    end


    ----------------------------------------------------------------
    -- Dramatic Shape GPU resource cache
    --
    -- Renderer-agnostic data stays in character_runtime.lua.
    -- Voxel3D meshes and Love2D Images stay here.
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


        if gpuAssetCache[assetPackage] then

            return gpuAssetCache[
                assetPackage
            ]
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

            mesh =
                mesh,

            mirroredMesh =
                mirroredMesh,

            textures =
                {}
        }


        gpuAssetCache[assetPackage] =
            gpuAsset


        return gpuAsset
    end


    ----------------------------------------------------------------
    -- Dramatic Shape / Love2D texture realization
    ----------------------------------------------------------------

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


        if gpuAsset.textures[
            textureKey
        ] then

            return gpuAsset.textures[
                textureKey
            ]
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


    ----------------------------------------------------------------
    -- Load and realize one asset for Dramatic Shape
    ----------------------------------------------------------------

    local function loadAsset(
        definition
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


        return {

            package =
                assetPackage,

            mesh =
                gpuAsset.mesh,

            mirroredMesh =
                gpuAsset.mirroredMesh,

            gpu =
                gpuAsset
        }
    end


    ----------------------------------------------------------------
    -- Renderer-independent Gen1 pose bridge
    ----------------------------------------------------------------

    local function getSpritePose(
        sprite,
        facing,
        phase,
        flip
    )

        return CharacterRuntime.getSpritePose(
            sprite,
            facing,
            phase,
            flip
        )
    end


    ----------------------------------------------------------------
    -- Renderer texture bridge
    ----------------------------------------------------------------

    local function textureForLoadedAsset(
        asset,
        sprite,
        colors
    )

        return textureFor(
            asset.package,
            asset.gpu,
            sprite,
            colors
        )
    end


    ----------------------------------------------------------------
    -- Find private upvalue
    --
    -- Historical helper used only by COMPAT 0.1.83.
    ----------------------------------------------------------------

    local function findUpvalue(
        fn,
        wantedName,
        wantedValue
    )

        if type(fn) ~= "function" then
            return nil
        end


        if not debug
            or not debug.getupvalue then

            return nil
        end


        for i = 1, 96 do

            local name,
                  value =

                debug.getupvalue(
                    fn,
                    i
                )


            if not name then
                break
            end


            if name == wantedName
                or (
                    wantedValue ~= nil
                    and value == wantedValue
                ) then

                return i,
                       value
            end

        end


        return nil
    end


    ----------------------------------------------------------------
    -- COMPATIBILITY PROFILES
    ----------------------------------------------------------------

    ----------------------------------------------------------------
    -- COMPAT: RECOMP 0.1.99
    --
    -- Integration introduced for Recomp 0.1.99.
    -- Uses observable/public Dramatic Shape module surfaces and 3D
    -- shadow casters. No private-function upvalue hooks are used.
    ----------------------------------------------------------------

    local function installCompat0199()

        local originalVoxelRender =
            VoxelScene.render


        local originalVoxelDraw =
            Voxel3D.draw


        local originalBillboardMesh =
            SpriteBillboards.mesh


        local originalShadowQuad =
            SpriteBillboards.shadowQuad


        local originalShadowDraw =
            ShadowMap.draw


        ------------------------------------------------------------
        -- PORYGONAL FLY STATE
        --
        -- Visual offsets / trajectory timings are read through Registry
        -- from character_tuning.lua and are not owned by this renderer.
        --
        -- Fly is not a normal Dramatic Shape character pose. Recomp
        -- draws a dedicated 2D bird FX while Dramatic Shape removes
        -- the player from its normal pose list.
        --
        -- Porygonal keeps its own small state machine across the map
        -- transition and renders:
        --
        --   bird_walk + <player>_mount_walk
        --
        -- The original 2D bird image is identified once during the
        -- departure and then suppressed by exact Image identity.
        ------------------------------------------------------------

        local originalLoveDraw =
            love.graphics.draw


        local flyState = {

            mode =
                "normal",

            startedAt =
                0,

            landingAt =
                0,

            startMap =
                nil,

            startPx =
                0,

            startPy =
                0,

            startGround =
                0,

            targetPx =
                0,

            targetPy =
                0,

            targetGround =
                0,

            playerSprite =
                nil,

            colors =
                nil,

            birdImage =
                nil,

            captureBird =
                false
        }


        ------------------------------------------------------------
        -- Fly trajectory is authored in Registry.fly_animation.
        -- The renderer only interprets those world-space parameters.
        ------------------------------------------------------------

        local function flyAnimationConfig()

            return Registry.fly_animation
                or {}
        end


        ------------------------------------------------------------
        -- Native Fly alternates its two visible bird frames roughly
        -- every 0.05 s. Use the same cadence to switch the authored
        -- idle/walk meshes for both mount and rider.
        ------------------------------------------------------------

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
                    and type(t)
                        == "number" then

                    return t
                end
            end


            return 0
        end


        local function flyObjectLike(value)

            local t =
                type(value)


            return t == "userdata"
                or t == "table"
        end


        local function flySafeDimensions(drawable)

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
                or type(method)
                    ~= "function" then

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


        local function flySafeViewport(quad)

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
                or type(method)
                    ~= "function" then

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


        if type(originalLoveDraw)
            == "function" then

            love.graphics.draw =
                function(
                    drawable,
                    ...
                )


    



     


                    if flyState.mode
                        ~= "normal" then

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

                                ------------------------------------------------
                                -- Skip only the exact native Fly bird Image.
                                ------------------------------------------------

                                return
                            end
                        end
                    end


                    return originalLoveDraw(
                        drawable,
                        ...
                    )
                end
        end


        if type(originalVoxelRender) ~= "function"
            or type(originalVoxelDraw) ~= "function"
            or type(originalBillboardMesh) ~= "function"
            or type(originalShadowQuad) ~= "function"
            or type(originalShadowDraw) ~= "function" then

            mod.log:error(
                "Dramatic Shape adapter: Recomp 0.1.99 compatibility surfaces unavailable"
            )

            return false
        end


        ----------------------------------------------------------------
        -- Billboard identity
        --
        -- SpriteBillboards caches one GPU mesh for:
        --
        --     def.image .. "#" .. frame
        --
        -- Remember which meshes are character billboards and which sprite
        -- definition/frame produced them.
        ----------------------------------------------------------------

        local billboardInfo =
            setmetatable(
                {},
                {
                    __mode = "k"
                }
            )


        ----------------------------------------------------------------
        -- Current VoxelScene.render context
        ----------------------------------------------------------------

        local renderContext =
            nil


        ----------------------------------------------------------------
        -- Per-entity motion history for procedural idle.
        --
        -- Do not rely on entity.progress / entity.moving here: some entity
        -- implementations keep those flags/values after a completed step.
        -- We compare actual world position from one captured pose to the next.
        ----------------------------------------------------------------

        local idleMotionHistory =
            {}


        ----------------------------------------------------------------
        -- World yaw
        ----------------------------------------------------------------

        local function facingToYaw(
            facing,
            isPlayer
        )

            ------------------------------------------------------------
            -- Player + Dramatic Shape free camera:
            -- use the continuous body orientation.
            ------------------------------------------------------------

            if isPlayer
                and FirstPerson
                and FirstPerson.engaged
                and FirstPerson.engaged()
                and FirstPerson.bodyYaw ~= nil then

                return FirstPerson.bodyYaw
            end


            ------------------------------------------------------------
            -- Normal world-space facing.
            ------------------------------------------------------------

            if facing == "down" then
                return 0
            end


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
        -- Palette supplied to a character standing on `map`.
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


        ----------------------------------------------------------------
        -- Palette for authored character FIGURES.
        --
        -- Normal GBC sprites use PaletteFX.spriteObp(realSpriteDef, seed),
        -- but an authored FIGURE has no real Sprite object. A fabricated
        -- minimal sprite def is insufficient for the OBP resolver and falls
        -- back to the raw grey Porygonal texture.
        --
        -- For these map-authored figures, use the map's EFFECTIVE palette
        -- directly. This keeps GRAY/CLASSIC/INVERTED/GBC modes consistent
        -- with the active scene instead of leaving the model uncolored.
        ----------------------------------------------------------------

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

                local playerColors =
                    PaletteFX.spriteObp(
                        state.player.sprite.def,
                        state.player.sprite.seed
                    )


                if playerColors then
                    return playerColors
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
        -- Temporarily observe one entity's existing pose() call.
        --
        -- IMPORTANT: we never call pose() ourselves.
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
                or type(entity.pose) ~= "function" then

                return
            end


            if alreadyWrapped[entity] then
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


            entity.pose =
                function(self, ...)

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
                        and sprite then

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


                        ctx.poses[
                            #ctx.poses + 1
                        ] = {

                            sprite =
                                sprite,

                            px =
                                (vx or self.px or 0)
                                + (offsetX or 0),

                            py =
                                basePy
                                + (offsetY or 0),

                            facing =
                                facing,

                            phase =
                                phase,

                            flip =
                                flip,

                            gh =
                                ground,

                            lift =
                                basePy
                                - visualY,

                            colors =
                                colors,

                            isPlayer =
                                isPlayer
                                and true
                                or false,

                            fishing =
                                isPlayer
                                and self.fishing
                                and true
                                or false,

                                

                                
                            ------------------------------------------------
                            -- Logical sprite identity of the map entity.
                            --
                            -- Important for Surf: pose() may return SEEL as
                            -- the visual sprite while the entity itself is
                            -- still RED / YELLOW / another player variant.
                            ------------------------------------------------

                            logicalSpriteId =
                                self.def
                                and self.def.id
                                or nil,

                            ------------------------------------------------
                            -- Stable per-entity identity + motion state.
                            -- Used by the procedural idle layer so nearby
                            -- NPCs do not breathe in perfect synchrony.
                            ------------------------------------------------

                            entityKey =
                                self.id
                                or (
                                    self.def
                                    and self.def.name
                                )
                                or tostring(self),

                            ------------------------------------------------
                            -- Filled just below from actual world-position
                            -- delta, not from sticky movement flags.
                            ------------------------------------------------

                            isMoving =
                                false
                        }





                    local captured =
                        ctx.poses[
                            #ctx.poses
                        ]

                    
                




                    local motionKey =
                        captured.entityKey


                    local previousMotion =
                        idleMotionHistory[
                            motionKey
                        ]


                    if previousMotion then

                        local dx =
                            captured.px
                            - previousMotion.x


                        local dz =
                            captured.py
                            - previousMotion.z


                        captured.isMoving =
                            (
                                dx * dx
                                + dz * dz
                            )
                            > 0.0001
                    end


                    idleMotionHistory[
                        motionKey
                    ] = {
                        x =
                            captured.px,

                        z =
                            captured.py
                    }
                    end


                    return sprite,
                           vx,
                           vy,
                           facing,
                           phase,
                           flip
                end


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
        -- Observe SpriteBillboards.mesh.
        --
        -- This establishes:
        --
        --     GPU mesh -> sprite definition + frame
        ----------------------------------------------------------------

        local function rememberBillboard(
            mesh,
            def,
            frame
        )

            if mesh then

                billboardInfo[mesh] = {

                    def =
                        def,

                    frame =
                        frame
                }
            end


            return mesh
        end


        SpriteBillboards.mesh =
            function(
                def,
                frame
            )

                return rememberBillboard(
                    originalBillboardMesh(
                        def,
                        frame
                    ),
                    def,
                    frame
                )
            end


        ----------------------------------------------------------------
        -- shadowQuad was assigned to the original mesh function when
        -- Dramatic Shape loaded. Wrap it separately so the FIRST shadow
        -- pass of a fresh session is identifiable too.
        ----------------------------------------------------------------

        SpriteBillboards.shadowQuad =
            function(
                def,
                frame
            )

                return rememberBillboard(
                    originalShadowQuad(
                        def,
                        frame
                    ),
                    def,
                    frame
                )
            end


        ----------------------------------------------------------------
        -- Poses that drawCast actually renders.
        ----------------------------------------------------------------

        local function visiblePoses(ctx)

            if ctx.visible then
                return ctx.visible
            end


            local hidePlayer =
                FirstPerson
                and FirstPerson.hidePlayer
                and FirstPerson.hidePlayer()
                or false


            ctx.visible =
                {}


            for _, p in ipairs(
                ctx.poses
            ) do

                if not (
                    p.isPlayer
                    and hidePlayer
                ) then

                    ctx.visible[
                        #ctx.visible + 1
                    ] =
                        p
                end
            end


            return ctx.visible
        end


        ----------------------------------------------------------------
        -- Resolve one authored FIGURE replacement.
        --
        -- This path is separate from the normal SpriteBillboards path.
        -- It never changes draw-index/pose association for normal NPCs.
        ----------------------------------------------------------------

        local function applyFigureIdleScale(
            model,
            info
        )

            local cfg =
                Registry.idle_animation
                or {}


            if cfg.enabled == false then
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


            ------------------------------------------------------------
            -- Stable ID-only-ish phase for authored figures.
            -- The key is supplied by the renderer (map + semantic role),
            -- so each recurring figure can breathe independently.
            ------------------------------------------------------------

            local key =
                tostring(
                    info.idleKey
                    or "figure"
                )


            local hash =
                17


            for i = 1, #key do

                hash =
                    (
                        hash * 131
                        + string.byte(
                            key,
                            i
                        )
                    )
                    % 104729
            end


            local timeOffset =
                1.0
                + (
                    hash
                    / 104729
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


        local function replacementDataForFigure(
            info
        )

            if not info
                or not info.replacement
                or not info.replacement.asset then

                return nil
            end


            local asset =
                loadAsset(
                    info.replacement.asset
                )


            if not asset then
                return nil
            end


            local figure =
                info.figure


            local x =
                (figure.wx or 0)
                + (
                    (figure.w or 16)
                    / 2
                )


            local y =
                figure.y
                or 0


            local z =
                figure.wz
                or 0


            local model =
                Mat4.mul(
                    Mat4.translate(
                        x,
                        y,
                        z
                    ),
                    Mat4.rotateY(
                        info.replacement.yaw
                        or 0
                    )
                )


            model =
                applyFigureIdleScale(
                    model,
                    info
                )


            local texture =
                textureForLoadedAsset(
                    asset,
                    info.sprite,
                    info.colors
                )


            if not texture then
                return nil
            end


            return {

                mesh =
                    asset.mesh,

                texture =
                    texture,

                model =
                    model
            }
        end


        ----------------------------------------------------------------
        -- Resolve one Porygonal replacement.
        --
        -- The same geometry/model is used by BOTH the camera pass and
        -- the sun pass. That is essential: the shadow map must contain
        -- the geometry the lit mesh later asks about.
        ----------------------------------------------------------------

        local function idleTimeOffsetForKey(key)

            ------------------------------------------------------------
            -- Stable per-entity idle desynchronization.
            --
            -- IMPORTANT:
            --   * ID ONLY
            --   * world position is deliberately ignored
            --
            -- For common entity IDs ending in a number (obj_1, obj_2...),
            -- use that number directly and scramble it with the golden-ratio
            -- fraction so consecutive IDs land far apart.
            --
            -- The result is a deterministic time offset in [1, 2) seconds.
            ------------------------------------------------------------

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


            ------------------------------------------------------------
            -- Only truly stationary ordinary characters.
            --
            -- Do not breathe:
            --   * while the entity is moving,
            --   * Surf composites,
            --   * Fly composites.
            --
            -- Bike is intentionally allowed here: when stationary it uses
            -- the same subtle idle scale; p.isMoving disables it while riding.
            ------------------------------------------------------------

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


            ------------------------------------------------------------
            -- 0..1 breathing wave rather than -1..1:
            -- the authored idle mesh remains the minimum-size pose.
            --
            -- Each entity receives a stable 1..2 second offset derived
            -- only from its ID, so nearby characters do not correlate
            -- merely because they stand close together.
            ------------------------------------------------------------

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


            ------------------------------------------------------------
            -- Character meshes are authored with their feet at Y=0.
            -- Scaling after translate/rotation therefore keeps the feet
            -- planted while the upper body subtly expands/contracts.
            ------------------------------------------------------------

            return Mat4.mul(
                model,
                Mat4.scale(
                    sxz,
                    sy,
                    sxz
                )
            )
        end


        local function replacementDataForPose(p)

            local worldFacing =
                p.facing


            local spriteId,
                  frame,
                  mirror =

                getSpritePose(
                    p.sprite,
                    worldFacing,
                    p.phase,
                    p.flip
                )


            local replacement =
                Registry.lookup(
                    spriteId,
                    frame,
                    mirror,
                    worldFacing,
                    {
                        isPlayer =
                            p.isPlayer,


                        fishing =
                            p.fishing,    


                        spriteDef =
                            p.sprite
                            and p.sprite.def
                            or nil,

                        spriteImage =
                            p.sprite
                            and p.sprite.def
                            and p.sprite.def.image
                            or nil
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
                    or worldFacing,
                    p.isPlayer
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
            -- Composite replacement (currently Surf).
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

                    local asset =
                        loadAsset(
                            part.asset
                        )


                    ----------------------------------------------------
                    -- Composite is atomic:
                    -- if one required part is missing, preserve the
                    -- original 2D fallback rather than draw half of it.
                    ----------------------------------------------------

                    if not asset then
                        return nil
                    end


                    local meshToDraw =
                        asset.mesh


                    if part.mirror then
                        meshToDraw =
                            asset.mirroredMesh
                    end


                    local texture =
                        textureForLoadedAsset(
                            asset,
                            p.sprite,
                            p.colors
                        )


                    if not texture then
                        return nil
                    end


                    draws[
                        #draws + 1
                    ] = {

                        mesh =
                            meshToDraw,

                        texture =
                            texture,

                        model =
                            part.role == "rider"
                            and riderModel
                            or mountModel
                    }
                end


                return {

                    composite =
                        true,

                    draws =
                        draws
                }
            end


            ------------------------------------------------------------
            -- Normal single-asset replacement.
            ------------------------------------------------------------

            if not replacement.asset then
                return nil
            end


            local asset =
                loadAsset(
                    replacement.asset
                )


            if not asset then
                return nil
            end


            local meshToDraw =
                asset.mesh


            if replacement.mirror then
                meshToDraw =
                    asset.mirroredMesh
            end


            local texture =
                textureForLoadedAsset(
                    asset,
                    p.sprite,
                    p.colors
                )


            return {

                mesh =
                    meshToDraw,

                texture =
                    texture,

                model =
                    baseModel
            }
        end


        ----------------------------------------------------------------
        -- Draw one visible Porygonal replacement.
        ----------------------------------------------------------------

        local function drawPorygonal(p)

            local data =
                replacementDataForPose(
                    p
                )


            if not data then
                return false
            end


            love.graphics.setMeshCullMode(
                "back"
            )


            ------------------------------------------------------------
            -- The sunModel is the SAME model used by ShadowMap.draw.
            --
            -- Do not use ShadowMap.snug here: snug is designed for thin
            -- billboard stand-ins. Our character is real 3D geometry,
            -- like a building, so caster and lookup should match exactly.
            ------------------------------------------------------------

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


            love.graphics.setMeshCullMode(
                "none"
            )


            return true
        end


        ----------------------------------------------------------------
        -- Draw one Porygonal shadow caster.
        ----------------------------------------------------------------

        local function drawPorygonalShadow(p)

            local data =
                replacementDataForPose(
                    p
                )


            if not data then
                return false
            end


            ------------------------------------------------------------
            -- ShadowMap.begin() already owns depth/shader/cull state.
            -- Keep culling disabled so the complete 3D volume can cast.
            ------------------------------------------------------------

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


        ------------------------------------------------------------
        -- Fly trajectory.
        --
        -- Returns world offset + yaw for the current Porygonal Fly state.
        -- X is used as the first prototype's horizontal travel axis;
        -- this can later be promoted to a camera-relative axis if needed.
        ------------------------------------------------------------

        local function flyTransform()

            if flyState.mode
                == "normal" then

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


            if flyState.mode
                == "departure" then

                local t =
                    now
                    - flyState.startedAt


                ----------------------------------------------------
                -- TAKEOFF
                ----------------------------------------------------

                if t < takeoff then

                    return 0,
                           0,
                           0,
                           math.rad(90),
                           true
                end


                t =
                    t - takeoff


                ----------------------------------------------------
                -- DEPARTURE: player anchor -> +X / +Y in world space.
                ----------------------------------------------------

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


                ----------------------------------------------------
                -- OFFSCREEN / BETWEEN-PASSES PHASE
                --
                -- Keep the Fly composite visible at the end of the
                -- departure path. The authored idle/walk animation keeps
                -- alternating because flyPoseName() continues to advance.
                ----------------------------------------------------

                if t < offscreen then

                    return departureDistance,
                           departureHeight,
                           0,
                           math.rad(90),
                           true
                end


                t =
                    t - offscreen


                ----------------------------------------------------
                -- RETURN PASS:
                -- resumes from +X after the between-passes phase,
                -- crosses the player anchor and continues to -X.
                ----------------------------------------------------

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


            if flyState.mode
                == "landing" then

                local t =
                    now
                    - flyState.landingAt


                ----------------------------------------------------
                -- LANDING:
                -- +X/+Y in world space -> exact player position.
                ----------------------------------------------------

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
                flyState.mode
                    == "landing"
                and flyState.targetPx
                or flyState.startPx


            local basePy =
                flyState.mode
                    == "landing"
                and flyState.targetPy
                or flyState.startPy


            local ground =
                flyState.mode
                    == "landing"
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

                local asset =
                    loadAsset(
                        part.asset
                    )


                if not asset then
                    return nil
                end


                ----------------------------------------------------
                -- Fly assets use the same Gen1 four-shade palette
                -- realization as ordinary overworld characters.
                --
                -- Previously the mount received sprite=nil/colors=nil,
                -- so bird_* fell back to its raw grayscale texture.
                --
                -- Passing the active map colors fixes that while keeping
                -- the rider's normal palette path intact.
                ----------------------------------------------------

                ----------------------------------------------------
                -- Palette source for Fly composite.
                --
                -- IMPORTANT:
                -- In GBC/color-pack mode, colorsForMap() deliberately
                -- returns nil because overworld sprites use per-sprite
                -- OBP palettes. Therefore passing only flyState.colors
                -- leaves the mount in raw grayscale.
                --
                -- Until we expose the native Fly bird's own sprite-def
                -- palette identity, use the active player's sprite as
                -- the palette resolver for BOTH parts. This guarantees
                -- CharacterRuntime -> PaletteFX.spriteObp() is invoked
                -- instead of falling back to the raw grayscale texture.
                ----------------------------------------------------

                local sprite =
                    flyState.playerSprite


                local colors =
                    flyState.colors


                local texture =
                    textureForLoadedAsset(
                        asset,
                        sprite,
                        colors
                    )


                if not texture then
                    return nil
                end


                draws[
                    #draws + 1
                ] = {

                    mesh =
                        asset.mesh,

                    texture =
                        texture,

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


            love.graphics.setMeshCullMode(
                "back"
            )


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


            love.graphics.setMeshCullMode(
                "none"
            )


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
        -- Observe ShadowMap.draw.
        --
        -- The shadow pass iterates ALL captured poses (including the
        -- player even when first-person hides the visible card).
        -- Billboard identity keeps authored figures / battle cards /
        -- terrain out of this path.
        ----------------------------------------------------------------

        ShadowMap.draw =
            function(
                mesh,
                texture,
                model
            )

                local info =
                    billboardInfo[mesh]


                local ctx =
                    renderContext


                --------------------------------------------------------
                -- Porygonal Fly shadow: draw once per shadow pass.
                --------------------------------------------------------

                if ctx
                    and ctx.flyActive
                    and not ctx.flyShadowDrawn then

                    ctx.flyShadowDrawn =
                        true


                    drawFlyShadow()
                end


                --------------------------------------------------------
                -- Authored FIGURE replacement.
                --------------------------------------------------------

                if ctx
                    and ctx.specialFigures
                    and ctx.specialFigures[mesh] then

                    local data =
                        replacementDataForFigure(
                            ctx.specialFigures[
                                mesh
                            ]
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


                if info
                    and ctx then

                    local poses =
                        ctx.poses


                    local count =
                        #poses


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
                            poses[
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
        -- Observe Voxel3D.draw.
        --
        -- A solid character draw is identified by BOTH:
        --
        --     * its mesh was returned by SpriteBillboards.mesh
        --     * sunModel is present
        --
        -- Ghost and fallback-shadow draws use billboard meshes too, but
        -- do not supply sunModel and therefore pass through untouched.
        ----------------------------------------------------------------

        Voxel3D.draw =
            function(
                mesh,
                texture,
                model,
                pull,
                sunModel
            )

                local info =
                    billboardInfo[mesh]


                local ctx =
                    renderContext


                --------------------------------------------------------
                -- Porygonal Fly visible composite: draw once in the solid
                -- camera pass, then suppress the normal player card/model
                -- until Porygonal's landing has completed.
                --------------------------------------------------------

                if ctx
                    and ctx.flyActive
                    and sunModel ~= nil
                    and not ctx.flyVisibleDrawn then

                    ctx.flyVisibleDrawn =
                        true


                    drawFlyVisible()
                end


                --------------------------------------------------------
                -- Authored FIGURE replacement.
                --
                -- The figure mesh is identified directly, so this path
                -- does not consume or modify the normal character draw
                -- index. Normal NPC rendering stays untouched.
                --------------------------------------------------------

                if ctx
                    and ctx.specialFigures
                    and ctx.specialFigures[mesh]
                    and sunModel ~= nil then

                    local data =
                        replacementDataForFigure(
                            ctx.specialFigures[
                                mesh
                            ]
                        )


                    if data then

                        love.graphics.setMeshCullMode(
                            "back"
                        )


                        originalVoxelDraw(
                            data.mesh,
                            data.texture,
                            data.model,
                            0,
                            data.model
                        )


                        love.graphics.setMeshCullMode(
                            "none"
                        )


                        return
                    end
                end


                if info
                    and ctx
                    and sunModel ~= nil then

                    local poses =
                        visiblePoses(
                            ctx
                        )


                    local count =
                        #poses


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
                            poses[
                                poseIndex
                            ]


                        if p
                            and p.sprite
                            and p.sprite.def
                            and p.sprite.def == info.def then

                            if ctx.flyActive
                                and p.isPlayer then

                                ------------------------------------------------
                                -- Do not let the normal player reappear between
                                -- departure, map transition and Porygonal landing.
                                ------------------------------------------------

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
                    sunModel
                )
            end


        ----------------------------------------------------------------
        -- Observe VoxelScene.render.
        --
        -- This is the frame boundary and provides the OverworldState.
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

                --------------------------------------------------------
                -- Porygonal Fly state machine.
                --------------------------------------------------------

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


                --------------------------------------------------------
                -- Start departure on native Fly.
                --------------------------------------------------------

                if flyState.mode
                    == "normal"
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


                    flyState.colors =
                        colorsForMap(
                            paletteFor,
                            state.map
                        )


                    flyState.birdImage =
                        nil


                    flyState.captureBird =
                        true
                end


                --------------------------------------------------------
                -- Detect destination.
                --
                -- Prefer map identity change. The position fallback also
                -- handles a destination represented by the same map object.
                --------------------------------------------------------

                if flyState.mode
                    == "departure"
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
                            or flyState.playerSprite


                        flyState.colors =
                            colorsForMap(
                                paletteFor,
                                state.map
                            )
                            or flyState.colors
                    end
                end


                --------------------------------------------------------
                -- End Porygonal landing and hand control back to the
                -- ordinary player renderer.
                --------------------------------------------------------

                if flyState.mode
                    == "landing" then

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

                    poses =
                        {},

                    visible =
                        nil,

                    characterDrawIndex =
                        0,

                    shadowDrawIndex =
                        0,



                    flyActive =
                        flyState.mode
                        ~= "normal",

                    flyVisibleDrawn =
                        false,

                    flyShadowDrawn =
                        false,

                    specialFigures =
                        setmetatable(
                            {},
                            {
                                __mode = "k"
                            }
                        )
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


                --------------------------------------------------------
                -- Ghost entities first, matching Dramatic Shape posesOf().
                --------------------------------------------------------

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


                --------------------------------------------------------
                -- Current-map entities.
                --------------------------------------------------------

                local mapColors =
                    colorsForMap(
                        paletteFor,
                        state.map
                    )


                --------------------------------------------------------
                -- Pokémon Center seated authored FIGURE.
                --
                -- The seated man is not a normal state.entities NPC.
                -- In tested Pokémon Centers (Viridian, Vermilion), he is
                -- exposed by Dramatic Shape as the map's authored FIGURE.
                --
                -- Therefore do NOT associate him with a nearby logical NPC.
                -- In a Pokémon Center, when the current map exposes exactly
                -- one authored FIGURE, that FIGURE gets the seated spe1 model.
                --------------------------------------------------------

                do
                    local mapId =
                        state.map
                        and state.map.id
                        or ""


                    local isPokecenter =
                        string.find(
                            string.upper(
                                tostring(mapId)
                            ),
                            "POKECENTER",
                            1,
                            true
                        ) ~= nil


                    if isPokecenter
                        and Registry.lookupPokecenterSeatedFigure
                        and ChunkMesher
                        and ChunkMesher.figures then

                        local figures =
                            ChunkMesher.figures(
                                state.map
                            )
                            or {}


                        ------------------------------------------------
                        -- Conservative rule:
                        -- only auto-assign when there is ONE authored
                        -- FIGURE on the Pokémon Center map.
                        ------------------------------------------------

                        if #figures == 1 then

                            local figure =
                                figures[1]


                            local special =
                                Registry.lookupPokecenterSeatedFigure()


                            if figure
                                and figure.mesh
                                and special then

                                ctx.specialFigures[
                                    figure.mesh
                                ] = {

                                    figure =
                                        figure,

                                    replacement =
                                        special,

                                    ------------------------------------------------
                                    -- Authored FIGURE palette.
                                    --
                                    -- The seated figure has no real Sprite instance.
                                    -- Use a stable character palette in GBC mode,
                                    -- and the effective map palette in other modes.
                                    ------------------------------------------------

                                    sprite =
                                        nil,

                                    colors =
                                        colorsForAuthoredFigure(
                                            paletteFor,
                                            state.map,
                                            state
                                        ),
                                    ------------------------------------------------
                                    -- Stable semantic key for procedural idle.
                                    ------------------------------------------------

                                    idleKey =
                                        tostring(mapId)
                                        .. ":pokecenter_seated"
                                }
                            end
                        end
                    end
                end


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


                --------------------------------------------------------
                -- Let Dramatic Shape execute its normal renderer.
                --------------------------------------------------------

                local ok,
                      resultA,
                      resultB,
                      resultC =

                    pcall(
                        function()

                            return originalVoxelRender(
                                state,
                                w,
                                h,
                                vw,
                                vh,
                                paletteFor,
                                eyes
                            )
                        end
                    )


                --------------------------------------------------------
                -- Always restore entity pose methods.
                --------------------------------------------------------

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



        return true
    end


    ----------------------------------------------------------------
    -- COMPAT: RECOMP 0.1.83
    --
    -- Original integration using Lua private-function hooks
    -- (debug.getupvalue / debug.setupvalue).
    -- Kept frozen as a fallback for the older runtime.
    ----------------------------------------------------------------

    local function installCompat0183()

        ----------------------------------------------------------------
        -- Locate drawCast
        ----------------------------------------------------------------

        local _,
              drawCast =

            findUpvalue(
                VoxelScene.render,
                "drawCast"
            )


        if type(drawCast)
            ~= "function" then

            mod.log:error(
                "Dramatic Shape adapter: drawCast was not found"
            )

            return false
        end


        ----------------------------------------------------------------
        -- Track the exact pose currently passed through viewFacing()
        --
        -- Dramatic Shape does:
        --
        -- viewFacing(p)
        -- immediately followed by
        -- drawEntity(...)
        --
        -- So we do not need to associate data with sprite objects.
        -- We only remember the current p.
        ----------------------------------------------------------------

        local currentPose =
            nil


        local viewFacingIndex,
              originalViewFacing =

            findUpvalue(
                drawCast,
                "viewFacing"
            )


        if not viewFacingIndex
            or type(originalViewFacing)
                ~= "function" then

            mod.log:error(
                "Dramatic Shape adapter: viewFacing was not found"
            )

            return false
        end


        local function trackedViewFacing(p)

            currentPose =
                p


            return originalViewFacing(
                p
            )
        end


        local viewFacingResult =
            debug.setupvalue(
                drawCast,
                viewFacingIndex,
                trackedViewFacing
            )


        if not viewFacingResult then

            mod.log:error(
                "Dramatic Shape adapter could not track current pose"
            )

            return false
        end


        ----------------------------------------------------------------
        -- Resolve true world-facing
        ----------------------------------------------------------------

        local function trueFacing(
            fallbackFacing
        )

            if currentPose
                and currentPose.facing then

                return currentPose.facing
            end


            return fallbackFacing
        end


        ----------------------------------------------------------------
        -- Is current pose the player?
        ----------------------------------------------------------------

        local function currentPoseIsPlayer()

            return currentPose
                and currentPose.isPlayer
                and true
                or false
        end


        ----------------------------------------------------------------
        -- World yaw
        ----------------------------------------------------------------

        local function facingToYaw(
            facing
        )

            ------------------------------------------------------------
            -- Player + free camera:
            -- continuous body yaw
            ------------------------------------------------------------

            if currentPoseIsPlayer()
                and FirstPerson
                and FirstPerson.engaged
                and FirstPerson.engaged()
                and FirstPerson.bodyYaw ~= nil then

                return FirstPerson.bodyYaw
            end


            ------------------------------------------------------------
            -- NPC / normal camera:
            -- original world facing
            ------------------------------------------------------------

            if facing == "down" then
                return 0
            end


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
        -- Locate drawEntity
        ----------------------------------------------------------------

        local entityIndex,
              originalDrawEntity =

            findUpvalue(
                drawCast,
                "drawEntity",
                VoxelScene.drawEntity
            )


        if not entityIndex
            or type(originalDrawEntity)
                ~= "function" then

            mod.log:error(
                "Dramatic Shape adapter: drawEntity was not found"
            )

            return false
        end


        ----------------------------------------------------------------
        -- Porygonal draw
        ----------------------------------------------------------------

        local function drawEntity(
            sprite,
            px,
            py,
            facing,
            phase,
            flip,
            gh,
            colors,
            lift
        )

            ------------------------------------------------------------
            -- `facing` may be Dramatic Shape viewFacing.
            --
            -- currentPose.facing is the original world-facing.
            ------------------------------------------------------------

            local worldFacing =
                trueFacing(
                    facing
                )


            ------------------------------------------------------------
            -- Determine Gen1 pose from real world-facing
            ------------------------------------------------------------

            local spriteId,
                  frame,
                  mirror =

                getSpritePose(
                    sprite,
                    worldFacing,
                    phase,
                    flip
                )


            ------------------------------------------------------------
            -- Registry lookup
            ------------------------------------------------------------

            local replacement =
                Registry.lookup(
                    spriteId,
                    frame,
                    mirror,
                    worldFacing
                )


            ------------------------------------------------------------
            -- Porygonal asset available
            ------------------------------------------------------------

            if replacement
                and replacement.asset then

                local asset =
                    loadAsset(
                        replacement.asset
                    )


                if asset then

                    local y =
                        (gh or 0)
                        + (lift or 0)


                    local yaw =
                        facingToYaw(
                            replacement.facing
                            or worldFacing
                        )


                    local model =
                        Mat4.mul(
                            Mat4.translate(
                                px + 8,
                                y,
                                py + 8
                            ),
                            Mat4.rotateY(
                                yaw
                            )
                        )


                    local meshToDraw =
                        asset.mesh


                    if replacement.mirror then

                        meshToDraw =
                            asset.mirroredMesh

                    end


                    local texture =
                        textureForLoadedAsset(
                    asset,
                            sprite,
                            colors
                        )


                    love.graphics.setMeshCullMode(
                        "back"
                    )


                    Voxel3D.draw(
                        meshToDraw,
                        texture,
                        model,
                        0
                    )


                    love.graphics.setMeshCullMode(
                        "none"
                    )


                    return true
                end
            end


            ----------------------------------------------------------------
            -- No 3D asset:
            -- preserve Dramatic Shape's original 2D behaviour.
            ----------------------------------------------------------------

            return originalDrawEntity(
                sprite,
                px,
                py,
                facing,
                phase,
                flip,
                gh,
                colors,
                lift
            )

        end


        ----------------------------------------------------------------
        -- Install replacement
        ----------------------------------------------------------------

        local result =
            debug.setupvalue(
                drawCast,
                entityIndex,
                drawEntity
            )


        if not result then

            mod.log:error(
                "Dramatic Shape adapter could not replace drawEntity"
            )

            return false
        end



        return true
    end


    ----------------------------------------------------------------
    -- Select compatibility profile
    ----------------------------------------------------------------

    if installCompat0199() then

        mod.log:info(
            "Dramatic Shape Porygonal adapter installed"
        )

        mod.log:info(
            "Porygonal COMPAT RECOMP 0.1.99 + 3D shadows installed"
        )

        return true
    end


    mod.log:info(
        "Porygonal COMPAT RECOMP 0.1.99 unavailable; trying 0.1.83"
    )


    if installCompat0183() then

        mod.log:info(
            "Dramatic Shape Porygonal adapter installed"
        )

        mod.log:info(
            "Porygonal COMPAT RECOMP 0.1.83 installed"
        )

        return true
    end


    mod.log:error(
        "Dramatic Shape adapter: no compatible Recomp integration found"
    )

    return false

end


return DramaticShapeAdapter
