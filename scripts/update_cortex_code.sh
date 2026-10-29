#!/usr/bin/env bash
set -euo pipefail

# This script updates the cortex-code flake version and metadata
# Usage: scripts/update_cortex_code.sh

# Resolve the directory of the flake relative to the repo root
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$REPO_ROOT"

FLAKE_DIR="pkgs/cortex-code"
METADATA_FILE="$FLAKE_DIR/metadata.json"

S3_BUCKET="sfc-repo.snowflakecomputing.com"
S3_PREFIX="cortex-code-cli/a4643c4278"
VERSION_URL="https://${S3_BUCKET}/${S3_PREFIX}/stable_version.txt"

echo "Fetching latest Cortex Code version..."
if ! VERSION=$(curl -fsSL "$VERSION_URL" | tr -d '[:space:]'); then
  echo "Error: Failed to fetch version from $VERSION_URL"
  exit 1
fi

if [[ -z "$VERSION" ]]; then
  echo "Error: Empty version received from $VERSION_URL"
  exit 1
fi
echo "Latest version is $VERSION"

# URL encode function for internal use
urlencode() {
  echo "$1" | sed 's/+/%2B/g'
}

ENCODED_VERSION=$(urlencode "$VERSION")

MANIFEST_URL="https://${S3_BUCKET}/${S3_PREFIX}/${ENCODED_VERSION}/manifest.json"
echo "Fetching manifest from $MANIFEST_URL..."
if ! MANIFEST=$(curl -fsSL "$MANIFEST_URL"); then
  echo "Error: Failed to fetch manifest from $MANIFEST_URL"
  exit 1
fi

# Function to extract and encode package names
get_package_info() {
  local os=$1
  local arch=$2
  local name=$(echo "$MANIFEST" | jq -r ".packages.${os}.${arch}.name" 2>/dev/null)
  local encoded_name=$(urlencode "$name")
  local url="https://${S3_BUCKET}/${S3_PREFIX}/${ENCODED_VERSION}/${encoded_name}"
  local sha256=$(echo "$MANIFEST" | jq -r ".packages.${os}.${arch}.checksum" 2>/dev/null)
  
  if [[ -z "$name" || "$name" == "null" || -z "$sha256" || "$sha256" == "null" ]]; then
    return 1
  fi
  
  jq -n --arg url "$url" --arg sha256 "$sha256" '{url: $url, sha256: $sha256}'
}

echo "Generating $METADATA_FILE..."

LINUX_AMD64=$(get_package_info linux amd64)
LINUX_ARM64=$(get_package_info linux arm64)
DARWIN_ARM64=$(get_package_info darwin arm64)

# Verify we got all info
if [[ -z "$LINUX_AMD64" || -z "$LINUX_ARM64" || -z "$DARWIN_ARM64" ]]; then
  echo "Error: Failed to extract metadata for all platforms"
  exit 1
fi

jq -n \
  --arg version "$VERSION" \
  --argjson linux_amd64 "$LINUX_AMD64" \
  --argjson linux_arm64 "$LINUX_ARM64" \
  --argjson darwin_arm64 "$DARWIN_ARM64" \
  '{
    version: $version,
    systems: {
      "x86_64-linux": $linux_amd64,
      "aarch64-linux": $linux_arm64,
      "aarch64-darwin": $darwin_arm64
    },
    acp: {
      registryId: "cortex-code",
      mode: "internal",
      command: "cortex-code",
      args: ["acp", "serve"],
      env: {}
    }
  }' > "$METADATA_FILE"

echo "metadata.json updated successfully to version $VERSION!"

echo "Updating flake locks..."
nix flake update --flake "./$FLAKE_DIR"
nix flake update

echo "Cortex Code metadata and locks updated successfully."
