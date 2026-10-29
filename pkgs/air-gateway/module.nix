{ self, metadata ? builtins.fromJSON (builtins.readFile ./metadata.json) }:
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.air-gateway;
  jsonFormat = pkgs.formats.json { };
  system = pkgs.stdenv.hostPlatform.system;
  effectiveSettings = {
    release_track = cfg.package.version;
  } // cfg.settings;
  settingsFile = jsonFormat.generate "air-gateway-settings.json" effectiveSettings;
in
{
  options.programs.air-gateway = {
    enable = lib.mkEnableOption "JetBrains Air Gateway (Central CLI)";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${system}.air-gateway;
      description = "The air-gateway package to use.";
    };

    settings = lib.mkOption {
      type = jsonFormat.type;
      default = { };
      description = ''
        User-configurable settings merged into ~/.jetbrains-central/config.json.
        Supported keys include proxy_port, log_level, release_track, jumpscare-mode,
        approve-all-policies, and google_analytics_accepted.
        Runtime state written by central (such as proxy_secret and ai_access) is preserved.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    home.activation.airGatewayConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      CONFIG_DIR="$HOME/.jetbrains-central"
      CONFIG_FILE="$CONFIG_DIR/config.json"
      $DRY_RUN_CMD mkdir -p "$CONFIG_DIR"
      if [ -L "$CONFIG_FILE" ]; then
        $DRY_RUN_CMD rm -f "$CONFIG_FILE"
      fi
      if [ -f "$CONFIG_FILE" ]; then
        if [ -z "''${DRY_RUN:-}" ]; then
          TMP_FILE=$(mktemp "$CONFIG_DIR/.config.json.XXXXXX")
          if ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$CONFIG_FILE" "${settingsFile}" > "$TMP_FILE" 2>/dev/null; then
            chmod 600 "$TMP_FILE"
            mv -f "$TMP_FILE" "$CONFIG_FILE"
          else
            rm -f "$TMP_FILE"
            cp "${settingsFile}" "$CONFIG_FILE"
            chmod 600 "$CONFIG_FILE"
          fi
        fi
      else
        $DRY_RUN_CMD cp "${settingsFile}" "$CONFIG_FILE"
        $DRY_RUN_CMD chmod 600 "$CONFIG_FILE"
      fi
    '';
  };
}
