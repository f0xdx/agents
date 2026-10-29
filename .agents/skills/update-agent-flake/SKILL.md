---
name: update-agent-flake
description: >-
  Expert procedural guidance for updating agent CLI flakes (e.g., Junie, Cortex Code, or all agents)
  in this repository. Use when asked to update agent metadata, refresh flake locks, verify builds,
  inspect upstream release sources, or maintain the agent flake collection.
---

# Update Agent Flake Skill

Procedural guidance for updating agent flakes, generating `metadata.json`, refreshing flake locks, and verifying builds.

## Workflow

### 1. Identify Target Agent

Determine whether the update is for a specific agent (`junie`, `cortex-code`, etc.) or for all agents in the repository.

### 2. Optional: Verify Upstream Release Source & ACP Registry

Before running the update script, optionally check if upstream source mechanisms, endpoints, or ACP Registry definitions (`https://cdn.agentclientprotocol.com/registry/v1/latest/registry.json` or `https://github.com/agentclientprotocol/registry`) have changed:
* Junie: Check `https://junie.jetbrains.com/` and inspect `https://junie.jetbrains.com/install.sh`, `update-info.jsonl`, or `junie/agent.json` in the ACP Registry.
* Cortex Code: Check Snowflake S3 bucket prefix (`sfc-repo.snowflakecomputing.com/cortex-code-cli/a4643c4278/stable_version.txt`) and `cortex-code/agent.json` in the ACP Registry.
* Air Gateway: Check `https://central-cli.labs.jb.gg/install.sh` and S3 bucket (`https://jetbrains-central-cli.s3.eu-west-1.amazonaws.com/central/stable/version.txt`).

### 3. Execute Update

Run the update command from the repository root:

* For a specific agent or utility:
  ```bash
  nix run .#update-<name>
  # Alternatively: ./scripts/update_<name>.sh
  ```
* For all flakes:
  ```bash
  nix run .#update-flakes
  ```

### 4. Verify Metadata & Lockfiles

Ensure that:
* `pkgs/<name>/metadata.json` contains valid version, URLs, and SHA-256 hashes for all supported platforms (`x86_64-linux`, `aarch64-linux`, `aarch64-darwin`), as well as a valid `acp` block for Pattern 1 / Pattern 2 flakes.
* Sub-flake lock (`pkgs/<name>/flake.lock`) and root `flake.lock` are updated.

### 5. Verify Builds & Binaries

Verify that the derivation builds cleanly and the binary executes:

```bash
# Build derivation
nix build .#<name>

# Verify binary help output
./result/bin/<binary-name> --help

# Structural flake check
nix flake check
```

### 6. Commit Changes

Commit updates using Conventional Commits:
* Single flake: `chore(<name>): update to version <VERSION>`
* Multiple/All flakes: `chore(flakes): update all agent flakes`

## Agent Reference Table

### Integrated Agent Flakes (Pattern 1)

| Agent | Flake Directory | Script | Upstream Source | ACP Mode & Registry ID |
|---|---|---|---|---|
| Junie | `pkgs/junie` | `scripts/update_junie.sh` | JetBrains GitHub `update-info.jsonl` | `internal` (`junie`, `--acp=true`) |
| Cortex Code | `pkgs/cortex-code` | `scripts/update_cortex_code.sh` | Snowflake S3 bucket manifest | `internal` (`cortex-code`, `acp serve`) |

### Standalone ACP Bridge Flakes (Pattern 2)

| Agent Bridge | Flake Directory | Script | Upstream Source | ACP Registry ID & Type |
|---|---|---|---|---|
| Antigravity ACP | `pkgs/antigravity-acp` | `scripts/update_antigravity_acp.sh` | Google ACP Server releases | `antigravity-acp` (prebuilt binary) |
| Codex ACP | `pkgs/codex-acp` | `scripts/update_codex_acp.sh` | npm `@agentclientprotocol/codex-acp` | `codex-acp` (npm package) |

### Standalone Agent Utilities & Gateways (Pattern 3)

| Utility | Flake Directory | Script | Upstream Source | Binary |
|---|---|---|---|---|
| Air Gateway | `pkgs/air-gateway` | `scripts/update_air_gateway.sh` | JetBrains Central CLI S3 (`version.txt` & `checksums.txt`) | `central` (`air-gateway`) |

## Adding a New Agent, ACP Bridge, or Utility to this Skill

When adding new agent tooling:
1. Verify upstream Home Manager status: check if the tool or agent CLI and module are already provided upstream.
2. Check `https://github.com/agentclientprotocol/registry` (`registry.json`):
   * If the agent is in upstream Home Manager and supports ACP natively (e.g., OpenCode via `opencode acp`), no flake is required.
   * If the agent is in upstream Home Manager and requires an external bridge, add it as a Standalone ACP Bridge (`pkgs/<name>-acp/`, Pattern 2).
   * If the agent is not in upstream Home Manager, add it as an Integrated Agent Flake (`pkgs/<name>/`, Pattern 1).
   * If the tool is a standalone agent gateway or utility not in upstream Home Manager, add it as a Standalone Agent Utility Flake (`pkgs/<name>/`, Pattern 3).
3. Ensure the update script (`scripts/update_<name>.sh` or `scripts/update_<name>_acp.sh`) is registered in root `flake.nix` under `apps` and included in `update-flakes`.
4. Add an entry to the Agent Reference Table above.
