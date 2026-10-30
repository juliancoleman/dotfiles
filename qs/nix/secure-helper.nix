{
  lib,
  rustPlatform,
}:

rustPlatform.buildRustPackage {
  pname = "qs-secure-helper";
  version = "0.1.0";
  src = lib.cleanSource ../secure-helper;
  cargoLock.lockFile = ../secure-helper/Cargo.lock;

  postInstall = ''
    ln -s qs-secret $out/bin/qs-askpass
    ln -s qs-secret $out/bin/pinentry-qs
  '';

  meta = {
    description = "askpass and pinentry front ends for the QS secure prompt";
    platforms = lib.platforms.linux;
    mainProgram = "pinentry-qs";
  };
}
