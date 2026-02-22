import SwiftUI

private struct SessionFontSizeKey: EnvironmentKey {
    static let defaultValue: CGFloat = 13
}

extension EnvironmentValues {
    var sessionFontSize: CGFloat {
        get { self[SessionFontSizeKey.self] }
        set { self[SessionFontSizeKey.self] = newValue }
    }
}
