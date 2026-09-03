PORYGONAL - POTATOVOXEL RENDERER ADAPTER
=========================================

Target Mod
----------

Name:
    PotatoVoxel

Target Mod ID:
    potato_voxel

Validated Mod Version:
    1.9.6

Porygonal Adapter:
    renderers/potato_voxel/potato_voxel_adapter.lua

Adapter Version:
    1.0.0


PURPOSE
-------

This Renderer Adapter connects Porygonal - Overworld Characters to PotatoVoxel.

PotatoVoxel remains responsible for the 3D overworld. Porygonal replaces
supported overworld character visuals through the adapter while leaving
PotatoVoxel's world rendering ownership intact.


VALIDATED SCOPE
---------------

The adapter has been runtime-tested with PotatoVoxel 1.9.6 for the normal
overworld character path and the Porygonal character states currently supported
by the project, including:

    - player and NPC overworld characters;
    - character shadows;
    - idle character animation;
    - bicycle and Surf character states;
    - Fishing presentation;
    - Fly presentation;
    - authored Pokémon Center character figures.

PotatoVoxel 1.9.6 requires a narrowly scoped compatibility repair for its
Pokémon Center authored figure data/cache path. That repair belongs to this
adapter and is intentionally limited to the affected Pokémon Center case.


VERSION POLICY
--------------

"Validated Mod Version" means the exact Target Mod version that was tested.

A different PotatoVoxel version may work, but compatibility should not be
assumed until it has been tested. Adapter metadata can be viewed in:

    OPTION -> PORYGONAL


OWNERSHIP
---------

Porygonal does not redistribute PotatoVoxel.

PotatoVoxel is a separate project and remains subject to its own license and
terms.
