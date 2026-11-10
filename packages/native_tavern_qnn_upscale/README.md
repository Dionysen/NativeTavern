# native_tavern_qnn_upscale

Android MethodChannel plugin for NativeTavern:

- Post-generation anime **upscale** (port `18081`)
- On-device SD1.5 NPU **generation** (port `18080`) with provider-driven load/unload

## Drop-in native files

Extract a Local Dream APK and copy:

| From APK | Into this plugin |
|---|---|
| `lib/arm64-v8a/libstable_diffusion_core.so` | `android/src/main/jniLibs/arm64-v8a/libstable_diffusion_core.so` |
| `assets/qnnlibs/*` | `android/src/main/assets/qnnlibs/` |

Binaries are gitignored (CC BY-NC / size).

## Generation lifecycle

Selecting **Local QNN** in image settings auto-starts the chosen downloaded
model (progress via EventChannel). Switching to an API provider stops the
process and clears the foreground notification.

## Channel API

- Upscale: `getCapability`, `ensureModel`, `upscale`, `dispose`
- Gen: `listModels`, `downloadModel`, `cancelDownload`, `startModel`,
  `stopModel`, `getBackendStatus`, `generate`, `stopGenerate`
- Events: `native_tavern_qnn_upscale/events`

See `NOTICE` for CC BY-NC attribution requirements.
