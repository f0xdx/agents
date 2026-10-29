{ self, metadata ? builtins.fromJSON (builtins.readFile ./metadata.json) }:
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.cortex-code;
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
  options.programs.cortex-code = {
    enable = lib.mkEnableOption "Snowflake Cortex Code CLI agent (coco)";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${system}.cortex-code;
      description = "The cortex-code package to use.";
    };

    settings = lib.mkOption {
      type = jsonFormat.type;
      default = { };
      description = "Configuration written to ~/.snowflake/cortex/settings.json.";
    };

    acp = {
      enable = lib.mkEnableOption "ACP (Agent Client Protocol) support for Cortex Code";

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
        description = "Command-line arguments required to start Cortex Code in ACP mode.";
      };

      env = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        readOnly = true;
        default = acpMeta.env or { };
        description = "Environment variables required to start Cortex Code in ACP mode.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ]
      ++ lib.optional (cfg.acp.enable && isExternalAcp) acpPackage;

    home.file.".snowflake/cortex/settings.json" = lib.mkIf (cfg.settings != { }) {
      source = jsonFormat.generate "cortex-code-settings.json" cfg.settings;
    };
  };
}
