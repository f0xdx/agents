# OpenAI Codex ACP Nix Flake

This flake provides the official [OpenAI Codex ACP Adapter](https://github.com/agentclientprotocol/codex-acp) (`codex-acp`, npm package `@agentclientprotocol/codex-acp`) as a Nix package and Home Manager module.

OpenAI Codex CLI itself is packaged and maintained in upstream Home Manager (`programs.codex`) and `nixpkgs` (`pkgs.codex`). This standalone flake provides the companion ACP (Agent Client Protocol) bridge according to Pattern 2 (Standalone ACP Bridge Flakes) so ACP-compatible code editors (such as Zed, Emacs, or Neovim) can interact with Codex uniformly.

## Usage

### 1. Add as an input to your system or home-manager flake

In your `flake.nix`:

```nix
{
  inputs = {
    # OPTION A: Reference the Codex ACP flake directly
    codex-acp.url = "github:<your-username>/agents?dir=pkgs/codex-acp";

    # OPTION B: Reference the root repository aggregate
    agents.url = "github:<your-username>/agents";
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    # ...
  };
}
```

### 2. Use the Home Manager Module

In your Home Manager configuration:

```nix
{ pkgs, inputs, ... }: {
  imports = [
    # If using OPTION A
    inputs.codex-acp.homeManagerModules.codex-acp

    # If using OPTION B
    # inputs.agents.homeManagerModules.codex-acp
  ];

  # Primary agent CLI (provided upstream by Home Manager)
  programs.codex.enable = true;

  # Standalone companion ACP bridge
  programs.codex.acp.enable = true;
}
```

Alternatively, the module can be enabled via the alias `programs.codex-acp.enable = true;`.

When `programs.codex.enable` is enabled in your configuration, `programs.codex.acp.env.CODEX_PATH` automatically defaults to the binary path `${config.programs.codex.package}/bin/codex`.

### 3. Downstream ACP Client Integration

Downstream editor modules (e.g. Zed, Neovim, or custom ACP wrappers) can consume the uniform read-only options exposed by this companion module:

```nix
{ config, ... }: {
  # Example: wiring into an ACP editor client configuration
  programs.zed.settings.agent_servers.codex = {
    command = config.programs.codex.acp.command;
    args = config.programs.codex.acp.args;
    env = config.programs.codex.acp.env;
  };
}
```

The options resolve to:
* `command`: `$out/bin/codex-acp`
* `args`: `[]` (empty list by default)
* `env`: Environment variables including `CODEX_PATH` pointing to the Codex binary executable

### 4. Use the Package directly

```nix
{ pkgs, inputs, ... }: {
  home.packages = [
    inputs.codex-acp.packages.${pkgs.stdenv.hostPlatform.system}.codex-acp
  ];
}
```

The package provides `codex-acp` in `$out/bin`.

## Maintenance

The package metadata (version, npm tarball URL, and SHA-256 hash) is stored in `metadata.json`.

To update to the latest version of Codex ACP from the official ACP Registry and npm, run the update script from the root repository:

```bash
nix run .#update-codex-acp
```

Alternatively, you can use the unified `.agents/skills/update-agent-flake` skill to automate this process.

## License

The OpenAI Codex ACP Adapter is open-source software licensed under the [Apache License 2.0](https://github.com/agentclientprotocol/codex-acp/blob/main/LICENSE).

This Nix derivation is marked with `meta.license = licenses.asl20;`.
