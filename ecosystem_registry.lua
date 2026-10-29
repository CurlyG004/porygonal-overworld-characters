-- Visual asset references only. Creature state and colors belong to Ecosystem.
local Registry = {}
local captureAim = {asset = {mesh = "assets/aim.lua", meshSource = "ecosystem_lua",
    texture = "assets/grayscale_palette.png", paletteMode = "gen1"},
    -- Authored base aligned to terrain, then raised by 3 PotatoVoxel units.
    offsetY = 2.414498}

function Registry.lookupCaptureAim()
    return captureAim
end
local meshes = {
    RATTATA = {
        idle = "assets/pkmn_019_rattata_idle.lua",
        walk = "assets/pkmn_019_rattata_walk.lua",
        lay = "assets/pkmn_019_rattata_lay.lua"
    },
    NIDORAN_M = {
        idle = "assets/pkmn_032_nidoranm_idle.lua",
        walk = "assets/pkmn_032_nidoranm_walk.lua",
        lay = "assets/pkmn_032_nidoranm_lay.lua"
    },
    NIDORAN_F = {
        idle = "assets/pkmn_029_nidoranf_idle.lua",
        walk = "assets/pkmn_029_nidoranf_walk.lua",
        lay = "assets/pkmn_029_nidoranf_lay.lua"
    },
    PIDGEY = {
        idle = "assets/pkmn_016_pidgey_idle.lua",
        walk = "assets/pkmn_016_pidgey_walk.lua",
        flyA = "assets/pkmn_016_pidgey_flyA.lua",
        flyB = "assets/pkmn_016_pidgey_flyB.lua"
    },
    SPEAROW = {
        idle = "assets/pkmn_021_spearow_idle.lua",
        walk = "assets/pkmn_021_spearow_walk.lua",
        flyA = "assets/pkmn_021_spearow_flyA.lua",
        flyB = "assets/pkmn_021_spearow_flyB.lua"
    }
}
local birdImages = {
    PIDGEY = {ground = "sprites/pidgey.png", flying = "sprites/pidgey_fly.png"},
    SPEAROW = {ground = "sprites/pkmn_021_spearow.png", flying = "sprites/pkmn_021_spearow_fly.png"}
}
-- Provisional 3D foliage calibration, in PotatoVoxel units. Native perched
-- elevation is already present; both idle meshes have their feet near Y=0.
local birdPerchedOffsetY = -11

local function matchesImage(image, path)
    if type(image) ~= "string" then return false end
    image = image:gsub("\\", "/")
    return image == path or image:sub(-#path - 1) == "/" .. path
end
local playerMeshes = {
    ECO_CAPTURE_RED_AIM = "assets/red_aim.lua",
    ECO_CAPTURE_RED_THROW = "assets/red_throw.lua"
}
local captureBallMeshes = {
    POKE_BALL = "assets/ball_poke_idle.lua",
    GREAT_BALL = "assets/ball_great_idle.lua",
    ULTRA_BALL = "assets/ball_ultra_idle.lua",
    MASTER_BALL = "assets/ball_master_idle.lua"
}
-- Provisional SOUTH depth calibration: facing +Z, so backward is -Z.
local heldBallOffsetZ = {down = -3}
-- Provisional side spacing, extending the native EAST -X / WEST +X hand anchors.
local heldBallOffsetX = {right = -1, left = 1}
-- ECO CaptureWiggles logical frames: neutral, one pixel left, one pixel right.
local shakeOffsetXByFrame = {[0] = 0, [1] = -1, [2] = 1}

function Registry.lookupCaptureBall(visual)
    if type(visual) ~= "table"
        or (visual.role ~= "projectile" and visual.role ~= "held"
            and visual.role ~= "shake") then return nil end
    local mesh = captureBallMeshes[visual.ballType]
    if not mesh then return nil end
    return {
        -- Initial artistic calibration: about one Ball height below the native
        -- frame center. PresentationObject position/elevation remain untouched.
        offsetY = visual.role == "held" and -6.2 or nil,
        offsetZByFacing = visual.role == "held" and heldBallOffsetZ or nil,
        offsetXByFacing = visual.role == "held" and heldBallOffsetX or nil,
        shakeOffsetXByFrame = visual.role == "shake" and shakeOffsetXByFrame or nil,
        asset = {mesh = mesh, meshSource = "ecosystem_lua",
        texture = "assets/grayscale_palette.png", paletteMode = "gen1"}}
end

function Registry.allowsMesh(path)
    if path == captureAim.asset.mesh then return true end
    for _, mesh in pairs(captureBallMeshes) do
        if path == mesh then return true end
    end
    for _, poses in pairs(meshes) do
        for _, mesh in pairs(poses) do
            if path == mesh then return true end
        end
    end
    for _, mesh in pairs(playerMeshes) do
        if path == mesh then return true end
    end
    return false
end

function Registry.lookupPlayerAppearance(spriteId, mirror, facing, isPlayer)
    local mesh = isPlayer == true and playerMeshes[spriteId]
    if not mesh then return nil end
    -- The raised hand is on local -X. With the existing +/-90 degree yaw,
    -- invert only AIM's side-facing mesh selection so the hand faces +Z
    -- (the normal camera side), matching the native held Ball's +Z anchor.
    if spriteId == "ECO_CAPTURE_RED_AIM" and (facing == "left" or facing == "right") then
        mirror = not mirror
    end
    return {
        asset = {
            mesh = mesh,
            meshSource = "ecosystem_lua",
            texture = "assets/grayscale_palette.png",
            paletteMode = "gen1"
        },
        mirror = mirror,
        facing = facing,
        -- Preserve the authored capture poses without procedural breathing.
        idle_animation = false
    }
end

function Registry.lookup(visual, phase, mirror, facing, spriteDef, groundShadow)
    if type(visual) ~= "table" then return nil end
    local poses = meshes[visual.species]
    if not poses then return nil end
    local pose, castShadow, flightHeading, offsetY
    local bird = birdImages[visual.species]
    if visual.state == "KO" then
        pose = "lay"
    elseif visual.state == "ACTIVE" or visual.state == "CAPTURE_OWNED" then
        -- Capture ownership does not itself hide the native body. Impact and
        -- breakout can still show its current appearance; visibility is native.
        pose = phase == 1 and "walk" or "idle"
        if bird then
            -- Creature.state stays ACTIVE throughout Bird locomotion. Use the
            -- actual native appearance, including TAKEOFF/LANDING/RECOVERING.
            if type(spriteDef) ~= "table" then return nil end
            if matchesImage(spriteDef.image, bird.flying) and spriteDef.walker == true then
                pose = phase == 1 and "flyB" or "flyA"
                mirror = facing == "right"
                castShadow = groundShadow
                flightHeading = true
            elseif matchesImage(spriteDef.image, bird.ground) then
                if spriteDef.walker ~= true then
                    pose = "idle" -- Native PERCHED has only standing frames.
                    castShadow = groundShadow
                    offsetY = birdPerchedOffsetY
                end
            else
                return nil
            end
        end
    else
        return nil
    end
    if not poses[pose] then return nil end
    return {
        asset = {
            mesh = poses[pose],
            meshSource = "ecosystem_lua",
            texture = "assets/grayscale_palette.png",
            paletteMode = "gen1"
        },
        mirror = mirror,
        facing = facing,
        idle_animation = pose ~= "flyA" and pose ~= "flyB",
        cast_shadow = castShadow,
        flight_heading = flightHeading,
        offsetY = offsetY
    }
end

return Registry
