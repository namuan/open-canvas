import SwiftUI
#if os(macOS)
import AppKit
#endif

struct MessageFeedView: View {
    let messages: [ChatMessage]
    @State private var lastStreamingScrollTime: TimeInterval = 0
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onAppear {
                scrollToBottom(using: proxy, animated: false)
            }
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(using: proxy, animated: true)
            }
            .onChange(of: messages.last?.id) { _, _ in
                scrollToBottom(using: proxy, animated: true)
            }
            .onChange(of: messages.last?.content) { _, _ in
                // Keep the newest streaming content visible as tokens arrive.
                let now = Date().timeIntervalSince1970
                guard now - lastStreamingScrollTime >= 0.08 else { return }
                lastStreamingScrollTime = now
                scrollToBottom(using: proxy, animated: false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ocFeedBackground)
    }

    private func scrollToBottom(using proxy: ScrollViewProxy, animated: Bool) {
        guard let lastMessage = messages.last else { return }

        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
}
