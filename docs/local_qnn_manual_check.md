# Local QNN generation — Snapdragon manual check

1. Build/install an Android arm64 build that includes
   `packages/native_tavern_qnn_upscale` native drop-ins
   (`libstable_diffusion_core.so` + `assets/qnnlibs/*`).
2. Open **Settings → Image generation**.
3. Choose provider **Local QNN**.
4. Download one catalog model (e.g. Anything V5). Progress should show.
5. After download, loading progress should appear until status is
   **Ready in memory**.
6. Generate from chat / dialog; image should appear as an assistant bubble.
7. Switch provider to any API backend (e.g. OpenAI). Status should briefly
   show releasing, then idle; system notification for the loaded model should
   disappear.
8. Switch back to Local QNN with a downloaded model selected → load progress
   again → Ready.
