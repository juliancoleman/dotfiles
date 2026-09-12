import QtQuick
import qs.Common
import qs.Services
import qs.Modules.ControlCenter.Widgets

CompoundPill {
    id: root

    iconName: "memory"

    readonly property real usage: DgopService.cpuUsage || 0

    isActive: DgopService.dgopAvailable && usage > 0

    primaryText: I18n.tr("CPU")

    secondaryText: {
        if (!DgopService.dgopAvailable)
            return I18n.tr("dgop not available");
        if (usage === 0)
            return "--";
        const temp = DgopService.cpuTemperature > 0 ? ("  " + DgopService.cpuTemperature.toFixed(0) + "C") : "";
        return usage.toFixed(0) + "%" + temp;
    }

    iconColor: {
        if (!DgopService.dgopAvailable)
            return Qt.rgba(Theme.surfaceText.r, Theme.surfaceText.g, Theme.surfaceText.b, 0.5);
        if (usage > 80)
            return Theme.error;
        if (usage > 60)
            return Theme.warning;
        return Theme.surfaceText;
    }

    Component.onCompleted: {
        DgopService.addRef(["cpu"]);
    }
    Component.onDestruction: {
        DgopService.removeRef(["cpu"]);
    }

    onToggled: {
        expandClicked();
    }
}
