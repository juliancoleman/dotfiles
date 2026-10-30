{
  lib,
  rustPlatform,
}:

rustPlatform.buildRustPackage {
  pname = "qs-fan-helper";
  version = "0.2.0";
  src = lib.cleanSource ../fan-helper;
  cargoLock.lockFile = ../fan-helper/Cargo.lock;

  meta = {
    description = "Fail-safe fan control helper for the QS shell";
    platforms = lib.platforms.linux;
    mainProgram = "qs-fan-helper";
  };
}
