{ self, nixpkgs, utils, ... }:

let
  metadata = builtins.fromJSON (builtins.readFile ./metadata.json);
  supportedSystems = builtins.attrNames metadata.systems;
in
utils.lib.eachSystem supportedSystems (system:
  let
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [ "junie" ];
    };
    juniePkg = import ./package.nix { inherit pkgs metadata; };
  in
  {
    packages = {
      junie = juniePkg;
      default = juniePkg;
    };

    devShells.default = pkgs.mkShell {
      buildInputs = [ juniePkg ];
    };
  }
) // {
  # Overlays
  overlays = rec {
    junie = final: prev: {
      junie = self.packages.${final.stdenv.hostPlatform.system}.junie;
    };
    default = junie;
  };

  # Home Manager Module
  homeManagerModules = rec {
    junie = import ./module.nix { inherit self metadata; };
    default = junie;
  };
}
