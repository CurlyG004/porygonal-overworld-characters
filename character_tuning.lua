----------------------------------------------------------------
-- Porygonal - persistent attributes tuning
--
-- THIS FILE IS MEANT TO BE EDITED BY HAND.
--
-- Mount geometry belongs to the MOUNT, not to the action that uses it.
-- This means Seel keeps its own offsets whether it is used for Surf,
-- and Bird keeps its own offsets whether it is used for Fly.
--
-- Future mounts can simply be added under `mounts`.
--
-- Coordinates are world-space units.
----------------------------------------------------------------

return {

    ------------------------------------------------------------
    -- Per-mount visual tuning
    ------------------------------------------------------------

    mounts = {

        --------------------------------------------------------
        -- SEEL
        --
        -- mount_offset:
        --   Position of Seel relative to the Surf/world anchor.
        --
        -- rider_offset:
        --   Position of the player relative to Seel.
        --   This is added on top of mount_offset.
        --------------------------------------------------------

        seel = {

            mount_offset = {
                x = 0,
                y = 0,
                z = 0
            },

            rider_offset = {
                x = 0,
                y = 5.3,
                z = 0
            }
        },


        --------------------------------------------------------
        -- BIRD
        --
        -- mount_offset:
        --   Position of Bird relative to the Fly animation anchor.
        --
        -- rider_offset:
        --   Position of the player relative to Bird.
        --   This is added on top of mount_offset.
        --------------------------------------------------------

        bird = {

            mount_offset = {
                x = 0,
                y = 0,
                z = 0
            },

            rider_offset = {
                x = 0,
                y = 8,
                z = -5
            }
        }
    },


    ------------------------------------------------------------
    -- Action-specific tuning
    --
    -- Fly trajectory belongs to the Fly action, not to Bird itself.
    ------------------------------------------------------------

    fly = {

        animation = {

            -- Time mounted at the player position before departure.
            takeoff =
                0.50,

            -- First pass: player position -> +X / +Y.
            departure_duration =
                0.55,

            departure_distance =
                64,

            departure_height =
                28,

            -- Time spent at the end of the first pass.
            -- The composite remains visible and keeps animating.
            offscreen =
                0.30,

            -- Second pass: +X -> -X.
            return_duration =
                1.05,

            return_distance =
                64,

            return_height =
                45,

            -- Destination: +X / +Y -> exact player position.
            landing_duration =
                0.80,

            landing_distance =
                64,

            landing_height =
                28,

            -- Short mounted pause before normal player rendering resumes.
            settle =
                0.18
        }
    },

    ----------------------------------------------------------------
    -- Idle
    ----------------------------------------------------------------

    idle_animation = {

        enabled =
            true,

        -- Breathing cycles per second-ish. Lower = calmer.
        speed =
            0.70,

        -- Vertical expansion. 0.012 = +1.2% at the top of the cycle.
        scale_y =
            0.03,

        -- Small inverse X/Z compression to avoid looking like uniform zoom.
        scale_xz =
            0.02
    },

}

