# Old-Racing car asset integration

Three models were chosen by the user from Poly Pizza:
1. Ferrari F40 — https://poly.pizza/m/RTwim9bhNd — creator PuKkBuMXDD — CC Attribution
2. Camaro ZL1 2017 — https://poly.pizza/m/7bF7UVAoYRG — creator Kris Tong — CC Attribution
3. Dodge Charger — https://poly.pizza/m/4b80hRVxqvv — creator David Sirera — CC Attribution

## Install
Download each model from its own Poly Pizza page, export/download as glTF/GLB where offered, and place the files under `godot/assets/cars/` with the exact filenames in `THIRD_PARTY_LICENSES.txt`. Ensure each model faces the game's forward direction and is scaled to approximately the current car dimensions before release.

The script is already configured to look for these paths and retain a fallback if a model is missing. **The models themselves have not yet been committed or verified in an APK**, because the current integration session cannot retrieve the model binary files from Poly Pizza's download endpoint. Do not advertise the three named cars as present in the build until their files are added and a successful Android export is tested.
