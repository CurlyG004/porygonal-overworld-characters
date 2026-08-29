local Tuning,
      Version = ...


local Registry = {}

if type(Version) ~= "table"
    or type(Version.group) ~= "function" then

    error(
        "character_registry.lua expected Version module"
    )
end
----------------------------------------------------------------
-- Persistent user tuning
--
-- Tuning is injected by main.lua after loading character_tuning.lua
-- through the mod-local loader. Registry therefore stays independent
-- from filesystem/package.path details.
----------------------------------------------------------------

if type(Tuning) ~= "table" then
    error(
        "character_registry.lua expected attributes_tuning table"
    )
end


----------------------------------------------------------------
-- Active game/version profile
--
-- Red + Blue share the current base assets. Yellow adds only its
-- own assets/overrides, using the suffix `_Y`.
--
-- Keep symbolic sprite IDs as Registry keys: numeric sprite values
-- differ between Red/Blue and Yellow after SPRITE_SEEL.
----------------------------------------------------------------

local VERSION_GROUP =
    Version.group()


local IS_RED_BLUE =
    VERSION_GROUP
        == Version.RED_BLUE


local IS_YELLOW =
    VERSION_GROUP
        == Version.YELLOW


assert(
    IS_RED_BLUE
        or IS_YELLOW,
    "Unsupported Registry version group: "
        .. tostring(VERSION_GROUP)
)


Registry.version = {
    group =
        VERSION_GROUP,

    asset_group =
        IS_YELLOW
        and "Y"
        or "RB"
}
----------------------------------------------------------------
-- Global Porygonal asset convention
----------------------------------------------------------------

local ASSET_ROOT =
    "assets/"

local CHARACTER_PALETTE =
    ASSET_ROOT
    .. "grayscale_palette.png"


----------------------------------------------------------------
-- Active player character
--
-- Surf temporarily replaces the player's VISUAL sprite with SEEL.
-- Recomp does not expose the original RED/YELLOW sprite ID through
-- that visual pose, so Surf must resolve the rider from a stable
-- Porygonal-side player configuration instead.
--
-- Change "red" later if/when another playable character is selected.
----------------------------------------------------------------

Registry.player = {
    base = "red"
}


----------------------------------------------------------------
-- Procedural idle life
--
-- Artistic values should live in character_tuning.lua.
-- Defaults are kept here only as a safe fallback so older tuning
-- files remain compatible.
----------------------------------------------------------------

Registry.idle_animation =
    Tuning.idle_animation
    or {
        enabled = true,

        speed = 1.15,

        scale_y = 0.012,

        scale_xz = 0.003
    }


----------------------------------------------------------------
-- Player-specific authored states
--
-- Bicycle assets are resolved automatically when Recomp switches
-- the player's visual sprite to a bike/bicycle sprite:
--
--   assets/<player>_bike_idle.lua
--   assets/<player>_bike_walk.lua
----------------------------------------------------------------


----------------------------------------------------------------
-- Fly mount
--
-- Generic mounted-player pose convention:
--   assets/<player>_mount_walk.lua
--
-- Fly alternates between:
--   assets/bird_idle.lua
--   assets/bird_walk.lua
--   assets/<player>_mount_idle.lua
--   assets/<player>_mount_walk.lua
--
-- flying_offset:
--   positions the flying creature relative to the animation anchor.
--
-- rider_offset:
--   is added on top of flying_offset for the mounted character.
----------------------------------------------------------------

Registry.fly_mount = {

    base = "bird",

    ------------------------------------------------------------
    -- Geometry comes from Bird's own persistent mount tuning.
    -- The renderer still receives the semantic Fly field name
    -- `flying_offset`, but the source value belongs to Bird.
    ------------------------------------------------------------

    flying_offset =
        Tuning.mounts.bird.mount_offset,

    rider_offset =
        Tuning.mounts.bird.rider_offset
}


