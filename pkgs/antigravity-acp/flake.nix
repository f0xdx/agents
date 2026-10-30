{
  description = "A standalone flake for the Google Antigravity ACP Server bridge";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs: import ./outputs.nix inputs;
}
