# Hide Niri's trailing empty unnamed workspace in DMS.
# Hide the DankDash "Wallpapers" tab (hardcoded in upstream QML).
# Put dgop + fanctl + gpustat on dms PATH so CPU/RAM/disk/fan/GPU widgets can poll.
final: prev:
let
  dms-fanctl = prev.writeShellScriptBin "dms-fanctl" (builtins.readFile ./fanctl.sh);
  dms-gpustat = prev.writeShellScriptBin "dms-gpustat" (builtins.readFile ./gpustat.sh);
in {
  dms-shell = prev.dms-shell.overrideAttrs (old: {
    postInstall =
      (old.postInstall or "")
      + ''
        wrapProgram $out/bin/dms --prefix PATH : ${prev.lib.makeBinPath [ prev.dgop prev.util-linux dms-fanctl dms-gpustat ]}

        ws="$out/share/quickshell/dms/Modules/DankBar/Widgets/WorkspaceSwitcher.qml"
        substituteInPlace "$ws" \
          --replace-fail \
          "        workspaces = workspaces.slice().sort((a, b) => a.idx - b.idx);" \
          "        workspaces = workspaces.slice().sort((a, b) => a.idx - b.idx);
        workspaces = workspaces.filter(ws => (ws.name && ws.name !== \"\") || ws.is_active || (NiriService.windows?.some(win => win.workspace_id === ws.id) ?? false));"

        substituteInPlace "$ws" \
          --replace-fail \
          "                    return Theme.withAlpha(Theme.surfaceText, opacity);" \
          "                    return Qt.rgba(0.894, 0.914, 0.941, opacity);"

        pill="$out/share/quickshell/dms/Modules/Plugins/BasePill.qml"
        substituteInPlace "$pill" \
          --replace-fail \
          "                    return Theme.withAlpha(Theme.surfaceText, opacity);" \
          "                    return Qt.rgba(0.894, 0.914, 0.941, opacity);"

        chmod +w "$out/share/quickshell/dms/Modules/DankDash/DankDashPopout.qml"
        chmod +w "$out/share/quickshell/dms/Modules/DankBar/Widgets/DiskUsage.qml"
        chmod +w "$out/share/quickshell/dms/Modules/ProcessList/DisksView.qml"
        chmod +w "$out/share/quickshell/dms/Modules/ControlCenter/Models/WidgetModel.qml"
        chmod +w "$out/share/quickshell/dms/Modules/ControlCenter/Components/DragDropGrid.qml"
        chmod +w "$out/share/quickshell/dms/Modules/ControlCenter/Components/DetailHost.qml"
        chmod +w "$out/share/quickshell/dms/Modules/ControlCenter/Components/DragDropDetailHost.qml"
        chmod +w "$out/share/quickshell/dms/Modules/ControlCenter/Widgets"
        chmod +w "$out/share/quickshell/dms/Modules/ControlCenter/Details"
        chmod +w "$out/share/quickshell/dms/Modules/ControlCenter/Details/DiskUsageDetail.qml"
        chmod +w "$out/share/quickshell/dms/Modules/ControlCenter/Widgets/DiskUsagePill.qml"
        chmod +w "$out/share/quickshell/dms/Modules/ControlCenter/ControlCenterPopout.qml"
        cp ${./DankDashPopout.qml} "$out/share/quickshell/dms/Modules/DankDash/DankDashPopout.qml"
        cp ${./DiskUsage.qml} "$out/share/quickshell/dms/Modules/DankBar/Widgets/DiskUsage.qml"
        cp ${./DisksView.qml} "$out/share/quickshell/dms/Modules/ProcessList/DisksView.qml"
        cp ${./WidgetModel.qml} "$out/share/quickshell/dms/Modules/ControlCenter/Models/WidgetModel.qml"
        cp ${./DragDropGrid.qml} "$out/share/quickshell/dms/Modules/ControlCenter/Components/DragDropGrid.qml"
        cp ${./DetailHost.qml} "$out/share/quickshell/dms/Modules/ControlCenter/Components/DetailHost.qml"
        cp ${./DragDropDetailHost.qml} "$out/share/quickshell/dms/Modules/ControlCenter/Components/DragDropDetailHost.qml"
        cp ${./CpuUsagePill.qml} "$out/share/quickshell/dms/Modules/ControlCenter/Widgets/CpuUsagePill.qml"
        cp ${./MemUsagePill.qml} "$out/share/quickshell/dms/Modules/ControlCenter/Widgets/MemUsagePill.qml"
        cp ${./SmallCpuUsageButton.qml} "$out/share/quickshell/dms/Modules/ControlCenter/Widgets/SmallCpuUsageButton.qml"
        cp ${./SmallMemUsageButton.qml} "$out/share/quickshell/dms/Modules/ControlCenter/Widgets/SmallMemUsageButton.qml"
        cp ${./CpuUsageDetail.qml} "$out/share/quickshell/dms/Modules/ControlCenter/Details/CpuUsageDetail.qml"
        cp ${./MemUsageDetail.qml} "$out/share/quickshell/dms/Modules/ControlCenter/Details/MemUsageDetail.qml"
        cp ${./ControlCenterPopout.qml} "$out/share/quickshell/dms/Modules/ControlCenter/ControlCenterPopout.qml"
        cp ${./DiskUsageDetail.qml} "$out/share/quickshell/dms/Modules/ControlCenter/Details/DiskUsageDetail.qml"
        cp ${./DiskUsagePill.qml} "$out/share/quickshell/dms/Modules/ControlCenter/Widgets/DiskUsagePill.qml"
        cp ${./FanControlPill.qml} "$out/share/quickshell/dms/Modules/ControlCenter/Widgets/FanControlPill.qml"
        cp ${./SmallFanControlButton.qml} "$out/share/quickshell/dms/Modules/ControlCenter/Widgets/SmallFanControlButton.qml"
        cp ${./FanControlDetail.qml} "$out/share/quickshell/dms/Modules/ControlCenter/Details/FanControlDetail.qml"
        cp ${./GpuUsagePill.qml} "$out/share/quickshell/dms/Modules/ControlCenter/Widgets/GpuUsagePill.qml"
        cp ${./SmallGpuUsageButton.qml} "$out/share/quickshell/dms/Modules/ControlCenter/Widgets/SmallGpuUsageButton.qml"
        cp ${./GpuUsageDetail.qml} "$out/share/quickshell/dms/Modules/ControlCenter/Details/GpuUsageDetail.qml"
      '';
  });
}
