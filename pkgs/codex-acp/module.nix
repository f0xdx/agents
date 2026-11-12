{ self, metadata ? builtins.fromJSON (builtins.readFile ./metadata.json) }:
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.codex.acp;
  aliasCfg = config.programs.codex-acp;
  system = pkgs.stdenv.hostPlatform.system;
  defaultPkg = self.packages.${system}.codex-acp;
  effectivePkg =
    if aliasCfg.enable && aliasCfg.package != defaultPkg
    then aliasCfg.package
    else cfg.package;
  hasUpstreamCodex =
    (config.programs ? codex)
    && (config.programs.codex.enable or false)
    && ((config.programs.codex.package or null) != null);
  defaultCodexPath =
    if hasUpstreamCodex
    then "${config.programs.codex.package}/bin/codex"
    else (metadata.env.CODEX_PATH or "codex");
  defaultEnv = (metadata.env or { }) // {
    CODEX_PATH = defaultCodexPath;
  };

  mkAcpOptions = descriptionPrefix: {
    enable = lib.mkEnableOption "${descriptionPrefix} (OpenAI Codex ACP bridge)";

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPkg;
      description = "The codex-acp bridge package to use.";
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
      default = metadata.args or [ ];
      description = "Command-line arguments required to start OpenAI Codex ACP server.";
    };

    env = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      readOnly = true;
      default = defaultEnv;
      description = "Environment variables required to start OpenAI Codex ACP server.";
    };
  };
in
{
  options.programs.codex.acp = mkAcpOptions "ACP support for OpenAI Codex";
  options.programs.codex-acp = mkAcpOptions "OpenAI Codex ACP companion";

  config = lib.mkIf (cfg.enable || aliasCfg.enable) {
    home.packages = [ effectivePkg ];
  };
}
