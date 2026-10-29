{
  description = "A standalone flake for the junie agent CLI";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs: import ./outputs.nix inputs;
}
