# native_tavern_qnn_upscale

Android MethodChannel plugin for NativeTavern's post-generation anime upscale
stage (Snapdragon / QNN, Local Dream-compatible).

## Drop-in native files

Extract a Local Dream APK (e.g. `LocalDream_armv8a_2.8.1`) and copy:

| From APK | Into this plugin |
|---|---|
| `lib/arm64-v8a/libstable_diffusion_core.so` | `android/src/main/jniLibs/arm64-v8a/libstable_diffusion_core.so` |
| `assets/qnnlibs/*` | `android/src/main/assets/qnnlibs/` |

Those binaries are gitignored (CC BY-NC / size). Without them,
`getCapability()` returns `available: false` and the Dart upscale stage skips.

## Channel API

- `getCapability`
- `ensureModel` (downloads Hugging Face anime QNN bin)
- `upscale` (RGB → JPEG via `http://127.0.0.1:18081/upscale`)
- `dispose`

See `NOTICE` for CC BY-NC attribution requirements.
