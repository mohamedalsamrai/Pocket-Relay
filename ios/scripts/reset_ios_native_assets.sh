#!/bin/sh

set -eu

app_root="${FLUTTER_APPLICATION_PATH:-$SRCROOT/..}"
native_assets_dir="$app_root/build/native_assets/ios"
flutter_build_dir="$app_root/.dart_tool/flutter_build"
platform_state_file="$app_root/.dart_tool/reset_ios_native_assets_platform"

current_platform="${PLATFORM_NAME:-}"
case "$current_platform" in
  iphoneos|iphonesimulator)
    ;;
  "")
    echo "Skipping native asset reset: PLATFORM_NAME is not set"
    exit 0
    ;;
  *)
    echo "Skipping native asset reset for unsupported platform: $current_platform"
    exit 0
    ;;
esac

previous_platform=""
if [ -f "$platform_state_file" ]; then
  previous_platform="$(cat "$platform_state_file")"
fi

if [ "$previous_platform" = "$current_platform" ]; then
  exit 0
fi

if [ -d "$native_assets_dir" ]; then
  echo "Removing stale iOS native assets from $native_assets_dir after platform switch to $current_platform"
  rm -rf "$native_assets_dir"
fi

if [ -d "$flutter_build_dir" ]; then
  find "$flutter_build_dir" -mindepth 1 -maxdepth 1 -type d | while IFS= read -r build_dir; do
    native_assets_json="$build_dir/native_assets.json"
    dart_build_result_json="$build_dir/dart_build_result.json"

    if [ -f "$native_assets_json" ] && grep -q '"ios_' "$native_assets_json"; then
      rm -f \
        "$build_dir/native_assets.json" \
        "$build_dir/dart_build_result.json" \
        "$build_dir/install_code_assets.d" \
        "$build_dir/dart_build.d"
      continue
    fi

    if [ -f "$dart_build_result_json" ] && grep -q '"ios_' "$dart_build_result_json"; then
      rm -f \
        "$build_dir/native_assets.json" \
        "$build_dir/dart_build_result.json" \
        "$build_dir/install_code_assets.d" \
        "$build_dir/dart_build.d"
    fi
  done
fi

mkdir -p "$(dirname "$platform_state_file")"
printf '%s' "$current_platform" > "$platform_state_file"
