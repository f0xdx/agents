{ pkgs, metadata, ... }:

pkgs.stdenv.mkDerivation {
  pname = "antigravity-acp";
  version = metadata.version;

  src = pkgs.fetchurl {
    url = metadata.systems."${pkgs.stdenv.hostPlatform.system}".url;
    sha256 = metadata.systems."${pkgs.stdenv.hostPlatform.system}".sha256;
  };

  nativeBuildInputs = [ pkgs.unzip pkgs.makeWrapper ];

  sourceRoot = ".";

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/libexec/antigravity-acp

    SERVER_BIN=$(find . -name "agy_acp_server.par" -type f | head -n 1)
    HARNESS_BIN=$(find . -name "localharness_external" -type f | head -n 1)

    if [ -z "$SERVER_BIN" ]; then
      echo "Error: Could not find agy_acp_server.par in archive"
      ls -R
      exit 1
    fi

    cp "$SERVER_BIN" $out/libexec/antigravity-acp/agy_acp_server.par
    chmod +x $out/libexec/antigravity-acp/agy_acp_server.par

    if [ -n "$HARNESS_BIN" ]; then
      cp "$HARNESS_BIN" $out/libexec/antigravity-acp/localharness_external
      chmod +x $out/libexec/antigravity-acp/localharness_external
    fi

    makeWrapper "$out/libexec/antigravity-acp/agy_acp_server.par" "$out/bin/agy_acp_server.par" \
      --set-default ANTIGRAVITY_HARNESS_PATH "$out/libexec/antigravity-acp/localharness_external" \
      --set-default AGY_BIN "agy"

    # Provide antigravity-acp convenience symlink
    ln -s $out/bin/agy_acp_server.par $out/bin/antigravity-acp
    runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "Google Antigravity ACP (Agent Client Protocol) Server";
    homepage = "https://antigravity.google/docs/ide/extensions";
    license = licenses.unfree;
    platforms = builtins.attrNames metadata.systems;
    mainProgram = "agy_acp_server.par";
  };
}
