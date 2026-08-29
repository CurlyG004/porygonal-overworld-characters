----------------------------------------------------------------
-- Porygonal - game version identity
--
-- Single source of truth for Porygonal's active version group.
--
-- ROM detection stays in main.lua. This module only stores and
-- exposes the explicit Porygonal version identity selected at startup.
----------------------------------------------------------------

local Version = {}


----------------------------------------------------------------
-- Version groups
----------------------------------------------------------------

Version.RED_BLUE =
    "redBlue"

Version.YELLOW =
    "yellow"


----------------------------------------------------------------
-- Reserved future vocabulary
--
-- These names are intentionally declared now so the architecture
-- does not treat Red/Blue as an implicit default.
--
-- They are NOT supported by configure() yet.
----------------------------------------------------------------

Version.GOLD_SILVER =
    "goldSilver"

Version.CRYSTAL =
    "crystal"


----------------------------------------------------------------
-- Runtime state
----------------------------------------------------------------

local activeGroup =
    nil


----------------------------------------------------------------
-- Configure active version group
----------------------------------------------------------------

function Version.configure(
    group
)

    assert(
        group == Version.RED_BLUE
        or group == Version.YELLOW,
        "Unsupported Porygonal version group: "
            .. tostring(group)
    )

    activeGroup =
        group
end


----------------------------------------------------------------
-- Current version group
----------------------------------------------------------------

function Version.group()

    assert(
        activeGroup ~= nil,
        "Porygonal Version has not been configured"
    )

    return activeGroup
end


----------------------------------------------------------------
-- Convenience queries
----------------------------------------------------------------

function Version.is(
    group
)

    return Version.group()
        == group
end


function Version.isRedBlue()

    return Version.is(
        Version.RED_BLUE
    )
end


function Version.isYellow()

    return Version.is(
        Version.YELLOW
    )
end


return Version
