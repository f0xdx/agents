{
  description = "Agent Flakes Collection and Management Tools";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils }@inputs:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      junieOutputs = import ./pkgs/junie/outputs.nix inputs;
      cortexCodeOutputs = import ./pkgs/cortex-code/outputs.nix inputs;
      airGatewayOutputs = import ./pkgs/air-gateway/outputs.nix inputs;
      antigravityAcpOutputs = import ./pkgs/antigravity-acp/outputs.nix inputs;
    in
    utils.lib.eachSystem supportedSystems (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [ "junie" "cortex-code" "air-gateway" "antigravity-acp" ];
        };

        updateRuntimeInputs = with pkgs; [
          jq
          curl
          nix
          git
          coreutils
          gnused
        ];

        mkUpdateApp = name: description: scriptBody: {
          type = "app";
          meta = { inherit description; };
          program = "${pkgs.writeShellApplication {
            inherit name;
            runtimeInputs = updateRuntimeInputs;
            text = ''
              REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
              cd "$REPO_ROOT"
              ${scriptBody}
            '';
          }}/bin/${name}";
        };
      in
      {
        # Aggregate packages from shared sub-flake outputs
        packages = {
          junie = junieOutputs.packages.${system}.junie;
          cortex-code = cortexCodeOutputs.packages.${system}.cortex-code;
          air-gateway = airGatewayOutputs.packages.${system}.air-gateway;
          antigravity-acp = antigravityAcpOutputs.packages.${system}.antigravity-acp;
          default = junieOutputs.packages.${system}.junie;
        };

        # Aggregated devShell with repository management tools
        devShells.default = pkgs.mkShell {
          name = "flakes-management-shell";
          buildInputs = updateRuntimeInputs;

          shellHook = ''
            echo "Nix Flakes Management Shell"
            echo "Available commands: nix run .#update-flakes, nix run .#update-junie, nix run .#update-cortex-code, nix run .#update-air-gateway, nix run .#update-antigravity-acp"
          '';
        };

        # Apps for management tasks
        apps = {
          update-flakes = mkUpdateApp "update-flakes" "Update all agent flakes and lockfiles" ''
            echo "Updating all flakes..."
            bash scripts/update_junie.sh
            bash scripts/update_cortex_code.sh
            bash scripts/update_air_gateway.sh
            bash scripts/update_antigravity_acp.sh
            echo "All flakes updated."
          '';

          update-junie = mkUpdateApp "update-junie" "Update the Junie agent flake metadata and locks" ''
            exec bash scripts/update_junie.sh
          '';

          update-cortex-code = mkUpdateApp "update-cortex-code" "Update the Cortex Code agent flake metadata and locks" ''
            exec bash scripts/update_cortex_code.sh
          '';

          update-air-gateway = mkUpdateApp "update-air-gateway" "Update the Air Gateway (Central CLI) flake metadata and locks" ''
            exec bash scripts/update_air_gateway.sh
          '';

          update-antigravity-acp = mkUpdateApp "update-antigravity-acp" "Update the Google Antigravity ACP flake metadata and locks" ''
            exec bash scripts/update_antigravity_acp.sh
          '';
        };
      }
    ) // {
      # Aggregate Home Manager modules from shared sub-flake outputs
      homeManagerModules = {
        junie = junieOutputs.homeManagerModules.junie;
        cortex-code = cortexCodeOutputs.homeManagerModules.cortex-code;
        air-gateway = airGatewayOutputs.homeManagerModules.air-gateway;
        antigravity-acp = antigravityAcpOutputs.homeManagerModules.antigravity-acp;
      };

      # Aggregate Overlays from shared sub-flake outputs
      overlays = rec {
        junie = junieOutputs.overlays.junie;
        cortex-code = cortexCodeOutputs.overlays.cortex-code;
        air-gateway = airGatewayOutputs.overlays.air-gateway;
        antigravity-acp = antigravityAcpOutputs.overlays.antigravity-acp;
        default = final: prev:
          (junie final prev)
          // (cortex-code final prev)
          // (air-gateway final prev)
          // (antigravity-acp final prev);
      };
    };
}
