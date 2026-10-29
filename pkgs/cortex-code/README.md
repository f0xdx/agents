# Cortex Code Nix Flake

This flake provides the [Snowflake Cortex Code CLI Agent](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli) (`coco`) as a Nix package and Home Manager module.

## Usage

### 1. Add as an input to your system or home-manager flake

In your `flake.nix`:

```nix
{
  inputs = {
    # OPTION A: Reference the Cortex Code flake directly
    cortex-code.url = "github:<your-username>/agents?dir=pkgs/cortex-code";
    
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
    inputs.cortex-code.homeManagerModules.cortex-code
    
    # If using OPTION B
    # inputs.agents.homeManagerModules.cortex-code
  ];

  programs.cortex-code = {
    enable = true;
    # Optional: package = inputs.cortex-code.packages.${pkgs.stdenv.hostPlatform.system}.cortex-code;
    acp.enable = true;
    settings = {
      # Written to ~/.snowflake/cortex/settings.json when non-empty
    };
  };
}
```

### 3. Use the Package directly

```nix
{ pkgs, inputs, ... }: {
  home.packages = [
    inputs.cortex-code.packages.${pkgs.stdenv.hostPlatform.system}.cortex-code
  ];
}
```

## Maintenance

The binary metadata (URLs and SHA-256 hashes) is stored in `metadata.json`. 
To update to the latest version of Cortex Code, run the update command from the root repository:

```bash
nix run .#update-cortex-code
```

Alternatively, you can use the unified `.agents/skills/update-agent-flake` skill to automate this process.

## License

Cortex Code is proprietary software provided by Snowflake subject to Snowflake's terms and conditions as detailed in the [Snowflake Cortex Code CLI Documentation](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli).

This Nix derivation is marked with `meta.license = licenses.unfree;`.

