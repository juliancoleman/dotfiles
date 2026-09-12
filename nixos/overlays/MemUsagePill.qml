import QtQuick
import qs.Common
import qs.Services
import qs.Modules.ControlCenter.Widgets

CompoundPill {
    id: root

    iconName: "developer_board"

    readonly property real usage: DgopService.memoryUsage || 0

    isActive: DgopService.dgopAvailable && usage > 0

    primaryText: I18n.tr("Memory")

    secondaryText: {
        if (!DgopService.dgopAvailable)
            return I18n.tr("dgop not available");
        if (DgopService.totalMemoryKB <= 0)
            return "--";
        return `${DgopService.formatSystemMemory(DgopService.usedMemoryKB)} / ${DgopService.formatSystemMemory(DgopService.totalMemoryKB)} (${usage.toFixed(0)}%)`;
    }

    iconColor: {
        if (!DgopService.dgopAvailable)
            return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5);
        if (usage > 90)
            return Theme.error;
        if (usage > 75)
            return Theme.warning;
        return Theme.surfaceText;
    }

    Component.onCompleted: {
        DgopService.addRef(["memory"]);
    }
    Component.onDestruction: {
        DgopService.removeRef(["memory"]);
    }

    onToggled: {
        expandClicked();
    }
}
