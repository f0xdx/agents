#!/usr/bin/env bash
set -euo pipefail

# This script updates the air-gateway flake version and metadata
# Usage: scripts/update_air_gateway.sh

# Resolve the directory of the flake relative to the repo root
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$REPO_ROOT"

FLAKE_DIR="pkgs/air-gateway"
METADATA_FILE="$FLAKE_DIR/metadata.json"

S3_BASE="https://jetbrains-central-cli.s3.eu-west-1.amazonaws.com"
VERSION_URL="$S3_BASE/central/stable/version.txt"

echo "Fetching latest Air Gateway (Central CLI) version..."
if ! VERSION=$(curl -fsSL "$VERSION_URL" | tr -d '[:space:]'); then
  echo "Error: Failed to fetch version from $VERSION_URL"
  exit 1
fi

VERSION="${VERSION#v}"
if [[ -z "$VERSION" ]]; then
  echo "Error: Empty version received from $VERSION_URL"
  exit 1
fi
echo "Latest version detected: $VERSION"

CHECKSUMS_URL="$S3_BASE/central/$VERSION/checksums.txt"
echo "Fetching checksums from $CHECKSUMS_URL..."
if ! CHECKSUMS=$(curl -fsSL "$CHECKSUMS_URL"); then
  echo "Error: Failed to fetch checksums from $CHECKSUMS_URL"
  exit 1
fi

get_platform_info() {
  local os=$1
  local arch=$2
  local archive="central_${VERSION}_${os}_${arch}.tar.gz"
  local url="$S3_BASE/central/$VERSION/$archive"
  local sha256
  sha256=$(printf '%s\n' "$CHECKSUMS" | sed -n "s/^\([0-9a-fA-F]\{64\}\)[[:space:]]\{1,\}${archive}$/\1/p" | head -n 1)

  if [[ -z "$sha256" ]]; then
    return 1
  fi

  jq -n --arg url "$url" --arg sha256 "$sha256" '{url: $url, sha256: $sha256}'
}

echo "Generating $METADATA_FILE..."

LINUX_X86_64=$(get_platform_info "linux" "x86_64")
LINUX_ARM64=$(get_platform_info "linux" "arm64")
DARWIN_ARM64=$(get_platform_info "darwin" "arm64")

if [[ -z "$LINUX_X86_64" || -z "$LINUX_ARM64" || -z "$DARWIN_ARM64" ]]; then
  echo "Error: Failed to extract metadata for all platforms"
  exit 1
fi

jq -n \
  --arg version "$VERSION" \
  --argjson linux_x86_64 "$LINUX_X86_64" \
  --argjson linux_arm64 "$LINUX_ARM64" \
  --argjson darwin_arm64 "$DARWIN_ARM64" \
  '{
    version: $version,
    systems: {
      "x86_64-linux": $linux_x86_64,
      "aarch64-linux": $linux_arm64,
      "aarch64-darwin": $darwin_arm64
    }
  }' > "$METADATA_FILE"

echo "metadata.json updated successfully to version $VERSION!"

echo "Updating flake locks..."
nix flake update --flake "./$FLAKE_DIR"
nix flake update

echo "Air Gateway metadata and locks updated successfully."
