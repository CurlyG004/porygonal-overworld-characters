-- Run from OWC: luajit tests/capture_ball_visuals.lua
-- Real ECO-T028 query and native PresentationObject/SpriteRenderer replay;
-- GPU, projection and scene lifecycle are simulated. Never starts the game.
package.path = "../gen1recomp-lab/?.lua;" .. package.path
local checks = 0
local function check(value, label) assert(value, label); checks = checks + 1 end
local function read(path)
    local f = assert(io.open(path, "rb")); local s = f:read("*a"); f:close(); return s
end
local records, graphicsState, stack = {}, {}, {}
local gpuFail, textureFail, drawFail, shadowFail = false, false, false, false
local shadowDraws, shadowCache, sceneAttempts, passCounts, shaderUniforms
local overrides, reads = {}, {}
local function imageData()
    return {pixels={}, getDimensions=function() return 4,1 end,
        getPixel=function(_,x) local v=1-x/3; return v,v,v,1 end,
        setPixel=function(self,x,_,...) self.pixels[x+1]={...} end,
        mapPixel=function() end}
end
love = {filesystem={newFileData=function(s) return s end}, image={newImageData=imageData},
    timer={getTime=function() return 0 end}, graphics={
        getRendererInfo=function() return "OpenGL" end,
        setMeshCullMode=function(v) graphicsState.cull=v end,
        newImage=function(data)
            if textureFail then error("recoverable texture allocation") end
            return {data=data,setFilter=function() end,getDimensions=function() return 16,96 end}
        end,
        newQuad=function(...) return {...} end,
        push=function()
            local copy={}; for k,v in pairs(graphicsState) do copy[k]=v end
            stack[#stack+1]=copy
        end,
        pop=function() graphicsState=assert(table.remove(stack)) end,
        translate=function(x,y) graphicsState.x=x; graphicsState.y=y end,
        scale=function(x,y) graphicsState.sx=x; graphicsState.sy=y end,
        draw=function(image,...)
            if graphicsState.shader then
                if shadowFail and image.vertices then error("recoverable caster draw") end
                shadowDraws[#shadowDraws+1]={mesh=image,model=shaderUniforms.model,
                    light=shaderUniforms.lightVP,sprite=shaderUniforms.sprite}
                return
            end
            check(graphicsState.overlay,"native draw inside scene overlay")
            records[#records+1]={native=true,image=image,args={...},x=graphicsState.x,
                y=graphicsState.y,scale=graphicsState.sx,eye=graphicsState.eye}
        end,
    }}
-- Execute PotatoVoxel's real ShadowMap lifecycle/math against a GPU double.
-- Canvas pixels and GLSL execution are deliberately outside this test.
local function canvas()
    return {setFilter=function() end,setWrap=function() end,release=function() end}
end
love.graphics.newCanvas=canvas
love.graphics.newShader=function()
    return {send=function(_,name,...)
        local args={...}; shaderUniforms[name]=args[#args]
    end}
end
love.graphics.setShader=function(sh) graphicsState.shader=sh end
love.graphics.setCanvas=function() end
love.graphics.setDepthMode=function() end
love.graphics.setBlendMode=function() end
love.graphics.getBlendMode=function() return "alpha","alphamultiply" end
love.graphics.setColor=function() end
love.graphics.clear=function() end
local defaultColors={{255,255,255},{180,180,180},{80,80,80},{0,0,0}}
package.loaded["src.render.Assets"]={register=function() end,
    imageData=imageData,image=function(path)
        return {path=path,getDimensions=function() return 16,96 end}
    end}
package.loaded["src.render.GbcPalette"]={}
package.loaded["src.core.GameVersion"]={generation=function() return 1 end,isYellow=function() return false end}
package.loaded["src.render.PaletteFX"]={usesGbcPack=function() return false end,
    usesSpriteObp=function() return false end, honorsTrueColor=function() return true end,
    dmgObj=function() return defaultColors,"dmg" end}
package.loaded["src.render.TileRenderer"]={
    recolorSample=dofile("../gen1recomp-lab/src/render/AtlasBake.lua").recolorSample}
local SpriteRenderer=require("src.render.SpriteRenderer")
local PresentationObject=require("src.world.PresentationObject")
local Mat4=dofile("../potato_voxel/lib/Mat4.lua")
local Sandbox=require("src.mods.Sandbox")
local compat=require("src.mods.LegacyCompat").new({modId="PORYGONAL_OVERWORLD_CHARACTERS",modPath=".",fs={}})
local env=Sandbox.envFor({modId="PORYGONAL_OVERWORLD_CHARACTERS",
    permissions={engine_internals=true},compat=compat})
local modules, ecosystem, state, mode
local mod={path=".",log={info=function() end,error=function() end,warn=function() end}}
function mod:read(path)
    reads[path]=(reads[path] or 0)+1
    if overrides[path]==false then return nil end
    return overrides[path] or read(path)
end
mod.find=function(id)
    if id=="porygonal_ecosystem" then return ecosystem end
    if id=="potato_voxel" then return {exports={lib={require=function(n) return modules[n] end}}} end
end
local function loadLocal(path,...)
    local source=mod:read(path)
    if not source then return nil end
    local chunk=assert(env.loadstring(source,"@"..path))
    return chunk(...)
end
local Runtime=loadLocal("character_runtime.lua")
local Registry=loadLocal("ecosystem_registry.lua")
local ballPath="assets/ball_poke_idle.lua"
local Ball=dofile("../porygonal-ecosystem/ecosystem/ball_identity.lua")
local palettes=dofile("../porygonal-ecosystem/palettes/ball_palettes.lua")
local CaptureRuntime=dofile("../porygonal-ecosystem/ecosystem/capture_runtime.lua")
local CapturePresentation=dofile("../porygonal-ecosystem/ecosystem/capture_presentation.lua")
local object
local queries=0
local function attachEcosystem()
    local current={x=1.25,y=2.5,facing="down"}
    state.player=current
    local token={isActive=function() return true end}
    local world={current=function() current.mapId=mode.mapId; return current end,
        playerPhysicalPosition=function() return {x=0,y=0} end,
        overworld=function() return state end,
        acquirePlayerAppearanceOverride=function() return token end,
        setPlayerFacing=function(_,facing) current.facing=facing; return true end,
        createPresentation=function(_,mapId,spec)
            local p=object("held",spec.x,spec.y)
            state.presentations[mapId]={p}
            return {id=p.id,presentation=p,ow=state,
                setPosition=function(_,...) return p:setPosition(...) end,
                setVisualElevation=function(_,...) return p:setVisualElevation(...) end}
        end}
    mode=CaptureRuntime.attach({world=world,events={on=function() end},hooks={wrap=function() end},
        content={sprites={register=function() end}},assets={path=function(_,p) return p end}},
        {BallIdentity=Ball,BallPalettes=palettes,CapturePresentation=CapturePresentation,
        CaptureMode={new=function(config)
            return {config=config,isActive=function() return true end}
        end}})
    mode.state="THROWING"; mode.mapId="MAP_A"
    local function query(mapId,id,observed)
        queries=queries+1
        check(mapId==observed.mapId and id==observed.id,"all three exact native arguments")
        return mode:captureBallVisualData(mapId,id,observed)
    end
    ecosystem={exports={captureBallVisualData=query}}
end
object=function(id,x,y)
    local sprite=SpriteRenderer.new({image="native.png",frames=1},id)
    local p=PresentationObject.new({},"MAP_A",{x=x or 1.25,y=y or 2.5,drawOrder=2},
        id,1,{sprite=sprite,spriteId="SPRITE_POKE_BALL"})
    p:setVisualElevation(0.75)
    return p
end
local runtime
local function harness()
    records={}; graphicsState={}; stack={}
    shadowDraws={}; shadowCache={}; sceneAttempts=0; passCounts={world=0,actor=0}; shaderUniforms={}
    state={map={id="MAP_A"},entities={},presentations={MAP_A={}},neighbors={}}
    attachEcosystem()
    local Voxel3D={cell=2,
        newMesh=function(vertices)
            if gpuFail then error("recoverable mesh allocation") end
            return {vertices=vertices,setTexture=function() end}
        end,
        depth=function(v) graphicsState.depth=v end,
        seams=function(v) graphicsState.seams=v end,
        glass=function(v) graphicsState.glass=v end,
        draw=function(mesh,texture,model)
            if drawFail then error("recoverable draw") end
            check(graphicsState.active and not graphicsState.overlay,"mesh in open 3D view")
            check(graphicsState.depth=="test","mesh depth-tested")
            check(not graphicsState.seams and not graphicsState.glass,"no grid/glass on ball")
            records[#records+1]={mesh=mesh,texture=texture,model=model,eye=graphicsState.eye}
        end,
        project=function(x,y,z) return x*2+graphicsState.eye,y*3+z*2,1.5 end,
        beginOverlay=function()
            if state.failOverlay then return false end
            graphicsState.overlay=true; return true
        end,
        endScene=function()
            check(graphicsState.active and not graphicsState.overlay,"scene state restored before closure")
            graphicsState.active=false
            return "canvas"..graphicsState.eye
        end}
    local Scene={groundAt=function(map,cx,cy)
        check(map.id=="MAP_A" or map.id=="MAP_B","terrain sampled on source map")
        local source=state.presentations[map.id][1]
        check(cx==math.floor(source.px/16) and cy==math.floor(source.py/16),
            "terrain from native continuous position")
        return map.id=="MAP_A" and 3 or 7
    end}
    local deps={Mat4=Mat4,VoxelState={level=1,FOCAL=1,angle=0},
        ShadowSettings={quality=function() return 512 end},
        Platform={isIOS=function() return false end},
        PixelCanvas={new=function() return true,canvas() end}}
    local ShadowMap=assert(loadfile("../potato_voxel/lib/ShadowMap.lua"))(
        {require=function(name) return assert(deps[name],name) end})
    Scene.render=function(_,_,_,_,_,_,eyes)
        sceneAttempts=sceneAttempts+1
        records={} -- only the latest scene attempt can be published
        if state.failBegin then return nil end
        if not state.noShadows then
            local worldSig="world:"..ShadowMap.KX..","..ShadowMap.KZ
            local actorSig="actors:"..ShadowMap.KX..","..ShadowMap.KZ
            local worldStale=ShadowMap.stale(worldSig,false)
            local actorStale=ShadowMap.stale(actorSig,true)
            for _,sprites in ipairs({false,true}) do
                if (sprites and (actorStale or worldStale)) or (not sprites and worldStale) then
                    check(ShadowMap.begin(80,72,160,144,sprites),"real shadow pass opens")
                    if sprites then passCounts.actor=passCounts.actor+1
                    else passCounts.world=passCounts.world+1 end
                    shadowDraws={}
                    -- Other casters keep exactly the submission supplied by PV.
                    ShadowMap.draw("foreign-caster",nil,Mat4.translate(1,2,3))
                    ShadowMap.finish(sprites and actorSig or worldSig,sprites)
                    shadowCache[sprites and "actor" or "world"]=shadowDraws
                end
            end
        end
        local out={}
        for eye=1,eyes and #eyes or 1 do
            graphicsState={active=true,eye=eye,cull="none"}
            out[eye]=Voxel3D.endScene()
        end
        return eyes and out or out[1]
    end
    modules={VoxelScene=Scene,Voxel3D=Voxel3D,Mat4=Mat4,
        SpriteBillboards={mesh=function() end},ShadowMap=ShadowMap,
        WorldFeature={},ChunkMesher={},TileShape={},MeshCache={}}
    runtime=Runtime.create(mod,loadLocal,"redBlue")
    check(loadLocal("renderers/potato_voxel/potato_voxel_adapter.lua").initialize(
        mod,loadLocal,{},runtime),"adapter initialized")
    return function(eyes, paletteFor)
        records={}
        local before={}; for k,v in pairs(state.presentations.MAP_A[1] or {}) do before[k]=v end
        local result=Scene.render(state,320,288,160,144,paletteFor,eyes)
        for k,v in pairs(before) do check(state.presentations.MAP_A[1][k]==v,"no native mutation: "..k) end
        check(#stack==0,"graphics stack balanced")
        return records,result
    end
end
local function launch(p, kind)
    state.presentations.MAP_A={p}
    mode.projectile={presentation=p,id=p.id,ow=state}
    mode.launchedBall=Ball.resolve(kind or "POKE_BALL",palettes)
end
local render=harness()
local p=object("projectile"); launch(p)
local draws,result=render()
check(result=="canvas1" and #draws==1 and draws[1].mesh,"one 3D submission, no duplicate 2D")
local mesh=draws[1].mesh
check(#mesh.vertices==400,"real ball mesh through existing loader")
local asset=runtime.loadAsset(Registry.lookupCaptureBall({ballType="POKE_BALL",role="projectile"}).asset)
check(#asset.indices==546 and runtime.loadAsset(Registry.lookupCaptureBall(
    {ballType="POKE_BALL",role="projectile"}).asset)==asset,"182 triangles, existing CPU cache")
check(draws[1].model[4]==28 and draws[1].model[8]==23 and draws[1].model[12]==52,
    "native world anchor + frame center + terrain + elevation; no minY offset")
for i=1,4 do for j=1,3 do
    check(draws[1].texture.data.pixels[i][j]==palettes.palette_pokeball[i][j]/255,"explicit Ecosystem RGB")
end end
check(not reads["assets/porygonal_characters.pak"],"no PAK access")
draws,result=render({{}, {}})
check(#draws==2 and draws[1].eye==1 and draws[2].eye==2 and #result==2,"one draw per eye")
check(draws[1].mesh==mesh and draws[2].mesh==mesh,"existing GPU cache across views")
-- Native elevation changes are consumed; no call to ThrowController is needed.
p:setVisualElevation(1.5); draws=render()
check(draws[1].model[8]==35,"native elevation update")
-- A non-default native anchor is honored without changing authored vertices.
p.sprite.anchorX=6; p.sprite.anchorY=10; draws=render()
check(draws[1].model[4]==30 and draws[1].model[8]==29,"native frame anchor")

for _,spec in ipairs({
    {"POKE_BALL","assets/ball_poke_idle.lua"},
    {"GREAT_BALL","assets/ball_great_idle.lua"},
    {"ULTRA_BALL","assets/ball_ultra_idle.lua"},
    {"MASTER_BALL","assets/ball_master_idle.lua"},
}) do
    render=harness(); p=object("projectile"); launch(p,spec[1])
    p:setGroundShadow(true); p.shadowImg={nativeShadow=true}
    draws=render()
    local replacement=Registry.lookupCaptureBall({ballType=spec[1],role="projectile"})
    check(replacement.asset.mesh==spec[2] and Registry.allowsMesh(spec[2]),
        spec[1]..": explicit registry and Lua allowlist")
    local loaded=assert(runtime.loadAsset(replacement.asset))
    check(#loaded.vertices>0 and #loaded.indices>0 and reads[spec[2]],spec[1]..": real Lua mesh loaded")
    check(#draws==1 and draws[1].mesh and draws[1].mesh.vertices==loaded.vertices,
        spec[1]..": one mesh, no native sprite or shadow")
    check(#shadowCache.actor==2 and shadowCache.actor[2].mesh==draws[1].mesh
        and shadowCache.actor[2].model==draws[1].model and shadowCache.actor[2].sprite==1,
        spec[1]..": actual ShadowMap actor pass uses identical mesh and model")
    for i=1,4 do for j=1,3 do
        check(draws[1].texture.data.pixels[i][j]==mode.launchedBall.colors[i][j]/255,
            spec[1]..": exact Ecosystem RGB")
    end end
    check(draws[1].model[4]==28 and draws[1].model[8]==23 and draws[1].model[12]==52,
        spec[1]..": existing native transform")
end
check(not Registry.lookupCaptureBall({ballType="UNKNOWN_BALL",role="projectile"}),
    "unknown type has no mesh fallback")
check(not Registry.allowsMesh("assets/ball_unknown_idle.lua"),"Lua allowlist remains closed")

local function fallback(label, setup, keepShadow)
    local draw=harness(); local ball=object("projectile"); launch(ball)
    ball:setGroundShadow(true); ball.shadowImg={nativeShadow=true}
    setup(ball)
    local all=draw()
    local list, shadows={},0
    for _,record in ipairs(all) do
        if record.image==ball.shadowImg then shadows=shadows+1
        else list[#list+1]=record end
    end
    check(shadows==(keepShadow and 4 or 0),label..": targeted shadow policy")
    check(ball.groundShadow==true,label..": native shadow property untouched")
    check(#list==1 and list[1].native,label..": native image actually emitted")
    check(#shadowCache.actor==1 and shadowCache.actor[1].mesh=="foreign-caster",
        label..": no orphan caster; foreign caster preserved")
    check(list[1].args[2]==-8 and list[1].args[3]==-16,label..": native anchor preserved")
    check(list[1].x==57 and list[1].y==149 and list[1].scale==3,label..": projected elevation/scale")
end
fallback("absent Ecosystem",function() ecosystem=nil end,true)
fallback("absent export",function() ecosystem.exports={} end,true)
fallback("query error",function() ecosystem.exports.captureBallVisualData=function() error("query") end end,true)
fallback("unknown presentation",function() mode.projectile=nil end,true)
fallback("stale native identity",function(ball) mode.projectile.presentation=object(ball.id) end,true)
fallback("retired owner",function() mode.cleanupPending=true end,true)
fallback("unknown type",function() mode.launchedBall.type="UNKNOWN_BALL" end)
fallback("unknown role",function() ecosystem.exports.captureBallVisualData=function(map,id)
    return {mapId=map,presentationId=id,ballType="POKE_BALL",role="foreign",colors=defaultColors}
end end,true)
for _,bad in ipairs({false,{},{{255,255,255}},{{255,255,255},{1,2,3},{4,5,6},{0,0,0/0}}}) do
    fallback("invalid palette",function() ecosystem.exports.captureBallVisualData=function(map,id)
        return {mapId=map,presentationId=id,ballType="POKE_BALL",role="projectile",colors=bad}
    end end)
end
fallback("out-of-range palette",function() ecosystem.exports.captureBallVisualData=function(map,id)
    return {mapId=map,presentationId=id,ballType="POKE_BALL",role="projectile",
        colors={{256,255,255},{1,2,3},{4,5,6},{0,0,0}}}
end end)
fallback("mismatched response identity",function() ecosystem.exports.captureBallVisualData=function()
    return {mapId="MAP_B",presentationId="projectile",ballType="POKE_BALL",role="projectile",colors=defaultColors}
end end,true)
overrides[ballPath]=false; fallback("missing mesh",function() end); overrides[ballPath]=nil
overrides[ballPath]="return {vertices={},indices={}}"
fallback("invalid mesh",function() end); overrides[ballPath]=nil
gpuFail=true; fallback("GPU allocation failure",function() end); gpuFail=false
textureFail=true; fallback("GPU texture failure",function() end); textureFail=false
drawFail=true; fallback("GPU draw failure",function() end); drawFail=false

render=harness(); p=object("projectile"); launch(p)
p:setGroundShadow(true); p.shadowImg={nativeShadow=true}; p:setGroundShadowOffset(4,-2)
draws=render()
check(#draws==1 and draws[1].mesh,"projectile mesh without native ground shadow")
check(p.groundShadow and p.groundShadowOffsetX==4 and p.groundShadowOffsetY==-2,
    "native shadow settings preserved")
p:setVisualElevation(2); draws=render()
check(#draws==1 and draws[1].mesh,"no projectile shadow after elevation update")
-- Unidentified native presentations, including a shared Ball sprite, retain shadows.
mode.projectile=nil; draws=render()
check(#draws==5 and draws[1].image==p.shadowImg and draws[5].native,
    "foreign presentation keeps four shadow blits and native sprite")
check(draws[1].x==65 and draws[1].y==109,"foreign shadow offsets and ground position")

render=harness(); p=object("projectile"); launch(p)
local neighbor=object("neighbor"); neighbor.mapId="MAP_B"; neighbor.drawSequence=2
state.presentations.MAP_B={neighbor}
state.neighbors={{map={id="MAP_B"},ox=100,oy=-16}}
draws=render()
check(#draws==2 and draws[2].native,"unknown neighbor retained")
check(draws[2].x==257 and draws[2].y==129,"source terrain and neighbor map offsets")
-- Real ECO query requires the current map. Move both world and owner to B
-- while rendering it as a neighbor to exercise a supported visual transform.
mode.mapId="MAP_B"; mode.projectile={id=neighbor.id,presentation=neighbor,ow=state}
draws=render()
check(draws[1].mesh and draws[1].model[4]==128 and draws[1].model[8]==27
    and draws[1].model[12]==36,"mesh respects source map terrain and neighbor offsets")

render=harness(); p=object("projectile"); launch(p); ecosystem=nil
draws=render({{}, {}})
check(#draws==2 and draws[1].native and draws[2].native
    and draws[1].eye==1 and draws[2].eye==2,"native fallback in each eye")
state.failOverlay=true
local ok=pcall(render)
check(not ok and not graphicsState.active and #stack==0,
    "overlay failure closes scene and propagates instead of silently dropping fallback")

render=harness(); p=object("projectile"); launch(p)
local ThrowController=dofile("../porygonal-ecosystem/ecosystem/throw_controller.lua")
local controller=assert(ThrowController.new({x=1.25,y=2.5},{x=1.75,y=2.75},p,
    {duration=1,startElevation=0.35,arcHeight=1.5}))
controller:update(0.25)
local px,py,elevation,elapsed=p.px,p.py,p.visualElevation,controller.elapsed
draws=render()
check(draws[1].model[4]==px+8 and draws[1].model[12]==py+12
    and draws[1].model[8]==3+elevation*16+8,"actual ThrowController output consumed directly")
check(p.px==px and p.py==py and p.visualElevation==elevation and controller.elapsed==elapsed,
    "render leaves trajectory, timing and elevation unchanged")

render=harness(); p=object("projectile"); launch(p)
p.visible=false; draws=render(); check(#draws==0,"invisible presentation excluded")
p.visible=true; p.destroyed=true; draws=render(); check(#draws==0,"destroyed presentation excluded")
p.destroyed=false; state.failBegin=true
draws,result=render(); check(#draws==0 and result==nil,"no injection after failed scene begin")

-- Native layered FX retain frame selection and before/after ordering.
render=harness(); p=object("fx"); launch(p); mode.projectile=nil
local a=SpriteRenderer.new({image="before.png",frames=2},"a")
local b=SpriteRenderer.new({image="after.png",frames=2},"b")
p.renderLayers={{sprite=b,phase="afterActors",order=0,index=2},
    {sprite=a,phase="beforeActors",order=0,index=1}}
p.sprite=b
check(p:setFrame(1),"native layered frame selection accepted")
draws=render()
check(#draws==2 and draws[1].args[1]==a.frames[1] and draws[2].args[1]==b.frames[1],
    "native layered FX ordering and exact selected frames")
check(#state.entities==0 and #state.presentations.MAP_A==1,"no additional world entity/presentation")
check(queries>0,"real Ecosystem identity query consumed")
print("PASS: "..checks.." targeted capture-ball checks (simulated GPU; native 2D replay)")

local function near(a,b,label) check(math.abs(a-b)<1e-9,label) end
local function sameModel(a,b,label)
    for i=1,16 do near(a[i],b[i],label.." ["..i.."]") end
end
render=harness(); p=object("projectile"); launch(p)
draws=render()
local stable=draws[1].model
local actorPasses,worldPasses=passCounts.actor,passCounts.world
draws=render({{}, {}})
check(passCounts.actor==actorPasses and passCounts.world==worldPasses,
    "unchanged ball does not refresh either solar layer")
sameModel(draws[1].model,stable,"paused ball keeps its transform")
check(draws[1].model==draws[2].model,"both eyes share the frame transform")
p:setPosition(1.5,2.5); draws=render()
check(passCounts.actor==actorPasses+1 and passCounts.world==worldPasses,
    "ball movement refreshes only actor layer")
check(shadowCache.actor[2].model==draws[1].model,"moving ball caster shares visible matrix")
p:setVisualElevation(1.25); draws=render()
check(passCounts.actor==actorPasses+2 and passCounts.world==worldPasses,
    "ball elevation invalidates actor cache")
check(shadowCache.actor[2].model[8]==draws[1].model[8],"caster uses native elevation")
local oldLight=shadowCache.actor[2].light
modules.ShadowMap.KX=0.65; modules.ShadowMap.KZ=0.25
draws=render()
check(shadowCache.actor[2].light~=nil and oldLight~=nil,"real light VP sent to caster shader")
-- The real module reuses its matrix storage: verify its ray direction
-- projects equal points on the ground/along the sun shear to the same UV.
local uv=modules.ShadowMap.uvVP
local x,y,z=draws[1].model[4],draws[1].model[8],draws[1].model[12]
local gx,gz=x+modules.ShadowMap.KX*y,z+modules.ShadowMap.KZ*y
near(uv[1]*x+uv[2]*y+uv[3]*z+uv[4],uv[1]*gx+uv[3]*gz+uv[4],
    "shadow light X follows current shear and elevation")
near(uv[5]*x+uv[6]*y+uv[7]*z+uv[8],uv[5]*gx+uv[7]*gz+uv[8],
    "shadow light Y follows current shear and elevation")
mode.projectile=nil; draws=render()
check(#shadowCache.actor==1,"retired projectile cleared from cached shadow layer")
actorPasses=passCounts.actor; worldPasses=passCounts.world
render(); render()
check(passCounts.actor==actorPasses and passCounts.world==worldPasses,
    "absent projectiles retain native cache optimization")

for _,kind in ipairs({"POKE_BALL","GREAT_BALL","ULTRA_BALL","MASTER_BALL"}) do
  for _,direction in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
    render=harness(); p=object("projectile"); launch(p,kind); render()
    p:setPosition(1.25+direction[1]*0.01,2.5+direction[2]*0.01)
    draws=render({{}, {}})
    local m=draws[1].model
    check(m[2]*direction[1]+m[10]*direction[2]<0,"mesh top rolls in reverse")
    near(m[6],math.cos(0.16/3.097192),"original angular speed retained")
    near(m[2]*direction[1]+m[10]*direction[2],-math.sin(0.16/3.097192),
        "only angular sign reversed")
    near(m[4],p.px+8,"central pivot X fixed")
    near(m[8],23,"central pivot Y fixed")
    near(m[12],p.py+12,"central pivot Z fixed")
    near(m[2]*direction[2]-m[10]*direction[1],0,"roll has no sideways component")
    check(m==draws[2].model and m==shadowCache.actor[2].model,
        "four directions: both eyes and caster share transform")
  end
end

local function sampledThrow(steps)
    local draw=harness(); local ball=object("sampled"); launch(ball)
    local controller=assert(ThrowController.new({x=1.25,y=2.5},{x=1.75,y=2.75},ball,
        {duration=1,startElevation=0.35,arcHeight=1.5}))
    draw()
    local result
    for i=1,steps do controller:update(1/steps); result=draw() end
    check(controller.state=="THROW_COMPLETE" or controller.elapsed>1-1e-12,
        "real ThrowController timing preserved")
    return result[1].model
end
sameModel(sampledThrow(30),sampledThrow(144),"30/144Hz give same final roll")

render=harness(); p=object("projectile"); launch(p); render()
drawFail=true; draws=render({{}, {}}); drawFail=false
check(sceneAttempts==3 and #draws==2 and draws[1].native and draws[2].native,
    "late draw failure retries once; publishes native fallback in both eyes")
check(#shadowCache.actor==1 and shadowCache.actor[1].mesh=="foreign-caster",
    "late visible failure removes cached ball caster without losing other casters")
render=harness(); p=object("projectile"); launch(p)
shadowFail=true; draws=render(); shadowFail=false
check(#draws==1 and draws[1].native and #shadowCache.actor==1,
    "caster failure keeps native fallback without orphan caster")

render=harness(); p=object("projectile"); launch(p)
state.noShadows=true; draws=render()
check(#draws==1 and draws[1].mesh and passCounts.actor==0,"no caster when shadows disabled")
state.noShadows=false; draws=render()
check(#shadowCache.actor==2,"existing solar pass resumes after shadows enabled")
local staleHook,finishHook=modules.ShadowMap.stale,modules.ShadowMap.finish
check(loadLocal("renderers/potato_voxel/potato_voxel_adapter.lua").initialize(
    mod,loadLocal,{},runtime),"adapter can initialize again on same PV modules")
check(modules.ShadowMap.stale==staleHook and modules.ShadowMap.finish==finishHook,
    "solar wrappers do not stack on repeated initialization")
p:setVisualElevation(1.5); draws=render()
check(#draws==1 and draws[1].mesh and #shadowCache.actor==2,
    "reinitialization keeps one visible mesh and one ball caster")
check(shadowCache.actor[2].model==draws[1].model,"reinitialized dispatch uses current context")
-- Exercise the real CapturePresentation offsets and ECO-T028 held query.
local function aim(kind,target)
    mode.state="AIMING"
    mode.config.selectBall(Ball.resolve(kind,palettes))
    check(mode.config.presentation:begin("MAP_A",{x=0,y=0},target),"real held presentation begins")
    return state.presentations.MAP_A[1]
end
local targets={up={x=1.25,y=1.5},down={x=1.25,y=3.5},
    left={x=0.25,y=2.5},right={x=2.25,y=2.5}}
for _,kind in ipairs({"POKE_BALL","GREAT_BALL","ULTRA_BALL","MASTER_BALL"}) do
    local placements={}
    for facing,target in pairs(targets) do
        render=harness(); p=aim(kind,target)
        local offset=CapturePresentation.defaults[facing]
        near(p.px,20+offset.xPx,"native held offset X")
        near(p.py,40+offset.yPx,"native held offset Y")
        near(p.visualElevation*16,offset.elevationPx,"native held elevation")
        local replacement,colors,projectile=runtime.captureBallReplacementFor("MAP_A",p.id,p)
        check(replacement.offsetY==-6.2,"held registry height calibration")
        check(Registry.lookupCaptureBall({ballType=kind,role="projectile"}).offsetY==nil,
            "projectile has no held calibration")
        check(Registry.lookupCaptureBall({ballType=kind,role="projectile"}).offsetXByFacing==nil,
            "projectile has no held side spacing")
        check(replacement.asset.mesh==Registry.lookupCaptureBall({ballType=kind,role="projectile"}).asset.mesh
            and not projectile,"held reuses type mapping without projectile identity")
        draws=render({{}, {}})
        placements[facing]=draws[1].model
        check(#draws==2 and draws[1].mesh and draws[2].mesh,"held mesh once per eye; no 2D duplicate")
        local spacing=facing=="right" and -1 or (facing=="left" and 1 or 0)
        sameModel(draws[1].model,Mat4.translate(p.px+8+spacing,3+p.visualElevation*16+8-6.2,p.py+12+(facing=="down" and -3 or 0)),
            "held native anchor with visual height calibration, no rotation")
        check(#shadowCache.actor==1 and shadowCache.actor[1].mesh=="foreign-caster",
            "held adds no solar caster")
        for i=1,4 do for j=1,3 do
            near(draws[1].texture.data.pixels[i][j],colors[i][j]/255,"held exact Ecosystem RGB")
        end end
        local passes=passCounts.actor
        check(mode.config.presentation:updateAim({},targets.right),"held follows native aiming update")
        draws=render()
        sameModel(draws[1].model,Mat4.translate(p.px+8-1,19-6.2,p.py+12),"held moves without rolling")
        check(passCounts.actor==passes,"held motion does not invalidate solar cache")
        check(#state.entities==0 and #state.presentations.MAP_A==1
            and mode.config.presentation.heldBall.presentation==p,"same native held object")
        p.visible=false; check(#render()==0,"hidden held stays hidden")
        p.visible=true; p.destroyed=true; check(#render()==0,"destroyed held stays hidden")
    end
    -- The player anchor is x=20+8. Extend the native +/-4px offsets by
    -- one world X unit without reflecting the already mirrored anchors.
    near(placements.left[4]-28,5,"west hand spacing increases outward by one")
    near(placements.right[4]-28,-5,"east hand spacing increases outward by one")
    near(placements.left[4]+placements.right[4],56,"east/west symmetric about player X")
    near(placements.left[12],placements.right[12],"east/west share native ground Z")
    near(placements.left[8],placements.right[8],"east/west share calibrated height")
    near(placements.up[4]-28,6,"north horizontal placement unchanged")
    near(placements.down[4]-28,-6,"south retains native X without previous correction")
    near(placements.down[12],49,"south moves backward by three world Z units")
    near(placements.up[12],52,"north depth unchanged")
    near(placements.left[12],52,"west depth unchanged")
    near(placements.right[12],52,"east depth unchanged")
end

for _,facing in ipairs({"down","left","right"}) do
  for _,failure in ipairs({"missing mesh","GPU allocation","texture","draw","palette","stale identity"}) do
    render=harness(); p=aim("POKE_BALL",targets[facing])
    if failure=="missing mesh" then overrides[ballPath]=false
    elseif failure=="GPU allocation" then gpuFail=true
    elseif failure=="texture" then textureFail=true
    elseif failure=="draw" then drawFail=true
    elseif failure=="palette" then
        local query=ecosystem.exports.captureBallVisualData
        ecosystem.exports.captureBallVisualData=function(...)
            local visual=query(...); visual.colors={}; return visual
        end
    else mode.config.presentation.heldBall.presentation=object(p.id) end
    draws=render({{}, {}})
    overrides[ballPath]=nil; gpuFail=false; textureFail=false; drawFail=false
    check(#draws==2 and draws[1].native and draws[2].native,failure..": held native fallback only")
    near(draws[1].y,137,failure..": native fallback excludes 3D height and SOUTH depth calibration")
    near(draws[1].x,(p.px+8)*2+1,failure..": native fallback retains directional X anchor")
    check(#shadowCache.actor==1,failure..": no held caster")
    check(#state.presentations.MAP_A==1 and p.visible and not p.destroyed,
        failure..": native owner preserved")
  end
end
-- OWC-T035: replay ECO-T041's actual two-layer native appearance as one mesh.
local function aimCursor()
    local defs = {}
    for _, id in ipairs({"ECO_AIM_BACK", "ECO_AIM_FRONT"}) do
        defs[id] = {image=id..".png", frames=1, frameWidth=16, frameHeight=16,
            frameColumns=1, anchorX=8, anchorY=16,
            paletteSource="ROM:SpriteSheetPointerTable[0]"}
    end
    local spec={x=1.25,y=2.5,layers={
        {sprite="ECO_AIM_BACK",phase="beforeActors"},
        {sprite="ECO_AIM_FRONT",phase="afterActors"}}}
    local id="porygonal_ecosystem_presentation_12"
    local appearance=assert(PresentationObject.appearance({sprites=defs},spec,id))
    local cursor=PresentationObject.new({},"MAP_A",spec,id,12,appearance)
    state.presentations.MAP_A={cursor}
    return cursor
end
local function aimPalette() return defaultColors end
render=harness(); p=aimCursor()
draws=render({{},{}},aimPalette)
check(#draws==2 and draws[1].mesh and draws[2].mesh,"Aim: one mesh per eye, no 2D layers")
check(#draws[1].mesh.vertices==294 and draws[1].mesh==draws[2].mesh,"Aim: real mesh and GPU cache")
local aimAsset=assert(runtime.loadAsset(Registry.lookupCaptureAim().asset))
check(#aimAsset.indices==1440,"Aim: 480 triangles via CharacterRuntime")
local lo,hi={math.huge,math.huge,math.huge},{-math.huge,-math.huge,-math.huge}
for _,v in ipairs(aimAsset.vertices) do
    for j=1,3 do lo[j]=math.min(lo[j],v[j]); hi[j]=math.max(hi[j],v[j]) end
    check(v[4]>=0 and v[4]<=1 and v[5]>=0 and v[5]<=1,"Aim: valid UV")
end
near(lo[2],0.585502,"Aim: authored base")
check(math.abs((lo[1]+hi[1])/2)<0.00001,"Aim: centered X pivot")
check(math.abs((lo[3]+hi[3])/2)<0.00001,"Aim: centered Z pivot")
near(Registry.lookupCaptureAim().offsetY - (-0.585502),3,"Aim: exactly +3 height calibration")
sameModel(draws[1].model,Mat4.translate(28,3+2.414498,48),"Aim: continuous cell center plus unchanged Y")
for i=1,4 do for j=1,3 do
    near(draws[1].texture.data.pixels[i][j],defaultColors[i][j]/255,"Aim: native resolved palette")
end end
check(#shadowCache.actor==2 and shadowCache.actor[1].mesh=="foreign-caster",
    "Aim: exactly one additional solar caster for both native layers")
check(shadowCache.actor[2].mesh==draws[1].mesh and shadowCache.actor[2].model==draws[1].model
    and draws[1].model==draws[2].model,"Aim: both eyes and solar caster share mesh transform")
local aimActorPasses,aimWorldPasses=passCounts.actor,passCounts.world
render({{},{}},aimPalette)
check(passCounts.actor==aimActorPasses and passCounts.world==aimWorldPasses,
    "Aim: unchanged cursor reuses both solar caches across eyes")
p:setPosition(3.5,4.25)
draws=render(nil,aimPalette)
check(passCounts.actor==aimActorPasses+1 and passCounts.world==aimWorldPasses,
    "Aim: movement invalidates only actor cache")
p:setVisualElevation(0.25)
draws=render(nil,aimPalette)
sameModel(draws[1].model,Mat4.translate(64,7+2.414498,76),"Aim: native position/elevation updates without snapping")
check(passCounts.actor==aimActorPasses+2 and shadowCache.actor[2].model==draws[1].model,
    "Aim: elevation invalidates caster with identical transform")
modules.ShadowMap.KX=0.65; modules.ShadowMap.KZ=0.25
draws=render({{},{}},aimPalette)
local aimUV=modules.ShadowMap.uvVP
local ax,ay,az=draws[1].model[4],draws[1].model[8],draws[1].model[12]
local agx,agz=ax+modules.ShadowMap.KX*ay,az+modules.ShadowMap.KZ*ay
check(shadowCache.actor[2].light==modules.ShadowMap.clipVP,
    "Aim: caster receives current solar light matrix")
near(aimUV[1]*ax+aimUV[2]*ay+aimUV[3]*az+aimUV[4],aimUV[1]*agx+aimUV[3]*agz+aimUV[4],
    "Aim: solar projection X follows current light direction")
near(aimUV[5]*ax+aimUV[6]*ay+aimUV[7]*az+aimUV[8],aimUV[5]*agx+aimUV[7]*agz+aimUV[8],
    "Aim: solar projection Y follows current light direction")
p.visible=false; check(#render(nil,aimPalette)==0,"Aim: hidden owner")
check(#shadowCache.actor==1,"Aim: hidden cursor removed from solar cache")
p.visible=true; render(nil,aimPalette)
check(#shadowCache.actor==2,"Aim: reappearance invalidates solar cache")
p.visible=true; p.destroyed=true; check(#render(nil,aimPalette)==0,"Aim: destroyed owner")
check(#shadowCache.actor==1,"Aim: destroyed cursor removed from solar cache")
aimActorPasses=passCounts.actor; render(nil,aimPalette)
check(passCounts.actor==aimActorPasses,"Aim: absent cursor retains cache optimization")

render=harness(); p=aimCursor(); render(nil,aimPalette)
drawFail=true; draws=render({{},{}},aimPalette); drawFail=false
check(sceneAttempts==3 and #draws==4,"Aim: late failure retries scene for both eyes")
for _,d in ipairs(draws) do check(d.native,"Aim: late failure restores both native layers") end
check(#shadowCache.actor==1 and shadowCache.actor[1].mesh=="foreign-caster",
    "Aim: late failure removes cached caster and preserves foreign caster")

for _,failure in ipairs({"no Ecosystem","foreign owner","different layer","different phase",
    "single sprite","missing mesh","invalid mesh","empty mesh","missing texture","GPU","texture","draw","caster","missing palette",
    "invalid palette","different layer palettes"}) do
    render=harness(); p=aimCursor()
    local palette=aimPalette
    if failure=="no Ecosystem" then ecosystem=nil
    elseif failure=="foreign owner" then p.id="other_presentation_12"
    elseif failure=="different layer" then p.renderLayers[2].spriteId="OTHER_FX"
    elseif failure=="different phase" then p.renderLayers[2].phase="beforeActors"
    elseif failure=="single sprite" then p.renderLayers=nil
    elseif failure=="missing mesh" then overrides["assets/aim.lua"]=false
    elseif failure=="invalid mesh" then overrides["assets/aim.lua"]="return {vertices={{0}},indices={1,2,3}}"
    elseif failure=="empty mesh" then overrides["assets/aim.lua"]="return {vertices={},indices={}}"
    elseif failure=="missing texture" then overrides["assets/grayscale_palette.png"]=false
    elseif failure=="GPU" then gpuFail=true
    elseif failure=="texture" then textureFail=true
    elseif failure=="draw" then drawFail=true
    elseif failure=="caster" then shadowFail=true
    elseif failure=="missing palette" then palette=nil
    elseif failure=="invalid palette" then palette=function() return {{}} end
    else
        local fx=package.loaded["src.render.PaletteFX"]
        fx.usesGbcPack=function() return true end
        fx.spriteObp=function(def)
            if def==p.renderLayers[1].sprite.def then return defaultColors,"aim-back" end
            return {{1,1,1},{2,2,2},{3,3,3},{4,4,4}},"aim-front"
        end
        palette=nil
    end
    draws=render({{},{}},palette)
    overrides["assets/aim.lua"]=nil; overrides["assets/grayscale_palette.png"]=nil
    gpuFail=false; textureFail=false; drawFail=false; shadowFail=false
    package.loaded["src.render.PaletteFX"].usesGbcPack=function() return false end
    local expected=failure=="single sprite" and 2 or 4
    check(#draws==expected,"Aim "..failure..": complete native fallback per eye")
    for _,d in ipairs(draws) do check(d.native,"Aim "..failure..": no duplicate mesh") end
    check(#shadowCache.actor==1 and shadowCache.actor[1].mesh=="foreign-caster",
        "Aim "..failure..": no orphan caster; foreign caster preserved")
    check(#state.presentations.MAP_A==1 and p.visible and not p.destroyed,
        "Aim "..failure..": preserves one native owner")
end
-- Native grid targets denote cell origins; exercise real cardinal updates.
render=harness(); p=aimCursor()
local GridAimController=dofile("../porygonal-ecosystem/ecosystem/grid_aim_controller.lua")
local grid=GridAimController.new({x=2,y=3},{x=2,y=4},6,function() return true end)
for _,direction in ipairs({"right","up","left","down"}) do
    assert(grid:move(direction))
    local target=grid:targetPosition()
    assert(p:setPosition(target.x,target.y))
    draws=render({{},{}},aimPalette)
    near(draws[1].model[4],(target.x+0.5)*16,"Aim: native grid cell center X")
    near(draws[1].model[12],(target.y+0.5)*16,"Aim: native grid cell center Z")
    check(p.x==target.x and p.y==target.y and p.px==target.x*16 and p.py==target.y*16,
        "Aim: gameplay target and native pixel origin unchanged")
    check(shadowCache.actor[2].model==draws[1].model and draws[2].model==draws[1].model,
        "Aim: centered native target shares caster and both eye transforms")
end
render=harness(); p=aimCursor()
state.presentations.MAP_A={}; p.mapId="MAP_B"
state.presentations.MAP_B={p}; state.neighbors={{map={id="MAP_B"},ox=160,oy=-48}}
draws=render(nil,aimPalette)
sameModel(draws[1].model,Mat4.translate(188,7+2.414498,0),"Aim: cell center plus neighbor offset and source terrain")
check(#shadowCache.actor==2 and shadowCache.actor[2].model==draws[1].model,
    "Aim: neighbor caster shares visual transform")
check(not reads["assets/porygonal_characters.pak"],"Aim: no PAK access")
-- OWC-T039: drive real Ecosystem Wiggles and exact native PresentationObjects.
local Wiggles=dofile("../porygonal-ecosystem/ecosystem/capture_wiggles.lua")
local shakeDef
Wiggles.register({content={sprites={register=function(_,_,def) shakeDef=def end}},
    assets={path=function(_,path) return path end}})
local function startShake(kind,count,caught)
    local ball
    local wiggles=assert(Wiggles.new({createPresentation=function(_,mapId,spec)
        ball=PresentationObject.new({},mapId,spec,"shake",1,
            {sprite=SpriteRenderer.new(shakeDef,"shake"),spriteId=spec.sprite})
        state.presentations[mapId]={ball}
        local handle={id=ball.id,presentation=ball,ow=state}
        for _,method in ipairs({"setFrame","setPosition","setVisualElevation","setGroundShadow"}) do
            local name=method
            handle[name]=function(_,...) return ball[name](ball,...) end
        end
        handle.destroy=function()
            ball.destroyed=true; state.presentations[mapId]={}; return true
        end
        return handle
    end},"MAP_A",{x=1.25,y=2.5},{shakes=count,caught=caught},nil,
        Ball.resolve(kind or "POKE_BALL",palettes)))
    mode.projectile=nil; mode.wiggles=wiggles; mode.state="WIGGLING"
    mode.launchedBall=Ball.resolve(kind or "POKE_BALL",palettes)
    return ball,wiggles
end
local radius=3.097192
local function assertShakePose(list,ball,dx,terrain,ox,oy)
    check(#list==1 and list[1].mesh,"shake: exactly one 3D Ball")
    local m=list[1].model
    local angle=-dx/radius
    check(math.abs(m[1]-math.cos(angle))<1e-9 and math.abs(m[5]-math.sin(angle))<1e-9
        and m[2]==-m[5],"shake: roll sign and distance/radius")
    check(m[4]==ball.px+(ox or 0)+8+dx and m[12]==ball.py+(oy or 0)+8,
        "shake: cell center plus discrete lateral displacement")
    local bottom=math.huge
    for _,v in ipairs(list[1].mesh.vertices) do
        bottom=math.min(bottom,m[5]*v[1]+m[6]*v[2]+m[8])
    end
    check(math.abs(bottom-terrain-ball.visualElevation*16)<1e-8,
        "shake: rotated bottom rests on source terrain plus native elevation")
    check(#shadowCache.actor==2 and shadowCache.actor[2].mesh==list[1].mesh,
        "shake: caster shares visible mesh")
    for i=1,16 do
        check(shadowCache.actor[2].model[i]==m[i],"shake: cached caster shares visible transform")
    end
end
for _,kind in ipairs({"POKE_BALL","GREAT_BALL","ULTRA_BALL","MASTER_BALL"}) do
    render=harness(); local ball,wiggles=startShake(kind,3,true)
    local selected,colors,casting=runtime.captureBallReplacementFor("MAP_A",ball.id,ball)
    check(casting and selected.asset.mesh==Registry.lookupCaptureBall({ballType=kind,role="projectile"}).asset.mesh,
        kind..": ECO-T028 shake uses existing mesh and caster policy")
    local tick=0
    for _,step in ipairs({{0,0,0},{43,0,0},{44,1,-1},{47,1,-1},{48,0,0},
        {51,0,0},{52,2,1},{55,2,1},{56,0,0},{100,1,-1},{104,0,0},{108,2,1},
        {112,0,0},{156,1,-1},{160,0,0},{164,2,1},{168,2,1}}) do
        wiggles:update((step[1]-tick)/60); tick=step[1]
        check(ball.frameIndex==step[2],"real native shake tick "..tick)
        local list=render(); assertShakePose(list,ball,step[3],3)
        for i=1,4 do for j=1,3 do
            check(list[1].texture.data.pixels[i][j]==colors[i][j]/255,
                kind..": shake retains exact Ecosystem RGB")
        end end
    end
    check(wiggles.complete and ball.frameIndex==2,"caught: native final right pose retained")
    mode.state="SUCCESS"; local list=render(); assertShakePose(list,ball,1,3)
    local actorPasses,worldPasses=passCounts.actor,passCounts.world
    list=render({{}, {}})
    check(#list==2 and list[1].model==list[2].model,"shake: stereo shares a single native snapshot")
    check(passCounts.actor==actorPasses and passCounts.world==worldPasses,
        "shake: unchanged SUCCESS pose retains solar caches")
    wiggles:destroy(); mode.wiggles=nil; list=render()
    check(#list==0 and #shadowCache.actor==1,"success cleanup: no Ball or orphan caster")
end
-- Native failure resets to center; zero shakes starts complete and centered.
for _,count in ipairs({0,1,2,3}) do
    render=harness(); local ball,wiggles=startShake("POKE_BALL",count,false)
    wiggles:update(count*56/60)
    check(wiggles.complete and ball.frameIndex==0,"failure: native center at resolved count "..count)
    assertShakePose(render(),ball,0,3)
    mode.state="BREAKOUT_FX"; wiggles:destroy(); mode.wiggles=nil
    check(#render()==0 and #shadowCache.actor==1,"failure: Ball and caster removed by native lifecycle")
end
render=harness(); local shakeBall,shake=startShake("POKE_BALL",1,false)
shake:update(44/60); assertShakePose(render(),shakeBall,-1,3)
-- Ground centering belongs to the cell, independently of 2D frame anchors.
shakeBall.sprite.anchorX=6; shakeBall.sprite.anchorY=10
assertShakePose(render(),shakeBall,-1,3)
shakeBall:setVisualElevation(0.5); assertShakePose(render(),shakeBall,-1,3)
local oldActor,oldWorld=passCounts.actor,passCounts.world
shake:update(4/60); assertShakePose(render(),shakeBall,0,3)
check(passCounts.actor==oldActor+1 and passCounts.world==oldWorld,"shake pose invalidates only actor cache")
shakeBall.visible=false
check(#render()==0 and #shadowCache.actor==1,"hidden shake removes visible Ball and caster")
shakeBall.visible=true; render(); shake:destroy(); mode.state="IDLE"; mode.wiggles=nil
check(#render()==0 and #shadowCache.actor==1,"cancel cleanup removes caster")
-- Neighbor placement samples its own terrain, keeping native offsets/elevation.
render=harness(); shakeBall,shake=startShake("POKE_BALL",1,false); shake:update(52/60)
state.presentations.MAP_A={}; shakeBall.mapId="MAP_B"
state.presentations.MAP_B={shakeBall}; mode.mapId="MAP_B"
state.neighbors={{map={id="MAP_B"},ox=100,oy=-16}}
assertShakePose(render(),shakeBall,1,7,100,-16)
-- Every recoverable failure keeps the native selected quad; no solar orphan.
for _,failure in ipairs({"ecosystem","export","query","foreign","stale","palette","mesh",
    "invalid mesh","GPU","texture","draw","caster","frame"}) do
    render=harness(); shakeBall,shake=startShake("POKE_BALL",1,false)
    shake:update(44/60); render() -- seed the prior valid caster
    if failure=="ecosystem" then ecosystem=nil
    elseif failure=="export" then ecosystem.exports={}
    elseif failure=="query" then ecosystem.exports.captureBallVisualData=function() error("query") end
    elseif failure=="foreign" then mode.wiggles=nil
    elseif failure=="stale" then mode.wiggles.ball.presentation=object("shake")
    elseif failure=="palette" then
        local query=ecosystem.exports.captureBallVisualData
        ecosystem.exports.captureBallVisualData=function(...)
            local visual=query(...); visual.colors={}; return visual
        end
    elseif failure=="mesh" then overrides[ballPath]=false
    elseif failure=="invalid mesh" then overrides[ballPath]="return {vertices={},indices={}}"
    elseif failure=="GPU" then gpuFail=true
    elseif failure=="texture" then textureFail=true
    elseif failure=="draw" then drawFail=true
    elseif failure=="caster" then shakeBall:setFrame(2); shadowFail=true
    elseif failure=="frame" then shakeBall.frameIndex=nil end
    -- Reload CPU/GPU caches for preparation failures after a valid caster.
    if failure=="mesh" or failure=="invalid mesh" or failure=="GPU" or failure=="texture" then
        runtime=Runtime.create(mod,loadLocal,"redBlue")
        check(loadLocal("renderers/potato_voxel/potato_voxel_adapter.lua").initialize(
            mod,loadLocal,{},runtime),"shake fallback: adapter reload")
    end
    local list=render()
    check(#list==1 and list[1].native,failure..": one native shake fallback, no double display")
    check(list[1].args[1]==shakeBall.sprite.frames[shakeBall.frameIndex or 0],
        failure..": fallback retains native shake frame")
    check(#shadowCache.actor==1 and shadowCache.actor[1].mesh=="foreign-caster",
        failure..": fallback clears prior shake caster")
    overrides[ballPath]=nil; gpuFail=false; textureFail=false; drawFail=false; shadowFail=false
end
print("PASS: "..checks.." total targeted checks; real ShadowMap Lua, simulated GPU")
