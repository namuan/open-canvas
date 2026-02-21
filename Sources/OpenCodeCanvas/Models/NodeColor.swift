import SwiftUI

enum NodeColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case blue = "Blue"
    case purple = "Purple"
    case green = "Green"
    case orange = "Orange"
    case pink = "Pink"
    case teal = "Teal"
    
    var id: String { rawValue }
    
    var gradient: LinearGradient {
        switch self {
        case .blue:
            LinearGradient(
                colors: [Color(hex: "4A90D9"), Color(hex: "357ABD")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .purple:
            LinearGradient(
                colors: [Color(hex: "9B59B6"), Color(hex: "8E44AD")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .green:
            LinearGradient(
                colors: [Color(hex: "2ECC71"), Color(hex: "27AE60")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .orange:
            LinearGradient(
                colors: [Color(hex: "E67E22"), Color(hex: "D35400")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .pink:
            LinearGradient(
                colors: [Color(hex: "E91E63"), Color(hex: "C2185B")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .teal:
            LinearGradient(
                colors: [Color(hex: "1ABC9C"), Color(hex: "16A085")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    var primaryColor: Color {
        switch self {
        case .blue: Color(hex: "4A90D9")
        case .purple: Color(hex: "9B59B6")
        case .green: Color(hex: "2ECC71")
        case .orange: Color(hex: "E67E22")
        case .pink: Color(hex: "E91E63")
        case .teal: Color(hex: "1ABC9C")
        }
    }
}
