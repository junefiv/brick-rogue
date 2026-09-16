# Original Godot 4 VFX assets

The editable SVG sources import into GPU textures in Godot. `explosion_atlas.svg` contains twelve 128×128 frames; `chest_atlas.svg` contains six 128×128 frames. `SpriteFrames` and `AtlasTexture` extract frames without individual texture files.

`flame.gdshader` is a time-driven flame material for fully charged balls. `surface.gdshader` combines animated corrosion veins and resonance ripples while leaving the center readable.

`ui/vfx_actor.gd` owns the pooled Sprite2D / AnimatedSprite2D / GPUParticles2D / Label actors. `ui/vfx_director.gd` synchronizes persistent projectile and brick visuals and queues effects. `ui/fusion_choreography.gd` contains 94 named visual timelines.

Rebuild the assets and catalog using Python 3: `python tools/build_vfx_assets.py`. Only the standard library is required. Sources and generated artwork are original project assets, without third-party art dependencies.
