# Hide Niri's trailing empty unnamed workspace in DMS.
# Hide the DankDash "Wallpapers" tab (hardcoded in upstream QML).
final: prev: {
  dms-shell = prev.dms-shell.overrideAttrs (old: {
    postInstall =
      (old.postInstall or "")
      + ''
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
        cp ${./DankDashPopout.qml} "$out/share/quickshell/dms/Modules/DankDash/DankDashPopout.qml"
      '';
  });
}
