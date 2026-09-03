PORYGONAL - DRAMATIC SHAPE RENDERER ADAPTER
============================================

Target Mod
----------

Name:
    Dramatic Shape Voxel Mod

Target Mod ID:
    DRAMATIC_SHAPE

Validated Mod Version:
    1.8.2

Porygonal Adapter:
    renderers/dramatic_shape/dramatic_shape_adapter.lua

Adapter Version:
    1.0.0


PURPOSE
-------

This Renderer Adapter connects Porygonal - Overworld Characters to Dramatic
Shape Voxel Mod.

Dramatic Shape remains responsible for the 3D overworld. Porygonal replaces
supported overworld character visuals through the adapter without taking
ownership of the world renderer.


VALIDATED SCOPE
---------------

The adapter has been runtime-tested with Dramatic Shape Voxel Mod 1.8.2 for the
normal overworld character path and the Porygonal character states currently
supported by the project, including:

    - player and NPC overworld characters;
    - character shadows;
    - bicycle and Surf character states;
    - Fishing presentation;
    - Fly presentation;
    - authored overworld character figures.

The adapter keeps renderer-specific compatibility behavior isolated from
Porygonal's character registry, tuning, palettes, and protected asset runtime.


VERSION POLICY
--------------

"Validated Mod Version" means the exact Target Mod version that was tested.

A different Dramatic Shape version may work, but compatibility should not be
assumed until it has been tested. Adapter metadata can be viewed in:

    OPTION -> PORYGONAL


OWNERSHIP
---------

Porygonal does not redistribute Dramatic Shape Voxel Mod.

Dramatic Shape Voxel Mod is a separate project and remains subject to its own
license and terms.
