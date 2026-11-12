#!/usr/bin/env bash
set -euo pipefail

# This script updates the codex-acp flake version and metadata
# Usage: scripts/update_codex_acp.sh

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$REPO_ROOT"

FLAKE_DIR="pkgs/codex-acp"
METADATA_FILE="$FLAKE_DIR/metadata.json"

REGISTRY_URL="https://raw.githubusercontent.com/agentclientprotocol/registry/main/codex-acp/agent.json"

echo "Fetching latest Codex ACP manifest from ACP Registry..."
if ! MANIFEST=$(curl -fsSL "$REGISTRY_URL"); then
  echo "Error: Failed to fetch manifest from $REGISTRY_URL"
  exit 1
fi

VERSION=$(printf '%s\n' "$MANIFEST" | jq -r '.version // empty')
if [[ -z "$VERSION" ]]; then
  echo "Error: Could not extract version from $REGISTRY_URL"
  exit 1
fi
echo "Latest version detected: $VERSION"

NPM_PACKAGE=$(printf '%s\n' "$MANIFEST" | jq -r '.distribution.npx.package // empty' | sed -E 's/@[0-9].*//')
if [[ -z "$NPM_PACKAGE" ]]; then
  NPM_PACKAGE="@agentclientprotocol/codex-acp"
fi

NPM_META_URL="https://registry.npmjs.org/${NPM_PACKAGE}/${VERSION}"
echo "Fetching npm metadata from $NPM_META_URL..."
if ! NPM_META=$(curl -fsSL "$NPM_META_URL"); then
  echo "Error: Failed to fetch npm metadata from $NPM_META_URL"
  exit 1
fi

TARBALL_URL=$(printf '%s\n' "$NPM_META" | jq -r '.dist.tarball // empty')
if [[ -z "$TARBALL_URL" ]]; then
  echo "Error: Could not extract tarball URL from $NPM_META_URL"
  exit 1
fi

echo "Computing SHA-256 for $TARBALL_URL..."
if command -v sha256sum >/dev/null 2>&1; then
  SHA256=$(curl -fsSL "$TARBALL_URL" | sha256sum | awk '{print $1}')
else
  SHA256=$(curl -fsSL "$TARBALL_URL" | shasum -a 256 | awk '{print $1}')
fi

if [[ -z "$SHA256" ]]; then
  echo "Error: Failed to compute SHA-256 checksum for tarball"
  exit 1
fi

echo "Checksum computed: $SHA256"

echo "Generating $METADATA_FILE..."
jq -n \
  --arg version "$VERSION" \
  --arg npm_package "$NPM_PACKAGE" \
  --arg tarball_url "$TARBALL_URL" \
  --arg sha256 "$SHA256" \
  '{
    version: $version,
    registryId: "codex-acp",
    npmPackage: $npm_package,
    distribution: {
      type: "npx",
      tarball: $tarball_url,
      sha256: $sha256
    },
    systems: {
      "x86_64-linux": {},
      "aarch64-linux": {},
      "aarch64-darwin": {}
    },
    command: "codex-acp",
    args: [],
    env: {
      "CODEX_PATH": "codex"
    }
  }' > "$METADATA_FILE"

echo "metadata.json updated successfully to version $VERSION!"

echo "Updating flake locks..."
nix flake update --flake "./$FLAKE_DIR"
nix flake update

echo "Codex ACP metadata and locks updated successfully."
