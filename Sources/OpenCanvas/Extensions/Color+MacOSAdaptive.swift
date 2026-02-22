import SwiftUI
#if os(macOS)
import AppKit
#endif

extension Color {
    static let ocPanelBackground = Color(nsColor: .ocPanelBackground)
    static let ocTitleBackground = Color(nsColor: .ocTitleBackground)
    static let ocFeedBackground = Color(nsColor: .ocFeedBackground)
    static let ocComposerBackground = Color(nsColor: .ocComposerBackground)
    static let ocInputBackground = Color(nsColor: .ocInputBackground)
    static let ocBubbleUserBackground = Color(nsColor: .ocBubbleUserBackground)
    static let ocBubbleAssistantBackground = Color(nsColor: .ocBubbleAssistantBackground)
    static let ocBubbleSystemBackground = Color(nsColor: .ocBubbleSystemBackground)
    static let ocBorder = Color(nsColor: .ocBorder)
}

#if os(macOS)
private extension NSColor {
    static let ocPanelBackground = NSColor(name: nil) { appearance in
        appearance.isDarkMode
            ? NSColor(calibratedWhite: 0.14, alpha: 1.0)
            : NSColor(calibratedWhite: 0.95, alpha: 1.0)
    }

    static let ocTitleBackground = NSColor(name: nil) { appearance in
        appearance.isDarkMode
            ? NSColor(calibratedWhite: 0.17, alpha: 1.0)
            : NSColor(calibratedWhite: 0.97, alpha: 1.0)
    }

    static let ocFeedBackground = NSColor(name: nil) { appearance in
        appearance.isDarkMode
            ? NSColor(calibratedWhite: 0.11, alpha: 1.0)
            : NSColor(calibratedWhite: 0.93, alpha: 1.0)
    }

    static let ocComposerBackground = NSColor(name: nil) { appearance in
        appearance.isDarkMode
            ? NSColor(calibratedWhite: 0.16, alpha: 1.0)
            : NSColor(calibratedWhite: 0.96, alpha: 1.0)
    }

    static let ocInputBackground = NSColor(name: nil) { appearance in
        appearance.isDarkMode
            ? NSColor(calibratedWhite: 0.13, alpha: 1.0)
            : NSColor(calibratedWhite: 1.0, alpha: 1.0)
    }

    static let ocBubbleUserBackground = NSColor(name: nil) { appearance in
        appearance.isDarkMode
            ? NSColor(calibratedWhite: 0.20, alpha: 1.0)
            : NSColor(calibratedWhite: 0.98, alpha: 1.0)
    }

    static let ocBubbleAssistantBackground = NSColor(name: nil) { appearance in
        appearance.isDarkMode
            ? NSColor(calibratedWhite: 0.16, alpha: 1.0)
            : NSColor(calibratedWhite: 0.95, alpha: 1.0)
    }

    static let ocBubbleSystemBackground = NSColor(name: nil) { appearance in
        appearance.isDarkMode
            ? NSColor(calibratedWhite: 0.14, alpha: 1.0)
            : NSColor(calibratedWhite: 0.93, alpha: 1.0)
    }

    static let ocBorder = NSColor(name: nil) { appearance in
        appearance.isDarkMode
            ? NSColor(calibratedWhite: 0.32, alpha: 1.0)
            : NSColor(calibratedWhite: 0.78, alpha: 1.0)
    }
}

private extension NSAppearance {
    var isDarkMode: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}
#endif
