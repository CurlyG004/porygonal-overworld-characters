# Porygonal - Overworld Characters: Differences from Vanilla

Porygonal intentionally changes the visual presentation of overworld characters while leaving game progression and gameplay logic to Gen1Recomp and the active renderer.

## Overworld character rendering

- Supported overworld character sprites are replaced with custom polygonal 3D models.
- Character appearance is adapted to the active supported 3D renderer.
- Player states such as walking, cycling, surfing, fishing, and Fly may use renderer-specific 3D presentation.
- Some authored overworld figures, such as the seated Pokémon Center figure where supported by the renderer, are presented as 3D models.

## Renderer integration

Porygonal currently provides compatibility adapters for Dramatic Shape, Dramaless Shape, and Potato Voxel. Renderer-specific compatibility code may suppress or replace a renderer's native 2D character/effect draw when Porygonal supplies the corresponding 3D presentation.

## Gameplay

Porygonal is a graphics/content mod. It does not intentionally change Pokémon data, battle mechanics, encounters, progression, dialogue, maps, or link-relevant gameplay data.

Disabling Porygonal restores the renderer/base game's normal character presentation.
