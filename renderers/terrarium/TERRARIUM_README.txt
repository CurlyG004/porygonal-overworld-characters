PORYGONAL - TERRARIUM RENDERER ADAPTER
======================================

Target Mod
    Terrarium (a Dramatic Shape Voxel Mod fork)
    id: TERRARIUM
    https://github.com/BrenoBertucci/Terrarium

Adapter Version
    1.0.0

Validated Mod Version
    1.36.0-beta


WHY A SEPARATE ADAPTER
----------------------

Terrarium is a fork of the Dramatic Shape Voxel Mod and keeps its module
layout, so the integration is the Dramatic Shape adapter's.  It needs its own
file for two reasons.

First, detection is by exact mod id.  Terrarium loads under TERRARIUM and
registers its own pipeline keys (terrarium_voxel / terrarium_tiltshift) so it
can sit beside upstream DRAMATIC_SHAPE without either overwriting the other,
which means the Dramatic Shape adapter cannot see it at all.

Second, three of the public functions the adapter wraps grew a parameter in
Terrarium after Dramatic Shape 1.8.2.  Wrapping them at the old arity does not
fail -- it silently drops the new argument on every call:

    Voxel3D.draw(mesh, texture, model, pull, sunModel, sway)

        `sway` is the wind's reach at the top of this mesh in world pixels.
        Terrarium sends it on EVERY draw rather than only on the passes that
        want it, so that a swaying pass cannot leak into the terrain drawn
        after it.  A five-parameter wrapper therefore does not merely miss
        the swaying passes: it pins the whole frame to zero, and the grass,
        the trees and the battle scene's grass all stand dead still with
        nothing logged anywhere.

    SpriteBillboards.mesh(def, frame, cut)
    SpriteBillboards.shadowQuad(def, frame, cut)

        `cut` is how many pixels of the FEET are hidden.  A swimming roamer
        is cut at the waterline so only the top of the body is above the
        pond; anybody standing in tall grass or settled snow is cut at what
        covers their boots.  Dropped, every one of them is drawn at full
        height, standing ON the water rather than in it.

The adapter forwards both.


FIRSTPERSON
-----------

Terrarium has no first-person mode and ships no FirstPerson module, and its
V.require raises on a missing module rather than returning nil -- which would
abort initialize() inside the renderer manager's pcall and read as "adapter
could not be initialized".

The adapter requires it through pcall and treats absence as a supported state.
Every use of FirstPerson in the shared integration is already nil-guarded, so
nothing else changes: FirstPerson.hidePlayer() is never consulted and the
player's card is always one of the visible poses.


KNOWN LIMITATION
----------------

Where Terrarium would have cut a character's card -- a player standing in tall
grass or in settled snow -- a Porygonal model replaces it at full height, the
way it does under any renderer without a waterline cut.  Water roamers are
Pokemon rather than characters, so they keep Terrarium's cut card.


GENERATED FILE
--------------

terrarium_adapter.lua is generated from
renderers/dramatic_shape/dramatic_shape_adapter.lua by Terrarium's
compat/porygonal/make_adapter.py, which applies the edits above and asserts
each one matched.  Edit the generator, not the output.
