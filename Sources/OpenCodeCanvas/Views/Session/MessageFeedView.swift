import SwiftUI

struct MessageFeedView: View {
    let messages: [ChatMessage]
    
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
                scrollToBottom(using: proxy, animated: false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.2))
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
