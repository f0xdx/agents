{ pkgs, metadata, ... }:

pkgs.stdenv.mkDerivation {
  pname = "air-gateway";
  version = metadata.version;

  src = pkgs.fetchurl {
    url = metadata.systems."${pkgs.stdenv.hostPlatform.system}".url;
    sha256 = metadata.systems."${pkgs.stdenv.hostPlatform.system}".sha256;
  };

  sourceRoot = ".";

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin

    BINARY=$(find . -name "central" -type f | head -n 1)
    if [ -z "$BINARY" ]; then
      echo "Error: Could not find central binary in archive"
      ls -R
      exit 1
    fi

    cp "$BINARY" $out/bin/central
    chmod +x $out/bin/central

    # Provide air-gateway convenience symlink
    ln -s $out/bin/central $out/bin/air-gateway
    runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "JetBrains Air Gateway (Central CLI) for connecting coding agents to JetBrains AI";
    homepage = "https://www.jetbrains.com/air/gateway/";
    license = licenses.unfree;
    platforms = builtins.attrNames metadata.systems;
    mainProgram = "central";
  };
}
