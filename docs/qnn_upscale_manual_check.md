# Manual check: Android Snapdragon QNN upscale

This path is skipped automatically on non-Android / non-Qualcomm devices.

## Prerequisites

1. Copy Local Dream `libstable_diffusion_core.so` (arm64-v8a) into  
   `packages/native_tavern_qnn_upscale/android/src/main/jniLibs/arm64-v8a/`.
2. Copy Local Dream `assets/qnnlibs/*` into  
   `packages/native_tavern_qnn_upscale/android/src/main/assets/qnnlibs/`.
3. Rebuild and install the Android app on a Snapdragon phone.

## Checklist

- [ ] Settings → Image Generation → enable generation, then enable **Upscale after generation**.
- [ ] Pick scale 2× / 3× / 4× and generate via dialog or one-tap imagine.
- [ ] First run downloads the anime QNN weights (needs network).
- [ ] Chat bubble shows the picture only (no prompt text).
- [ ] Result looks sharper / larger than the raw generation size.
- [ ] On a non-Snapdragon Android device (or without the `.so`), generation still succeeds and upscale is skipped.
- [ ] With upscale toggle off, behavior matches pre-feature generation.

## License note

Local Dream native components are CC BY-NC 4.0. See  
`packages/native_tavern_qnn_upscale/NOTICE`.
