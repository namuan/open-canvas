import SwiftUI

struct NodeColorPicker: View {
    @Binding var selectedColor: NodeColor
    var onColorSelected: ((NodeColor) -> Void)?
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(NodeColor.allCases) { color in
                Button {
                    selectedColor = color
                    onColorSelected?(color)
                } label: {
                    Circle()
                        .fill(color.gradient)
                        .frame(width: 24, height: 24)
                        .overlay {
                            if selectedColor == color {
                                Circle()
                                    .stroke(.white, lineWidth: 2)
                                    .frame(width: 20, height: 20)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(.rect(cornerRadius: 8))
    }
}
