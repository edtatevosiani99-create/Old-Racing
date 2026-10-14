# OLD RACING

An original Android highway-racing prototype built with Kotlin and a custom Canvas renderer.

## Current prototype
- Landscape full-screen gameplay.
- Four-lane divided highway: two lanes in each direction.
- One-way and two-way modes.
- Three selectable stylized starter cars inspired by Mustang GT, BMW M4 and Opel Astra GTC (not licensed 3D models).
- Touch steering and optional accelerometer tilt steering (toggle by tapping the top-left HUD area during a run).
- Traffic, speed controls, distance counter, saved best distance, collisions, pause/resume and restart.
- Collectible road coins saved between sessions.
- In-game engine upgrade shop: spend collected coins on up to five engine levels; each level raises the speed limit.
- GitHub Actions builds a debug APK artifact automatically on pushes and manual workflow runs.

## Build and download
Open the repository's **Actions** tab, choose the latest **Android APK** run, and download the `old-racing-debug-apk` artifact. GitHub provides the artifact as a ZIP containing the debug APK.

## Important
This first version is a pseudo-3D prototype, not a full 3D game. Realistic licensed 3D models, engine audio, a visual garage and polished effects remain future improvements. The current coin wallet and engine upgrades are prototype systems. Real car models require appropriately licensed assets.


## 3D migration in progress
The `godot/` directory now contains the first Godot 4 3D prototype scene. It builds a real 3D road, low-poly cars, roadside scenery, chase camera, on-screen steering, gas/brake controls, tilt steering, traffic and coins from generated geometry. It is a separate prototype source tree and is **not yet the Android APK shipped by the existing Gradle workflow**. The current Android APK is still the Kotlin/Canvas prototype while the Godot scene is validated and Android export is configured.
