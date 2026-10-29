# JetBrains Air Gateway (Central CLI) Nix Flake

This flake provides [JetBrains Air Gateway](https://www.jetbrains.com/air/gateway/) (documented as [JetBrains Central CLI](https://www.jetbrains.com/help/central-cli/cli-in-depth.html), binary `central`) as a Nix package and Home Manager module.

Air Gateway runs a local authenticating reverse proxy (`127.0.0.1:19516`) that connects terminal coding agents (such as Codex, Claude Agent, Gemini CLI, Junie CLI, Pi, and GitHub Copilot) to your JetBrains AI subscription.

## Usage

### 1. Add as an input to your system or home-manager flake

In your `flake.nix`:

```nix
{
  inputs = {
    # OPTION A: Reference the Air Gateway flake directly
    air-gateway.url = "github:<your-username>/agents?dir=pkgs/air-gateway";

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
    inputs.air-gateway.homeManagerModules.air-gateway

    # If using OPTION B
    # inputs.agents.homeManagerModules.air-gateway
  ];

  programs.air-gateway = {
    enable = true;
    # Optional: package = inputs.air-gateway.packages.${pkgs.stdenv.hostPlatform.system}.air-gateway;
    settings = {
      # Merged in-place into ~/.jetbrains-central/config.json on activation.
      # Runtime fields managed by central (proxy_secret, ai_access) are preserved.
      # release_track defaults to cfg.package.version to prevent out-of-band self-updates.
      proxy_port = 19516;
      log_level = "info";
      "jumpscare-mode" = true;
      "approve-all-policies" = true;
      google_analytics_accepted = false;
    };
  };
}
```

### 3. Authenticate and Connect Agents

Because `central` manages OAuth tokens in your system keychain and generates a local `proxy_secret` in `~/.jetbrains-central/config.json`, authentication and agent routing are performed at runtime using the `central` CLI:

* Authenticate with your JetBrains Account:
  ```bash
  central login
  ```
* Run an agent for a single session without modifying its configuration files (works even when the agent's config is a read-only Home Manager store symlink):
  ```bash
  central run codex -- "explain this code"
  ```
* Connect an agent permanently by updating its configuration file in place (requires the target agent's configuration file, such as `~/.codex/config.toml`, to be writable rather than a read-only Nix store symlink):
  ```bash
  central add codex
  ```
* Check authentication, proxy, and connected agent status:
  ```bash
  central status
  ```

### 4. Use the Package Directly

```nix
{ pkgs, inputs, ... }: {
  home.packages = [
    inputs.air-gateway.packages.${pkgs.stdenv.hostPlatform.system}.air-gateway
  ];
}
```

## Maintenance

The binary metadata (URLs and SHA-256 hashes) is stored in `metadata.json`.
To update to the latest version of Air Gateway, run the update command from the root repository:

```bash
nix run .#update-air-gateway
```

Alternatively, you can use the unified `.agents/skills/update-agent-flake` skill to automate this process.

## License

JetBrains Air Gateway (Central CLI) is proprietary software provided by JetBrains s.r.o. and governed by the [JetBrains Central CLI EAP User Agreement](https://www.jetbrains.com/legal/docs/terms/jetbrains-central-cli-eap/).

This Nix derivation is marked with `meta.license = licenses.unfree;`.
