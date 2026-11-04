{
  lib,
  stdenvNoCC,
  makeWrapper,
  quickshell,
  fd,
  iproute2,
  networkmanager,
  poppler-utils,
  wl-clipboard,
  xdg-utils,
}:

stdenvNoCC.mkDerivation {
  pname = "qs";
  version = "0.1.0";
  src = lib.cleanSource ../.;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/qs/config" "$out/bin"
    cp -R qml/shell "$out/share/qs/shell"
    install -m 0444 config/default.json "$out/share/qs/config/default.json"

    makeWrapper ${lib.getExe quickshell} "$out/bin/qs-shell" \
      --add-flags "-p $out/share/qs/shell" \
      --suffix PATH : ${lib.makeBinPath [ fd iproute2 networkmanager poppler-utils wl-clipboard xdg-utils ]}

    runHook postInstall
  '';

  meta = {
    description = "Quickshell-based desktop shell";
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    mainProgram = "qs-shell";
  };
}
