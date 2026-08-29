PORYGONAL - RENDERER ADAPTER GUIDE
=================================

PURPOSE
-------

The `renderers/` directory is the main extension point for community renderer
support in Porygonal - Overworld Characters.

This guide explains how Porygonal renderer adapters are organized, what an
adapter is responsible for, and how to investigate a new renderer without
breaking the rest of the mod.

You do NOT need access to Porygonal's character asset sources to create a
renderer adapter. Adapters consume the public runtime/Registry contracts and
the packaged character assets through CharacterRuntime.

DIRECTORY LAYOUT
----------------

renderers/
    README_RENDERERS.txt
    renderer_manager.lua

    dramatic_shape/
        dramatic_shape_renderer.lua
        DRAMATIC_SHAPE_README.txt

    dramaless_shape/
        dramaless_shape_renderer.lua
        DRAMALESS_SHAPE_README.txt

    potato_voxel/
        potato_voxel_renderer.lua
        POTATO_VOXEL_README.txt

Preferred convention:

    ONE RENDERER = ONE FOLDER = ONE MAIN IMPLEMENTATION LUA FILE

A renderer-specific README should live beside the adapter and document the
exact renderer versions, hooks, special states, known limitations, and test
matrix.

ARCHITECTURE
------------

Porygonal deliberately separates three responsibilities.

Gen1Recomp / the game owns:
    gameplay state
    actor lifecycle
    maps and movement
    native transitions

The active 3D renderer owns:
    scene rendering
    world geometry
    camera
    shadows
    effects
    reflections
    renderer-specific cache/prebuild systems

Porygonal owns:
    character identity
    replacement asset selection
    character palettes
    visual tuning
    replacement character visuals

A renderer adapter is the bridge between the renderer's draw/state surfaces
and Porygonal's renderer-independent character runtime.

Do not move renderer-specific hooks into the character registry.
Do not hardcode ordinary character identities inside an adapter.

ADAPTER CONTRACT
----------------

A renderer adapter exports:

    Renderer.detect(mod)

    Renderer.initialize(
        mod,
        loadLocalModule,
        Registry,
        CharacterRuntime
    )

`detect(mod)` must be side-effect-free.

It should only determine whether the target renderer is available and appears
compatible.

`initialize(...)` installs the actual compatibility hooks.

The renderer manager intentionally initializes exactly one supported renderer.

If no supported renderer is present, Porygonal does not guess.

If multiple supported renderers are active, Porygonal should not arbitrarily
choose which renderer owns the scene.

WHAT REGISTRY PROVIDES
----------------------

The Registry is the semantic character layer.

An adapter should ask Registry which Porygonal character/state corresponds to
the observed Gen1Recomp/rendered actor.

Ordinary renderer code should not contain character-specific branches such as:

    if spriteId == RED then ...

Character identity belongs in the Registry.

If no Porygonal replacement is available for an observed actor, preserve the
renderer/native behavior.

WHAT CHARACTERRUNTIME PROVIDES
------------------------------

CharacterRuntime is the renderer-independent asset/palette runtime.

Adapters use it to obtain Porygonal replacement data and palette/image state.

The production asset package is intentionally opaque to renderer adapters.
Do not parse or reproduce the package format inside a renderer adapter.

The adapter's job begins after the runtime has provided the character data it
needs.

FIRST STEP: MAP THE RENDERER
----------------------------

Before hooking anything, inspect the exact renderer version.

Find:

    manifest / mod id
    exported library/API
    main scene render entry
    ordinary actor pose collection
    billboard or sprite mesh creation
    visible actor draw
    shadow draw
    renderer FX pass
    reflections or repeated scene passes
    first-person/special camera behavior
    authored map figures
    final scene/lifecycle seam
    cache/prebuild path if relevant

Write down the real call chain.

IMPORTANT:
An exported function is not necessarily the function the renderer actually
calls internally.

A renderer may expose a function on a module table while its render loop calls
a private/local closure directly.

Always trace the call site before wrapping a function.

VALIDATE BEFORE MUTATION
------------------------

Validate the required renderer surfaces before replacing any of them.

Prefer:

    validate A
    validate B
    validate C
    install wrappers

over:

    replace A
    discover B is missing
    return with A still modified

If partial installation cannot be avoided, provide rollback.

POSE SAFETY
-----------

Never call the game's/renderer’s pose function an extra time merely to discover
identity or state.

