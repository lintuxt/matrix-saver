#!/usr/bin/env bash
# Install MatrixSaver, the Matrix digital-rain screen saver for macOS.
#
#   curl -fsSL https://raw.githubusercontent.com/lintuxt/matrix-saver/trunk/install.sh | bash
#   wget -qO-  https://raw.githubusercontent.com/lintuxt/matrix-saver/trunk/install.sh | bash
#
# Piped (as above) it downloads the latest GitHub Release. Run from a clone of the repo
# it builds from source instead. See --help, or docs/install.md.
set -euo pipefail

REPO="lintuxt/matrix-saver"
SAVER_DIR="${MATRIX_SAVER_DIR:-$HOME/Library/Screen Savers}"
BIN_DIR="${MATRIX_SAVER_BIN_DIR:-$HOME/.local/bin}"
TMP_DIR=""

usage() {
  cat <<'EOF'
Usage: install.sh [--release | --source] [--version vX.Y.Z]
       install.sh --uninstall
       install.sh --help

Installs MatrixSaver.saver into ~/Library/Screen Savers and the matrix-config
helper into ~/.local/bin. No sudo needed.

  --release         Download a prebuilt release (default when piped from curl/wget)
  --source          Build from this checkout with Xcode (default inside a clone)
  --version vX.Y.Z  Release to install (default: latest)
  --uninstall       Remove the screen saver and matrix-config (settings are kept)

Environment overrides: MATRIX_SAVER_DIR, MATRIX_SAVER_BIN_DIR, MATRIX_SAVER_VERSION.
EOF
}

say()  { printf '==> %s\n' "$*"; }
die()  { printf 'install.sh: %s\n' "$*" >&2; exit 1; }

check_macos() {
  [[ $(uname -s) == Darwin ]] || die "MatrixSaver is a macOS screen saver; this is $(uname -s)."
  local major
  major=$(sw_vers -productVersion | cut -d. -f1)
  (( major >= 14 )) || die "macOS 14 or later is required (found $(sw_vers -productVersion))."
}

restart_hosts() {
  # The screen saver host caches loaded bundles; restart it so the new build is picked up.
  killall legacyScreenSaver 2>/dev/null || true
  killall "legacyScreenSaver (Wallpaper)" 2>/dev/null || true
}

install_bundle() {  # path to a MatrixSaver.saver
  mkdir -p "$SAVER_DIR"
  rm -rf "$SAVER_DIR/MatrixSaver.saver"
  ditto "$1" "$SAVER_DIR/MatrixSaver.saver"
  xattr -dr com.apple.quarantine "$SAVER_DIR/MatrixSaver.saver" 2>/dev/null || true
}

install_config_tool() {  # path to matrix-config
  mkdir -p "$BIN_DIR"
  install -m 0755 "$1" "$BIN_DIR/matrix-config"
}

installed_version() {
  /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
    "$SAVER_DIR/MatrixSaver.saver/Contents/Info.plist" 2>/dev/null || echo unknown
}

latest_tag() {
  local url
  url=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest") \
    || die "could not reach GitHub to find the latest release."
  [[ $url == */tag/v* ]] || die "no published release found at github.com/$REPO/releases."
  printf '%s\n' "${url##*/}"
}

install_release() {
  local tag=$1 pkg base tmp
  [[ -n $tag ]] || tag=$(latest_tag)
  [[ $tag == v* ]] || tag="v$tag"
  pkg="MatrixSaver-$tag"
  base="https://github.com/$REPO/releases/download/$tag"

  TMP_DIR=$(mktemp -d)
  trap 'rm -rf "$TMP_DIR"' EXIT
  tmp=$TMP_DIR

  say "Downloading $pkg"
  curl -fsSL -o "$tmp/$pkg.zip" "$base/$pkg.zip" || die "download failed: $base/$pkg.zip"
  curl -fsSL -o "$tmp/$pkg.zip.sha256" "$base/$pkg.zip.sha256" || die "checksum download failed."

  say "Verifying checksum"
  (cd "$tmp" && shasum -a 256 -c "$pkg.zip.sha256" >/dev/null) || die "checksum mismatch; not installing."

  ditto -x -k "$tmp/$pkg.zip" "$tmp"
  [[ -d $tmp/$pkg/MatrixSaver.saver ]] || die "release archive is missing MatrixSaver.saver."

  install_bundle "$tmp/$pkg/MatrixSaver.saver"
  install_config_tool "$tmp/$pkg/matrix-config"
}

install_source() {
  local root=$1
  command -v xcodebuild >/dev/null 2>&1 || die "Xcode is required to build from source (or use --release)."
  cd "$root"
  if command -v xcodegen >/dev/null 2>&1; then
    say "Generating Xcode project"
    xcodegen generate --quiet
  fi
  say "Building Release"
  xcodebuild -project MatrixSaver.xcodeproj -scheme MatrixSaver -configuration Release \
    -derivedDataPath build -quiet build
  install_bundle "build/Build/Products/Release/MatrixSaver.saver"
  install_config_tool "matrix-config"
}

uninstall() {
  rm -rf "$SAVER_DIR/MatrixSaver.saver"
  rm -f "$BIN_DIR/matrix-config"
  restart_hosts
  say "Removed MatrixSaver. Settings are kept; run 'matrix-config --reset' first to clear them."
}

finish() {
  restart_hosts
  say "Installed MatrixSaver $(installed_version) to $SAVER_DIR/MatrixSaver.saver"
  say "Installed matrix-config to $BIN_DIR/matrix-config"
  case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) say "Note: $BIN_DIR is not on your PATH; run it as $BIN_DIR/matrix-config" ;;
  esac
  cat <<'EOF'

Next: open System Settings > Wallpaper > Screen Saver and pick "Matrix".
Try it now with:  open -a ScreenSaverEngine
EOF
}

main() {
  local mode="" version="${MATRIX_SAVER_VERSION:-}" script_dir=""

  while (($#)); do
    case $1 in
      --release)   mode=release ;;
      --source)    mode=source ;;
      --version)   shift; version=${1:-}; [[ -n $version ]] || die "--version needs a value" ;;
      --uninstall) mode=uninstall ;;
      -h|--help)   usage; exit 0 ;;
      *)           die "unknown option '$1' (see --help)" ;;
    esac
    shift
  done

  # A file on disk next to project.yml means we're in a clone; piped input has no file.
  if [[ -n ${BASH_SOURCE[0]:-} && -f ${BASH_SOURCE[0]} ]]; then
    script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
  fi
  if [[ -z $mode ]]; then
    if [[ -n $script_dir && -f $script_dir/project.yml ]]; then mode=source; else mode=release; fi
  fi

  check_macos
  case $mode in
    uninstall) uninstall; return ;;
    source)
      [[ -n $script_dir && -f $script_dir/project.yml ]] || die "--source must be run from a clone of the repo."
      install_source "$script_dir" ;;
    release) install_release "$version" ;;
  esac
  finish
}

# Everything runs from here, so a partially downloaded script never executes.
main "$@"
