{ pkgs, metadata, ... }:

pkgs.stdenv.mkDerivation {
  pname = "cortex-code";
  version = metadata.version;

  src = pkgs.fetchurl {
    url = metadata.systems."${pkgs.stdenv.hostPlatform.system}".url;
    sha256 = metadata.systems."${pkgs.stdenv.hostPlatform.system}".sha256;
  };

  nativeBuildInputs = [ pkgs.makeWrapper ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/share/cortex-code
    cp -r * $out/share/cortex-code/

    # Handle NodeJS or Standalone binary distributions
    if [ -f "$out/share/cortex-code/dist/index.js" ]; then
      makeWrapper ${pkgs.nodejs}/bin/node $out/bin/cortex-code \
        --add-flags "$out/share/cortex-code/dist/index.js"
    elif [ -f "$out/share/cortex-code/cortex" ]; then
      chmod +x $out/share/cortex-code/cortex
      ln -s $out/share/cortex-code/cortex $out/bin/cortex-code
    else
      # Some versions might have a different binary name or structure
      BINARY=$(find . -maxdepth 1 -type f -executable | head -n 1)
      if [ -n "$BINARY" ]; then
        cp "$BINARY" $out/bin/cortex-code
      else
        echo "Error: Could not determine Cortex Code binary format"
        ls -R
        exit 1
      fi
    fi

    # Provide coco alias symlink
    ln -s $out/bin/cortex-code $out/bin/coco
    runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "Snowflake Cortex Code Agent CLI (coco)";
    homepage = "https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli";
    license = licenses.unfree;
    platforms = builtins.attrNames metadata.systems;
    mainProgram = "cortex-code";
  };
}
