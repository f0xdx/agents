# Junie Nix Flake

This flake provides the [Junie CLI Agent](https://junie.jetbrains.com/) by JetBrains as a Nix package and Home Manager module.

## Usage

### 1. Add as an input to your system or home-manager flake

In your `flake.nix`:

```nix
{
  inputs = {
    # ... your other inputs

    # OPTION A: Reference the Junie flake directly
    junie.url = "github:<your-username>/agents?dir=pkgs/junie";

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
    inputs.junie.homeManagerModules.junie

    # If using OPTION B
    # inputs.agents.homeManagerModules.junie
  ];

  programs.junie = {
    enable = true;
    # Optional: package = inputs.junie.packages.${pkgs.stdenv.hostPlatform.system}.junie;
    acp.enable = true;
    settings = {
      # Written to ~/.junie/config.json when non-empty
    };
  };
}
```

### 3. Use the Package directly

```nix
{ pkgs, inputs, ... }: {
  home.packages = [
    inputs.junie.packages.${pkgs.stdenv.hostPlatform.system}.junie
  ];
}
```

## Maintenance

The binary metadata (URLs and SHA-256 hashes) is stored in metadata.json.

To update to the latest version of Junie, you can run the provided update script from the root repository (requires `jq` and `curl`):

```bash
# From the root of this repository
nix run .#update-junie
```

Alternatively, if you are using an AI agent like Gemini CLI, you can activate the `update-agent-flake` skill to automate this process.

## License

Junie is proprietary software provided by JetBrains subject to JetBrains terms and conditions as detailed on [JetBrains Junie](https://junie.jetbrains.com/).

This Nix derivation is marked with `meta.license = licenses.unfree;`.
