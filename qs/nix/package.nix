{
  lib,
  stdenvNoCC,
  makeWrapper,
  quickshell,
  bash,
  coreutils,
  curl,
  fd,
  gnugrep,
  iproute2,
  matugen,
  networkmanager,
  niri,
  pipewire,
  poppler-utils,
  systemd,
  wl-clipboard,
  xdg-utils,
  meter-helper,
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
      --suffix PATH : ${lib.makeBinPath [ bash coreutils curl fd gnugrep iproute2 matugen networkmanager niri pipewire poppler-utils systemd wl-clipboard xdg-utils meter-helper ]}

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
