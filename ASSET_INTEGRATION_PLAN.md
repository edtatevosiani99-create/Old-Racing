# Old-Racing — 3D asset integration shortlist

This file records the selected sources for the next visual-quality pass. The game is a Godot 4 Android project; assets should be imported locally at build time, never fetched at runtime.

## Priority 1 — Roadside environment (free, commercial use)

| Use | Asset pack | Format / scope | License | Source |
|---|---|---|---|---|
| Highway pieces, barriers, signs, traffic lights | Kenney — City Kit (Roads) | glTF/GLB and other formats; ~90 models | CC0 1.0 | https://kenney.nl/assets/city-kit-roads |
| Houses, driveways, fences, suburban roadside | Kenney — City Kit (Suburban) | glTF/GLB and other formats; ~40 models | CC0 1.0 | https://kenney.nl/assets/city-kit-suburban |
| Dense urban blocks / commercial buildings | Kenney — City Kit (Commercial) | 3D city kit; ~50 files | CC0 | https://kenney.nl/assets/city-kit-commercial |
| Trees, bushes and natural roadside variation | Kenney — Nature Kit | 3D vegetation kit; ~330 models | CC0 | https://kenney.nl/assets/nature-kit |
| High-quality PBR ground/asphalt/grass materials | ambientCG | PBR texture sets; select 1K–2K maps for mobile | CC0 | https://ambientcg.com/ |
| Realistic trees, scanned materials and lighting HDRIs | Poly Haven | High-quality models, PBR textures and HDRIs | CC0 | https://polyhaven.com/models |

## Priority 2 — More realistic traffic cars

| Candidate | What is known | License / mobile note | Source |
|---|---|---|---|
| Car Game-Ready by IntroBuck | 44.5k triangles, 2K PBR textures; one post-apocalyptic game-ready car | CC BY: include creator attribution in the game/repository. Suitable as a candidate for the player car after checking scale, materials and file size. Use a simplified LOD for distant traffic. | https://sketchfab.com/3d-models/car-game-ready-d3f2d9bf71ac403a80d5dc9b9a45b785 |
| car blend by asifkhalil652 | 5.7k triangles, 2.7k vertices, PBR maps, GLB advertised | CC BY: attribution required. Lower polygon count is promising for Android, but inspect the actual downloadable file and material setup before accepting it. | https://sketchfab.com/3d-models/car-blend-55ab1483d0ba43ceac91c9f30a9be0fb |
| Kenney Cars Pack | 8 models, FBX/OBJ/Blend | CC0, commercial use allowed; visually more stylized, so keep as traffic/fallback models rather than the main realism target. | https://quaternius.com/packs/cars.html |

## Integration rules

1. Prefer GLB/glTF for Godot 4. Keep each source's license/attribution in `godot/assets/THIRD_PARTY_LICENSES.txt`.
2. Do not import every asset in a pack. Select only needed models to control APK size and draw calls.
3. Target mobile-friendly textures (1K–2K), reuse materials, enable mipmaps, and use LODs or simpler traffic meshes for distant vehicles.
4. Add collision shapes separately; imported visual meshes should not become detailed per-triangle physics colliders for traffic.
5. Keep the existing fallback meshes so missing/import-failed assets do not make the road or vehicles disappear.
6. After asset changes: run the headless Godot import, export the APK, verify the APK signature, then test in-game steering, collisions, and frame rate on Android.

## Current limitation

These are verified candidate pages, not claims that all listed models are already in the APK. Sketchfab candidate files require a direct download and a license/geometry check before they can be bundled. The environment packs are the safest first integration because their CC0 terms and engine-compatible formats are clearly stated by the publishers.


## User-selected cars — Old-Racing traffic pass (2026-10-14)

The user approved these three Poly Pizza candidates to add to the game:
- Ferrari F40 — https://poly.pizza/m/RTwim9bhNd — FBX/GLTF, Creative Commons Attribution; credit PuKkBuMXDD.
- Chevrolet Camaro / Camaro ZL1 2017 — https://poly.pizza/m/kVcKsd2dEk and https://poly.pizza/m/7bF7UVAoYRG — FBX/GLTF or OBJ/GLTF, Creative Commons Attribution; credit PuKkBuMXDD and Kris Tong.
- Dodge Charger — https://poly.pizza/m/4b80hRVxqvv — OBJ/GLTF, Creative Commons Attribution; credit David Sirera.

### Integration status and requirements
These are selected source pages, not yet bundled game assets. All three pages label the models Low Poly and Creative Commons Attribution, so the repository/game must include appropriate creator credits. Before treating them as integrated, download the actual model files, inspect mesh scale/materials and wheel geometry, convert to GLB if needed, place them under `godot/assets/cars/`, add attribution to `godot/assets/THIRD_PARTY_LICENSES.txt`, instance the models in the traffic spawning code with a safe fallback, then run Godot import/export and test the APK on Android. Do not claim the cars are present in the APK until those steps and a successful build are verified.
