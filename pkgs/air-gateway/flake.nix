{
  description = "A standalone flake for JetBrains Air Gateway (Central CLI)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs: import ./outputs.nix inputs;
}
