PORYGONAL - RENDERER ADAPTERS
==============================

Porygonal - Overworld Characters does not replace the world renderer itself.

Instead, Porygonal uses small compatibility modules called Renderer Adapters.
A Renderer Adapter connects Porygonal's character system to a supported external
3D mod.

Terminology
-----------

Renderer Adapter
    The Porygonal compatibility code stored in this directory.

Target Mod
    The external 3D mod that the adapter connects to.

Adapter Version
    The version of the Porygonal adapter itself.

Validated Mod Version
    The exact Target Mod version that was tested with the adapter.

A validated version is a known working reference. A newer or older Target Mod
version may still work, but it should not be assumed compatible until tested.


CURRENT ADAPTERS
----------------

PotatoVoxel
    Adapter:
        renderers/potato_voxel/potato_voxel_adapter.lua

    Adapter Version:
        1.0.0

    Validated Mod Version:
        1.9.6


Dramatic Shape Voxel Mod
    Adapter:
        renderers/dramatic_shape/dramatic_shape_adapter.lua

    Adapter Version:
        1.0.0

    Validated Mod Version:
        1.8.2


Dramaless Shape
    Adapter:
        renderers/dramaless_shape/dramaless_shape_adapter.lua

    Adapter Version:
        1.0.0

    Validated Mod Version:
        2.0.3


Battle Art Voxel Fork
    Adapter:
        renderers/battle_art_voxel/battle_art_voxel_adapter.lua

    Adapter Version:
        1.0.0

    Validated Mod Version:
        1.10.1


IN-GAME INFORMATION
-------------------

The active adapter information can be viewed in:

    OPTION -> PORYGONAL

This screen reports the Porygonal version, the active Target Mod, the Adapter
Version, and the Target Mod version that the adapter was tested on.


SELECTION RULES
---------------

Porygonal detects the installed supported Target Mods at startup.

If exactly one compatible Target Mod is detected, its Renderer Adapter is
initialized.

If none are detected, Porygonal leaves character rendering unchanged and reports
that no compatible 3D renderer was found.

If more than one compatible Target Mod is detected, Porygonal does not choose
between them automatically. This avoids stacking multiple renderer integrations
on the same character pass.


ADDING OR MAINTAINING AN ADAPTER
--------------------------------

Keep each Renderer Adapter isolated in its own folder.

Preferred public structure:

    renderers/<target_mod>/
        <target_mod>_adapter.lua
        <TARGET_MOD>_README.txt

An adapter should:

    - detect only the Target Mod it belongs to;
    - keep detection free of runtime side effects;
    - initialize only after compatibility has been confirmed;
    - use Porygonal's Registry and CharacterRuntime instead of duplicating
      character identity or asset ownership;
    - preserve the Target Mod's original behavior when Porygonal has no matching
      character asset;
    - keep Target-Mod-specific compatibility code inside the adapter;
    - expose adapter metadata through Adapter.info.

Recommended metadata:

    Adapter.info = {
        adapterVersion = "x.y.z",
        targetMod = {
            id = "...",
            name = "...",
            validatedVersion = "...",
        },
        porygonalVersion = "...",
    }

Do not move Target-Mod-specific fixes into Porygonal's renderer-independent
character core unless they are genuinely shared behavior.


THIRD-PARTY MODS
----------------

Target Mods are separate projects.

Porygonal does not redistribute them. Users must obtain and install supported
Target Mods separately, and each Target Mod remains subject to its own license
and terms.
