struct StatusItemTitleVisibilityPolicy {
    let displayMode: StatusBarDisplayMode
    let isStatusItemHovered: Bool
    let isShortcutRevealActive: Bool
    let isMenuOpen: Bool
    let keepsStatusTitleWhileMenuOpen: Bool

    var shouldShowTitle: Bool {
        switch displayMode {
        case .iconOnly:
            isShortcutRevealActive
        case .iconAndText:
            true
        case .textOnHover:
            isShortcutRevealActive || isStatusItemHovered || (isMenuOpen && keepsStatusTitleWhileMenuOpen)
        }
    }
}
