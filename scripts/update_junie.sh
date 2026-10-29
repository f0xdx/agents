#!/usr/bin/env bash
set -euo pipefail

# This script updates the junie flake version and metadata
# Usage: scripts/update_junie.sh

# Resolve the directory of the flake relative to the repo root
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$REPO_ROOT"

FLAKE_DIR="pkgs/junie"
METADATA_FILE="$FLAKE_DIR/metadata.json"

UPDATE_INFO_URL="https://raw.githubusercontent.com/jetbrains-junie/junie/main/update-info.jsonl"
TMP_JSONL=$(mktemp)
if ! curl -sSL "$UPDATE_INFO_URL" -o "$TMP_JSONL"; then
  echo "Error: Failed to fetch update info from $UPDATE_INFO_URL"
  rm -f "$TMP_JSONL"
  exit 1
fi

# Extract latest version (last line of the jsonl)
VERSION=$(tail -n 1 "$TMP_JSONL" | jq -r '.version' 2>/dev/null)

if [[ -z "$VERSION" || "$VERSION" == "null" ]]; then
  echo "Error: Could not extract version from $UPDATE_INFO_URL"
  rm -f "$TMP_JSONL"
  exit 1
fi

echo "Latest version detected: $VERSION"

# Function to get info for a platform using jq
get_info() {
  local platform=$1
  # Since it's JSONL, we use jq -s (slurp) to read all lines into an array
  local info=$(jq -s -c "map(select(.platform == \"$platform\" and .version == \"$VERSION\")) | .[0] | {url: .downloadUrl, sha256: .sha256}" "$TMP_JSONL" 2>/dev/null)
  
  if [[ -z "$info" || "$info" == "null" ]]; then
    return 1
  fi
  echo "$info"
}

echo "Generating $METADATA_FILE..."

LINUX_AMD64=$(get_info "linux-amd64")
LINUX_AARCH64=$(get_info "linux-aarch64")
MACOS_AARCH64=$(get_info "macos-aarch64")

# Verify we got all info
if [[ -z "$LINUX_AMD64" || -z "$LINUX_AARCH64" || -z "$MACOS_AARCH64" ]]; then
  echo "Error: Failed to extract metadata for all platforms"
  rm -f "$TMP_JSONL"
  exit 1
fi

# Generate metadata.json
jq -n \
  --arg version "$VERSION" \
  --argjson linux_amd64 "$LINUX_AMD64" \
  --argjson linux_aarch64 "$LINUX_AARCH64" \
  --argjson macos_aarch64 "$MACOS_AARCH64" \
  '{
    version: $version,
    systems: {
      "x86_64-linux": $linux_amd64,
      "aarch64-linux": $linux_aarch64,
      "aarch64-darwin": $macos_aarch64
    },
    acp: {
      registryId: "junie",
      mode: "internal",
      command: "junie",
      args: ["--acp=true"],
      env: {}
    }
  }' > "$METADATA_FILE"

rm -f "$TMP_JSONL"
echo "metadata.json updated successfully to version $VERSION!"

echo "Updating flake locks..."
nix flake update --flake "./$FLAKE_DIR"
nix flake update

echo "Junie metadata and locks updated successfully."
