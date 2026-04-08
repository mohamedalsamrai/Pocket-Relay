#!/bin/sh

set -eu

app_root="${FLUTTER_APPLICATION_PATH:-$SRCROOT/..}"
native_assets_dir="$app_root/build/native_assets/ios"
flutter_build_dir="$app_root/.dart_tool/flutter_build"

if [ -d "$native_assets_dir" ]; then
  echo "Removing stale iOS native assets from $native_assets_dir"
  rm -rf "$native_assets_dir"
fi

if [ -d "$flutter_build_dir" ]; then
  find "$flutter_build_dir" \
    \( -name native_assets.json -o -name dart_build_result.json -o -name install_code_assets.d -o -name dart_build.d \) \
    -delete
fi
