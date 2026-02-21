import SwiftUI

struct ZoomControl: View {
    @Binding var scale: CGFloat
    let minScale: CGFloat = 0.3
    let maxScale: CGFloat = 2.5
    
    var body: some View {
        HStack(spacing: 8) {
            Button {
                scale = max(minScale, scale / 1.2)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(.borderless)
            
            Text("\(Int(scale * 100))%")
                .font(.system(.caption, design: .monospaced))
                .frame(width: 45)
            
            Button {
                scale = min(maxScale, scale * 1.2)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(.borderless)
        }
    }
}