----------------------------------------------------------------
-- Fly world-space trajectory
--
-- Values come from character_tuning.lua.
-- All distances are expressed in world units.
--
-- takeoff:
--   time spent mounted at the player's position before departure.
--
-- offscreen:
--   duration between departure and return pass.
--   The composite stays visible at the end of the departure path and
--   keeps alternating idle/walk during this phase.
----------------------------------------------------------------

Registry.fly_animation =
    Tuning.fly.animation


----------------------------------------------------------------
-- Gen1Recomp sprite ID -> Porygonal basename
--
-- Naming convention:
--
-- WALKER:
--   assets/<base>_idle.lua
--   assets/<base>_walk.lua
--
-- OPTIONAL SPECIAL ASSET:
--   assets/<base>_spe1.lua
--
-- STATIC:
--   assets/<base>_idle.lua
--
-- Shared texture:
--   assets/grayscale_palette.png
----------------------------------------------------------------

Registry.characters = {

    ----------------------------------------------------------------
    -- Main characters
    ----------------------------------------------------------------

    SPRITE_RED = {
        base = "red"
    },

    SPRITE_BLUE = {
        base = "blue"
    },

    SPRITE_OAK = {
        base = "oak"
    },


    ----------------------------------------------------------------
    -- Overworld characters / NPCs
    ----------------------------------------------------------------

    SPRITE_YOUNGSTER = {
        base = "youngster"
    },

    SPRITE_MONSTER = {
        base = "monster"
    },

    SPRITE_COOLTRAINER_F = {
        base = "cooltrainer_f"
    },

    SPRITE_COOLTRAINER_M = {
        base = "cooltrainer_m",

        ------------------------------------------------------------
        -- Optional authored-figure replacement.
        --
        -- Dramatic Shape identifies the seated Pokémon Center person
        -- as an authored FIGURE cut from the tileset, not as the normal
        -- Cooltrainer billboard. The logical map entity remains useful
        -- as the stable identity anchor for Porygonal.
        ------------------------------------------------------------

        spe1 = {

            --------------------------------------------------------
            -- Pokémon Center seated authored FIGURE orientation.
            --
            -- The renderer now identifies that FIGURE directly on
            -- Pokémon Center maps. No logical NPC/entity-name match
            -- is involved here.
            --------------------------------------------------------

            yaw =
                math.rad(90)
        }
    },

    SPRITE_LITTLE_GIRL = {
        base = "little_girl"
    },

    SPRITE_BIRD = {
        base = "bird"
    },

    SPRITE_MIDDLE_AGED_MAN = {
        base = "middle_aged_man"
    },

    SPRITE_GAMBLER = {
        base = "gambler"
    },

    SPRITE_SUPER_NERD = {
        base = "super_nerd"
    },

    SPRITE_GIRL = {
        base = "girl"
    },

    SPRITE_HIKER = {
        base = "hiker"
    },

    SPRITE_BEAUTY = {
        base = "beauty"
    },

    SPRITE_GENTLEMAN = {
        base = "gentleman"
    },

    SPRITE_DAISY = {
        base = "daisy"
    },

    SPRITE_BIKER = {
        base = "biker"
    },

    SPRITE_SAILOR = {
        base = "sailor"
    },

    SPRITE_COOK = {
        base = "cook"
    },

    SPRITE_BIKE_SHOP_CLERK = {
        base = "bike_shop_clerk"
    },

    SPRITE_MR_FUJI = {
        base = "mr_fuji"
    },

    SPRITE_GIOVANNI = {
        base = "giovanni"
    },

    SPRITE_ROCKET = {
        base = "rocket"
    },

    SPRITE_CHANNELER = {
        base = "channeler"
    },

    SPRITE_WAITER = {
        base = "waiter"
    },

    SPRITE_SILPH_WORKER_F = {
        base = "silph_worker_f"
    },

    SPRITE_MIDDLE_AGED_WOMAN = {
        base = "middle_aged_woman"
    },

    SPRITE_BRUNETTE_GIRL = {
        base = "brunette_girl"
    },

    SPRITE_LANCE = {
        base = "lance"
    },


    ----------------------------------------------------------------
    -- Scientist
    --
    -- Two ROM IDs share the same visual asset.
    ----------------------------------------------------------------

    SPRITE_UNUSED_SCIENTIST = {
        base = "scientist"
    },

    SPRITE_SCIENTIST = {
        base = "scientist"
    },


    ----------------------------------------------------------------
    -- More overworld NPCs
    ----------------------------------------------------------------

    SPRITE_ROCKER = {
        base = "rocker"
    },

    SPRITE_SWIMMER = {
        base = "swimmer"
    },

    SPRITE_SAFARI_ZONE_WORKER = {
        base = "safari_zone_worker"
    },

    SPRITE_GYM_GUIDE = {
        base = "gym_guide"
    },

    SPRITE_GRAMPS = {
        base = "gramps"
    },

    SPRITE_CLERK = {
        base = "clerk"
    },

    SPRITE_FISHING_GURU = {
        base = "fishing_guru"
    },

    SPRITE_GRANNY = {
        base = "granny"
    },

    SPRITE_NURSE = {
        -- Same symbolic ID in all Gen 1 versions, but Yellow uses
        -- distinct authored artwork/model assets.
        base = IS_YELLOW and "nurse_Y" or "nurse"
    },

    SPRITE_LINK_RECEPTIONIST = {
        base = "link_receptionist"
    },

    SPRITE_SILPH_PRESIDENT = {
        base = "silph_president"
    },

    SPRITE_SILPH_WORKER_M = {
        base = "silph_worker_m"
    },

    SPRITE_WARDEN = {
        base = "warden"
    },

    SPRITE_CAPTAIN = {
        base = "captain"
    },

    SPRITE_FISHER = {
        base = "fisher"
    },

    SPRITE_KOGA = {
        base = "koga"
    },


    ----------------------------------------------------------------
    -- Guards
    ----------------------------------------------------------------

    SPRITE_GUARD = {
        base = "guard"
    },

    SPRITE_UNUSED_GUARD = {
        base = "guard"
    },


    ----------------------------------------------------------------
    -- Remaining overworld characters
    ----------------------------------------------------------------

    SPRITE_MOM = {
        base = "mom"
    },

    SPRITE_BALDING_GUY = {
        base = "balding_guy"
    },

    SPRITE_LITTLE_BOY = {
        base = "little_boy"
    },


    ----------------------------------------------------------------
    -- Gameboy Kid
    ----------------------------------------------------------------

    SPRITE_UNUSED_GAMEBOY_KID = {
        base = "gameboy_kid"
    },

    SPRITE_GAMEBOY_KID = {
        base = "gameboy_kid"
    },


    ----------------------------------------------------------------
    -- Special characters / creatures
    ----------------------------------------------------------------

    SPRITE_FAIRY = {
        base = "fairy"
    },

    SPRITE_AGATHA = {
        base = "agatha"
    },

    SPRITE_BRUNO = {
        base = "bruno"
    },

    SPRITE_LORELEI = {
        base = "lorelei"
    },

    SPRITE_SEEL = {
        base = "seel",

        ------------------------------------------------------------
        -- Optional Surf mount configuration.
        --
        -- The normal overworld creature still uses:
        --   seel_idle.lua
        --   seel_walk.lua
        --
        -- These offsets are only applied when THIS visual sprite is
        -- being used by the PLAYER as a Surf mount.
        --
        -- floating_offset:
        --   Moves the creature relative to the water/world anchor.
        --   Useful later for Pokémon that need to sit deeper in water.
        --
        -- rider_offset:
        --   Added ON TOP of floating_offset for the rider.
        --   It is expressed in mount-local coordinates and therefore
        --   follows the mount/player facing.
        ------------------------------------------------------------

        surf_mount = {

            --------------------------------------------------------
            -- Geometry belongs to Seel itself.
            -- `floating_offset` remains the renderer-facing Surf
            -- semantic name, but its source is Seel.mount_offset.
            --------------------------------------------------------

            floating_offset =
                Tuning.mounts.seel.mount_offset,

            rider_offset =
                Tuning.mounts.seel.rider_offset
        }
    },


    ----------------------------------------------------------------
    -- STATIC OVERWORLD OBJECTS
    --
    -- These use only:
    --
    -- assets/<base>_idle.lua
    --
    -- They do not use walk, facing rotation or mirror.
    ----------------------------------------------------------------

    SPRITE_POKE_BALL = {
        base = "poke_ball",
        type = "static",
        idle_animation = false
    },

    SPRITE_FOSSIL = {
        base = "fossil",
        type = "static",
        idle_animation = false
    },

    SPRITE_BOULDER = {
        base = "boulder",
        type = "static",
        idle_animation = false
    },

    SPRITE_PAPER = {
        base = "paper",
        type = "static",
        idle_animation = false
    },

    SPRITE_POKEDEX = {
        base = "pokedex",
        type = "static",
        idle_animation = false
    },

    SPRITE_CLIPBOARD = {
        base = "clipboard",
        type = "static",
        idle_animation = false
    },

    SPRITE_SNORLAX = {
        base = "snorlax",
        type = "static"
    },


    ----------------------------------------------------------------
    -- Old Amber
    --
    -- Both IDs use the same asset.
    ----------------------------------------------------------------

    SPRITE_UNUSED_OLD_AMBER = {
        base = "old_amber",
        type = "static",
        idle_animation = false
    },

    SPRITE_OLD_AMBER = {
        base = "old_amber",
        type = "static",
        idle_animation = false
    },


    ----------------------------------------------------------------
    -- Gambler asleep
    --
    -- Three IDs use the same visual asset.
    ----------------------------------------------------------------

    SPRITE_UNUSED_GAMBLER_ASLEEP_1 = {
        base = "gambler_asleep",
        type = "static"
    },

    SPRITE_UNUSED_GAMBLER_ASLEEP_2 = {
        base = "gambler_asleep",
        type = "static"
    },

    SPRITE_GAMBLER_ASLEEP = {
        base = "gambler_asleep",
        type = "static"
    }

}


