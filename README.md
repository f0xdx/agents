# Nix Flake Collection

This repository is a collection of [Nix Flakes](https://nixos.wiki/wiki/Flakes)
for various AI agents and tools. Each tool is self-contained within its own
directory in `pkgs/`.

## Repository Management

This root directory contains a management flake that aggregates all tools and
provides maintenance scripts.

### Management Shell

To get a shell with all required management tools (`jq`, `curl`, `nix`):

```bash
nix develop
```

### Update Tools

To update all tools to their latest versions:

```bash
nix run .#update-flakes
```

To update a specific tool:

```bash
nix run .#update-junie
nix run .#update-cortex-code
nix run .#update-air-gateway
```

## Available Flakes

### Repository-Managed Agent CLIs

| Flake | Description | ACP Support | License | Directory |
|---|---|---|---|---|
| Junie | JetBrains Junie CLI Agent | Built-in (`junie --acp=true`) | Proprietary ([License](https://junie.jetbrains.com/)) | [`pkgs/junie`](./pkgs/junie) |
| Cortex Code | Snowflake Cortex Code CLI Agent (`coco`) | Built-in (`cortex-code acp serve`) | Proprietary ([License & Documentation](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli)) | [`pkgs/cortex-code`](./pkgs/cortex-code) |

### Standalone ACP Bridges (for Upstream Home Manager Agents)

| Flake | Description | ACP Implementation | License | Directory |
|---|---|---|---|---|
| Antigravity ACP | Google Antigravity ACP Server | Prebuilt Binary (`agy_acp_server.par`) | Proprietary ([Terms](https://antigravity.google/terms)) | Planned (`pkgs/antigravity-acp`) |
| Codex ACP | OpenAI Codex ACP Adapter | npm package (`@agentclientprotocol/codex-acp`) | Apache-2.0 | Planned (`pkgs/codex-acp`) |

### Agent Gateways & Utilities

| Flake | Description | Binary | License | Directory |
|---|---|---|---|---|
| Air Gateway | JetBrains Air Gateway (Central CLI) proxy for connecting agents to JetBrains AI | `central` (`air-gateway`) | Proprietary ([EAP User Agreement](https://www.jetbrains.com/legal/docs/terms/jetbrains-central-cli-eap/)) | [`pkgs/air-gateway`](./pkgs/air-gateway) |

## Licenses & Unfree Packages

Certain agent packages, utilities, and ACP companion bridges included in this repository are distributed under upstream proprietary licenses:
* Junie: JetBrains proprietary license (see [JetBrains Junie](https://junie.jetbrains.com/)).
* Cortex Code: Snowflake proprietary license (see [Snowflake Cortex Code CLI Documentation](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli)).
* Air Gateway (JetBrains Central CLI): JetBrains proprietary license (see [JetBrains Central CLI EAP User Agreement](https://www.jetbrains.com/legal/docs/terms/jetbrains-central-cli-eap/)).
* Google Antigravity ACP: Google proprietary license (see [Google Antigravity Terms](https://antigravity.google/terms)).

To support pure evaluation without requiring global `--impure` flags, this repository uses a scoped `allowUnfreePredicate` in its flake outputs. By using these flakes, users acknowledge the respective proprietary licenses. Open-source bridges (e.g., Codex ACP under Apache-2.0) are governed by their respective permissive licenses.

## How to use a flake from this collection

To use a specific flake in your own Nix configuration, you can reference it as
an input using the `?dir=` parameter.

Example in your `flake.nix`:

```nix
{
  inputs = {
    # Reference an integrated agent flake directly
    junie.url = "github:<username>/agents?dir=pkgs/junie";

    # Reference a standalone ACP bridge flake directly
    antigravity-acp.url = "github:<username>/agents?dir=pkgs/antigravity-acp";

    # Reference an agent utility flake directly
    air-gateway.url = "github:<username>/agents?dir=pkgs/air-gateway";
  };
}
```

Alternatively, reference the root flake to access all tools and companion modules:

```nix
{
  inputs = {
    agents.url = "github:<username>/agents";
  };

  outputs = { self, agents, ... }: {
    # Integrated Agent (Package & HM Module)
    # agents.packages.${system}.junie
    # agents.homeManagerModules.junie

    # Standalone ACP Bridge (Package & HM Module)
    # agents.packages.${system}.antigravity-acp
    # agents.homeManagerModules.antigravity-acp

    # Agent Gateway Utility (Package & HM Module)
    # agents.packages.${system}.air-gateway
    # agents.homeManagerModules.air-gateway

    # Overlays (Root Aggregate or Individual Tools)
    # agents.overlays.default
    # agents.overlays.junie
    # agents.overlays.cortex-code
    # agents.overlays.air-gateway
  };
}
```

### Development Shells (via Overlays)

To use agent commands directly by name in your development shell (e.g., `air-gateway`, `central`, `cortex-code`, `coco`, `junie`), consume the flake's overlay:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    agents.url = "github:<username>/agents";
  };

  outputs = { self, nixpkgs, flake-utils, agents }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ agents.overlays.default ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            air-gateway   # provides `central` and `air-gateway`
            cortex-code   # provides `coco` and `cortex-code`
            junie         # provides `junie`
          ];
        };
      });
}
```

Individual sub-flakes also export their own scoped overlays (e.g., `air-gateway.overlays.default` or `air-gateway.overlays.air-gateway`) if you only require a specific tool.

### Home Manager Configuration

For repository-managed agents (e.g., Junie):

```nix
programs.junie = {
  enable = true;
  acp.enable = true; # enables native ACP server exposure
};
```

For agents managed upstream in Home Manager (e.g., Antigravity):

```nix
# Upstream Home Manager module manages the agent CLI
programs.antigravity.enable = true;

# Standalone ACP sub-flake provides ACP companion options
programs.antigravity.acp.enable = true;
```

For JetBrains Air Gateway (Central CLI):

```nix
programs.air-gateway = {
  enable = true;
  settings = {
    # Merged in-place into ~/.jetbrains-central/config.json on activation,
    # preserving runtime state (proxy_secret, ai_access) written by central.
    proxy_port = 19516;
    log_level = "info";
  };
};
```

After enabling `programs.air-gateway`, authenticate and connect agents manually at runtime:
* Log in to your JetBrains AI subscription: `central login`
* Run an agent for a single session (leaves agent config files untouched): `central run codex -- "explain this code"`
* Permanently connect an agent (modifies the agent's writable config file in place): `central add codex`

## Contributing and Maintenance

Each sub-flake in `pkgs/` has its own `README.md` with specific installation
instructions. Most flakes in this repository include automation scripts in the
root `scripts/` directory to keep versions up to date.

## TODO Extension Points

Date: 2026-10-21

* [x] update the cortex-code and junie agent flakes
* [x] update [AGENTS.md](AGENTS.md) and maintenance skill for dual-model ACP architecture (integrated agent flakes vs standalone ACP bridges)
* [x] extend junie with ACP support (native out-of-the-box)
* [x] extend cortex-code with ACP support (native out-of-the-box)
* [x] verify OpenCode ACP support: native ACP (`opencode acp`) is supported out-of-the-box and agent CLI is maintained in upstream Home Manager (no flake required in this repository)
* [x] add standalone flake for [JetBrains Air Gateway (Central CLI)](https://www.jetbrains.com/air/gateway/) (`pkgs/air-gateway`)
* [ ] integrate standalone ACP bridge flake for [Google Antigravity](https://github.com/agentclientprotocol/registry/blob/main/antigravity-acp/agent.json) (`pkgs/antigravity-acp`)
* [ ] integrate standalone ACP bridge flake for [Codex](https://github.com/agentclientprotocol/registry/blob/main/codex-acp/agent.json) (`pkgs/codex-acp`)
