{ self, nixpkgs, utils, ... }:

let
  metadata = builtins.fromJSON (builtins.readFile ./metadata.json);
  supportedSystems = builtins.attrNames metadata.systems;
in
utils.lib.eachSystem supportedSystems (system:
  let
    pkgs = import nixpkgs { inherit system; };
    codexAcpPkg = import ./package.nix { inherit pkgs metadata; };
  in
  {
    packages = {
      codex-acp = codexAcpPkg;
      default = codexAcpPkg;
    };

    devShells.default = pkgs.mkShell {
      buildInputs = [ codexAcpPkg ];
    };
  }
) // {
  # Overlays
  overlays = rec {
    codex-acp = final: prev: {
      codex-acp = self.packages.${final.stdenv.hostPlatform.system}.codex-acp;
    };
    default = codex-acp;
  };

  # Home Manager Module
  homeManagerModules = rec {
    codex-acp = import ./module.nix { inherit self metadata; };
    default = codex-acp;
  };
}
