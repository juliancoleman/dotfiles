import QtQuick
import QtQuick.Shapes
import "../Common"

// A full ring whose fill grows from the top down both sides: 0.5 is a half ring
// open at the bottom, 1 is a closed circle. `gap` (0..1) parts the ring at the
// bottom to seat a label of `gapWidth`.
Item {
    id: root

    property real value: 0
    property real gap: 0
    property real gapWidth: 0
    property real lineWidth: 2
    property color trackColor: Theme.statusTrack
    property color fillColor: Theme.textPrimary

    readonly property real topAngle: -90
    readonly property real cx: width / 2
    readonly property real cy: height / 2
    readonly property real radius: Math.max(0, Math.min(width, height) / 2 - lineWidth / 2)
    readonly property real gapHalf: radius <= 0 ? 0
        : Math.min(179, Math.max(0, gap) * (gapWidth / 2 + lineWidth / 2) / radius * 180 / Math.PI)
    // Degrees each side may travel from the top before reaching the label gap.
    readonly property real reach: 180 - gapHalf
    readonly property real fillReach: Math.min(reach, 180 * Math.max(0, Math.min(1, value)))

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // A closed ring takes flat caps; overlapping round caps would double the translucent track's alpha.
        Segment {
            color: root.trackColor
            from: root.topAngle + 180 + root.gapHalf
            span: root.reach * 2
            capStyle: root.gapHalf > 0.5 ? ShapePath.RoundCap : ShapePath.FlatCap
        }
        Segment { color: root.fillColor; from: root.topAngle; span: root.fillReach }
        Segment { color: root.fillColor; from: root.topAngle - root.fillReach; span: root.fillReach }
    }

    component Segment: ShapePath {
        id: segment

        property color color
        property real from: 0
        property real span: 0

        strokeColor: span > 0.05 ? color : "transparent"
        strokeWidth: root.lineWidth
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap

        PathAngleArc {
            centerX: root.cx
            centerY: root.cy
            radiusX: root.radius
            radiusY: root.radius
            startAngle: segment.from
            sweepAngle: Math.max(0.01, segment.span)
        }
    }
}
