----------------------------------------------------------------
-- Porygonal - Options UI
--
-- Adds a PORYGONAL row to Gen1Recomp's OPTION menu and exposes
-- renderer-adapter compatibility metadata on a dedicated screen.
----------------------------------------------------------------

local PorygonalOptions = {}

local SCREEN_ID = "PorygonalOptions"

local function text(value, fallback)
    if value == nil or value == "" then
        return fallback or "unknown"
    end
    return tostring(value)
end

function PorygonalOptions.install(
    mod,
    RendererManager
)

    ----------------------------------------------------------------
    -- Dedicated Porygonal information screen
    ----------------------------------------------------------------

    mod.content.screens:register(
        SCREEN_ID,
        {
            new = function(game)

                local Font =
                    mod.ui.Font

                local self = {
                    game = game,
                    isOpaque = true
                }

                function self:update(dt)
                    if game.input:wasPressed("b")
                        or game.input:wasPressed("a") then

                        game.stack:pop()
                    end
                end

                function self:draw()

                    local active =
                        RendererManager.getActive
                        and RendererManager.getActive()
                        or nil

                    local info =
                        active
                        and active.info
                        or nil

                    local target =
                        info
                        and info.targetMod
                        or nil

                    local targetName =
                        target
                        and target.name
                        or (
                            active
                            and active.name
                            or "No active adapter"
                        )

                    local adapterVersion =
                        info
                        and info.adapterVersion
                        or "unknown"

                    local validatedVersion =
                        target
                        and target.validatedVersion
                        or "unknown"

                    local porygonalVersion =
                        info
                        and info.porygonalVersion
                        or "unknown"

                    Font.drawBox(
                        0,
                        0,
                        20,
                        18
                    )

                    Font.draw(
                        "PORYGONAL",
                        16,
                        16
                    )

                    Font.draw(
                        "OVERWORLD CHARACTERS",
                        16,
                        32
                    )

                    Font.draw(
                        "VERSION " ..
                        text(
                            porygonalVersion
                        ),
                        16,
                        48
                    )

                    Font.draw(
                        "ACTIVE ADAPTER",
                        16,
                        64
                    )

                    Font.draw(
                        text(
                            targetName,
                            "No active adapter"
                        ),
                        16,
                        80
                    )

                    Font.draw(
                        "ADAPTER " ..
                        text(
                            adapterVersion
                        ),
                        16,
                        96
                    )

                    Font.draw(
                        "VALIDATED MOD " ..
                        text(
                            validatedVersion
                        ),
                        16,
                        112
                    )

                    Font.draw(
                        "B: BACK",
                        16,
                        128
                    )
                end

                return self
            end
        }
    )


    ----------------------------------------------------------------
    -- OPTION menu row
    ----------------------------------------------------------------

    mod.hooks:wrap(
        "ui.options.rows",
        function(
            next,
            game,
            rows
        )

            rows =
                next(
                    game,
                    rows
                )
                or rows

            mod.ui.insertBefore(
                rows,
                "CANCEL",
                {
                    label = "PORYGONAL",
                    onSelect = function()
                        mod.ui.push(
                            game,
                            SCREEN_ID
                        )
                    end
                }
            )

            return rows
        end
    )


    return true
end


return PorygonalOptions
