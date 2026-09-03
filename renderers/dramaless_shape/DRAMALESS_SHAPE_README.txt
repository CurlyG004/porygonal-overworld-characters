PORYGONAL - DRAMALESS SHAPE RENDERER ADAPTER
=============================================

Target Mod
----------

Name:
    Dramaless Shape

Target Mod ID:
    DRAMALESS_SHAPE

Validated Mod Version:
    2.0.3

Porygonal Adapter:
    renderers/dramaless_shape/dramaless_shape_adapter.lua

Adapter Version:
    1.0.0


PURPOSE
-------

This Renderer Adapter connects Porygonal - Overworld Characters to Dramaless
Shape.

Dramaless Shape remains responsible for the 3D overworld. Porygonal replaces
supported overworld character visuals through the adapter while preserving the
Target Mod's renderer ownership.


VALIDATED SCOPE
---------------

The adapter has been runtime-tested with Dramaless Shape 2.0.3 for the normal
overworld character path and the Porygonal character states currently supported
by the project, including:

    - player and NPC overworld characters;
    - character shadows;
    - bicycle and Surf character states;
    - Fishing presentation;
    - Fly presentation;
    - authored overworld character figures.

Fishing and Fly compatibility are kept narrowly scoped to the relevant
renderer/field-FX passes so unrelated native effects continue to use the Target
Mod's normal behavior.


VERSION POLICY
--------------

"Validated Mod Version" means the exact Target Mod version that was tested.

A different Dramaless Shape version may work, but compatibility should not be
assumed until it has been tested. Adapter metadata can be viewed in:

    OPTION -> PORYGONAL


OWNERSHIP
---------

Porygonal does not redistribute Dramaless Shape.

Dramaless Shape is a separate project and remains subject to its own license and
terms.
