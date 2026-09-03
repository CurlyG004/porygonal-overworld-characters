PORYGONAL - BATTLE ART VOXEL FORK RENDERER ADAPTER
===================================================

Target Mod
----------

Name:
    Battle Art Voxel Fork

Target Mod ID:
    BATTLE_ART_VOXEL_FORK

Validated Mod Version:
    1.10.1

Porygonal Adapter:
    renderers/battle_art_voxel/battle_art_voxel_adapter.lua

Adapter Version:
    1.0.0


PURPOSE
-------

This Renderer Adapter connects Porygonal - Overworld Characters to Battle Art
Voxel Fork.

Battle Art Voxel Fork remains responsible for the 3D overworld. Porygonal
replaces supported overworld character visuals through the adapter without
taking ownership of the world renderer.


VALIDATED SCOPE
---------------

The adapter has been runtime-tested with Battle Art Voxel Fork 1.10.1 across
multiple maps and character configurations, including:

    - player and NPC overworld characters;
    - repeated NPC types on the same scene;
    - character shadows;
    - bicycle and Surf character states;
    - Fishing presentation;
    - Fly presentation across map transitions;
    - authored Pokémon Center character figures.

The adapter associates ordinary visible characters by renderer-observed identity
and position rather than relying on a fragile sequential draw order. Special
states such as Fly are handled at renderer lifecycle points that remain valid
when the player is temporarily absent from the ordinary character pass.


VERSION POLICY
--------------

"Validated Mod Version" means the exact Target Mod version that was tested.

A different Battle Art Voxel Fork version may work, but compatibility should not
be assumed until it has been tested. Adapter metadata can be viewed in:

    OPTION -> PORYGONAL


OWNERSHIP
---------

Porygonal does not redistribute Battle Art Voxel Fork.

Battle Art Voxel Fork is a separate project and remains subject to its own
license and terms.
