{ pkgs, metadata, ... }:

pkgs.stdenv.mkDerivation {
  pname = "codex-acp";
  version = metadata.version;

  src = pkgs.fetchurl {
    url = metadata.distribution.tarball;
    sha256 = metadata.distribution.sha256;
  };

  nativeBuildInputs = [ pkgs.makeWrapper ];

  sourceRoot = "package";

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/libexec/codex-acp

    cp -r dist package.json LICENSE README.md $out/libexec/codex-acp/

    makeWrapper "${pkgs.nodejs}/bin/node" "$out/bin/codex-acp" \
      --add-flags "$out/libexec/codex-acp/dist/index.js" \
      --set-default CODEX_PATH "codex"

    runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "ACP (Agent Client Protocol) adapter for OpenAI Codex";
    homepage = "https://github.com/agentclientprotocol/codex-acp";
    license = licenses.asl20;
    platforms = builtins.attrNames metadata.systems;
    mainProgram = "codex-acp";
  };
}