----------------------------------------------------------------
-- Pokémon Yellow-only overworld sprites
--
-- Yellow inserts ten animated overworld sprite IDs after SEEL.
-- Asset naming convention:
--
--   assets/<name>_Y_idle.lua
--   assets/<name>_Y_walk.lua
--
-- Numeric IDs below are Yellow overworld IDs for documentation only.
-- Runtime matching stays SYMBOLIC so Red/Blue's shifted numeric IDs
-- never collide with Yellow.
----------------------------------------------------------------

if IS_YELLOW then

    Registry.characters.SPRITE_PIKACHU = {
        -- Yellow: $3D / 61
        base = "pikachu_Y"
    }

    Registry.characters.SPRITE_OFFICER_JENNY = {
        -- Yellow: $3E / 62
        base = "officer_jenny_Y"
    }

    Registry.characters.SPRITE_SANDSHREW = {
        -- Yellow: $3F / 63
        base = "sandshrew_Y"
    }

    Registry.characters.SPRITE_ODDISH = {
        -- Yellow: $40 / 64
        base = "oddish_Y"
    }

    Registry.characters.SPRITE_BULBASAUR = {
        -- Yellow: $41 / 65
        base = "bulbasaur_Y"
    }

    Registry.characters.SPRITE_JIGGLYPUFF = {
        -- Yellow: $42 / 66
        base = "jigglypuff_Y"
    }

    Registry.characters.SPRITE_CLEFAIRY = {
        -- Yellow: $43 / 67
        base = "clefairy_Y"
    }

    Registry.characters.SPRITE_CHANSEY = {
        -- Yellow: $44 / 68
        base = "chansey_Y"
    }

    Registry.characters.SPRITE_JESSIE = {
        -- Yellow: $45 / 69
        base = "jessie_Y"
    }

    Registry.characters.SPRITE_JAMES = {
        -- Yellow: $46 / 70
        base = "james_Y"
    }
