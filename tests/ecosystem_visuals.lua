-- Run from OWC: luajit tests/ecosystem_visuals.lua
-- Headless contract tests; sibling checkouts are read only.
package.path = "../gen1recomp-lab/?.lua;" .. package.path
local checks = 0
local function check(value, message)
    assert(value, message)
    checks = checks + 1
end
local function read(path)
    local file = assert(io.open(path, "rb"))
    local bytes = file:read("*a")
    file:close()
    return bytes
end
local recolor = dofile("../gen1recomp-lab/src/render/AtlasBake.lua").recolorSample
package.loaded["src.render.TileRenderer"] = {recolorSample = recolor}
package.loaded["src.render.SpriteRenderer"] = {
    WALK = {down=1, up=3, left=5, right=5},
    STAND = {down=0, up=2, left=4, right=4}
}
local gbc = false
package.loaded["src.render.PaletteFX"] = {usesGbcPack=function() return gbc end}
local gpuFail, textureFail, nextMesh = false, false, 0
local function imageData()
    return {
        pixels = {},
        getDimensions=function() return 4, 1 end,
        getPixel=function(_, x) local shade = 1-x/3; return shade, shade, shade, 1 end,
        setPixel=function(self, x, _, ...) self.pixels[x+1] = {...} end
    }
end
love = {
    filesystem = {newFileData=function(bytes) return bytes end},
    image = {newImageData=imageData},
    graphics = {
        newImage=function(data)
            if textureFail then error("recoverable texture failure") end
            return {data=data, setFilter=function() end}
        end,
        getRendererInfo=function() return "OpenGL" end,
        setMeshCullMode=function() end
    },
    timer = {getTime=function() return 0 end},
    data = {}
}
local Sandbox = require("src.mods.Sandbox")
local compat = require("src.mods.LegacyCompat").new({
    modId="PORYGONAL_OVERWORLD_CHARACTERS", modPath=".", fs={}
})
local env = Sandbox.envFor({modId="PORYGONAL_OVERWORLD_CHARACTERS",
    permissions={engine_internals=true}, compat=compat})
-- Match main.lua's local module boundary, including sandboxed compilation.
local overrides, reads = {}, {}
local exports, current = {}, {}
local mod = {path=".", log={info=function() end, warn=function() end, error=function() end}}
function mod:read(path)
    reads[path] = (reads[path] or 0)+1
    if overrides[path] == false then return nil end
    return overrides[path] or read(path)
end
mod.find = function(id)
    if id == "porygonal_ecosystem" then return exports end
end
local function loadLocal(path, ...)
    local source = mod:read(path)
    if not source then return nil end
    local chunk = env.loadstring(source, "@"..path)
    if not chunk then return nil end
    local ok, result = pcall(chunk, ...)
    if ok then return result end
end
local Runtime = assert(loadLocal("character_runtime.lua"))
local Registry = assert(loadLocal("ecosystem_registry.lua"))
local palettes = dofile("../porygonal-ecosystem/palettes/creature_palettes.lua")
local normal, shiny = palettes.resolve("RATTATA", "normal"), palettes.resolve("RATTATA", "shiny")
local function visual(npc)
    return {species=npc.species or "RATTATA", state=npc.state or "ACTIVE",
        colors=npc.colors or normal, mapId=npc.mapId, npcId=npc.id,
        creatureId=npc.id, bodyGeneration=npc.generation or 1}
end
local queries = 0
local function query(mapId, npcId, npc)
    queries = queries+1
    check(mapId == npc.mapId and npcId == npc.id, "exact native arguments")
    if current[npcId] ~= npc then return nil end
    return visual(npc)
end
exports.exports = {creatureVisualData=query}
local runtime = Runtime.create(mod, loadLocal, "redBlue")
local function replacement(pose)
    return Registry.lookup({species="RATTATA", state=pose=="lay" and "KO" or "ACTIVE"},
        pose=="walk" and 1 or 0, false, "down")
