#!/usr/bin/env bash
# Rewrite third-party Flutter plugin Android Gradle scripts so they no longer
# declaratively apply the Kotlin Gradle Plugin (KGP).
#
# Flutter 3.47+ warns (and will later fail) when plugin build files contain
# `apply plugin: 'kotlin-android'` / `id("kotlin-android")`. With
# android.builtInKotlin=false, Flutter itself applies KGP to plugin subprojects
# that do not declare it, so removing the declarative apply clears the warning
# without breaking the build.
#
# Safe to re-run; skips files that are already clean.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLUGINS_FILE="$ROOT/.flutter-plugins-dependencies"

if [[ ! -f "$PLUGINS_FILE" ]]; then
  echo "No .flutter-plugins-dependencies yet; run flutter pub get first."
  exit 0
fi

python3 - "$PLUGINS_FILE" <<'PY'
import json, pathlib, re, sys

plugins_file = pathlib.Path(sys.argv[1])
data = json.loads(plugins_file.read_text(encoding="utf-8"))
android_plugins = (data.get("plugins") or {}).get("android") or []

apply_re = re.compile(
    r"(?m)^[ \t]*apply[ \t]+plugin[ \t]*:[ \t]*['\"](?:kotlin-android|org\.jetbrains\.kotlin\.android)['\"][ \t]*\r?\n"
)
id_paren_re = re.compile(
    r"(?m)^[ \t]*(?:id|alias)[ \t]*\([ \t]*['\"](?:kotlin-android|org\.jetbrains\.kotlin\.android)['\"][ \t]*\)[ \t]*\r?\n"
)
id_space_re = re.compile(
    r"(?m)^[ \t]*(?:id|alias)[ \t]+['\"](?:kotlin-android|org\.jetbrains\.kotlin\.android)['\"][ \t]*\r?\n"
)
detect_re = re.compile(
    r"(?m)^[ \t]*apply[ \t]+plugin[ \t]*:[ \t]*['\"](?:kotlin-android|org\.jetbrains\.kotlin\.android)['\"]|"
    r"[ \t]*(?:id|alias)[ \t]*\([ \t]*['\"](?:kotlin-android|org\.jetbrains\.kotlin\.android)['\"][ \t]*\)|"
    r"[ \t]*(?:id|alias)[ \t]+['\"](?:kotlin-android|org\.jetbrains\.kotlin\.android)['\"]"
)

patched = 0
skipped = 0

for plugin in android_plugins:
    name = plugin.get("name") or ""
    path = plugin.get("path") or ""
    if not path:
        continue
    android_dir = pathlib.Path(path) / "android"
    if not android_dir.is_dir():
        continue
    for file_name in ("build.gradle", "build.gradle.kts"):
        build_file = android_dir / file_name
        if not build_file.is_file():
            continue
        original = build_file.read_text(encoding="utf-8")
        if not detect_re.search(original):
            skipped += 1
            continue
        updated = apply_re.sub("", original)
        updated = id_paren_re.sub("", updated)
        updated = id_space_re.sub("", updated)
        if updated == original:
            print(f"Detected KGP apply in {name} but patch produced no change: {build_file}")
            continue
        if detect_re.search(updated):
            print(f"Incomplete KGP patch for {name}: {build_file}")
        build_file.write_text(updated, encoding="utf-8")
        print(f"Patched KGP apply out of {name} ({file_name})")
        patched += 1

print(f"KGP patch complete: {patched} patched, {skipped} already clean.")
PY