end


----------------------------------------------------------------
-- Build asset definition automatically
--
-- Example:
--
-- base = "girl"
-- pose = "walk"
--
-- ->
--
-- assets/girl_walk.lua
----------------------------------------------------------------

local function buildAsset(
    base,
    pose
)

    return {

        mesh =
            ASSET_ROOT
            .. base
            .. "_"
            .. pose
            .. ".lua",

        texture =
            CHARACTER_PALETTE,

        paletteMode =
            "gen1"
    }

end


----------------------------------------------------------------
-- Fly composite lookup
--
-- Kept in the Registry so the renderer only receives a semantic
-- composite definition and does not hard-code asset filenames.
----------------------------------------------------------------

function Registry.lookupFly(pose)

    pose =
        pose
        or "walk"


    local mount =
        Registry.fly_mount


    local rider =
        Registry.player


    if not mount
        or not mount.base
        or not rider
        or not rider.base then

        return nil
    end


    return {

        type =
            "fly_composite",

        flying_offset =
            mount.flying_offset,

        rider_offset =
            mount.rider_offset,

        parts = {

            {
                role =
                    "mount",

                asset =
                    buildAsset(
                        mount.base,
                        pose
                    )
            },

            {
                role =
                    "rider",

                asset =
                    buildAsset(
                        rider.base
                        .. "_mount",
                        pose
                    )
            }
        }
    }
