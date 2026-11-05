#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PDFRX_FILE="${PUB_CACHE:-$HOME/.pub-cache}/hosted/pub.dev/pdfrx-1.3.5/lib/src/pdfium/pdf_file_cache.dart"
if [[ -f "$PDFRX_FILE" ]] && grep -q 'cache\.blockSize' "$PDFRX_FILE"; then
  python3 - "$PDFRX_FILE" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
t = p.read_text()
t = t.replace('(blockId + 1) * cache.blockSize', '(blockId + 1) * cache!.blockSize', 1)
t = t.replace('await cache.read(buffer, bufferPosition, p, sizeToRead);',
              'await cache!.read(buffer, bufferPosition, p, sizeToRead);', 1)
p.write_text(t)
print(f'patched {p}')
PY
fi

# Live2D Cubism Core dylibs rebuilt with new Xcode often ship minos 15.7+ while
# NativeTavern still targets macOS 13.0. Lower the load-command minos only.
LIVE2D_DYLIB="$ROOT/packages/native_tavern_live2d_macos/macos/Libs/libLive2DCubismCore.dylib"
if [[ -f "$LIVE2D_DYLIB" ]] && command -v vtool >/dev/null; then
  if vtool -show-build "$LIVE2D_DYLIB" 2>/dev/null | grep -Eq 'minos 1[5-9]\.|minos [2-9][0-9]\.'; then
    sdk="$(vtool -show-build "$LIVE2D_DYLIB" 2>/dev/null | awk '/sdk /{print $2; exit}')"
    sdk="${sdk:-26.2}"
    vtool -set-build-version macos 13.0 "$sdk" -replace -output "$LIVE2D_DYLIB" "$LIVE2D_DYLIB"
    codesign -f -s - "$LIVE2D_DYLIB" >/dev/null
    echo "patched Live2D Cubism Core minos -> 13.0 (sdk $sdk) ($LIVE2D_DYLIB)"
  fi
fi
