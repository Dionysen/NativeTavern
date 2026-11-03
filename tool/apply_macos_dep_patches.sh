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