end


----------------------------------------------------------------
-- Pokémon Center authored-figure special lookup
--
-- The seated character is emitted by Dramatic Shape as an authored
-- FIGURE rather than a normal SpriteBillboards entity. The renderer
-- identifies that FIGURE directly on Pokémon Center maps.
----------------------------------------------------------------

function Registry.lookupPokecenterSeatedFigure()

    local character =
        Registry.characters[
            "SPRITE_COOLTRAINER_M"
        ]


    if not character
        or not character.base then

        return nil
    end


    local spe1 =
        character.spe1
        or {}


    return {

        spriteId =
            "SPRITE_COOLTRAINER_M",

        pose =
            "spe1",

        asset =
            buildAsset(
                character.base,
                "spe1"
            ),

        facing =
            "down",

        mirror =
            false,

        yaw =
            spe1.yaw
            or math.rad(90)
    }
end


----------------------------------------------------------------
-- Registry lookup
----------------------------------------------------------------

function Registry.lookup(
    spriteId,
    frame,
    mirror,
    facing,
    context
)


----------------------------------------------------------------
-- PLAYER FISHING
--
-- Fishing is an explicit player semantic state supplied by the
-- renderer bridge. The fishing rod is authored directly into the
-- player mesh; it is not a separate Porygonal asset.
--
-- Asset:
--   assets/<player>_fishing_idle.lua
----------------------------------------------------------------

if context
    and context.isPlayer
    and context.fishing then

    local player =
        Registry.player


    if player
        and player.base then

        return {
            type =
                "fishing",

            asset =
                buildAsset(
                    player.base
                    .. "_fishing",
                    "idle"
                ),

            facing =
                facing,

            mirror =
                mirror
        }
    end