Pose evaluation may be stateful and may be expected exactly once per actor per
frame.

If you need pose information, observe the renderer's existing pose call and
capture its normal result.

IDENTITY MATCHING
-----------------

Prefer semantic identity.

Useful evidence includes:

    actor/entity reference
    sprite definition
    sprite frame
    facing / phase / mirror
    GPU mesh linked to sprite definition/frame
    game state
    renderer-authored figure mesh
    map/tileset context

Avoid relying on a sequential draw index unless the exact renderer proves a
strict one-actor/one-draw relationship.

Culling, reflections, shadow passes, repeated scene passes, and special states
can all break sequential assumptions.

A useful pattern for billboard renderers is:

    billboard mesh creation
        -> remember GPU mesh -> sprite definition/frame
        -> observe actual 3D draw
        -> ask Registry
        -> draw Porygonal replacement

VISIBLE AND SHADOWS
-------------------

Treat visible geometry and shadows as separate milestones.

Recommended order:

    1. identify the native visible actor
    2. prove it can be suppressed
    3. draw the Porygonal visible model
    4. identify the native shadow
    5. suppress/replace the shadow

A correct Porygonal-shaped shadow while the visible sprite remains flat is
useful diagnostic evidence: character lookup may already be correct and the
remaining failure may be limited to the visible draw seam.

PROCEDURAL IDLE
---------------

Renderers that do not naturally reproduce Porygonal's idle motion may need the
adapter to apply it.

Prefer movement detection from actual world-position changes rather than only
an animation label.

Useful state:

    stable entity key
    previous position
    moving/stationary result
    deterministic animation phase

Respect character tuning and special-state exclusions.

Do not apply idle deformation to moving actors.

FISHING
-------

Fishing must be tested independently from ordinary character rendering.

There are usually two separate problems:

    Porygonal fishing character/model
    native renderer/game fishing effect

Do not assume an exposed field controls the real FX dispatch.

If a renderer hides the actual FX function in a local closure, a tightly
scoped low-level interception can be appropriate.

Only use raw draw interception when all of these are known:

    exact game state
    exact renderer pass
    exact native drawable
    smallest possible wrapper lifetime
    reliable restoration

Never globally suppress graphics calls.

FLY
---

Fly is a separate rendering lifecycle.

The ordinary player entity may disappear from normal renderer pose/draw flow
while Fly is active.

Use native Fly state as lifecycle/synchronization information, but allow
Porygonal to own its replacement visual choreography.

Important considerations:

    departure
    map transition
    arrival/landing
    player may be absent from ordinary pose enumeration
    logical player position may not be the desired visual position
    replacement state may need to survive a map transition

If the ordinary actor seam disappears, look for a guaranteed renderer
lifecycle seam.

A good lifecycle seam runs regardless of optional map content.

Do not attach a special-state draw to grass, a particular object, or one map
just because that happened to work during testing.

AUTHORED MAP FIGURES
--------------------

Some visible people are not logical NPC entities.

A renderer may reconstruct a person painted into map art/furniture as authored
geometry during chunk/structure generation.

Treat these as a separate actor class.

Do not associate them with:

    NPC draw indexes
    player pose flow
    ordinary entity ordering

Instead, identify the renderer-authored figure semantically and replace its
visible/shadow geometry at the appropriate renderer surfaces.

The seated Pokemon Center figure is an example handled by existing adapters.

REFLECTIONS AND REPEATED PASSES
-------------------------------

A renderer can draw the scene more than once:

    main view
    reflection
    cast/reflected scene
    shadow
    offscreen pass

Determine which passes call your hook before introducing "already drawn this
frame" logic.

A global once-per-frame flag can accidentally remove a reflection or leave a
native sprite visible in another pass.

FIRST PERSON
------------

Treat first-person mode separately if the renderer supports it.

The renderer may intentionally hide the player or change actor culling.

Do not force normal third-person behavior into first-person without checking
the renderer's semantics.

CACHE / PREBUILD
----------------

If the renderer has a geometry cache or PREBUILD system, test both:

    fresh/on-demand build
    cached/prebuilt build

If a character works with a fresh build but fails after PREBUILD, stop changing
the final draw hook.

The difference may occur earlier in:

    source geometry/profile data
    worker/thread VM behavior
    serialization
    cache encoding/decoding
    prebuild-specific generation

The PotatoVoxel adapter README documents a real example of this class of bug.

WRAPPER HYGIENE
---------------

