import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ToolUseCard: View {
    let toolUse: ToolUseInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                toolIcon
                
                Text(toolUse.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                statusBadge
            }
            
            if let input = toolUse.input, !input.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Input:")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    
                    Text(input)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(5)
                }
            }
            
            if let output = toolUse.output, !output.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Output:")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    
                    Text(output)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(5)
                }
            }
        }
        .padding(10)
        .background(Color.ocBubbleSystemBackground)
        .clipShape(.rect(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.ocBorder, lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var toolIcon: some View {
        Group {
            switch toolUse.name.lowercased() {
            case let name where name.contains("read") || name.contains("file"):
                Image(systemName: "doc.text")
            case let name where name.contains("write") || name.contains("edit"):
                Image(systemName: "pencil.and.outline")
            case let name where name.contains("bash") || name.contains("shell"):
                Image(systemName: "terminal")
            case let name where name.contains("search") || name.contains("grep"):
                Image(systemName: "magnifyingglass")
            default:
                Image(systemName: "wrench.and.screwdriver")
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .frame(width: 20, height: 20)
        .background(Color.ocComposerBackground)
        .clipShape(.rect(cornerRadius: 4))
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        Group {
            switch toolUse.status {
            case .pending:
                Text("Pending")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
            case .running:
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.5)
                    Text("Running")
                        .font(.system(size: 10))
                }
                .foregroundStyle(.blue)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.green)
            case .error:
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            case .permissionRequired:
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.yellow)
            }
        }
    }
}