end


    ------------------------------------------------------------
    -- PLAYER BICYCLE VISUAL SWITCH
    --
    -- Gen1/Recomp may expose the bicycle as a simple replacement
    -- of the player's current visual sprite rather than as a separate
    -- world entity/composite.
    --
    -- We keep recognition deliberately semantic:
    --   * player only
    --   * symbolic sprite id contains BIKE/BICYCLE, OR
    --   * current sprite image path contains bike/bicycle
    --
    -- This cannot collide with NPC SPRITE_BIKER or the bike-shop
    -- clerk because `context.isPlayer` is required.
    --
    -- Assets:
    --   assets/<player>_bike_idle.lua
    --   assets/<player>_bike_walk.lua
    ------------------------------------------------------------

    if context
        and context.isPlayer then

        local idText =
            string.upper(
                tostring(
                    spriteId
                    or ""
                )
            )


        local imageText =
            string.lower(
                tostring(
                    context.spriteImage
                    or ""
                )
            )


        local isBikeVisual =
            string.find(
                idText,
                "BIKE",
                1,
                true
            ) ~= nil
            or string.find(
                idText,
                "BICYCLE",
                1,
                true
            ) ~= nil
            or string.find(
                imageText,
                "bike",
                1,
                true
            ) ~= nil
            or string.find(
                imageText,
                "bicycle",
                1,
                true
            ) ~= nil


        if isBikeVisual then

            local player =
                Registry.player


            if player
                and player.base then

                local pose =
                    (
                        frame == 3
                        or frame == 4
                        or frame == 5
                    )
                    and "walk"
                    or "idle"


                return {

                    type =
                        "bike",

                    asset =
                        buildAsset(
                            player.base
                            .. "_bike",
                            pose
                        ),

                    facing =
                        facing,

                    mirror =
                        mirror
                }
            end
        end
    end


    local character =
        Registry.characters[
            spriteId
        ]


    ----------------------------------------------------------------
    -- Unknown sprite
    --
    -- Dramatic Shape keeps rendering its original sprite.
    ----------------------------------------------------------------

    if not character then
        return nil
    end


    ----------------------------------------------------------------
    -- PLAYER SURF COMPOSITE
    --
    -- Recomp uses SPRITE_SEEL as the player's visual sprite while
    -- surfing. The SAME sprite ID is also used by ordinary overworld
    -- creatures, so isPlayer is the discriminator.
    --
    -- The active player base is supplied by Registry.player because
    -- pose() has already substituted the Surf visual sprite at this point.
    -- That lets us resolve:
    --
    --   Seel creature:
    --       seel_idle / seel_walk
    --
    --   Player surfing on Seel:
    --       seel_idle / seel_walk
    --       +
    --       <player>_mount_idle / <player>_mount_walk
    ----------------------------------------------------------------

    if context
        and context.isPlayer
        and character.surf_mount then

        local riderCharacter =
            Registry.player


        if riderCharacter
            and riderCharacter.base then

            local pose =
                (
                    frame == 3
                    or frame == 4
                    or frame == 5
                )
                and "walk"
                or "idle"


            return {

                type =
                    "composite",

                facing =
                    facing,

                mirror =
                    mirror,

                floating_offset =
                    character.surf_mount.floating_offset,

                rider_offset =
                    character.surf_mount.rider_offset,

                parts = {

                    {
                        role =
                            "mount",

                        asset =
                            buildAsset(
                                character.base,
                                pose
                            ),

                        mirror =
                            mirror
                    },

                    {
                        role =
                            "rider",

                        asset =
                            buildAsset(
                                riderCharacter.base
                                .. "_mount",
                                pose
                            ),

                        mirror =
                            mirror
                    }
                }
            }
        end
    end


    ----------------------------------------------------------------
    -- STATIC OBJECT
    --
    -- Always uses a single idle mesh.
    --
    -- Orientation is fixed to DOWN / +Z.
    -- Mirror is disabled.
    ----------------------------------------------------------------

    if character.type == "static" then

        return {

            asset =
                buildAsset(
                    character.base,
                    "idle"
                ),

            facing =
                "down",

            mirror =
                false,

            idle_animation =
                character.idle_animation    
        }

    end


    ----------------------------------------------------------------
    -- CHARACTER IDLE
    --
    -- Gen1:
    --
    -- frame 0 = down
    -- frame 1 = up
    -- frame 2 = side
    ----------------------------------------------------------------

    if frame == 0
        or frame == 1
        or frame == 2 then

        return {

            asset =
                buildAsset(
                    character.base,
                    "idle"
                ),

            facing =
                facing,

            mirror =
                mirror
        }

    end


    ----------------------------------------------------------------
    -- CHARACTER WALK
    --
    -- Gen1:
    --
    -- frame 3 = down walk
    -- frame 4 = up walk
    -- frame 5 = side walk
    ----------------------------------------------------------------

    if frame == 3
        or frame == 4
        or frame == 5 then

        return {

            asset =
                buildAsset(
                    character.base,
                    "walk"
                ),

            facing =
                facing,

            mirror =
                mirror
        }

    end


    ----------------------------------------------------------------
    -- Unsupported frame
    ----------------------------------------------------------------

    return nil
end


return Registry