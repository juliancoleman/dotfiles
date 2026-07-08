// Allow the julian user (wheel group) to perform NetworkManager wifi
// operations without a password prompt: scan, add/modify connections,
// activate. This unblocks the popover-shell wifi picker — without it,
// `nmcli device wifi rescan` fails with "not authorized" under polkit.
//
// Scoped to wheel (the user is already in wheel via shared/system.nix)
// and to the NetworkManager action set only.
polkit.addRule(function(action, subject) {
    if (action.id.indexOf("org.freedesktop.NetworkManager.") === 0 &&
        subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
