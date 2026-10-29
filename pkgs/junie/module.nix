{ self, metadata ? builtins.fromJSON (builtins.readFile ./metadata.json) }:
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.junie;
  jsonFormat = pkgs.formats.json { };
  system = pkgs.stdenv.hostPlatform.system;
  acpMeta = metadata.acp;
  isExternalAcp = (acpMeta.mode or "internal") == "external";
  acpPackage =
    if isExternalAcp
    then import ./acp.nix { inherit pkgs metadata; }
    else cfg.package;
in
{
  options.programs.junie = {
    enable = lib.mkEnableOption "Junie CLI agent";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${system}.junie;
      description = "The junie package to use.";
    };

    settings = lib.mkOption {
      type = jsonFormat.type;
      default = { };
      description = "Configuration written to ~/.junie/config.json.";
    };

    acp = {
      enable = lib.mkEnableOption "ACP (Agent Client Protocol) support for Junie";

      command = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        default = "${acpPackage}/bin/${acpMeta.command}";
        description = "Resolved ACP server command path for downstream ACP clients.";
      };

      args = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        readOnly = true;
        default = acpMeta.args or [ ];
        description = "Command-line arguments required to start Junie in ACP mode.";
      };

      env = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        readOnly = true;
        default = acpMeta.env or { };
        description = "Environment variables required to start Junie in ACP mode.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ]
      ++ lib.optional (cfg.acp.enable && isExternalAcp) acpPackage;

    home.file.".junie/config.json" = lib.mkIf (cfg.settings != { }) {
      source = jsonFormat.generate "junie-config.json" cfg.settings;
    };
  };
}
