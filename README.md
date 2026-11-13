# Agent Flakes

[![Update Flakes](https://github.com/f0xdx/agents/actions/workflows/update-flakes.yml/badge.svg)](https://github.com/f0xdx/agents/actions/workflows/update-flakes.yml)

A curated collection of [Nix Flakes](https://nixos.wiki/wiki/Flakes), [Home Manager](https://github.com/nix-community/home-manager) modules, and Nixpkgs overlays for AI coding agents, [Agent Client Protocol (ACP)](https://agentclientprotocol.com/) bridges, and agent gateways.

All packages are updated daily via automated CI, locked with fixed-output hashes for pure Nix evaluation, and supported across `x86_64-linux`, `aarch64-linux`, and `aarch64-darwin`.

> [!NOTE]
> This project is in alpha state, so expect breaking changes.

## Overview

This repository complements upstream Home Manager by packaging agent tooling where upstream gaps exist:

* Standalone CLI coding agents not yet available in upstream Nixpkgs or Home Manager
* Companion ACP bridge servers for upstream agents that do not natively speak ACP
* Local agent gateways and routing proxies
* A uniform Home Manager ACP contract (`programs.<agent>.acp.{enable,command,args,env}`) so editors like Zed, Neovim, and Emacs can configure any agent's ACP server identically

Each tool lives in its own self-contained flake under [`pkgs/`](./pkgs) and can be consumed either individually (`?dir=pkgs/<name>`) or through the root aggregate flake.

---

## Available Packages

### Agent CLIs

| Package | Attribute | Description | ACP Support | License | Sub-Flake |
|---|---|---|---|---|---|
| Junie | `junie` | JetBrains Junie CLI coding agent | Native (`junie --acp=true`) | Proprietary ([Terms](https://junie.jetbrains.com/)) | [`pkgs/junie`](./pkgs/junie) |
| Cortex Code | `cortex-code` | Snowflake Cortex Code CLI agent (`coco`) | Native (`cortex-code acp serve`) | Proprietary ([Terms](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli)) | [`pkgs/cortex-code`](./pkgs/cortex-code) |

### Standalone ACP Bridges

Companion bridges from the [ACP Registry](https://github.com/agentclientprotocol/registry) for agents whose CLI is already packaged in upstream Home Manager:

| Package | Attribute | Description | Upstream Distribution | License | Sub-Flake |
|---|---|---|---|---|---|
| Antigravity ACP | `antigravity-acp` | Google Antigravity ACP server | Prebuilt binary (`agy_acp_server.par`) | Proprietary ([Terms](https://antigravity.google/terms)) | [`pkgs/antigravity-acp`](./pkgs/antigravity-acp) |
| Codex ACP | `codex-acp` | OpenAI Codex ACP adapter | npm (`@agentclientprotocol/codex-acp`) | [Apache-2.0](https://www.apache.org/licenses/LICENSE-2.0) | [`pkgs/codex-acp`](./pkgs/codex-acp) |

### Agent Gateways & Utilities

| Package | Attribute | Description | Binaries | License | Sub-Flake |
|---|---|---|---|---|---|
| Air Gateway | `air-gateway` | JetBrains Air Gateway (Central CLI) local proxy connecting agents to JetBrains AI | `central`, `air-gateway` | Proprietary ([EAP Terms](https://www.jetbrains.com/legal/docs/terms/jetbrains-central-cli-eap/)) | [`pkgs/air-gateway`](./pkgs/air-gateway) |

---

## Quick Start

Run any tool directly without installing it permanently:

```bash
nix run github:f0xdx/agents#junie -- --help
nix run github:f0xdx/agents#cortex-code -- --help
nix run github:f0xdx/agents#air-gateway -- --help
nix run github:f0xdx/agents#antigravity-acp -- --help
nix run github:f0xdx/agents#codex-acp -- --help
```

---

## Usage

### 1. Add to Your `flake.nix`

You can reference either the root repository flake (to access all packages, modules, and overlays) or an individual sub-flake using `?dir=`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Option A: Root flake aggregating all packages, modules, and overlays
    agents.url = "github:f0xdx/agents";

    # Option B: Individual sub-flakes (only fetches metadata for that specific tool)
    junie.url = "github:f0xdx/agents?dir=pkgs/junie";
    antigravity-acp.url = "github:f0xdx/agents?dir=pkgs/antigravity-acp";
    codex-acp.url = "github:f0xdx/agents?dir=pkgs/codex-acp";
    air-gateway.url = "github:f0xdx/agents?dir=pkgs/air-gateway";
  };
}
```

### 2. Home Manager Configuration

Import the desired module(s) from `agents.homeManagerModules` (or from the individual sub-flake):

```nix
{ inputs, ... }:
{
  imports = [
    inputs.agents.homeManagerModules.junie
    inputs.agents.homeManagerModules.cortex-code
    inputs.agents.homeManagerModules.antigravity-acp
    inputs.agents.homeManagerModules.codex-acp
    inputs.agents.homeManagerModules.air-gateway
  ];

  # Repository-managed Agent CLI with native ACP support
  programs.junie = {
    enable = true;
    acp.enable = true;
    settings = { };
  };

  # Upstream Home Manager Agent CLIs paired with Standalone ACP Bridges
  programs.antigravity-cli = {
    enable = true;
    acp.enable = true;
  };

  programs.codex = {
    enable = true;
    acp.enable = true;
  };

  # JetBrains Air Gateway (Central CLI)
  programs.air-gateway = {
    enable = true;
    settings = {
      # Merged in-place into ~/.jetbrains-central/config.json on activation,
      # preserving runtime credentials (proxy_secret, ai_access).
      proxy_port = 19516;
      log_level = "info";
    };
  };
}
```

#### Consuming the Uniform ACP Contract in Editors

Every agent module in this repository exposes read-only `acp.command`, `acp.args`, and `acp.env` options when `acp.enable = true`. You can wire them directly into your editor configuration (such as Zed):

```nix
{ config, ... }:
{
  programs.zed-editor.userSettings.agent_servers = {
    junie = {
      command = config.programs.junie.acp.command;
      args = config.programs.junie.acp.args;
      env = config.programs.junie.acp.env;
    };
    codex = {
      command = config.programs.codex.acp.command;
      args = config.programs.codex.acp.args;
      env = config.programs.codex.acp.env;
    };
  };
}
```

### 3. Nixpkgs Overlays & Development Shells

Apply `agents.overlays.default` (or a tool-specific overlay such as `agents.overlays.junie`) to expose the packages directly on `pkgs`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    agents.url = "github:f0xdx/agents";
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
            junie         # provides `junie`
            cortex-code   # provides `cortex-code` and `coco`
            air-gateway   # provides `central` and `air-gateway`
            antigravity-acp
            codex-acp
          ];
        };
      });
}
```

---

## Licenses & Unfree Packages

Several upstream agent binaries and bridges packaged in this repository are distributed under proprietary licenses:

* Junie is governed by the [JetBrains Junie License Terms](https://junie.jetbrains.com/)
* Cortex Code is governed by the [Snowflake Cortex Code CLI Terms](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli)
* Air Gateway (JetBrains Central CLI) is governed by the [JetBrains Central CLI EAP User Agreement](https://www.jetbrains.com/legal/docs/terms/jetbrains-central-cli-eap/)
* Google Antigravity ACP is governed by the [Google Antigravity Terms of Service](https://antigravity.google/terms)

To allow pure flake evaluation (`nix build`, `nix run`) without requiring global `--impure` flags or system-wide `allowUnfree = true`, this repository configures a scoped `allowUnfreePredicate` limited strictly to the unfree packages managed here (`junie`, `cortex-code`, `air-gateway`, and `antigravity-acp`). By using these flakes, you acknowledge and agree to the respective upstream license terms. Open-source packages in this collection (such as `codex-acp` under Apache-2.0) are governed by their respective permissive licenses.

---

## Maintenance & Contributing

All flakes in this repository are automatically checked and updated daily via GitHub Actions. If you want to update packages locally:

```bash
# Update all sub-flakes and root flake.lock
nix run .#update-flakes

# Update an individual flake
nix run .#update-junie
```

For full details on the repository architecture, adding new agents or ACP bridges, running the local development shell, and how automated daily updates and AI failure triage work, see [CONTRIBUTING.md](./CONTRIBUTING.md).
