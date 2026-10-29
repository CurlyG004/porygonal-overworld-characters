local CharacterRuntime = {}


function CharacterRuntime.create(
    mod,
    loadLocalModule,
    versionGroup
)

assert(
    versionGroup ~= nil,
    "character_runtime.lua expected versionGroup"
)

    ----------------------------------------------------------------
    -- Gen1Recomp modules
    --
    -- These describe the CHARACTER DATA semantics used by Porygonal.
    -- They are intentionally kept out of renderer-specific adapters.
    ----------------------------------------------------------------

    local SR =
        require(
            "src.render.SpriteRenderer"
        )


    local TileRenderer =
        require(
            "src.render.TileRenderer"
        )


    local PaletteFX =
        require(
            "src.render.PaletteFX"
        )

    ----------------------------------------------------------------
    -- Version-aware palette resolver
    ----------------------------------------------------------------

    local PaletteResolverModule =
        loadLocalModule(
            "palettes/palette_resolver.lua"
        )

    assert(
        PaletteResolverModule
            and type(PaletteResolverModule.create)
                == "function",
        "Could not load Porygonal palette resolver"
    )


    local PaletteResolver =
        PaletteResolverModule.create(
            loadLocalModule
        )
        

    ----------------------------------------------------------------
    -- Protected character package V4
    --
    -- The package is a storage layer only. Registry and renderer adapters
    -- continue to request the same logical .lua paths as before.
    --
    -- V4 does NOT contain Lua source. Each protected chunk decodes directly
    -- to the mesh table expected by the existing renderer pipeline.
    ----------------------------------------------------------------

    local PACKAGE_PATH =
        "assets/porygonal_characters.pak"

    local PACKAGE_MAGIC =
        "PGCHAR04"

    local PACKAGE_VERSION =
        4

    local PACKAGE_MASTER_SEED =
        0x51A7C3D9

    local FIXED_SCALE =
        1000000

    local bitlib =
        bit

    if not bitlib then

        local okBit,
              loadedBit =
            pcall(
                require,
                "bit"
            )

        if okBit then
            bitlib = loadedBit
        end

    end

    assert(
        bitlib
            and bitlib.band
            and bitlib.bxor
            and bitlib.lshift
            and bitlib.rshift,
        "Porygonal protected assets require LuaJIT bit operations"
    )

    local band =
        bitlib.band

    local bxor =
        bitlib.bxor

    local lshift =
        bitlib.lshift

    local rshift =
        bitlib.rshift

    local packageState = {
        loaded = false,
        failed = false,
        bytes = nil,
        index = nil
    }


    local function u32(value)

        if value < 0 then
            return value + 4294967296
        end

        return value
    end


    local function readU16LE(
        bytes,
        offset
    )

        local a,
              b =
            bytes:byte(
                offset,
                offset + 1
            )

        if not b then
            return nil
        end

        return a
            + b * 256
    end


    local function readU32LE(
        bytes,
        offset
    )

        local a,
              b,
              c,
              d =
            bytes:byte(
                offset,
                offset + 3
            )

        if not d then
            return nil
        end

        return a
            + b * 256
            + c * 65536
            + d * 16777216
    end


    local function readS32LE(
        bytes,
        offset
    )

        local value =
            readU32LE(
                bytes,
                offset
            )

        if not value then
            return nil
        end

        if value >= 2147483648 then
            value =
                value - 4294967296
        end

        return value
    end


    local function assetHash(path)

        local normalized =
            tostring(path)
                :gsub("\\", "/")
                :lower()

        local h =
            5381

        for i = 1, #normalized do

            h =
                band(
                    h
                        + lshift(h, 5)
                        + normalized:byte(i),
                    0xffffffff
                )

        end

        return u32(h)
    end


    local function streamSeed(
        nameHash,
        rawSize
    )

        local seed =
            bxor(
                PACKAGE_MASTER_SEED,
                nameHash,
                lshift(rawSize, 7),
                rshift(rawSize, 3)
            )

        seed =
            band(
                seed,
                0xffffffff
            )

        if seed == 0 then
            seed = 0x6d2b79f5
        end

        return seed
    end


    local function nextStreamByte(state)

        state =
            bxor(
                state,
                lshift(state, 13)
            )

        state =
            bxor(
                state,
                rshift(state, 17)
            )

        state =
            bxor(
                state,
                lshift(state, 5)
            )

        state =
            band(
                state,
                0xffffffff
            )

        return state,
               band(state, 0xff)
    end


    local function unprotect(
        protected,
        seed
    )

        local out = {}
        local state = seed
        local piece = {}
        local pieceCount = 0

        for i = 1, #protected do

            local keyByte

            state,
            keyByte =
                nextStreamByte(
                    state
                )

            pieceCount =
                pieceCount + 1

            piece[pieceCount] =
                string.char(
                    bxor(
                        protected:byte(i),
                        keyByte
                    )
                )

            if pieceCount >= 4096 then

                out[#out + 1] =
                    table.concat(
                        piece
                    )

                piece = {}
                pieceCount = 0
            end

        end

        if pieceCount > 0 then

            out[#out + 1] =
                table.concat(
                    piece
                )

        end

        return table.concat(
            out
        )
    end


    local function ensurePackage()

        if packageState.loaded then
            return true
        end

        if packageState.failed then
            return false
        end

        local bytes,
              readErr =
            mod:read(
                PACKAGE_PATH
            )

        if not bytes then

            mod.log:error(
                "Could not read Porygonal character package %s: %s",
                PACKAGE_PATH,
                tostring(readErr)
            )

            packageState.failed =
                true

            return false
        end

        if bytes:sub(1, 8)
            ~= PACKAGE_MAGIC then

            mod.log:error(
                "Invalid Porygonal character package signature"
            )

            packageState.failed =
                true

            return false
        end

        local version =
            readU32LE(
                bytes,
                9
            )

        local count =
            readU32LE(
                bytes,
                13
            )

        if version ~= PACKAGE_VERSION
            or not count then

            mod.log:error(
                "Unsupported Porygonal character package version: %s",
                tostring(version)
            )

            packageState.failed =
                true

            return false
        end

        local index = {}
        local cursor = 17

        for i = 1, count do

            local nameHash =
                readU32LE(
                    bytes,
                    cursor
                )

            local offset =
                readU32LE(
                    bytes,
                    cursor + 4
                )

            local packedSize =
                readU32LE(
                    bytes,
                    cursor + 8
                )

            local rawSize =
                readU32LE(
                    bytes,
                    cursor + 12
                )

            local check =
                readU32LE(
                    bytes,
                    cursor + 16
                )

            if not nameHash
                or not offset
                or not packedSize
                or not rawSize
                or not check then

                mod.log:error(
                    "Truncated Porygonal character package index"
                )

                packageState.failed =
                    true

                return false
            end

            index[nameHash] = {
                offset = offset,
                packedSize = packedSize,
                rawSize = rawSize,
                check = check
            }

            cursor =
                cursor + 20
        end

        packageState.bytes =
            bytes

        packageState.index =
            index

        packageState.loaded =
            true

        mod.log:info(
            "Porygonal character package V4 ready (%d assets)",
            count
        )

        return true
    end


    local function decodeMeshBinary(
        bytes,
        nameHash,
        expectedCheck
    )

        local vertexCount =
            readU32LE(
                bytes,
                1
            )

        local indexCount =
            readU32LE(
                bytes,
                5
            )

        if not vertexCount
            or not indexCount then

            return nil,
                   "truncated mesh header"
        end

        local expectedSize =
            8
                + vertexCount * 24
                + indexCount * 2

        if #bytes ~= expectedSize then

            return nil,
                   "mesh binary size mismatch"
        end

        local calculatedCheck =
            band(
                vertexCount * 65537
                    + indexCount * 257
                    + nameHash,
                0xffffffff
            )

        calculatedCheck =
            u32(
                calculatedCheck
            )

        if calculatedCheck
            ~= expectedCheck then

            return nil,
                   "mesh metadata check failed"
        end

        local vertices = {}
        local cursor = 9

        for i = 1, vertexCount do

            local a =
                readS32LE(bytes, cursor)

            local b =
                readS32LE(bytes, cursor + 4)

            local c =
                readS32LE(bytes, cursor + 8)

            local d =
                readS32LE(bytes, cursor + 12)

            local e =
                readS32LE(bytes, cursor + 16)

            local f =
                readS32LE(bytes, cursor + 20)

            if not f then

                return nil,
                       "truncated vertex data"
            end

            vertices[i] = {
                a / FIXED_SCALE,
                b / FIXED_SCALE,
                c / FIXED_SCALE,
                d / FIXED_SCALE,
                e / FIXED_SCALE,
                f / FIXED_SCALE
            }

            cursor =
                cursor + 24
        end

        local indices = {}

        for i = 1, indexCount do

            local index =
                readU16LE(
                    bytes,
                    cursor
                )

            if not index then

                return nil,
                       "truncated index data"
            end

            indices[i] =
                index

            cursor =
                cursor + 2
        end

        return {
            vertices = vertices,
            indices = indices
        }
    end


    local function loadProtectedMesh(
        path
    )

        if not ensurePackage() then
            return nil
        end

        local nameHash =
            assetHash(
                path
            )

        local entry =
            packageState.index[
                nameHash
            ]

        if not entry then

            mod.log:error(
                "Mesh is missing from Porygonal character package: %s",
                tostring(path)
            )

            return nil
        end

        local first =
            entry.offset + 1

        local last =
            entry.offset
                + entry.packedSize

        local protected =
            packageState.bytes:sub(
                first,
                last
            )

        if #protected
            ~= entry.packedSize then

            mod.log:error(
                "Truncated protected mesh chunk: %s",
                tostring(path)
            )

            return nil
        end

        local compressed =
            unprotect(
                protected,
                streamSeed(
                    nameHash,
                    entry.rawSize
                )
            )

        local okDecompress,
              binary =
            pcall(
                love.data.decompress,
                "string",
                "zlib",
                compressed
            )

        compressed = nil

        if not okDecompress
            or type(binary) ~= "string" then

            mod.log:error(
                "Could not decode protected mesh %s: %s",
                tostring(path),
                tostring(binary)
            )

            return nil
        end

        if #binary
            ~= entry.rawSize then

            mod.log:error(
                "Protected mesh size mismatch: %s",
                tostring(path)
            )

            return nil
        end

        local meshData,
              decodeErr =
            decodeMeshBinary(
                binary,
                nameHash,
                entry.check
            )

        binary = nil

        if not meshData then

            mod.log:error(
                "Could not reconstruct protected mesh %s: %s",
                tostring(path),
                tostring(decodeErr)
            )

            return nil
        end

        return meshData
    end


    ----------------------------------------------------------------
    -- Renderer-agnostic asset cache
    --
    -- IMPORTANT:
    -- This cache contains DATA only:
    -- vertices, indices and ImageData.
    --
    -- It does NOT contain Voxel3D meshes, Love2D Images, Mat4 objects,
    -- ShadowMap objects or any other renderer-specific GPU resource.
    ----------------------------------------------------------------

    local assetCache = {}

    local EcosystemRegistry = loadLocalModule("ecosystem_registry.lua")
    assert(EcosystemRegistry, "Could not load Ecosystem visual registry")
    local TcgRegistry = loadLocalModule("tcg_registry.lua")

    local function denseArray(value)
        if type(value) ~= "table" then return false end
        local count = #value
        if count == 0 then return false end
        local entries = 0
        for key in pairs(value) do
            if type(key) ~= "number" or key % 1 ~= 0
                or key < 1 or key > count then return false end
            entries = entries + 1
        end
        return entries == count
    end

    local function finite(value)
        return type(value) == "number" and value == value
            and value ~= math.huge and value ~= -math.huge
    end

    local function loadLuaMesh(path, registry)
        if not registry or not registry.allowsMesh(path) then return nil end
        -- The injected local loader compiles with Gen1Recomp's sandboxed load.
        local ok, data = pcall(loadLocalModule, path)
        if not ok or type(data) ~= "table"
            or not denseArray(data.vertices) or not denseArray(data.indices)
            or #data.indices % 3 ~= 0 then return nil end
        for _, vertex in ipairs(data.vertices) do
            if not denseArray(vertex) or #vertex ~= 6 then return nil end
            for i = 1, 6 do
                if not finite(vertex[i]) then return nil end
            end
        end
        for _, index in ipairs(data.indices) do
            if not finite(index) or index % 1 ~= 0
                or index < 1 or index > #data.vertices then return nil end
        end
        return data
    end

    local function ecosystemReplacementFor(npc, phase, mirror, facing, observedSprite)
        if not npc or type(npc.mapId) ~= "string" or type(npc.id) ~= "string"
            or not npc.def or npc.def.owner ~= "porygonal_ecosystem"
            or type(mod.find) ~= "function" then return nil end
        local ok, ecosystem = pcall(mod.find, "porygonal_ecosystem")
        local query = ok and ecosystem and ecosystem.exports
            and ecosystem.exports.creatureVisualData
        if type(query) ~= "function" then return nil end
        local valid, visual = pcall(query, npc.mapId, npc.id, npc)
        if not valid or type(visual) ~= "table"
            or visual.mapId ~= npc.mapId or visual.npcId ~= npc.id
            or type(visual.colors) ~= "table" then return nil end
        for i = 1, 4 do
            local color = visual.colors[i]
            if type(color) ~= "table" then return nil end
            for j = 1, 3 do
                if not finite(color[j]) or color[j] < 0 or color[j] > 255 then return nil end
            end
        end
        if observedSprite and npc.sprite ~= observedSprite then return nil end
        local sprite = observedSprite or npc.sprite
        return EcosystemRegistry.lookup(visual, phase, mirror, facing,
            sprite and sprite.def, npc.groundShadow), visual.colors
    end

    local function captureBallReplacementFor(mapId, presentationId, observed)
        if type(mapId) ~= "string" or type(presentationId) ~= "string"
            or type(observed) ~= "table" or observed.mapId ~= mapId
            or observed.id ~= presentationId or observed.destroyed
            or type(mod.find) ~= "function" then return nil end
        local ok, ecosystem = pcall(mod.find, "porygonal_ecosystem")
        local query = ok and ecosystem and ecosystem.exports
            and ecosystem.exports.captureBallVisualData
        if type(query) ~= "function" then return nil end
        local valid, visual = pcall(query, mapId, presentationId, observed)
        if not valid or type(visual) ~= "table" or visual.mapId ~= mapId
            or visual.presentationId ~= presentationId then return nil end
        -- Identity is independent of replacement readiness, including palette failure.
        local castingBall = visual.role == "projectile" or visual.role == "shake"
        if not denseArray(visual.colors) or #visual.colors ~= 4 then
            return nil, nil, castingBall
        end
        for _, color in ipairs(visual.colors) do
            if not denseArray(color) or #color ~= 3 then return nil, nil, castingBall end
            for _, value in ipairs(color) do
                if not finite(value) or value < 0 or value > 255 then
                    return nil, nil, castingBall
                end
            end
        end
        return EcosystemRegistry.lookupCaptureBall(visual), visual.colors, castingBall
    end


    ----------------------------------------------------------------
    -- Load texture ImageData
    ----------------------------------------------------------------

    local function loadTextureData(path)

        local bytes =
            mod:read(path)


        if not bytes then
            return nil
        end


        local fileData =
            love.filesystem.newFileData(
                bytes,
                path
            )


        local okImageData,
              imageData =

            pcall(
                love.image.newImageData,
                fileData
            )


        if not okImageData then

            mod.log:error(
                "Could not decode texture %s: %s",
                path,
                tostring(imageData)
            )

            return nil
        end


        return imageData
    end


    ----------------------------------------------------------------
    -- Palette cache key
    ----------------------------------------------------------------

    local function paletteKey(colors)

        if not colors then
            return "raw"
        end


        local parts = {}


        for i = 1, 4 do

            local c =
                colors[i]


            if c then

                parts[#parts + 1] =
                    tostring(c[1])

                parts[#parts + 1] =
                    tostring(c[2])

                parts[#parts + 1] =
                    tostring(c[3])

            else

                parts[#parts + 1] =
                    "nil"

            end

        end


        return table.concat(
            parts,
            ","
        )
    end


 ----------------------------------------------------------------
-- Resolve active character palette
--
-- Palette policy belongs to the active version resolver.
-- CharacterRuntime only requests the resolved colors.
----------------------------------------------------------------

local function resolveCharacterColors(
    sprite,
    colors
)

    return PaletteResolver.resolve(
        versionGroup,
        PaletteFX,
        sprite,
        colors
    )
end


    local function tcgReplacementFor(npc, phase, mirror, facing, sprite, colors)
        local def = npc and npc.def
        if not TcgRegistry or not def or def.tcgNpcId ~= 0x27
            or def.name ~= "PORYGONAL_TCG_BRITTANY"
            or def.sprite ~= "SPRITE_TCG_GIRL_BLUE"
            or type(npc.mapId) ~= "string" or type(def.index) ~= "number"
            or npc.id ~= npc.mapId .. "_obj_" .. def.index
            or npc.destroyed or npc.visible == false or npc.sprite ~= sprite
            or not sprite or not sprite.def or sprite.def.walker ~= true
            or sprite.def.frames ~= 6
            or sprite.def.paletteSource ~= "ROM:SpriteSheetPointerTable[1]"
            or type(mod.find) ~= "function" or not mod.world
            or type(mod.world.npc) ~= "function" then return nil end
        local ok, tcg = pcall(mod.find, "PORYGONAL_TCG")
        if not ok or not tcg then return nil end
        -- Public native lookup checks the current pool, including neighbor maps.
        -- Compare bodies so a stale captured pose cannot replace a rebuilt NPC.
        local live, handle = pcall(mod.world.npc, mod.world, npc.mapId, def.name)
        if not live or not handle or handle.npc ~= npc then return nil end
        local valid, resolved = pcall(resolveCharacterColors, sprite, npc.objPaletteOverride or colors)
        if not valid or not denseArray(resolved) or #resolved ~= 4 then return nil end
        for _, color in ipairs(resolved) do
            if not denseArray(color) or #color ~= 3 then return nil end
            for _, value in ipairs(color) do
                if not finite(value) or value < 0 or value > 255 then return nil end
            end
        end
        return TcgRegistry.lookup(phase, mirror, facing), resolved
    end


    ----------------------------------------------------------------
    -- Recolor shared four-shade texture as ImageData
    --
    -- No love.graphics.newImage() here:
    -- GPU texture creation belongs to the active renderer.
    ----------------------------------------------------------------

    local function buildPaletteImageData(
        sourceImageData,
        colors
    )

        local width,
              height =

            sourceImageData:getDimensions()


        local output =
            love.image.newImageData(
                width,
                height
            )


        for y = 0, height - 1 do

            for x = 0, width - 1 do

                local r,
                      g,
                      b,
                      a =

                    sourceImageData:getPixel(
                        x,
                        y
                    )


                r,
                g,
                b,
                a =

                    TileRenderer.recolorSample(
                        r,
                        g,
                        b,
                        a,
                        colors
                    )


                output:setPixel(
                    x,
                    y,
                    r,
                    g,
                    b,
                    a
                )

            end

        end


        return output
    end


    ----------------------------------------------------------------
    -- Build renderer-agnostic mirrored geometry
    --
    -- X is negated and triangle winding is reversed so a renderer can
    -- safely use back-face culling on the mirrored model.
    ----------------------------------------------------------------

    local function buildMirroredMeshData(
        vertices,
        indices
    )

        local mirroredVertices = {}
        local mirroredIndices = {}


        for i, vertex in ipairs(vertices) do

            mirroredVertices[i] = {
                -vertex[1],
                vertex[2],
                vertex[3],
                vertex[4],
                vertex[5],
                vertex[6]
            }

        end


        for i = 1, #indices, 3 do

            local a =
                indices[i]

            local b =
                indices[i + 1]

            local c =
                indices[i + 2]


            mirroredIndices[#mirroredIndices + 1] =
                a

            mirroredIndices[#mirroredIndices + 1] =
                c

            mirroredIndices[#mirroredIndices + 1] =
                b

        end


        return mirroredVertices,
               mirroredIndices
    end


    ----------------------------------------------------------------
    -- Load one Porygonal asset PACKAGE
    --
    -- The returned package is renderer-agnostic.
    ----------------------------------------------------------------

    local function loadAsset(definition)

        if not definition
            or not definition.mesh then

            return nil
        end


        local key =
            tostring(definition.meshSource or "v4") .. "|"
            .. tostring(definition.paletteMode) .. "|"
            .. tostring(definition.mesh)
            .. "|"
            .. tostring(definition.texture)


        if assetCache[key] ~= nil then

            if assetCache[key] == false then
                return nil
            end


            return assetCache[key]
        end


        local meshData
        if definition.meshSource == "ecosystem_lua" then
            meshData = loadLuaMesh(definition.mesh, EcosystemRegistry)
        elseif definition.meshSource == "tcg_lua" then
            meshData = loadLuaMesh(definition.mesh, TcgRegistry)
        elseif definition.meshSource == nil then
            meshData = loadProtectedMesh(definition.mesh)
        end


        if not meshData then

            assetCache[key] =
                false

            return nil
        end


        if not meshData.vertices
            or not meshData.indices then

            mod.log:error(
                "Invalid mesh data: %s",
                tostring(definition.mesh)
            )


            assetCache[key] =
                false

            return nil
        end


        local mirroredVertices,
              mirroredIndices =

            buildMirroredMeshData(
                meshData.vertices,
                meshData.indices
            )


        local textureData =
            loadTextureData(
                definition.texture
            )


        if not textureData then

            assetCache[key] =
                false

            return nil
        end


        local asset = {

            vertices =
                meshData.vertices,

            indices =
                meshData.indices,

            mirroredVertices =
                mirroredVertices,

            mirroredIndices =
                mirroredIndices,

            textureData =
                textureData,

            paletteMode =
                definition.paletteMode,

            paletteImageData =
                {}
        }


        assetCache[key] =
            asset


        mod.log:info(
            "Loaded Porygonal asset package: %s",
            tostring(definition.mesh)
        )


        return asset
    end


    ----------------------------------------------------------------
    -- Palette-aware texture DATA
    --
    -- Returns:
    --   ImageData
    --   stable cache key for the renderer's own GPU texture cache
    ----------------------------------------------------------------

    local function textureDataFor(
        asset,
        sprite,
        colors
    )

        if asset.paletteMode
            ~= "gen1" then

            return asset.textureData,
                   "raw"
        end


        local resolvedColors =
            resolveCharacterColors(
                sprite,
                colors
            )


        if not resolvedColors then

            return asset.textureData,
                   "raw"
        end


        local key =
            paletteKey(
                resolvedColors
            )


        if asset.paletteImageData[key] then

            return asset.paletteImageData[key],
                   key
        end


        local imageData =
            buildPaletteImageData(
                asset.textureData,
                resolvedColors
            )


        asset.paletteImageData[key] =
            imageData


        return imageData,
               key
    end


    ----------------------------------------------------------------
    -- Original Gen1 sprite pose -> Porygonal identity
    ----------------------------------------------------------------

    local function getSpritePose(
        sprite,
        facing,
        phase,
        flip
    )

        if not sprite
            or not sprite.def then

            return nil,
                   nil,
                   false
        end


        local def =
            sprite.def


        local frame = 0
        local mirror = false


        if (def.frames or 1) > 1 then

            if def.walker
                and phase == 1 then

                frame =
                    SR.WALK[facing]

            else

                frame =
                    SR.STAND[facing]

            end


            --------------------------------------------------------
            -- 3D gait mirror
            --
            -- Keep the original directional mirror:
            --   left  = normal mesh
            --   right = mirrored mesh
            --
            -- But let the game's alternating `flip` drive the WALK gait
            -- in every direction, not only north/south.
            --
            -- This preserves the original result for up/down while giving
            -- east/west a complete alternating left/right step cycle.
            --
            -- XOR is important for RIGHT:
            --   direction mirror = true
            --   gait flip        = true
            --   final mirror     = false
            --------------------------------------------------------

            local directionMirror =
                facing == "right"


            local gaitMirror =
                def.walker
                and phase == 1
                and flip


            mirror =
                directionMirror
                ~= gaitMirror

        end


        return def.id,
               frame,
               mirror
    end


    -- ENG-T052's one native owner and exact ECO-T041 appearance identify Aim;
    -- image paths alone cannot establish its identity. No Ball export is used.
    local function captureAimReplacementFor(mapId, presentationId, observed, colors)
        if type(observed) ~= "table" or type(presentationId) ~= "string"
            or not presentationId:match("^porygonal_ecosystem_presentation_%d+$")
            or observed.id ~= presentationId or observed.mapId ~= mapId
            or observed.destroyed or observed.visible == false
            or type(mod.find) ~= "function" then return nil end
        local ok, ecosystem = pcall(mod.find, "porygonal_ecosystem")
        if not ok or not ecosystem then return nil end
        local layers = observed.renderLayers
        if not denseArray(layers) or #layers ~= 2 then return nil end
        for i, identity in ipairs({{"ECO_AIM_BACK", "beforeActors"},
                                   {"ECO_AIM_FRONT", "afterActors"}}) do
            local layer = layers[i]
            if type(layer) ~= "table" or layer.spriteId ~= identity[1]
                or layer.phase ~= identity[2] or layer.index ~= i
                or not layer.sprite or not layer.sprite.def
                or layer.sprite.def.paletteSource ~= "ROM:SpriteSheetPointerTable[0]"
                then return nil end
        end
        -- Resolve both native layer sprites with the existing version policy.
        -- An absent/malformed palette must never select the raw gray texture.
        if observed.objPaletteOverride then return nil end
        local resolved = {}
        for i, layer in ipairs(layers) do
            resolved[i] = resolveCharacterColors(layer.sprite, colors)
            if not denseArray(resolved[i]) or #resolved[i] ~= 4 then return nil end
            for _, color in ipairs(resolved[i]) do
                if not denseArray(color) or #color ~= 3 then return nil end
                for _, value in ipairs(color) do
                    if not finite(value) or value < 0 or value > 255 then return nil end
                end
            end
        end
        if paletteKey(resolved[1]) ~= paletteKey(resolved[2]) then return nil end
        return EcosystemRegistry.lookupCaptureAim(), resolved[1]
    end

    return {

        captureAimReplacementFor = captureAimReplacementFor,
        tcgReplacementFor = tcgReplacementFor,
        ecosystemReplacementFor = ecosystemReplacementFor,
        captureBallReplacementFor = captureBallReplacementFor,
        playerAppearanceReplacementFor = EcosystemRegistry.lookupPlayerAppearance,

        loadAsset =
            loadAsset,

        textureDataFor =
            textureDataFor,

        getSpritePose =
            getSpritePose
    }
end


return CharacterRuntime
