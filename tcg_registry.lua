-- Visual references only; identity, movement and duels remain native to TCG.
local Registry = {}
local meshes = {
    idle = "assets/tcg_brittany_idle.lua",
    walk = "assets/tcg_brittany_walk.lua"
}

function Registry.allowsMesh(path)
    return path == meshes.idle or path == meshes.walk
end

function Registry.lookup(phase, mirror, facing)
    return {
        asset = {mesh = phase == 1 and meshes.walk or meshes.idle,
            meshSource = "tcg_lua", texture = "assets/grayscale_palette.png",
            paletteMode = "gen1"},
        mirror = mirror,
        facing = facing
    }
end

return Registry
