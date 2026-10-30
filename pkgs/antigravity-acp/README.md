# Google Antigravity ACP Nix Flake

This flake provides the official [Google Antigravity ACP Server](https://antigravity.google/docs/ide/extensions) (`antigravity-acp`, binary `agy_acp_server.par` and companion `localharness_external`) as a Nix package and Home Manager module.

Google Antigravity CLI itself is packaged and managed in upstream Home Manager (`programs.antigravity`). This standalone flake provides the companion ACP (Agent Client Protocol) bridge according to Pattern 2 (Standalone ACP Bridge Flakes) so ACP-compatible code editors (such as Zed, Emacs, or Neovim) can interact with Antigravity uniformly.

## Usage

### 1. Add as an input to your system or home-manager flake

In your `flake.nix`:

```nix
{
  inputs = {
    # OPTION A: Reference the Antigravity ACP flake directly
    antigravity-acp.url = "github:<your-username>/agents?dir=pkgs/antigravity-acp";

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
    inputs.antigravity-acp.homeManagerModules.antigravity-acp

    # If using OPTION B
    # inputs.agents.homeManagerModules.antigravity-acp
  ];

  # Primary agent CLI (provided upstream by Home Manager)
  programs.antigravity.enable = true;

  # Standalone companion ACP bridge
  programs.antigravity.acp.enable = true;
}
```

Alternatively, the module can be enabled via the alias `programs.antigravity-acp.enable = true;`.

### 3. Downstream ACP Client Integration

Downstream editor modules (e.g. Zed, Neovim, or custom ACP wrappers) can consume the uniform read-only options exposed by this companion module:

```nix
{ config, ... }: {
  # Example: wiring into an ACP editor client configuration
  programs.zed.settings.agent_servers.antigravity = {
    command = config.programs.antigravity.acp.command;
    args = config.programs.antigravity.acp.args;
    env = config.programs.antigravity.acp.env;
  };
}
```

The options resolve to:
* `command`: `$out/bin/agy_acp_server.par`
* `args`: Platform-specific arguments (`["--uid="]` on Linux, `[]` on macOS)
* `env`: Environment variables including `ANTIGRAVITY_HARNESS_PATH` pointing to `localharness_external`

### 4. Use the Package directly

```nix
{ pkgs, inputs, ... }: {
  home.packages = [
    inputs.antigravity-acp.packages.${pkgs.stdenv.hostPlatform.system}.antigravity-acp
  ];
}
```

The package provides both `agy_acp_server.par` and the convenience alias `antigravity-acp` in `$out/bin`.

## Maintenance

The binary metadata (URLs and SHA-256 hashes) is stored in `metadata.json`.

To update to the latest version of Antigravity ACP from the official ACP Registry, run the update script from the root repository:

```bash
nix run .#update-antigravity-acp
```

Alternatively, you can use the unified `.agents/skills/update-agent-flake` skill to automate this process.

## License

Google Antigravity ACP Server is proprietary software provided by Google LLC and governed by the [Google Antigravity Terms of Service](https://antigravity.google/terms).

This Nix derivation is marked with `meta.license = licenses.unfree;`.
