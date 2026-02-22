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

            // Pass through if the cursor is over a scrollable view (e.g. session node
            // message feed) so that native scroll behaviour works for non-maximised nodes.
            if self.cursorIsOverScrollView(at: locationInWindow) {
                return event
            }

            // Use precise deltas from trackpad-style scrolling to pan the canvas.
            if !event.hasPreciseScrollingDeltas {
                return event
            }

            self.onScroll?(CGSize(width: event.scrollingDeltaX, height: event.scrollingDeltaY))
            return nil
        }
    }

    /// Returns `true` when the deepest `NSView` under `locationInWindow`
    /// (in the key window's coordinate system) has an `NSScrollView` somewhere
    /// in its ancestor chain, indicating the event should scroll content rather
    /// than pan the canvas.
    private func cursorIsOverScrollView(at locationInWindow: CGPoint) -> Bool {
        guard let contentView = window?.contentView,
              let hit = contentView.hitTest(locationInWindow) else { return false }
        var view: NSView? = hit
        while let v = view {
            if v is NSScrollView { return true }
            view = v.superview
        }
        return false
    }

    private func stopMonitoring() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
#endif
