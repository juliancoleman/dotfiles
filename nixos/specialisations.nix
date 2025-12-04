{ config, pkgs, ... }:

{
  specialisation = {
    nvidia = {
      configuration = {
      	services.xserver.videoDrivers = [ "nvidia" ];
	hardware.nvidia = {
	  modesetting.enable = true;
	  open = false; # use proprietary drivers this time
	  package = config.boot.kernelPackages.nvidiaPackages.stable;
	  nvidiaSettings = true; # provides nvidia-smi
	};
	hardware.opengl.enable = true;

	environment.sessionVariables = {
	  GBM_BACKEND = "nvidia-drm";
	  __GLX_VENDOR_LIBRARY_NAME = "nvidia";
	  WLR_NO_HARDWARE_CURSORS = "1";
	  XDG_SESSION_TYPE = "wayland";
	  NIXOS_OZONE_WL = "1";
        };
      };
    };
  };
}
