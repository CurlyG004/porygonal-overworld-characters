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
                    isOpaque = true,
                    scroll = 1
                }

                local function wrapWords(
                    value,
                    maxChars
                )

                    local source =
                        text(
                            value,
                            "unknown"
                        )

                    local lines = {}
                    local current = ""

                    for word in string.gmatch(
                        source,
                        "%S+"
                    ) do

                        local candidate =
                            current == ""
                            and word
                            or (
                                current
                                .. " "
                                .. word
                            )

                        if #candidate
                            <= maxChars then

                            current =
                                candidate

                        else

                            if current
                                ~= "" then

                                lines[
                                    #lines + 1
                                ] = current
                            end

                            current = word
                        end
                    end

                    if current
                        ~= "" then

                        lines[
                            #lines + 1
                        ] = current
                    end

                    if #lines == 0 then
                        lines[1] = "unknown"
                    end

                    return lines
                end


                local function buildLines()

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

                    local lines = {
                        "-PORYGONAL:",
                        " V" .. text(
                            porygonalVersion
                        ),
                        "-ADAPTER:"
                    }

                    local wrappedTarget =
                        wrapWords(
                            targetName,
                            16
                        )

                    for _, line in ipairs(
                        wrappedTarget
                    ) do

                        lines[
                            #lines + 1
                        ] = " " .. line
                    end

                    lines[
                        #lines + 1
                    ] = " V" .. text(
                        adapterVersion
                    )

                    lines[
                        #lines + 1
                    ] = "-TESTED ON MOD:"

                    lines[
                        #lines + 1
                    ] = " V" .. text(
                        validatedVersion
                    )

                    return lines
                end


                function self:update(dt)

                    local lines =
                        buildLines()

                    local visibleLines = 6

                    local maxScroll =
                        math.max(
                            1,
                            #lines
                            - visibleLines
                            + 1
                        )

                    if game.input:wasPressed(
                        "up"
                    ) then

                        self.scroll =
                            math.max(
                                1,
                                self.scroll - 1
                            )
                    end

                    if game.input:wasPressed(
                        "down"
                    ) then

                        self.scroll =
                            math.min(
                                maxScroll,
                                self.scroll + 1
                            )
                    end

                    if game.input:wasPressed(
                        "b"
                    ) then

                        game.stack:pop()
                    end
                end


                function self:draw()

                    local lines =
                        buildLines()

                    Font.drawBox(
                        0,
                        0,
                        20,
                        18
                    )

                    local displayLines =
                        lines

                    local visibleLines = 6

                    local maxScroll =
                        math.max(
                            1,
                            #displayLines
                            - visibleLines
                            + 1
                        )

                    self.scroll =
                        math.min(
                            self.scroll,
                            maxScroll
                        )

                    for i = 1,
                        visibleLines do

                        local line =
                            displayLines[
                                self.scroll
                                + i
                                - 1
                            ]

                        if line then

                            Font.draw(
                                line,
                                16,
                                16
                                + (i - 1) * 16
                            )
                        end
                    end

                    if self.scroll > 1 then
                        Font.draw(
                            "^",
                            144,
                            48
                        )
                    end

                    if self.scroll
                        < maxScroll then

                        Font.draw(
                            "v",
                            144,
                            112
                        )
                    end

                    Font.draw(
                        "B:BACK",
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

            rows[#rows + 1] = {
                id = "porygonal",
                label = "PORYGONAL",
                activate = function(currentGame)
                    mod.ui.push(
                        currentGame,
                        SCREEN_ID
                    )
                end
            }

            return rows
        end
    )


    return true
end


return PorygonalOptions
