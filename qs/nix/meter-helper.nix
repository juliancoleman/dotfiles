{
  lib,
  rustPlatform,
}:

rustPlatform.buildRustPackage {
  pname = "qs-meter-helper";
  version = "0.1.0";
  src = lib.cleanSource ../meter-helper;
  cargoLock.lockFile = ../meter-helper/Cargo.lock;

  meta = {
    description = "Peak/RMS lines from raw PCM for the QS shell's level meters";
    platforms = lib.platforms.linux;
    mainProgram = "qs-meter";
  };
}
