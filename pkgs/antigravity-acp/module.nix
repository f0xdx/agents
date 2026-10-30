{ self, metadata ? builtins.fromJSON (builtins.readFile ./metadata.json) }:
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.antigravity.acp;
  aliasCfg = config.programs.antigravity-acp;
  system = pkgs.stdenv.hostPlatform.system;
  defaultPkg = self.packages.${system}.antigravity-acp;
  effectivePkg =
    if aliasCfg.enable && aliasCfg.package != defaultPkg
    then aliasCfg.package
    else cfg.package;
  systemArgs = metadata.systems.${system}.args or metadata.args or [ ];
  defaultEnv = {
    ANTIGRAVITY_HARNESS_PATH = "${effectivePkg}/libexec/antigravity-acp/localharness_external";
  } // (metadata.env or { });

  mkAcpOptions = descriptionPrefix: {
    enable = lib.mkEnableOption "${descriptionPrefix} (Google Antigravity ACP bridge)";

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPkg;
      description = "The antigravity-acp bridge package to use.";
    };

    command = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "${effectivePkg}/bin/${metadata.command}";
      description = "Resolved ACP server command path for downstream ACP clients.";
    };

    args = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      default = systemArgs;
      description = "Command-line arguments required to start Google Antigravity ACP server.";
    };

    env = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      default = defaultEnv;
      description = "Environment variables required to start Google Antigravity ACP server.";
    };
  };
in
{
  options.programs.antigravity.acp = mkAcpOptions "ACP support for Google Antigravity";
  options.programs.antigravity-acp = mkAcpOptions "Google Antigravity ACP companion";

  config = lib.mkIf (cfg.enable || aliasCfg.enable) {
    home.packages = [ effectivePkg ];
  };
}
