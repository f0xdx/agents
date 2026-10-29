{ self, nixpkgs, utils, ... }:

let
  metadata = builtins.fromJSON (builtins.readFile ./metadata.json);
  supportedSystems = builtins.attrNames metadata.systems;
in
utils.lib.eachSystem supportedSystems (system:
  let
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [ "air-gateway" ];
    };
    airGatewayPkg = import ./package.nix { inherit pkgs metadata; };
  in
  {
    packages = {
      air-gateway = airGatewayPkg;
      default = airGatewayPkg;
    };

    devShells.default = pkgs.mkShell {
      buildInputs = [ airGatewayPkg ];
    };
  }
) // {
  # Overlays
  overlays = rec {
    air-gateway = final: prev: {
      air-gateway = self.packages.${final.stdenv.hostPlatform.system}.air-gateway;
      central = final.air-gateway;
    };
    default = air-gateway;
  };

  # Home Manager Module
  homeManagerModules = rec {
    air-gateway = import ./module.nix { inherit self metadata; };
    default = air-gateway;
  };
}
