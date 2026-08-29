PORYGONAL - POTATOVOXEL ADAPTER
=============================

PURPOSE
-------

This file documents the PotatoVoxel-specific compatibility strategy and known
version-sensitive behavior.

Implementation:
    potato_voxel_renderer.lua

Read:
    ../README_RENDERERS.txt

first for the general adapter methodology.

TESTED VERSION
--------------

PotatoVoxel 1.9.6 has been explicitly investigated for the behavior documented
below.

When adding support for a newer PotatoVoxel release, inspect that release's
source and revalidate these assumptions rather than carrying old compatibility
patches forward automatically.

RENDERER SURFACES
-----------------

PotatoVoxel exposes its renderer library through:

    mod.exports.lib

Important modules/surfaces observed during adapter development include:

    VoxelScene
    Voxel3D
    SpriteBillboards
    ShadowMap
    ChunkMesher
    TileShape
    MeshCache

CALL-PATH WARNING
-----------------

A function exposed on a PotatoVoxel module is not automatically the function
used by the renderer's internal loop.

Always trace the exact source/version and confirm the real call site before
wrapping a surface.

ORDINARY CHARACTERS
-------------------

The adapter associates PotatoVoxel billboard/mesh identity with Gen1
definition/frame information and consumes that identity at the actual visible
and shadow draw surfaces.

Do not call pose evaluation an extra time.

PROCEDURAL IDLE
---------------

Porygonal procedural idle is applied by the adapter using observed actor
movement.

The implementation distinguishes moving and stationary actors from actual
world-position history and applies the renderer-independent character tuning
only when appropriate.

FISHING
-------

PotatoVoxel's native fishing rod is part of its FX rendering path.

Simply changing an exposed rod-related field was not sufficient in the tested
version because the actual FX dispatch used internal/captured behavior.

The working strategy scopes interception to the Fishing FX pass and suppresses
only the exact native rod drawable while the Porygonal Fishing model is active.

Do not globally suppress love.graphics.draw.

FLY
---

The normal player actor path is not reliable during Fly.

The game/renderer can omit the player from ordinary entity rendering.

The adapter therefore keeps Porygonal Fly visual state separately and draws it
from a reliable scene seam while using native Fly state for lifecycle
synchronization.

Do not assume logical player coordinates are the complete visual Fly
trajectory.

Fly state must survive the map transition.

AUTHORED POKEMON CENTER FIGURE
------------------------------

The seated Pokemon Center person is not a normal NPC in PotatoVoxel.

It is reconstructed through PotatoVoxel's authored FIGURE/chunk-meshing
system.

The adapter treats it as a separate renderer-authored actor:

    recognize POKECENTER context
    identify the authored figure
    map it to Porygonal's seated-figure Registry entry
    replace visible geometry
    replace the figure shadow

Do not map it through NPC draw indexes.

POTATOVOXEL 1.9.6 PROFILE / PREBUILD COMPATIBILITY
--------------------------------------------------

PotatoVoxel 1.9.6 contains a malformed authored POKECENTER figure profile:
the record's source-tile count and replacement-under-tile count do not match.

PotatoVoxel's authored-mask validation rejects malformed records.

The Porygonal adapter contains a narrowly scoped compatibility repair for this
tested version so the Pokemon Center figure can be exposed to the normal
Porygonal figure-replacement path.

A second issue appears when affected geometry has already been produced by
PotatoVoxel's PREBUILD path.

PREBUILD work can occur outside the live renderer VM, so repairing only live
semantic data is not sufficient for already-generated cached geometry.

The compatibility strategy is therefore scoped to the affected POKECENTER
geometry/cache path and allows PotatoVoxel to rebuild that geometry through
its normal live/on-demand path.

Important constraints:

    do not disable PotatoVoxel's cache globally
    do not invalidate geometry every render
    do not apply this version-specific repair to unrelated tilesets

This behavior has been validated in multiple Pokemon Centers with PREBUILD
data present.

CACHE TESTING
-------------

Whenever this part of the adapter changes, test both modes.

Fresh path:

    WIPE CACHE
    do not PREBUILD
    visit Pokemon Center
    verify seated figure is 3D

PREBUILD path:

    PREBUILD/cache present
    visit Pokemon Center
    verify seated figure is 3D

Then visit a second Pokemon Center to verify map diversity.

A pass in only one cache mode is not sufficient.

KNOWN FAILURE LESSONS
---------------------

Early figure registration can be unreliable when chunk/prefetch state is not
ready.

A final draw-layer hook cannot repair semantic geometry that was already baked
incorrectly earlier in the pipeline.

Render-time cache invalidation is too aggressive and timing-sensitive.

Cache bypass alone is insufficient if the live source semantics are also
invalid.

These lessons are useful when investigating future PotatoVoxel versions.

TEST CHECKLIST
--------------

[ ] ordinary player
[ ] NPC
[ ] visible replacement
[ ] shadows
[ ] idle
[ ] bicycle
[ ] Surf
[ ] Fishing model
[ ] native rod suppression
[ ] Fly departure
[ ] Fly transition
[ ] Fly landing
[ ] Pokemon Center - fresh cache
[ ] Pokemon Center - PREBUILD cache
[ ] second Pokemon Center

VERSION UPDATE POLICY
---------------------

For a newer PotatoVoxel version:

1. inspect its manifest/API;
2. inspect the real VoxelScene/actor draw call path;
3. inspect authored Pokemon Center figure data;
4. inspect TileShape/ChunkMesher figure handling;
5. inspect cache/prebuild behavior;
6. determine whether the existing compatibility repair is still necessary;
7. remove obsolete version-specific workarounds;
8. rerun the complete regression matrix;
9. update this README with the newly tested version.
