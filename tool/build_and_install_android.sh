#!/usr/bin/env bash
# Build arm64 release APK and install it onto an adb device.
#
# Usage:
#   tool/build_and_install_android.sh <device-id>
#   tool/build_and_install_android.sh -l
#   tool/build_and_install_android.sh --uninstall-first <device-id>
#
# Example:
#   tool/build_and_install_android.sh adb-R5CW929XXFH-AujM9A._adb-tls-connect._tcp
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APK="$ROOT/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
PACKAGE_ID="com.miaomiaoxworld.nativetavern"
UNINSTALL_FIRST=0
DEVICE=""

usage() {
  cat <<EOF
Usage:
  $(basename "$0") <device-id>
  $(basename "$0") -l | --list
  $(basename "$0") --uninstall-first <device-id>

Builds:
  flutter build apk --split-per-abi --target-platform android-arm64

Then installs:
  adb -s <device-id> install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

Options:
  -l, --list             List adb devices and exit
  --uninstall-first      Uninstall existing app before install (clears data;
                         use when signatures do not match)
  -h, --help             Show this help
EOF
}

list_devices() {
  adb devices -l
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -l|--list)
      list_devices
      exit 0
      ;;
    --uninstall-first)
      UNINSTALL_FIRST=1
      shift
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      if [[ -n "$DEVICE" ]]; then
        echo "Unexpected argument: $1" >&2
        usage >&2
        exit 2
      fi
      DEVICE="$1"
      shift
      ;;
  esac
done

if [[ -z "$DEVICE" ]]; then
  echo "Missing device id." >&2
  echo >&2
  usage >&2
  echo >&2
  echo "Connected devices:" >&2
  list_devices >&2
  exit 2
fi

if ! command -v flutter >/dev/null; then
  echo "flutter not found in PATH" >&2
  exit 1
fi
if ! command -v adb >/dev/null; then
  echo "adb not found in PATH" >&2
  exit 1
fi

if ! adb devices | awk 'NR>1 && $2=="device" {print $1}' | grep -Fxq -- "$DEVICE"; then
  echo "Device not connected (or not in 'device' state): $DEVICE" >&2
  echo >&2
  list_devices >&2
  exit 1
fi

cd "$ROOT"

echo "==> Patching plugin Android Gradle files (remove declarative KGP apply)"
bash "$(dirname "$0")/patch_android_plugin_kgp.sh"

echo "==> Building arm64 release APK"
flutter build apk --split-per-abi --target-platform android-arm64

if [[ ! -f "$APK" ]]; then
  echo "APK not found after build: $APK" >&2
  exit 1
fi

echo "==> Installing to $DEVICE"
echo "    $APK ($(du -h "$APK" | awk '{print $1}'))"

if [[ "$UNINSTALL_FIRST" -eq 1 ]]; then
  echo "==> Uninstalling $PACKAGE_ID (data will be cleared)"
  adb -s "$DEVICE" uninstall "$PACKAGE_ID" >/dev/null 2>&1 || true
fi

set +e
install_out="$(adb -s "$DEVICE" install -r "$APK" 2>&1)"
install_status=$?
set -e
echo "$install_out"

if [[ $install_status -ne 0 ]]; then
  if echo "$install_out" | grep -q 'INSTALL_FAILED_UPDATE_INCOMPATIBLE'; then
    echo >&2
    echo "Signature mismatch with the installed app." >&2
    echo "Re-run with --uninstall-first to replace it (clears app data):" >&2
    echo "  $(basename "$0") --uninstall-first \"$DEVICE\"" >&2
  fi
  exit "$install_status"
fi

echo "==> Done"
