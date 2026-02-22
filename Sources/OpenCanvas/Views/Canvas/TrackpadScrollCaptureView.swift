import SwiftUI
#if os(macOS)
import AppKit

struct TrackpadScrollCaptureView: NSViewRepresentable {
    let onScroll: (CGSize) -> Void
    var isBlocked: Bool = false

    func makeNSView(context: Context) -> ScrollMonitorView {
        let view = ScrollMonitorView()
        view.onScroll = onScroll
        view.isBlocked = isBlocked
        return view
    }

    func updateNSView(_ nsView: ScrollMonitorView, context: Context) {
        nsView.onScroll = onScroll
        nsView.isBlocked = isBlocked
    }
}

final class ScrollMonitorView: NSView {
    var onScroll: ((CGSize) -> Void)?
    var isBlocked: Bool = false
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            startMonitoring()
        } else {
            stopMonitoring()
        }
    }

    private func startMonitoring() {
        guard monitor == nil else { return }

        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, self.window != nil else { return event }

            // Pass events through when a modal overlay (e.g. Settings sheet) is open.
            guard !self.isBlocked else { return event }

            let locationInWindow = event.locationInWindow
            let locationInView = self.convert(locationInWindow, from: nil)
            guard self.bounds.contains(locationInView) else { return event }

            // Use precise deltas from trackpad-style scrolling to pan the canvas.
            if !event.hasPreciseScrollingDeltas {
                return event
            }

            self.onScroll?(CGSize(width: event.scrollingDeltaX, height: event.scrollingDeltaY))
            return nil
        }
    }

    private func stopMonitoring() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
#endif