For every wrapper:

    store the original
    preserve arguments
    preserve required return values
    avoid recursive installation
    avoid installing twice
    minimize wrapper lifetime
    restore temporary wrappers even after errors where practical

Use adapter-owned context/state instead of unrelated globals.

PERFORMANCE
-----------

Renderer adapters run in rendering paths, so keep them cheap.

Avoid:

    per-frame asset discovery
    repeated module discovery
    unnecessary allocations in hot loops
    repeated static-map analysis
    unbounded actor-history tables
    additional pose evaluations

Use CharacterRuntime's existing asset/cache contract rather than creating a
second asset pipeline inside the adapter.

DEBUGGING
---------

Prefer binary observations over speculative changes.

Useful checkpoints:

    adapter initialized?
    target actor observed?
    Registry returned a replacement?
    target GPU mesh identified?
    visible draw seam reached?
    shadow seam reached?
    special state active?
    lifecycle seam reached?
    authored figure present?
    fresh cache differs from PREBUILD?

If no console is available, use a temporary diagnostic that clearly
distinguishes "diagnostic loaded but event not reached" from "diagnostic never
loaded".

Remove diagnostics before submitting a pull request.

IMPLEMENTATION ORDER FOR A NEW RENDERER
---------------------------------------

Recommended sequence:

1. Detect the renderer without side effects.

2. Validate its required API/surfaces.

3. Establish the frame/scene context.

4. Observe ordinary actor identity without extra pose calls.

5. Ask Registry for the replacement.

6. Load replacement data through CharacterRuntime.

7. Replace one ordinary visible actor.

8. Generalize ordinary visible actors.

9. Replace shadows.

10. Add procedural idle if needed.

11. Test bicycle.

12. Test Surf.

13. Implement Fishing and native FX handling.

14. Implement Fly departure/transition/landing.

15. Handle reflections/first-person if applicable.

16. Handle renderer-authored figures if applicable.

17. Test map diversity.

18. Test fresh and prebuilt caches if applicable.

19. Remove diagnostics.

20. Document the exact renderer/version and special cases in its README.

MINIMUM TEST MATRIX
-------------------

Before proposing a renderer adapter as supported:

[ ] renderer absent: Porygonal fails cleanly
[ ] renderer present: adapter detected
[ ] ordinary player walking
[ ] ordinary player idle
[ ] ordinary NPC
[ ] visible replacement
[ ] player/NPC shadows
[ ] bicycle
[ ] Surf
[ ] Fishing model
[ ] native Fishing FX behavior
[ ] Fly departure
[ ] Fly transition
[ ] Fly landing
[ ] map-diverse Fly test
[ ] first-person if supported
[ ] reflections/repeated passes if supported
[ ] authored map figures if applicable
[ ] multiple maps for authored figures
[ ] fresh cache if applicable
[ ] PREBUILD/cache if applicable
[ ] no obvious regression to renderer world geometry/FX

CONTRIBUTING A RENDERER
-----------------------

A renderer contribution should normally contain:

    renderers/<renderer_name>/<renderer_name>_renderer.lua
    renderers/<renderer_name>/<RENDERER_NAME>_README.txt

and the minimal renderer-manager change required to register/detect it.

The renderer README should document:

    renderer name
    exact tested version(s)
    renderer mod ID
    API/export used
    main interception surfaces
    special-state handling
    cache/prebuild behavior
    known limitations
    regression test results

Keep renderer-specific code in the renderer folder.

Do not modify core character mappings merely to make one renderer easier to
hook unless the change represents a genuinely renderer-independent semantic
improvement.

PULL REQUEST EXPECTATIONS
-------------------------

A renderer PR should explain:

    what renderer/version was tested
    what native surfaces are wrapped
    how actor identity is obtained
    how visible and shadow replacement work
    how Fishing/Fly are handled
    whether reflections/first-person were tested
    whether authored map figures exist
    whether cache/PREBUILD changes behavior
    which regression tests passed

Small, evidence-based compatibility changes are preferred over broad rewrites
of unrelated core code.

FINAL PRINCIPLE
---------------

Map the renderer first.
Trace the real call path.
Validate before mutation.
Never add pose evaluations.
Match identity semantically.
Replace visible and shadow independently.
Treat special states separately.
Use lifecycle seams when ordinary actors disappear.
Scope low-level interception tightly.
Test multiple maps.
Test fresh and prebuilt caches.
Document the evidence.
