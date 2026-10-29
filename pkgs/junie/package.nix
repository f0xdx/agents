{ pkgs, metadata, ... }:

pkgs.stdenv.mkDerivation {
  pname = "junie";
  version = metadata.version;

  src = pkgs.fetchurl {
    url = metadata.systems."${pkgs.stdenv.hostPlatform.system}".url;
    sha256 = metadata.systems."${pkgs.stdenv.hostPlatform.system}".sha256;
  };

  nativeBuildInputs = [ pkgs.unzip pkgs.makeWrapper ];

  sourceRoot = ".";

  dontConfigure = true;
  dontBuild = true;

  # Note: stdenv automatically unzips if unzip is in nativeBuildInputs
  # and the file ends in .zip. But we need to handle the nested structure.

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    
    # Replicate search logic from install.sh shim and ACP registry archive layout
    if [ -d "Applications/junie.app" ]; then
      # macOS app bundle (found in Applications subfolder)
      mkdir -p $out/Applications
      cp -r Applications/junie.app $out/Applications/
      BINARY="$out/Applications/junie.app/Contents/MacOS/junie"
    elif [ -d "junie.app" ]; then
      # macOS app bundle (found in current folder)
      mkdir -p $out/Applications
      cp -r junie.app $out/Applications/
      BINARY="$out/Applications/junie.app/Contents/MacOS/junie"
    elif [ -f "junie-app/bin/junie" ]; then
      # Linux package structure (newer releases)
      mkdir -p $out/share
      cp -r junie-app $out/share/junie
      BINARY="$out/share/junie/bin/junie"
    elif [ -f "junie/bin/junie" ]; then
      # Linux package structure
      mkdir -p $out/share
      cp -r junie $out/share/junie
      BINARY="$out/share/junie/bin/junie"
    elif [ -f "junie" ]; then
      # Direct binary
      mkdir -p $out/bin
      cp junie $out/bin/.junie-real
      chmod +x $out/bin/.junie-real
      BINARY="$out/bin/.junie-real"
    else
      echo "Error: Could not find junie binary in archive"
      ls -R
      exit 1
    fi
    
    # Wrap the binary to set necessary environment variables
    # Based on install.sh shim: EJ_RUNNER_PWD and JUNIE_DATA
    makeWrapper "$BINARY" "$out/bin/junie" \
      --run 'export JUNIE_DATA="''${JUNIE_DATA:-$HOME/.local/share/junie}"' \
      --run 'export EJ_RUNNER_PWD="''${EJ_RUNNER_PWD:-$(pwd)}"'
    runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "Junie CLI Agent by JetBrains";
    homepage = "https://junie.jetbrains.com";
    license = licenses.unfree;
    platforms = builtins.attrNames metadata.systems;
    mainProgram = "junie";
  };
}
