PORYGONAL - DRAMATIC SHAPE ADAPTER
=================================

PURPOSE
-------

This file documents the Dramatic Shape adapter so contributors can understand
its compatibility strategy before modifying it.

Implementation:
    dramatic_shape_renderer.lua

Read:
    ../README_RENDERERS.txt

first for the general Porygonal renderer-adapter rules.

DESIGN
------

The adapter integrates with Dramatic Shape through observable renderer
surfaces where available.

Important surfaces used by the mature compatibility path include:

    VoxelScene.render
    Voxel3D.draw
    SpriteBillboards mesh/shadow behavior
    ShadowMap.draw
    scoped renderer/graphics behavior for special states

The adapter associates renderer billboard/mesh identity with the Gen1
character definition/frame, asks Porygonal's Registry for a replacement, then
substitutes the Porygonal geometry at the actual visible/shadow draw surfaces.

POSE SAFETY
-----------

Do not call pose evaluation an extra time.

The adapter observes the renderer's existing pose work rather than independently
evaluating game pose logic again.

VISIBLE / SHADOW
----------------

Visible geometry and shadow replacement are separate paths.

When debugging, prove them independently.

PROCEDURAL IDLE
---------------

Porygonal idle motion is applied using adapter-observed actor motion and the
renderer-independent tuning/Registry configuration.

Do not duplicate artistic idle values in this README or adapter when they
belong in character_tuning.lua.

FLY
---

Fly is not assumed to be an ordinary player pose.

The game/renderer can remove the player from its normal pose list while native
Fly is active.

The adapter therefore treats native Fly state as lifecycle information and
maintains Porygonal's replacement Fly visuals across the transition.

Do not add an extra player pose call to recover Fly state.

FISHING
-------

Fishing should be tested as both:

    replacement character/model
    native Fishing FX

Do not assume ordinary walking success proves Fishing compatibility.

AUTHORED POKEMON CENTER FIGURE
------------------------------

The seated Pokemon Center person may be renderer-authored geometry rather than
a logical NPC.

The adapter uses authored figure information and handles visible/shadow
replacement separately.

Do not associate this figure with ordinary NPC draw indexes.

LEGACY COMPATIBILITY
--------------------

Historical compatibility for older Dramatic Shape/Recomp behavior has required
more fragile/private implementation knowledge.

Treat legacy compatibility code conservatively.

For new renderer versions:

    prefer observable/public surfaces
    inspect the exact source/version
    do not copy private/upvalue assumptions forward automatically

TEST CHECKLIST
--------------

[ ] ordinary player
[ ] NPC
[ ] visible models
[ ] shadows
[ ] idle
[ ] bicycle
[ ] Surf
[ ] Fishing
[ ] Fly departure
[ ] Fly transition
[ ] Fly landing
[ ] Pokemon Center authored figure
[ ] map diversity
[ ] first-person/reflection behavior where applicable

CONTRIBUTOR NOTE
----------------

Before replacing a Dramatic Shape function, confirm that the exact supported
version actually calls that function internally.

An exported function name alone is not proof of dispatch ownership.
