---
layout: page
title: "Performance - out of scope"
---

What would save frame time but changes a setting or the picture, so it is left out of the work
([baseline](baseline.md)). Each entry is for the operator to decide on later, with its cost once
measured.

| Item | Where | Why it would help | Cost measured |
|---|---|---|---|
| Sky radiance cubemap 256 px, redrawn every frame, holds only a gradient | `gnd_skydome` (`Skydome.gd`), `filmic_procedural_sky.gdshader:447-450` | 64 px would look the same for a gradient | - |
| Volumetric fog volume 96³ (Godot's default 64³), lights' fog energy 16 | `project.godot` `[rendering]`, `[maszyna]` | 3.4 times the froxels of the default | - |
| SSIL, on in the player's `settings.cfg` | `render/ssil_enabled` | it is the player's choice | **14.2 ms GPU** on Wrzosy at 1080p (26%) |
| GI at full resolution | `rendering/global_illumination/gi/use_half_resolution` | GI is low-frequency | - |
| Directional shadow atlas 8192 also outside the cab | libmaszyna `maszyna_sky_environment.gd:72, 368-370` | 4096 while the cab light casts no shadow | - |
| Smoke density 3.0 | `project.godot` `smoke/dynamic/density` | each particle's opacity is divided by the density, so 3.0 is three times the overdraw for about the same plume | - |
| Mirrors render to the main camera's far plane, with sun shafts | libmaszyna `PlanarMirror3D.cpp` | a far plane at the fog distance; no compositor in the mirror | - |
| Merged street lamps become omni lights (6 shadow passes each) | libmaszyna `E3DLightFactory.cpp:162` | spots where the lamp points down | - |
| Mesh LODs, vertex compression | libmaszyna `E3DMesh.cpp` | fewer triangles, less bandwidth | - |
| Rain streaks lit and shadowed | `gnd_weather` `rain_streak.gdshader` | `shadows_disabled` | - |
| DDS textures without a full mip chain | libmaszyna `dds_texture_loader.gd:88-101` | missing mips cost bandwidth and shimmer (quality as much as speed) | - |
| Anisotropic filtering not used by most material shaders | libmaszyna `types/*.gdshader` (`filter_linear_mipmap`) | quality, not speed | - |

## Environment

* **AC power.** On battery the integrated GPU stays at 400-635 MHz and the frame's GPU time nearly
  doubles (94 ms against 51 ms on Wrzosy). That is the machine's power profile, not the game.
* **VSync** (on by default, `settings.json`) rounds a frame to 16.7 ms steps at 60 Hz. A frame of
  51 ms shows as 66.7 ms (15 FPS), so 1-2 ms saved near that edge can be worth 5 FPS.
