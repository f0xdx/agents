{ self, nixpkgs, utils, ... }:

let
  metadata = builtins.fromJSON (builtins.readFile ./metadata.json);
  supportedSystems = builtins.attrNames metadata.systems;
in
utils.lib.eachSystem supportedSystems (system:
  let
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [ "cortex-code" ];
    };
    cortexCodePkg = import ./package.nix { inherit pkgs metadata; };
  in
  {
    packages = {
      cortex-code = cortexCodePkg;
      default = cortexCodePkg;
    };

    devShells.default = pkgs.mkShell {
      buildInputs = [ cortexCodePkg ];
    };
  }
) // {
  # Overlays
  overlays = rec {
    cortex-code = final: prev: {
      cortex-code = self.packages.${final.stdenv.hostPlatform.system}.cortex-code;
      coco = final.cortex-code;
    };
    default = cortex-code;
  };

  # Home Manager Module
  homeManagerModules = rec {
    cortex-code = import ./module.nix { inherit self metadata; };
    default = cortex-code;
  };
}
