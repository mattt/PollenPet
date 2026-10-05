# Sources and credits

Pollen Pet is an independent, noncommercial project.
Its dialogue, voices, reactions, and robot movement are original.
Pollen Robotics does not endorse this app,
and the app makes no claim of affiliation.

## Microduck model

Microduck's geometry and assembly are by
[Pollen Robotics](https://pollen-robotics.com/microduck/), from
[microduck_rl at revision 1e79c29](https://github.com/pollen-robotics/microduck_rl/tree/1e79c29c97d8b38aee9eefde77a545860ba7658e).
The upstream README assigns hardware design files to Creative Commons BY-SA-NC
and software to Apache 2.0.
It does not state a Creative Commons license version.
The software notice is in [microduck-LICENSE.txt](microduck-LICENSE.txt).
The converted model remains subject to the hardware license,
so commercial distribution requires permission for the model.

[microduck-sources.json](microduck-sources.json) records the pinned revision,
source hashes, conversion changes, and output hash.
`Scripts/import_microduck.py` converts the visual STL meshes and MJCF hierarchy
to USDZ, applies the source STAND pose, and changes coordinates to Y-up.
It treats CAD colors as sRGB, converts them to linear USD color values, and
sets material roughness to 0.48.
Collision meshes, physics, sensors, and controllers are omitted.
A visual hinge at the jaw bearing moves the lower jaw and mouth pad.
The original closed positions are preserved, and the upper beak stays fixed.

To rebuild the model, run this command from any directory.
It downloads the pinned sources to `.cache/microduck-source`:

```sh
uv run Scripts/import_microduck.py
```

## Reachy Mini model

The [Reachy Mini](https://pollen-robotics.com/reachy-mini/) visualization model
comes from [Pollen Robotics' Blender repository](https://github.com/pollen-robotics/reachy_mini_blender/tree/bfa02cfee9fde8a1bcca7159921110b1a4a2368e).
Its README credits the 3D model and rig to Clément Plays.
The repository includes an Apache 2.0 license, copied to
[reachy-mini-LICENSE.txt](reachy-mini-LICENSE.txt).

[reachy-mini-sources.json](reachy-mini-sources.json) records the pinned revision,
source hash, conversion changes, and output hash.
`Scripts/import_reachy_mini.py` evaluates the Blender rig at rest, groups its head
under a pivot for local animation, and exports the geometry to USDZ.
It uses the source model's flat viewport colors in place of procedural materials
and omits one unresolved decorative image reference.

To rebuild the model, install Blender, clone the source repository into
`.cache/reachy_mini_blender`, check out the pinned revision above, and run:

```sh
blender --background \
  .cache/reachy_mini_blender/reachy_mini_link/assets/reachy_mini.blend \
  --python Scripts/import_reachy_mini.py
```

Blender's USD export is not reproducible byte for byte,
so a rebuilt model can have a different output hash.

## Voices

Both robots speak with tones that the app synthesizes at run time.
Each burst of up to three letters is a short pitch glide,
and sentence punctuation adds a separate accent tone.
The voices use no recordings from the hardware, the product film, or other sources.

## Interface

The SwiftUI interface uses a locally drawn rounded comic panel.
Its colors and visual style take inspiration from the
[official Microduck website](https://pollen-robotics.com/microduck/).
The model's editable colors are separate visual approximations;
the app does not claim exact hardware color matching.

The character picker uses the [Microduck head sticker](https://pollen-robotics.com/assets/microduck/stickers/duck-head-mark.webp)
and the [Reachy Mini icon](https://pollen-robotics.com/assets/reachy-icon.svg)
from Pollen Robotics' websites, converted to PNG for the app.

Headings use [Anton](https://github.com/google/fonts/tree/main/ofl/anton)
by Vernon Adams under the SIL Open Font License 1.1.
The font is bundled as `Resources/Fonts/Anton-Regular.ttf`.
Its notice is in [Anton-OFL.txt](Anton-OFL.txt).
Dialogue and interface controls use the macOS system font.
