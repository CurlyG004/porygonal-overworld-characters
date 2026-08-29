PORYGONAL - DRAMALESS SHAPE ADAPTER
==================================

PURPOSE
-------

This file documents the Dramaless Shape adapter and the renderer-specific
constraints contributors should preserve.

Implementation:
    dramaless_shape_renderer.lua

Read:
    ../README_RENDERERS.txt

first for the general adapter methodology.

DESIGN
------

Dramaless Shape has distinct ordinary actor, shadow, reflection/special, FX,
and scene-lifecycle behavior.

The adapter observes renderer billboard/mesh identity and replaces characters
at the actual 3D/shadow draw surfaces.

Never call pose evaluation an extra time.

IDENTITY / DRAW ORDER
---------------------

Do not rely on sequential draw indexes as durable actor identity.

Culling, reflections, repeated passes, and special states can change draw
order/count.

Prefer semantic mesh/definition/frame identity and game state.

REFLECTIONS
-----------

Dramaless can draw repeated scene passes.

Before adding once-per-frame state, determine whether the relevant hook is
executing for:

    main scene
    reflected/cast scene
    shadow pass
    multiple passes

FISHING
-------

Fishing character replacement and native Fishing FX are independent concerns.

Any native FX suppression must be scoped to the exact Fishing state/pass.

FLY
---

The ordinary player draw path is not a guaranteed Fly seam.

Earlier integration approaches tied Fly injection to optional scene content
and therefore worked on some maps but not others.

The robust adapter path uses the renderer's final scene lifecycle:

    Porygonal Fly is drawn immediately before Voxel3D.endScene

This seam is intentionally independent of optional grass, ordinary player
draws, or location-specific map content.

Native Fly state provides lifecycle/synchronization.
Porygonal provides the replacement visual choreography.

Test departure, transition, and landing separately.

AUTHORED POKEMON CENTER FIGURE
------------------------------

Dramaless reconstructs the seated Pokemon Center person as an authored FIGURE,
not as a normal NPC.

The adapter:

    recognizes Pokemon Center context
    observes ChunkMesher figure data
    uses a conservative figure match
    replaces visible geometry
    replaces shadow geometry
    applies normal Porygonal palette/idle behavior

Do not bind this figure to logical NPC draw order.

VOXEL COMPANION API
-------------------

An additive renderer extension API is not automatically an actor-replacement
API.

Use an extension API only when it explicitly owns the exact actor surfaces
needed by Porygonal.

TEST CHECKLIST
--------------

[ ] ordinary player
[ ] NPC
[ ] shadows
[ ] idle
[ ] bicycle
[ ] Surf
[ ] Fishing
[ ] Fly departure
[ ] Fly at map-diverse/difficult location
[ ] Fly transition
[ ] Fly landing
[ ] Pokemon Center authored figure
[ ] reflections/repeated passes
[ ] first-person behavior if applicable

CONTRIBUTOR NOTE
----------------

Prefer renderer lifecycle seams over hooks that depend on optional map
content.

A fix that works on only one map is not sufficient evidence for a robust
special-state integration.
