#!/usr/bin/env bash
set -euo pipefail

# This script updates the antigravity-acp flake version and metadata
# Usage: scripts/update_antigravity_acp.sh

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$REPO_ROOT"

FLAKE_DIR="pkgs/antigravity-acp"
METADATA_FILE="$FLAKE_DIR/metadata.json"

REGISTRY_URL="https://raw.githubusercontent.com/agentclientprotocol/registry/main/antigravity-acp/agent.json"

echo "Fetching latest Antigravity ACP manifest from ACP Registry..."
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

get_platform_info() {
  local target=$1
  printf '%s\n' "$MANIFEST" | jq -c --arg target "$target" '
    .distribution.binary[$target] as $b
    | if ($b == null or ($b.archive // "") == "" or ($b.sha256 // "") == "") then
        empty
      else
        { url: $b.archive, sha256: $b.sha256 }
        + (if ($b.args != null and ($b.args | length) > 0) then { args: $b.args } else {} end)
      end
  '
}

LINUX_X86_64=$(get_platform_info "linux-x86_64")
LINUX_AARCH64=$(get_platform_info "linux-aarch64")
DARWIN_AARCH64=$(get_platform_info "darwin-aarch64")

if [[ -z "$LINUX_X86_64" || -z "$LINUX_AARCH64" || -z "$DARWIN_AARCH64" ]]; then
  echo "Error: Failed to extract metadata for all required platforms"
  exit 1
fi

RAW_CMD=$(printf '%s\n' "$MANIFEST" | jq -r '.distribution.binary["darwin-aarch64"].cmd // "./agy_acp_server.par"')
COMMAND="${RAW_CMD#./}"

echo "Generating $METADATA_FILE..."
jq -n \
  --arg version "$VERSION" \
  --arg command "$COMMAND" \
  --argjson linux_x86_64 "$LINUX_X86_64" \
  --argjson linux_aarch64 "$LINUX_AARCH64" \
  --argjson darwin_aarch64 "$DARWIN_AARCH64" \
  '{
    version: $version,
    registryId: "antigravity-acp",
    distribution: "binary",
    systems: {
      "x86_64-linux": $linux_x86_64,
      "aarch64-linux": $linux_aarch64,
      "aarch64-darwin": $darwin_aarch64
    },
    command: $command,
    args: [],
    env: {}
  }' > "$METADATA_FILE"

echo "metadata.json updated successfully to version $VERSION!"

echo "Updating flake locks..."
nix flake update --flake "./$FLAKE_DIR"
if [[ "${SKIP_ROOT_LOCK_UPDATE:-0}" != "1" ]]; then
  nix flake update
fi

echo "Antigravity ACP metadata and locks updated successfully."
