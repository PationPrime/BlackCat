#!/usr/bin/env bash
#
# Packs the macOS release build into a .dmg named after the version in
# Info.plist and the architecture the binary was actually built for, e.g.
# BlackCat_0.1.0.1_aarch64.dmg.
#
#   tool/make_dmg.sh                              a dmg for this Mac
#   tool/make_dmg.sh --skip-build                 packs what is already built
#   FLUTTER_XCODE_ARCHS=x86_64 tool/make_dmg.sh   a dmg for Intel
#
# The app inside is signed the way the build signed it. Ad-hoc signed builds
# are refused by Gatekeeper on any other Mac until its quarantine attribute
# is removed by hand; a dmg meant for other people needs a Developer ID
# identity and notarization.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

readonly products='build/macos/Build/Products/Release'
readonly staging='build/macos/dmg-staging'

case "${1:-}" in
  '') flutter build macos --release ;;
  '--skip-build') ;;
  *)
    echo "Unknown argument: $1" >&2
    echo "Usage: tool/make_dmg.sh [--skip-build]" >&2
    echo "The dmg is named from the version and the architecture of the" >&2
    echo "build; there is nothing to pass." >&2
    exit 1
    ;;
esac

app="$(find "$products" -maxdepth 1 -name '*.app' -print -quit)"

if [[ -z "$app" ]]; then
  echo "No .app in $products. Run without --skip-build." >&2
  exit 1
fi

plist="$app/Contents/Info.plist"
name="$(basename "$app" .app)"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")"
build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")"
executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist")"

# "Non-fat file: … is architecture: arm64" or "… are: x86_64 arm64"
archs="$(lipo -info "$app/Contents/MacOS/$executable" | sed 's/.*: //')"

case "$archs" in
  'arm64') arch='aarch64' ;;
  'x86_64') arch='x86_64' ;;
  *) arch='universal' ;;
esac

readonly dmg="build/${name}_${version}.${build}_${arch}.dmg"
readonly volume="$name $version"

# A volume left mounted by an earlier run holds the old image open.
# hdiutil warns that it is deprecated in favour of diskutil; the replacement
# needs macOS 27, hdiutil works everywhere, so the warning is expected
hdiutil detach "/Volumes/$volume" >/dev/null 2>&1 || true

rm -rf "$staging"
mkdir -p "$staging"

# ditto keeps the symlinks and signature of the bundle intact, cp -R does not
ditto "$app" "$staging/$name.app"
ln -s /Applications "$staging/Applications"

hdiutil create \
  -volname "$volume" \
  -srcfolder "$staging" \
  -fs HFS+ \
  -format UDZO \
  -ov \
  "$dmg" >/dev/null

rm -rf "$staging"

echo "$dmg ($(du -h "$dmg" | cut -f1), $archs)"
