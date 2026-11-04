pragma Singleton

import QtQuick
import "ja.js" as Ja

// Quickshell can't install a QTranslator from QML, so qsTr can't retranslate live; tr() reads `locale`
// instead, which makes every binding that calls it re-evaluate when the locale changes.
QtObject {
    // Mirrors ClockConfig.locale ("en" | "jp"), as Theme mirrors the motion settings, so Common needn't
    // import the shell module that imports it.
    property string locale: "en"
    readonly property bool japanese: locale === "jp"
    // "jp" isn't a Qt locale name; this is the one to hand Qt.locale() for day, month, and number formatting.
    readonly property string qtLocale: japanese ? "ja_JP" : "en_US"

    // Keyed by the exact English source, so .arg() placeholders survive; a missing key falls back to English.
    function tr(text) {
        return japanese && Ja.strings.hasOwnProperty(text) ? Ja.strings[text] : text
    }

    // A wall-clock time the way the locale says it: "9 PM" or 午後9時, "9:30 PM" or 午後9:30. A 24-hour clock
    // drops the period; a bare Japanese hour still takes its 時, which English leaves off.
    function timeOfDay(hours, minutes, use24Hour, withMinutes) {
        const pad = n => (n < 10 ? "0" : "") + n
        if (use24Hour)
            return withMinutes ? pad(hours) + ":" + pad(minutes) : japanese ? hours + "時" : pad(hours)
        // Japanese counts 午前0時 to 午後11時; English counts 12 AM to 11 PM.
        const shown = japanese ? hours % 12 : hours % 12 || 12
        const time = withMinutes ? shown + ":" + pad(minutes) : japanese ? shown + "時" : String(shown)
        if (japanese)
            return (hours < 12 ? "午前" : "午後") + time
        return time + (hours < 12 ? " AM" : " PM")
    }
}
