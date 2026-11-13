{ self, metadata ? builtins.fromJSON (builtins.readFile ./metadata.json) }:
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.antigravity-cli.acp;
  aliasCfg = config.programs.antigravity-acp;
  system = pkgs.stdenv.hostPlatform.system;
  defaultPkg = self.packages.${system}.antigravity-acp;
  basePkg =
    if aliasCfg.enable && aliasCfg.package != defaultPkg
    then aliasCfg.package
    else cfg.package;

  hasUpstreamAntigravityCli =
    (config.programs ? antigravity-cli)
    && (config.programs.antigravity-cli.enable or false)
    && ((config.programs.antigravity-cli.package or null) != null);

  defaultAgyPath =
    if hasUpstreamAntigravityCli
    then "${config.programs.antigravity-cli.package}/bin/agy"
    else (metadata.env.AGY_BIN or "agy");

  effectivePkg =
    if hasUpstreamAntigravityCli
    then
      pkgs.symlinkJoin {
        name = "${basePkg.pname or "antigravity-acp"}-wrapped-${basePkg.version or metadata.version}";
        paths = [ basePkg ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram "$out/bin/${metadata.command}" \
            --prefix PATH : "${lib.makeBinPath [ config.programs.antigravity-cli.package ]}" \
            --set-default AGY_BIN "${defaultAgyPath}"
        '';
      }
    else basePkg;

  systemArgs = metadata.systems.${system}.args or metadata.args or [ ];
  defaultEnv = (metadata.env or { }) // {
    ANTIGRAVITY_HARNESS_PATH = "${basePkg}/libexec/antigravity-acp/localharness_external";
    AGY_BIN = defaultAgyPath;
  };

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
  options.programs.antigravity-cli.acp = mkAcpOptions "ACP support for Google Antigravity CLI";
  options.programs.antigravity-acp = mkAcpOptions "Google Antigravity ACP companion";

  config = lib.mkIf (cfg.enable || aliasCfg.enable) {
    home.packages = [ effectivePkg ];
  };
}
