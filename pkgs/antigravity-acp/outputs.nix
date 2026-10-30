{ self, nixpkgs, utils, ... }:

let
  metadata = builtins.fromJSON (builtins.readFile ./metadata.json);
  supportedSystems = builtins.attrNames metadata.systems;
in
utils.lib.eachSystem supportedSystems (system:
  let
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [ "antigravity-acp" ];
    };
    antigravityAcpPkg = import ./package.nix { inherit pkgs metadata; };
  in
  {
    packages = {
      antigravity-acp = antigravityAcpPkg;
      default = antigravityAcpPkg;
    };

    devShells.default = pkgs.mkShell {
      buildInputs = [ antigravityAcpPkg ];
    };
  }
) // {
  # Overlays
  overlays = rec {
    antigravity-acp = final: prev: {
      antigravity-acp = self.packages.${final.stdenv.hostPlatform.system}.antigravity-acp;
    };
    default = antigravity-acp;
  };

  # Home Manager Module
  homeManagerModules = rec {
    antigravity-acp = import ./module.nix { inherit self metadata; };
    default = antigravity-acp;
  };
}