end
for _, pose in ipairs({"idle", "walk", "lay"}) do
    check(replacement(pose).idle_animation == true, pose.." enables breathing")
    local def = replacement(pose).asset
    local asset = runtime.loadAsset(def)
    check(asset and #asset.vertices==892 and #asset.indices==1716, pose.." real mesh")
    check(asset.mirroredVertices[1][1]==-asset.vertices[1][1], "mirrored geometry")
    check(runtime.loadAsset(def)==asset, "CPU cache reuse")
end
check(not reads["assets/porygonal_characters.pak"], "Lua meshes do not read V4")
check(not Registry.lookup({species="BULBASAUR", state="ACTIVE"}, 0), "unknown species")
check(not Registry.lookup({species="RATTATA", state="SLEEP"}, 0), "unsupported state")
local path = replacement("idle").asset.mesh
for _, bad in ipairs({
    "return {}", "return {vertices={},indices={}}", "error('broken')", "return !!!",
    "return {vertices={{0,0,0,0,0,0/0}},indices={1,1,1}}",
    "return {vertices={{0,0,0,0,0,math.huge}},indices={1,1,1}}",
    "return {vertices={{0,0,0,0,0}},indices={1,1,1}}",
    "return {vertices={{0,0,0,0,0,1}},indices={0,1,1}}",
    "return {vertices={{0,0,0,0,0,1}},indices={1,1,2}}",
    "return {vertices={{0,0,0,0,0,1}},indices={1,1,1.5}}",
    "return {vertices={{0,0,0,0,0,1}},indices={1,1}}",
    "return {vertices={{0,0,0,0,0,1}},indices={[1]=1,[2]=1,[4]=1}}"
}) do
    overrides[path] = bad
    local fresh = Runtime.create(mod, loadLocal, "redBlue")
    check(not fresh.loadAsset(replacement("idle").asset), "invalid Lua mesh rejected")
end
overrides[path] = false
check(not Runtime.create(mod, loadLocal, "redBlue").loadAsset(replacement("idle").asset), "missing mesh")
overrides[path] = nil
env.owcSandboxSentinel = 42
overrides[path] = "return {vertices={{owcSandboxSentinel,0,0,0,0,1}},indices={1,1,1}}"
check(Runtime.create(mod,loadLocal,"redBlue").loadAsset(replacement("idle").asset).vertices[1][1]==42
    and _G.owcSandboxSentinel==nil, "mesh executes in the existing mod sandbox")
overrides[path] = nil
local denied = replacement("idle").asset
denied.mesh = "../outside.lua"
check(not runtime.loadAsset(denied) and not reads[denied.mesh], "allowlist before read")
for _, group in ipairs({"redBlue", "yellow"}) do
    local rt = Runtime.create(mod, loadLocal, group)
    local asset = rt.loadAsset(replacement("idle").asset)
    for _, colors in ipairs({normal, shiny}) do
        gbc = not gbc
        local data, key = rt.textureDataFor(asset, {}, colors)
        for i = 1, 4 do
            for j = 1, 3 do check(data.pixels[i][j]==colors[i][j]/255, "Ecosystem RGB bake") end
        end
        local again, sameKey = rt.textureDataFor(asset, {}, colors)
        check(again==data and sameKey==key, "palette cache")
    end
end

-- Exercise the unchanged V4 decoder with a small protected package fixture.
local bit = require("bit")
local function u32(v) return v < 0 and v+4294967296 or v end
local function le(v, count)
    local out = {}
    for i = 1, count do out[i]=string.char(v%256); v=math.floor(v/256) end
    return table.concat(out)
end
local meshPath = "assets/test_vanilla_idle.lua"
local hash = 5381
for i=1,#meshPath do hash=bit.band(hash+bit.lshift(hash,5)+meshPath:byte(i),0xffffffff) end
hash = u32(hash)
local binary = le(1,4)..le(3,4)..string.rep(le(1000000,4),6)..le(1,2):rep(3)
local compressed = "fixture-zlib"
love.data.decompress = function(_, format, value)
    check(format=="zlib" and value==compressed, "V4 stream unprotected")
    return binary
end
local seed = bit.bxor(0x51A7C3D9,hash,bit.lshift(#binary,7),bit.rshift(#binary,3))
local protected = {}
for i=1,#compressed do
    seed=bit.bxor(seed,bit.lshift(seed,13)); seed=bit.bxor(seed,bit.rshift(seed,17))
    seed=bit.bxor(seed,bit.lshift(seed,5))
    protected[i]=string.char(bit.bxor(compressed:byte(i),bit.band(seed,255)))
end
overrides["assets/porygonal_characters.pak"] = "PGCHAR04"..le(4,4)..le(1,4)
    ..le(hash,4)..le(36,4)..le(#compressed,4)..le(#binary,4)
    ..le(u32(bit.band(65537+3*257+hash,0xffffffff)),4)..table.concat(protected)
local vanillaDef = {mesh=meshPath, texture="assets/grayscale_palette.png", paletteMode="gen1"}
local vanilla = runtime.loadAsset(vanillaDef)
check(vanilla and vanilla.vertices[1][1]==1 and #vanilla.indices==3, "V4 decoder still used")

-- Adapter harness: real Mat4, native card transforms, shared image cache and
-- snug scratch behavior; draw/GPU calls are recorded rather than executed.
local Mat4 = dofile("../potato_voxel/lib/Mat4.lua")
local visible, shadows = {}, {}
local Voxel3D = {
    newMesh=function(vertices)
        if gpuFail then error("recoverable GPU failure") end
        nextMesh=nextMesh+1; return {vertices=vertices, id=nextMesh}
    end,
    draw=function(mesh, texture, model) visible[#visible+1]={mesh=mesh,texture=texture,model=model} end
}
local cards = {}
local Billboards = {mesh=function(def, frame)
    local key=def.image.."#"..frame
    cards[key]=cards[key] or {card=true}; return cards[key]
end}
Billboards.shadowQuad=Billboards.mesh
local snugScratch = {}
local ShadowMap = {
    draw=function(mesh,texture,model)
        local copy={}; for i=1,16 do copy[i]=model[i] end
        shadows[#shadows+1]={mesh=mesh,texture=texture,model=copy}
    end,
    snug=function(model)
        local translated=Mat4.mul(Mat4.translate(0.3,0.4,0.5),model)
        for i=1,16 do snugScratch[i]=translated[i] end
        return snugScratch
    end
}
local Scene = {groundAt=function() return 3 end}
local function cardMatrix(p)
    return Mat4.mul(Mat4.translate(p.x+8,p.y,p.z+8),Mat4.translate(-8,0,0))
end
Scene.render=function(state)
    local posed={}
    local function collect(npc, ox, oy)
        local sprite,x,y,facing,phase,flip=npc:pose()
        posed[#posed+1]={sprite=sprite,x=x+(ox or 0),z=npc.py+(oy or 0),
            y=3+npc.py-y,phase=phase,facing=facing,flip=flip}
    end
    for _,g in ipairs(state.ghosts or {}) do collect(g.npc,g.ox,g.oy) end
    for _,npc in ipairs(state.entities or {}) do collect(npc) end
    if state.afterPose then state.afterPose() end
    -- Deliberately reverse submissions and omit cards: order is not identity.
    for i=#posed,1,-1 do
        local p=posed[i]
        if i~=state.skip then
            if not state.noShadows then
                local mesh=Billboards.shadowQuad(p.sprite.def,p.phase)
                ShadowMap.draw(mesh,{},ShadowMap.snug(cardMatrix(p)))
            end
            local mesh=Billboards.mesh(p.sprite.def,p.phase)
            Voxel3D.draw(mesh,{},cardMatrix(p),0,{})
        end
    end
    if state.structuralFailure then error("structural render failure") end
end
local modules={VoxelScene=Scene,Voxel3D=Voxel3D,SpriteBillboards=Billboards,Mat4=Mat4,
    ShadowMap=ShadowMap,WorldFeature={},ChunkMesher={},TileShape={},MeshCache={}}
local originalFind=mod.find
mod.find=function(id)
    if id=="potato_voxel" then return {exports={lib={require=function(name) return modules[name] end}}} end
    return originalFind(id)
end
local adapter=assert(loadLocal("renderers/potato_voxel/potato_voxel_adapter.lua"))
local vanillaRegistry={idle_animation={enabled=false},lookup=function(id)
    if id=="VANILLA" then return {asset=vanillaDef} end
end}
check(adapter.initialize(mod,loadLocal,vanillaRegistry,runtime),"adapter initialized")
local function npc(id, x, colors)
    local entity={id=id,mapId="MAP_A",px=x,py=20,cellX=1,cellY=1,
        colors=colors,def={owner="porygonal_ecosystem"},
        sprite={def={id="MON",image="shared.png",walker=true,frames=6}},phase=0}
    function entity:pose() return self.sprite,self.px,self.py,"down",self.phase,false end
    current[id]=entity
    return entity
end
local a,b=npc("body_a",10,normal),npc("body_b",40,shiny)
local map={id="MAP_A"}
local function render(state)
    visible,shadows={},{}
    state.map=state.map or map
    Scene.render(state)
    return visible,shadows
end
render({entities={a,b}})
check(#visible==2 and #shadows==2,"two bodies, no extra entity")
check(not visible[1].mesh.card and not visible[2].mesh.card,"two Rattata replaced")
check(visible[1].texture.data.pixels[2][1]==shiny[2][1]/255,"second body shiny")
check(visible[2].texture.data.pixels[2][1]==normal[2][1]/255,"first body normal")
check(visible[1].mesh==shadows[1].mesh and visible[2].mesh==shadows[2].mesh,"matching shadow meshes")
check(shadows[1].model[4]==48 and shadows[2].model[4]==18,"shadow positions")
render({entities={a,b},skip=1,noShadows=true})
check(#visible==1 and not visible[1].mesh.card and visible[1].model[4]==48,"skipped/repeated pass identity")
b.state="KO"; render({entities={b}})
check(visible[1].mesh.vertices==runtime.loadAsset(replacement("lay").asset).vertices,"KO lay GPU")
b.state="ACTIVE"; b.phase=1; render({entities={b}})
check(visible[1].mesh.vertices==runtime.loadAsset(replacement("walk").asset).vertices,"ACTIVE walk GPU")
render({map={id="MAP_B"},entities={},ghosts={{npc=a,map=map,ox=100,oy=-16}}})
check(visible[1].model[4]==118 and visible[1].model[12]==12,"neighbor offset")
local old=a
a=npc("body_a",70,shiny)
render({entities={old,a}})
check(not visible[1].mesh.card and visible[2].mesh.card,"rebuilt body rejects old reference")
check(shadows[1].mesh==visible[1].mesh and shadows[2].mesh.card
    and math.abs(shadows[2].model[4]-10.3)<0.001,"reconstruction shadow and native fallback transform")
render({entities={a},afterPose=function() current[a.id]=nil end})
check(visible[1].mesh.card,"stale identity between pose and submission")
current[a.id]=a
b.px=a.px; render({entities={a,b}})
check(visible[1].mesh.card and visible[2].mesh.card,"ambiguous overlap preserves cards")
b.px=40
local function fallback(label, action, restore)
    action(); render({entities={a}})
    check(visible[1].mesh.card and shadows[1].mesh.card,label)
    if restore then restore() end
end
fallback("absent Ecosystem",function() exports=nil end,function() exports={exports={creatureVisualData=query}} end)
fallback("unavailable export",function() exports.exports={} end,function() exports.exports.creatureVisualData=query end)
fallback("query failure",function() exports.exports.creatureVisualData=function() error("recoverable query") end end,
    function() exports.exports.creatureVisualData=query end)
fallback("unknown species",function() a.species="BULBASAUR" end,function() a.species=nil end)
fallback("foreign NPC",function() a.def.owner="foreign" end,function() a.def.owner="porygonal_ecosystem" end)
-- Fresh runtime avoids previously prepared GPU resources for failure tests.
local realLoad=runtime.loadAsset
runtime.loadAsset=function(def) return realLoad(def) and Runtime.create(mod,loadLocal,"redBlue").loadAsset(def) end
fallback("GPU failure",function() gpuFail=true end,function() gpuFail=false end)
fallback("texture failure",function() textureFail=true end,function() textureFail=false end)
fallback("missing mesh in render",function() overrides[path]=false end,function() overrides[path]=nil end)
fallback("invalid mesh in render",function() overrides[path]="return {}" end,function() overrides[path]=nil end)
runtime.loadAsset=realLoad
local v=npc("vanilla",5)
v.def={}; v.sprite.def.id="VANILLA"
exports=nil; render({entities={v}})
check(not visible[1].mesh.card and visible[1].mesh.vertices==vanilla.vertices,"vanilla without Ecosystem")
local pose=v.pose
local ok=pcall(render,{entities={v},structuralFailure=true})
check(not ok and v.pose==pose,"structural failures propagate and pose restored")
check(queries>0,"public API consumed")

-- OWC-T027: exact player appearances use the same Lua/GPU path and native pose.
-- Register the real Ecosystem definitions: the registry key is NOT def.id.
local NativeRegistry=require("src.mods.Registry")
local captureDefinitions=NativeRegistry.new("sprites")
local CapturePresentation=dofile("../porygonal-ecosystem/ecosystem/capture_presentation.lua")
CapturePresentation.new({content={sprites=captureDefinitions},world={},
    assets={path=function(_,p) return "mods/PORYGONAL_ECOSYSTEM/"..p end}},nil,{})
package.loaded["src.render.Assets"]={register=function() end,
    image=function() return {getDimensions=function() return 16,96 end} end}
package.loaded["src.render.GbcPalette"]={}
package.loaded["src.core.GameVersion"]={}
love.graphics.newQuad=function(...) return {...} end
local RealSpriteRenderer=dofile("../gen1recomp-lab/src/render/SpriteRenderer.lua")
local captureSprites={}
for _,id in pairs(CapturePresentation.sprites) do
    local def=assert(captureDefinitions:get(id))
    check(def.id==nil,"real capture definition has no injected id")
    captureSprites[id]=RealSpriteRenderer.new(def,"player")
end
for _,name in ipairs({"src.world.Collision","src.world.FieldDefaults",
    "src.render.GroundShadow","src.mods.Runtime"}) do package.loaded[name]={} end
local Player=dofile("../gen1recomp-lab/src/world/Player.lua")
local player=npc("player",24)
player.def={}
local normalSprite={def={id="VANILLA",image="player.png",frames=3,walker=false}}
player.sprite=normalSprite
local facing, phase, flip="down",0,false
player.hasAppearanceOverride=Player.hasAppearanceOverride
player.pose=Player.pose
player.walkPhase=function() return phase end
player.fishShakeDy=-2
local function setCapture(id)
    player.appearanceOverride={sprite=captureSprites[id],spriteId=id,
        isActive=function(self) return not self.released end}
end
local playerPose=player.pose
local function renderPlayer()
    player.facing=facing
    player.animClock=flip and 16 or 0
    render({player=player,entities={player}})
    check(player.pose==playerPose,"player pose method restored")
    check(#visible==1 and #shadows==1,"one player, one shadow")
end
local packageReads=reads["assets/porygonal_characters.pak"]
local captureAssets={}
for id, mesh in pairs({ECO_CAPTURE_RED_AIM="assets/red_aim.lua",
    ECO_CAPTURE_RED_THROW="assets/red_throw.lua"}) do
    check(not runtime.playerAppearanceReplacementFor(id,false,"down",false),"capture excludes NPC")
    check(not runtime.playerAppearanceReplacementFor(id.."_OTHER",false,"down",true),"exact ID only")
    local capture=runtime.playerAppearanceReplacementFor(id,false,"down",true)
    check(capture and capture.asset.mesh==mesh and capture.idle_animation==false,"capture mapping and fixed pose")
    local asset=runtime.loadAsset(capture.asset)
    captureAssets[id]=asset
    check(asset and #asset.vertices==1698 and #asset.indices==3750,"real capture mesh validated")
    check(runtime.loadAsset(capture.asset)==asset,"capture CPU cache reuse")
    setCapture(id)
    -- Catch accidental breathing even when global idle animation is enabled.
    vanillaRegistry.idle_animation.enabled=true
    for direction, yaw in pairs({down=0,up=math.pi,left=-math.pi/2,right=math.pi/2}) do
        facing=direction
        renderPlayer()
        local _,_,mirror=runtime.getSpritePose(captureSprites[id],facing,phase,flip)
        if id=="ECO_CAPTURE_RED_AIM" and (facing=="left" or facing=="right") then
            mirror=not mirror
        end
        check(visible[1].mesh.vertices==(mirror and asset.mirroredVertices or asset.vertices),"capture GPU selection")
        if id=="ECO_CAPTURE_RED_AIM" and (facing=="left" or facing=="right") then
            -- Sample the authored raised-hand surface (local negative X),
            -- then verify the actual submitted mesh/yaw places it camera-side.
            local handIndex
            for i,v in ipairs(asset.vertices) do
                if v[1]<-3 and v[2]>9 and v[2]<11 and v[3]>-3 and v[3]<-1 then
                    handIndex=i; break
                end
            end
            local hand=visible[1].mesh.vertices[assert(handIndex,"raised-hand surface in real AIM asset")]
            local m=visible[1].model
            check(m[9]*hand[1]+m[10]*hand[2]+m[11]*hand[3]>0,
                "east/west raised hand lies on visible positive-Z side")
        end
        check(visible[1].mesh==shadows[1].mesh,"capture shadow uses same mesh")
        local expected=Mat4.mul(Mat4.translate(32,5,28),Mat4.rotateY(yaw))
        for i=1,16 do
            check(math.abs(visible[1].model[i]-expected[i])<0.000001,"native position, lift, facing and scale")
            check(math.abs(shadows[1].model[i]-expected[i])<0.000001,"capture shadow transform")
        end
    end
    facing="right"
    phase,flip=1,true
    renderPlayer()
    check(visible[1].mesh.vertices==(id=="ECO_CAPTURE_RED_AIM" and asset.vertices or asset.mirroredVertices),
        "capture selection independent of walk phase")
    phase,flip=0,false
    local impostor=npc("impostor",60)
    impostor.def={}; impostor.sprite=captureSprites[id]
    impostor.hasAppearanceOverride=function() error("NPC override must not be queried") end
    render({player=player,entities={player,impostor}})
    check(visible[1].mesh.card and not visible[2].mesh.card,"shared capture sprite replaces player only")
    -- Force fresh CPU/GPU resources to exercise preparation failures.
    runtime.loadAsset=function(def) return Runtime.create(mod,loadLocal,"redBlue").loadAsset(def) end
    for _, bad in ipairs({false,"return {}","return !!!"}) do
        overrides[mesh]=bad
        renderPlayer()
        check(visible[1].mesh.card and shadows[1].mesh.card,"missing/invalid capture keeps native sprite and shadow")
    end
    overrides[mesh]=nil
    gpuFail=true; renderPlayer()
    check(visible[1].mesh.card and shadows[1].mesh.card,"capture GPU failure keeps 2D")
    gpuFail=false; textureFail=true; renderPlayer()
    check(visible[1].mesh.card and shadows[1].mesh.card,"capture texture failure keeps 2D")
    textureFail=false; runtime.loadAsset=realLoad
    renderPlayer()
    check(not visible[1].mesh.card,"capture recovers with valid resources")
end
check(reads["assets/porygonal_characters.pak"]==packageReads,"capture never reads V4")
vanillaRegistry.idle_animation.enabled=false
setCapture("ECO_CAPTURE_RED_AIM"); renderPlayer()
check(visible[1].mesh.vertices==captureAssets.ECO_CAPTURE_RED_AIM.vertices,"aim selected")
setCapture("ECO_CAPTURE_RED_THROW"); renderPlayer()
check(visible[1].mesh.vertices==captureAssets.ECO_CAPTURE_RED_THROW.mirroredVertices,"throw replaces cached aim")
player.appearanceOverride=nil; renderPlayer()
check(visible[1].mesh.vertices==vanilla.vertices and shadows[1].mesh==visible[1].mesh,
    "normal appearance returns without stale capture association")
-- An observed capture sprite alone never establishes an active override.
player.sprite=captureSprites.ECO_CAPTURE_RED_AIM
renderPlayer()
check(visible[1].mesh.card and shadows[1].mesh.card,"absent override keeps unidentified sprite native")
setCapture("ECO_CAPTURE_RED_AIM")
player.appearanceOverride.released=true
renderPlayer()
check(visible[1].mesh.card and shadows[1].mesh.card,"stale override cannot identify capture sprite")
player.sprite=normalSprite
renderPlayer()
check(visible[1].mesh.vertices==vanilla.vertices,"stale override preserves vanilla player")
-- Change/release the override after pose collection, before either draw pass.
setCapture("ECO_CAPTURE_RED_AIM")
render({player=player,entities={player},afterPose=function()
    player.appearanceOverride.sprite=captureSprites.ECO_CAPTURE_RED_THROW
end})
check(visible[1].mesh.card and shadows[1].mesh.card,"different token sprite rejects captured pose")
setCapture("ECO_CAPTURE_RED_AIM")
render({player=player,entities={player},afterPose=function()
    player.appearanceOverride.released=true
end})
check(visible[1].mesh.card and shadows[1].mesh.card,"override released after observation is not reused")
setCapture("ECO_CAPTURE_RED_AIM")
player.appearanceOverride.spriteId="ECO_CAPTURE_RED_AIM_OTHER"
renderPlayer()
check(visible[1].mesh.card and shadows[1].mesh.card,"active unknown override keeps native sprite")
player.appearanceOverride=nil
renderPlayer()
check(visible[1].mesh.vertices==vanilla.vertices,"normal player restored after rejected overrides")
local tuning=assert(loadLocal("character_tuning.lua"))
local nativeRegistry=assert(loadLocal("character_registry.lua",tuning,
    {RED_BLUE="redBlue",YELLOW="yellow",group=function() return "redBlue" end}))
check(nativeRegistry.lookup("SPRITE_RED",0,false,"down",{isPlayer=true}).asset.mesh=="assets/red_idle.lua",
    "real vanilla registry keeps normal player mapping")
check(not nativeRegistry.lookup("ECO_CAPTURE_RED_AIM",0,false,"down",{isPlayer=false}),"no vanilla capture collision")
-- OWC-T033: reuse the actual Species appearances, native NPC pose/phase and
-- Ecosystem palettes. Scene submissions and GPU resources remain simulated.
do
    local NativeNPC = dofile("../gen1recomp-lab/src/world/NPC.lua")
    local entries = {
        {id="NIDORAN_M", file="nidoran_m", prefix="pkmn_032_nidoranm", poses={"idle","walk","lay"}},
        {id="NIDORAN_F", file="nidoran_f", prefix="pkmn_029_nidoranf", poses={"idle","walk","lay"}},
        {id="PIDGEY", file="pidgey", prefix="pkmn_016_pidgey", poses={"idle","walk","flyA","flyB"}},
        {id="SPEAROW", file="spearow", prefix="pkmn_021_spearow", poses={"idle","walk","flyA","flyB"}}
    }
    exports={exports={creatureVisualData=query}}
    for _, entry in ipairs(entries) do
        local species=dofile("../porygonal-ecosystem/species/"..entry.file..".lua")
        local entity=npc("batch_"..entry.id,80)
        entity.species=species.id
        entity.pose=NativeNPC.pose
        entity.walkPhase=NativeNPC.walkPhase
        entity.facing="right"
        entity.stepFlip=false
        entity.visualElevation=0
        local function appearance(def)
            local copy={}
            for k,v in pairs(def) do copy[k]=v end
            copy.image="mods/PORYGONAL_ECOSYSTEM/"..def.image
            entity.sprite={def=copy}
        end
        local function expect(pose, elevation, shadow)
            local px,py=entity.px,entity.py
            render({entities={entity}})
            check(#visible==1 and not visible[1].mesh.card,"one replacement: "..entry.id.." "..pose)
            local asset=runtime.loadAsset({mesh="assets/"..entry.prefix.."_"..pose..".lua",
                meshSource="ecosystem_lua",texture="assets/grayscale_palette.png",paletteMode="gen1"})
            check(visible[1].mesh.vertices==(pose=="lay" and asset.vertices or asset.mirroredVertices),
                "native right facing (single-frame KO keeps native orientation): "..pose)
            local perchedOffset = entity.sprite.def.walker == false and entity.state == "ACTIVE"
                and species.appearances and -11 or 0
            check(visible[1].model[8]==3+elevation*16+perchedOffset,"native elevation plus perched calibration: "..pose)
            check(visible[1].model[4]==px+8 and visible[1].model[12]==py+8,"physical anchor preserved")
            check(entity.px==px and entity.py==py,"render does not move Creature")
            check(#shadows==(shadow and 1 or 0),"native shadow visibility: "..pose)
            if shadow then
                check(shadows[1].mesh==visible[1].mesh,"same shadow geometry")
                for i=1,16 do check(shadows[1].model[i]==visible[1].model[i],"same shadow transform") end
            end
            for i=1,4 do
                for j=1,3 do
                    check(visible[1].texture.data.pixels[i][j]==entity.colors[i][j]/255,"species RGB from Ecosystem")
                end
            end
        end
        for _, pose in ipairs(entry.poses) do
            local path="assets/"..entry.prefix.."_"..pose..".lua"
            local def={mesh=path,meshSource="ecosystem_lua",texture="assets/grayscale_palette.png",paletteMode="gen1"}
            local asset=runtime.loadAsset(def)
            check(asset and #asset.indices%3==0,"real batch mesh validated: "..path)
            check(runtime.loadAsset(def)==asset,"batch CPU cache reused")
            local lo,hi={math.huge,math.huge,math.huge},{-math.huge,-math.huge,-math.huge}
            for _, vertex in ipairs(asset.vertices) do
                for axis=1,3 do lo[axis]=math.min(lo[axis],vertex[axis]); hi[axis]=math.max(hi[axis],vertex[axis]) end
            end
            for axis=1,3 do check(hi[axis]>lo[axis],"non-degenerate bounds") end
            print(string.format("ASSET %s: %d vertices, %d indices; XYZ [%.3f,%.3f] [%.3f,%.3f] [%.3f,%.3f]",
                path,#asset.vertices,#asset.indices,lo[1],hi[1],lo[2],hi[2],lo[3],hi[3]))
            for _, bad in ipairs({false,"return {vertices={},indices={}}"}) do
                overrides[path]=bad
                check(not Runtime.create(mod,loadLocal,"redBlue").loadAsset(def),"missing/invalid batch mesh rejected")
            end
            overrides[path]=nil
        end
        for _, group in ipairs({"redBlue","yellow"}) do
            for _, variant in ipairs({"normal","shiny"}) do
                entity.colors=palettes.resolve(species.id,variant)
                entity.state="ACTIVE"
                appearance(species.ACTIVE)
                entity.moving=false; entity.animClock=0; entity.visualElevation=0
                expect("idle",0,true)
                entity.moving=true; entity.animClock=4
                expect("walk",0,true)
                local selected=runtime.ecosystemReplacementFor(entity,1,true,"right",entity.sprite)
                check(selected.idle_animation==true,"ground breathing retained")
                local rt=Runtime.create(mod,loadLocal,group)
                local data=rt.textureDataFor(rt.loadAsset(selected.asset),{},entity.colors)
                for i=1,4 do for j=1,3 do
                    check(data.pixels[i][j]==entity.colors[i][j]/255,"both version groups preserve species RGB")
                end end
                if species.appearances then
                    appearance(species.appearances.FLYING)
                    entity.groundShadow=true
                    -- TAKEOFF, cruise, LANDING and recovery all use native FLYING
                    -- appearance. Heights below are observed pose inputs, never OWC constants.
                    for _, height in ipairs({0,.5,1,2,1,.25,0}) do
                        entity.visualElevation=height
                        entity.animClock=0; expect("flyA",height,true)
                        entity.animClock=20; expect("flyB",height,true)
                    end
                    selected=runtime.ecosystemReplacementFor(entity,1,false,"right",entity.sprite)
                    check(selected.idle_animation==false and selected.mirror==true,"flight phase has no gait flip/breathing")
                    entity.groundShadow=false; expect("flyB",0,false)
                    appearance(species.appearances.PERCHED)
                    entity.visualElevation=.5
                    expect("idle",.5,false)
                    appearance(species.appearances.GROUND)
                    entity.visualElevation=0; entity.moving=false
                    expect("idle",0,true)
                end
                entity.state="KO"; appearance(species.KO)
                if species.appearances then
                    render({entities={entity}})
                    check(visible[1].mesh.card and shadows[1].mesh.card,"bird KO stays native without lay")
                else
                    expect("lay",0,true)
                end
            end
        end
        entity.state="ACTIVE"; appearance(species.ACTIVE)
        entity.colors={{0/0,0,0},{0,0,0},{0,0,0},{0,0,0}}
        render({entities={entity}})
        check(visible[1].mesh.card and shadows[1].mesh.card,"unavailable palette preserves native batch sprite")
        entity.colors=palettes.resolve(species.id,"normal")
        render({entities={entity},afterPose=function() appearance(species.KO) end})
        check(visible[1].mesh.card and shadows[1].mesh.card,"appearance changed after observation keeps native card")
        if species.appearances then
            appearance(species.appearances.FLYING)
            entity.visualElevation=1.25; entity.groundShadow=false
            for _, direction in ipairs({"down","up","left","right"}) do
                entity.facing=direction
                local selected=runtime.ecosystemReplacementFor(entity,1,true,direction,entity.sprite)
                check(selected.mirror==(direction=="right") and selected.facing==direction,
                    "flight keeps native orientation in every direction")
            end
            entity.facing="right"
            entity.moving=false
            local flightPath="assets/"..entry.prefix.."_flyA.lua"
            runtime.loadAsset=function(def) return Runtime.create(mod,loadLocal,"redBlue").loadAsset(def) end
            for _, fault in ipairs({"missing","invalid","gpu","texture"}) do
                overrides[flightPath]=nil
                if fault=="missing" then overrides[flightPath]=false
                elseif fault=="invalid" then overrides[flightPath]="return {}" end
                gpuFail=fault=="gpu"; textureFail=fault=="texture"
                render({entities={entity}})
                check(visible[1].mesh.card and shadows[1].mesh.card,
                    "failed flight replacement preserves native sprite/caster: "..fault)
            end
            overrides[flightPath]=nil; gpuFail=false; textureFail=false; runtime.loadAsset=realLoad
            render({entities={entity},afterPose=function() appearance(species.appearances.GROUND) end})
            check(visible[1].mesh.card and shadows[1].mesh.card,"flight transition after pose rejects stale mesh")
            appearance({image="sprites/unknown_fly.png",walker=true})
            render({entities={entity}})
            check(visible[1].mesh.card and shadows[1].mesh.card,"unknown bird appearance stays 2D")
        end
    end
end
-- OWC-T034: use the native active segment, including non-cardinal vectors;
-- the real NPC update proves that this is the path actually travelled.
do
    local NativeNPC = dofile("../gen1recomp-lab/src/world/NPC.lua")
    exports={exports={creatureVisualData=query}}
    for _, name in ipairs({"pidgey", "spearow"}) do
        local species=dofile("../porygonal-ecosystem/species/"..name..".lua")
        local function bird(id)
            local e=npc(id,80,normal)
            e.species=species.id; e.facing="down"; e.visualElevation=.5
            e.animClock=0; e.stepFlip=false
            for _, method in ipairs({"pose","physicalPosition","moveDirect","update","cancelDirectMovement"}) do
                e[method]=NativeNPC[method]
            end
            -- Keep this test independent of the game's text-box stack.
            e.walkPhase=function(self) return self.phase end
            return e
        end
        local function appearance(e, kind)
            e.sprite={def=species.appearances[kind]}
            e.groundShadow=kind=="FLYING"
        end
        local e=bird("heading_"..name)
        appearance(e,"FLYING")
        local function direction(dx,dz, message)
            local m=visible[1].model
            local length=math.sqrt(dx*dx+dz*dz)
            check(math.abs(m[3]-dx/length)<1e-9 and math.abs(m[11]-dz/length)<1e-9,message)
            check(m[8]==11,"flight keeps native lift without perched offset")
            check(shadows[1].mesh==visible[1].mesh,"heading caster mesh")
            for i=1,16 do check(shadows[1].model[i]==m[i],"heading caster transform") end
        end
        render({entities={e}}); direction(0,1,"no segment keeps native facing")
        for _, delta in ipairs({{0,1},{1,0},{0,-1},{-1,0},{1,1},{1,-1},{-1,1},{-1,-1},{2,1}}) do
            local x,z=e:physicalPosition()
            e:moveDirect(x+delta[1],z+delta[2],2,"down")
            local px,py=e.px,e.py
            e:update(nil,nil,1/60)
            check(math.abs((e.px-px)*delta[2]-(e.py-py)*delta[1])<1e-9,"actual native segment direction")
            for _, phase in ipairs({0,1}) do
                e.phase=phase
                render({entities={e}}); direction(delta[1],delta[2],"cardinal/diagonal heading, both wing poses")
            end
        end
        e:cancelDirectMovement()
        render({entities={e}}); direction(2,1,"temporary stop retains yaw")
        local other=bird("other_"..name); appearance(other,"FLYING")
        render({entities={e,other}})
        check(math.abs(visible[1].model[3])<1e-9,"distinct body receives no borrowed heading")
        appearance(e,"PERCHED")
        render({entities={e}})
        check(visible[1].model[8]==0 and visible[1].model[3]==0 and #shadows==0,
            "flight to perched restores native facing, adds only perched offset, hides native shadow")
        appearance(e,"FLYING")
        render({entities={e}}); direction(0,1,"perched to flight forgets previous heading")
        e:moveDirect(20,10,2,"down")
        render({entities={e}})
        e:cancelDirectMovement(); appearance(e,"GROUND"); e.visualElevation=0
        render({entities={e}})
        check(visible[1].model[8]==3 and visible[1].model[3]==0,"landing clears heading and height offset")
        appearance(e,"FLYING"); e.visualElevation=.5
        -- A fresh reliable segment works immediately, without waiting for deltas.
        e:moveDirect(20,10,2,"down"); render({entities={e}})
        e:cancelDirectMovement()
        render({map={id="MAP_B"},entities={e}}); direction(0,1,"view map change clears held yaw")
        e:moveDirect(20,10,2,"down"); render({entities={e}})
        e:cancelDirectMovement(); render({entities={}}); render({entities={e}})
        direction(0,1,"disappearance retires held yaw")
        e:moveDirect(20,10,2,"down"); render({entities={e}})
        local old=e
        e=bird(old.id); appearance(e,"FLYING")
        render({entities={old,e}})
        check(visible[2].mesh.card and shadows[2].mesh.card,"rebuilt body rejects obsolete native reference")
        render({entities={e}}); direction(0,1,"rebuilt NPC does not inherit held yaw")
        for _, delta in ipairs({{0,0},{1e-9,1e-9},{0/0,1},{math.huge,1}}) do
            e.moving=true; e.directMovement={dx=delta[1],dy=delta[2]}
            render({entities={e}}); direction(0,1,"unreliable vector keeps native orientation")
        end
        e:cancelDirectMovement()
        e.px,e.py=2000,2000
        render({entities={e}}); direction(0,1,"teleport cannot invent a heading from position deltas")
    end
end
-- OWC-T037: TCG shares the native NPC draw path and the validated Lua loader.
do
    local catalog=dofile("../porygonal-TCG/tcg/npc/catalog.lua")
    local obj, placementMap, talk
    local tcg={exports={},content={maps={
        get=function(_,id) placementMap=id; return {objects={{index=4}}} end,
        patch=function(_,id,patch) obj=patch.objects.__append[1] end
    },map_scripts={register=function(_,id,scripts) talk=scripts end}}}
    local instance,bind=dofile("../porygonal-TCG/tcg/npc/placement.lua")(
        tcg,catalog,catalog.sprites[0x1C].id,catalog.NPC_BRITTANY)
    check(instance.npc==0x27 and placementMap=="ROUTE_2" and instance.x==6 and instance.y==44,
        "real Brittany identity and current placement")
    check(obj.movement=="WALK" and obj.range=="ANY_DIR","native roaming retained")
    local interactions=0
    bind(function(done) interactions=interactions+1; done() end)
    talk.talk[obj.text](nil,nil,nil,function() interactions=interactions+1 end)
    check(interactions==2,"original talk callback and completion remain intact")
    local e=npc(instance.npcId,40,normal)
    e.mapId,e.def=instance.map,obj
    e.sprite={def=catalog.sprites[0x1C]}
    e.sprite.def.frames,e.sprite.def.walker=6,true
    e.sprite.def.image="native-tcg-girl.png"
    gbc=false
    vanillaRegistry.idle_animation.enabled=false
    Scene._modeColors=function() return e.colors end
    local live=e
    local previousFind=mod.find
    mod.find=function(id) if id=="PORYGONAL_TCG" then return tcg end; return previousFind(id) end
    mod.world={npc=function(_,mapId,name)
        check(mapId==e.mapId and name==obj.name,"exact public native lookup")
        return live and {npc=live}
    end}
    local registry=assert(loadLocal("tcg_registry.lua"))
    for _,phase in ipairs({0,1}) do
        e.phase=phase
        local rep=registry.lookup(phase,false,"down")
        check(rep.asset.mesh=="assets/tcg_brittany_"..(phase==1 and "walk" or "idle")..".lua","TCG pose mapping")
        local asset=assert(runtime.loadAsset(rep.asset))
        check(runtime.loadAsset(rep.asset)==asset,"TCG CPU cache")
        local lo,hi={math.huge,math.huge,math.huge},{-math.huge,-math.huge,-math.huge}
        for _,v in ipairs(asset.vertices) do
            for axis=1,3 do lo[axis]=math.min(lo[axis],v[axis]); hi[axis]=math.max(hi[axis],v[axis]) end
            check(v[4]>=0 and v[4]<=1 and v[5]>=0 and v[5]<=1,"TCG normalized UV")
        end
        print(string.format("TCG %s: vertices=%d indices=%d bounds=(%g,%g,%g)..(%g,%g,%g)",
            phase==1 and "walk" or "idle",#asset.vertices,#asset.indices,
            lo[1],lo[2],lo[3],hi[1],hi[2],hi[3]))
        for _,facing in ipairs({"down","up","left","right"}) do
            for _,flip in ipairs({false,true}) do
                e.pose=function(self) return self.sprite,self.px,self.py-2,facing,self.phase,flip end
                render({entities={e}})
                local _,_,mirror=runtime.getSpritePose(e.sprite,facing,e.phase,flip)
                local vertices=mirror and asset.mirroredVertices or asset.vertices
                check(#visible==1 and #shadows==1 and visible[1].mesh.vertices==vertices,"TCG pose/orientation/mirror")
                check(visible[1].model[4]==48 and visible[1].model[8]==5 and visible[1].model[12]==28,
                    "native terrain, position and lift")
                check(visible[1].mesh==shadows[1].mesh,"TCG shadow mesh")
                for i=1,16 do check(visible[1].model[i]==shadows[1].model[i],"TCG shadow transform") end
                check(visible[1].texture.data.pixels[2][1]==normal[2][1]/255,"native palette bake")
            end
        end
    end
    local function card(label,change,restore)
        change(); render({entities={e}})
        check(visible[1].mesh.card and shadows[1].mesh.card,label)
        restore()
    end
    card("TCG absent",function() tcg=nil end,function() tcg={} end)
    card("stale body",function() live={} end,function() live=e end)
    render({entities={e},afterPose=function() live=nil end})
    check(visible[1].mesh.card,"TCG expires between pose and draw"); live=e
    card("other TCG NPC",function() obj.tcgNpcId=0x33 end,function() obj.tcgNpcId=0x27 end)
    card("name alone insufficient",function() obj.sprite="SPRITE_GIRL" end,function() obj.sprite="SPRITE_TCG_GIRL_BLUE" end)
    card("palette source mismatch",function() e.sprite.def.paletteSource=nil end,
        function() e.sprite.def.paletteSource="ROM:SpriteSheetPointerTable[1]" end)
    local paletteFX=package.loaded["src.render.PaletteFX"]
    local oldGbc,oldObp=paletteFX.usesGbcPack,paletteFX.spriteObp
    for _,group in ipairs({"redBlue","yellow"}) do
        local rt=Runtime.create(mod,loadLocal,group)
        paletteFX.usesGbcPack=function() return true end
        paletteFX.spriteObp=function(def) check(def==e.sprite.def,"native palette definition"); return normal end
        local rep,colors=rt.tcgReplacementFor(e,0,false,"down",e.sprite,nil)
        check(rep and colors==normal,"version palette resolver")
    end
    paletteFX.usesGbcPack=function() return false end
    card("palette unavailable",function() e.colors=nil end,function() e.colors=normal end)
    card("palette invalid",function() e.colors={{0/0,0,0}} end,function() e.colors=normal end)
    paletteFX.usesGbcPack,paletteFX.spriteObp=oldGbc,oldObp
    local realLoad=runtime.loadAsset
    runtime.loadAsset=function(def) return Runtime.create(mod,loadLocal,"redBlue").loadAsset(def) end
    local path=registry.lookup(e.phase).asset.mesh
    card("TCG missing mesh",function() overrides[path]=false end,function() overrides[path]=nil end)
    card("TCG invalid mesh",function() overrides[path]="return {}" end,function() overrides[path]=nil end)
    card("TCG GPU failure",function() gpuFail=true end,function() gpuFail=false end)
    card("TCG texture failure",function() textureFail=true end,function() textureFail=false end)
    runtime.loadAsset=realLoad
    check(not runtime.loadAsset({meshSource="tcg_lua",mesh="assets/red_aim.lua"}),"TCG mesh allowlist")
    check(not runtime.loadAsset({meshSource="ecosystem_lua",mesh=path}),"registries stay distinct")
    render({entities={}}); check(#visible==0 and #shadows==0,"TCG disappearance")
    mod.find=previousFind
end
-- OWC-T038: real Diagonal registrations + native Player pose, existing registry
-- selection and adapter matrices. V4 geometry is a CPU fixture in this harness.
do
    local version=assert(loadLocal("game_version_profile.lua"))
    version.configure("redBlue")
    local registry=assert(loadLocal("character_registry.lua",loadLocal("character_tuning.lua"),version))
    local definitions=NativeRegistry.new("sprites")
    assert(loadstring(read("../porygonal_diagonal/main.lua")))(
        {content={sprites=definitions},assets={path=function(_,p) return "diagonal/"..p end},
         world={acquirePlayerMovementIntentProvider=function() end},events={on=function() end}})
    local previousLookup=vanillaRegistry.lookupDiagonalAppearance
    vanillaRegistry.lookupDiagonalAppearance=registry.lookupDiagonalAppearance
    vanillaRegistry.idle_animation.enabled=false
    local previousLoad=runtime.loadAsset
    local idleAsset=previousLoad(vanillaDef)
    local walkAsset={}
    for k,v in pairs(idleAsset) do walkAsset[k]=v end
    -- Distinct GPU cache keys for the two existing logical mesh paths.
    local fail
    runtime.loadAsset=function(def)
        if def.mesh=="assets/red_idle.lua" or def.mesh=="assets/red_walk.lua" then
            if fail=="missing" then return nil end
            if fail=="invalid" then error("invalid prepared mesh") end
            return def.mesh=="assets/red_idle.lua" and idleAsset or walkAsset
        end
        return previousLoad(def)
    end
    player.appearanceOverride=nil
    local diagonalSprite
    local function setDiagonal(id)
        local def=assert(definitions:get(id))
        check(def.id==nil,"Diagonal native registration has no def.id")
        diagonalSprite=RealSpriteRenderer.new(def,"player")
        player.locomotionAppearanceOverride={sprite=diagonalSprite,spriteId=id,
            isActive=function(self) return not self.released end,
            allowsLocomotionPose=function(self) return not self.suspended end}
    end
    for dir,degrees in pairs({NE=135,NW=-135,SE=45,SW=-45}) do
        for _,pose in ipairs({"idle","walk1","walk2"}) do
            local id="PORYGONAL_DIAGONAL_"..dir.."_"..pose
            setDiagonal(id)
            local rep=registry.lookupDiagonalAppearance(id)
            local asset=pose=="idle" and idleAsset or walkAsset
            check(rep.asset.mesh=="assets/red_"..(pose=="idle" and "idle" or "walk")..".lua",
                "Diagonal reuses registered Red idle/walk")
            local mirror=(dir:sub(2)=="E")~=(pose=="walk2")
            for _,cardinal in ipairs({"up","down","left","right"}) do
                for _,nativeFlip in ipairs({false,true}) do
                    facing,phase,flip=cardinal,1,nativeFlip
                    renderPlayer()
                    check(visible[1].mesh.vertices==(mirror and asset.mirroredVertices or asset.vertices),
                        "explicit Diagonal foot and mirror ignore cardinal/native phase")
                    local expected=Mat4.mul(Mat4.translate(32,5,28),Mat4.rotateY(math.rad(degrees)))
                    for i=1,16 do
                        check(math.abs(visible[1].model[i]-expected[i])<0.000001,"Diagonal pivot/lift/yaw")
                        check(math.abs(shadows[1].model[i]-expected[i])<0.000001,"Diagonal caster matrix")
                    end
                    check(visible[1].mesh==shadows[1].mesh,"Diagonal caster mesh")
                end
            end
        end
    end
    for _,bad in ipairs({"PORYGONAL_DIAGONAL_NE_walk3","PORYGONAL_DIAGONAL_NN_idle",
        "PORYGONAL_DIAGONAL_NE_idle_extra","ECO_CAPTURE_RED_AIM"}) do
        check(not registry.lookupDiagonalAppearance(bad),"exact Diagonal IDs only")
    end
    local function diagonalFallback(label,change,restore)
        change(); renderPlayer()
        check(visible[1].mesh.card and shadows[1].mesh.card,label)
        restore()
    end
    setDiagonal("PORYGONAL_DIAGONAL_SE_walk2")
    diagonalFallback("Diagonal missing mesh",function() fail="missing" end,function() fail=nil end)
    diagonalFallback("Diagonal invalid mesh",function() fail="invalid" end,function() fail=nil end)
    -- New CPU fixture keys force fresh GPU allocation for these failures.
    local oldIdle,oldWalk=idleAsset,walkAsset
    idleAsset,walkAsset={},{}
    for k,v in pairs(oldWalk) do walkAsset[k]=v end
    diagonalFallback("Diagonal GPU allocation",function() gpuFail=true end,function() gpuFail=false end)
    diagonalFallback("Diagonal texture allocation",function() textureFail=true end,function() textureFail=false end)
    idleAsset,walkAsset=oldIdle,oldWalk
    local token=player.locomotionAppearanceOverride
    -- A raw sprite/forged def.id is insufficient without the observed token.
    local baseSprite=player.sprite
    player.sprite=diagonalSprite
    diagonalFallback("Diagonal sprite without active token",function() token.released=true end,
        function() token.released=false end)
    player.sprite=baseSprite
    local impostor=npc("diagonal_impostor",90)
    impostor.def={}; impostor.sprite=diagonalSprite
    render({entities={impostor}})
    check(visible[1].mesh.card and shadows[1].mesh.card,"Diagonal excludes NPCs")
    for _,kind in ipairs({"released","suspended"}) do
        token[kind]=true
        renderPlayer()
        check(visible[1].mesh.vertices==vanilla.vertices,"Diagonal yields to native cardinal pose")
        token[kind]=false
        renderPlayer()
        check(visible[1].mesh.vertices==walkAsset.vertices,"cardinal to Diagonal restores explicit foot")
    end
    setCapture("ECO_CAPTURE_RED_AIM")
    facing,phase,flip="down",0,false
    renderPlayer()
    check(visible[1].mesh.vertices==captureAssets.ECO_CAPTURE_RED_AIM.vertices,
        "foreground special pose takes priority over Diagonal")
    player.appearanceOverride=nil; player.locomotionAppearanceOverride=nil
    renderPlayer()
    check(visible[1].mesh.vertices==vanilla.vertices,"no Diagonal retains native replacement")
    runtime.loadAsset=previousLoad
    vanillaRegistry.lookupDiagonalAppearance=previousLookup
end
-- OWC-T040: native visibility owns capture rendering, independently of state.
do
    exports={exports={creatureVisualData=query}}
    local target=npc("capture_target",110,normal)
    local other=npc("capture_neighbor",150,shiny)
    -- Exercise the actual native pose: it still returns a sprite while hidden.
    target.pose=require("src.world.NPC").pose
    target.visualElevation=0
    target.walkPhase=function(self) return self.phase end
    local originalPose=target.pose
    target.state="CAPTURE_OWNED" -- Existing Ecosystem acquireCapture state.
    render({entities={target,other}})
    check(#visible==2 and not visible[2].mesh.card,"visible capture-owned body keeps 3D during impact")
    local entities={target,other}
    target.visible=false
    check(target:pose()==target.sprite,"native hidden NPC pose still exposes its sprite")
    render({entities=entities})
    check(#visible==1 and #shadows==1 and not visible[1].mesh.card,
        "hidden capture target has neither 2D/3D draw nor caster; neighbor stays 3D")
    check(entities[1]==target and #entities==2 and target.pose==originalPose,
        "render filtering preserves native list, body and pose")
    -- Same cached sprite, same position: filtering must precede billboard matching.
    other.px=target.px
    render({entities=entities})
    check(#visible==1 and not visible[1].mesh.card,"hidden overlap does not force neighbor fallback")
    other.px=150
    render({map={id="MAP_B"},entities={},ghosts={{npc=target,map=map,ox=100,oy=-16},
        {npc=other,map=map,ox=100,oy=-16}}})
    check(#visible==1 and #shadows==1 and not visible[1].mesh.card,"hidden neighbor ghost respects visibility")
    for _,outcome in ipairs({"breakout","cancel"}) do
        target.visible=true
        render({entities={target}})
        check(#visible==1 and not visible[1].mesh.card,outcome.." restores 3D before Capture releases ownership")
        target.state="ACTIVE"
        render({entities={target}})
        check(not visible[1].mesh.card,outcome.." retains 3D after release")
        target.state="CAPTURE_OWNED"; target.visible=false
    end
    -- Success removes the body in Ecosystem; OWC has no retained capture entry.
    current[target.id]=nil
    render({entities={other}})
    check(#visible==1 and not visible[1].mesh.card,"success removal leaves the neighbor alone")
    local rebuilt=npc(target.id,110,normal)
    render({entities={rebuilt}})
    check(#visible==1 and not visible[1].mesh.card,"reused ID/rebuilt body does not inherit hiding")
    render({map={id="MAP_B"},entities={}})
    check(#visible==0 and #shadows==0,"map change has no retained capture representation")
    exports=nil; rebuilt.visible=false
    render({entities={rebuilt}})
    check(#visible==0 and #shadows==0,"native hidden flag works without Ecosystem export")
    rebuilt.visible=true
    render({entities={rebuilt}})
    check(visible[1].mesh.card and shadows[1].mesh.card,"visible fallback remains without Ecosystem")
    exports={exports={creatureVisualData=query}}
    local load=runtime.loadAsset
    runtime.loadAsset=function() return nil end
    render({entities={rebuilt}})
    check(visible[1].mesh.card and shadows[1].mesh.card,"invalid mesh retains visible 2D fallback")
    rebuilt.visible=false
    render({entities={rebuilt}})
    check(#visible==0 and #shadows==0,"invalid mesh cannot reveal a hidden native body")
    runtime.loadAsset=load
end
print("PASS: "..checks.." targeted checks (headless; no visual validation)")
