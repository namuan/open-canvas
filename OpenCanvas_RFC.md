<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p><strong>RFC-001</strong></p>
<p><strong>OpenCanvas</strong></p>
<p>A Multi-Session Node Canvas for macOS</p>
<p>Swift · SwiftUI · OpenCode HTTP API · SSE</p></td>
</tr>
</tbody>
</table>

|                  |                      |
|------------------|----------------------|
| **Document ID**  | RFC-001              |
| **Status**       | Draft                |
| **Author**       | Engineering          |
| **Platform**     | macOS 14.0+ (Sonoma) |
| **Language**     | Swift 5.9 / SwiftUI  |
| **Last Updated** | Sat Feb 21 2026      |

**1. Executive Overview**

OpenCanvas is a native macOS desktop application that provides an
infinite, zoomable canvas where developers can create, arrange, and
manage multiple OpenCode AI sessions simultaneously. Each session is
represented as an interactive node on the canvas — a draggable card that
owns its own OpenCode server session, chat history, and real-time
status.

The application targets power users who want to run parallel AI coding
tasks: exploring different approaches, managing multiple repositories,
or orchestrating complex multi-step workflows — all in a single visual
workspace.

|       |                                                                                                                                                              |
|-------|--------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **ℹ** | OpenCanvas connects to a locally running OpenCode server (opencode serve) via its HTTP API and SSE event stream. It does not bundle its own AI runtime. |

**1.1 Core Value Proposition**

- Run many AI coding sessions in parallel without context-switching
  between terminal windows

- Visualize session relationships with a freeform canvas and node
  connections

- Spawn child sessions or fork sessions from a specific message

- Monitor all session statuses at a glance from a single unified
  workspace

- Persistent canvas layout — nodes remember their positions between app
  launches

**1.2 Goals**

- **Native macOS first-class experience:** Full SwiftUI with macOS
  design idioms, menu bar integration, keyboard shortcuts, and smooth
  60fps animations.

- **Session isolation:** Every node owns exactly one OpenCode session.
  Actions in one node never bleed into another.

- **Real-time reactivity:** SSE event streams propagate session status
  changes, new messages, and tool use indicators instantly.

- **Zero-friction workflow:** Drag to reposition, double-click to
  rename, right-click for context menus — no modal dialogs for common
  actions.

- **Robust observability:** Extensive file-based logging with rolling
  logs under ~/Library/Logs/OpenCanvas/ for every meaningful event.

**2. Product Specification**

**2.1 Application Entry Point — The Canvas**

On launch, the application opens directly to a full-window infinite
canvas. There is no splash screen or onboarding wizard. The canvas
occupies the entire window content area; a slim toolbar sits at the top,
and an optional collapsible sidebar lists all nodes.

**Canvas behaviors:**

- Pinch-to-zoom (trackpad) and scroll wheel zoom: scale range 0.3× –
  2.5×

- Two-finger pan (trackpad) or click-and-drag on empty canvas:
  translates the viewport

- The canvas coordinate system is infinite — nodes can be placed
  anywhere

- A subtle dot-grid background reacts to zoom level, reinforcing spatial
  awareness

- The current zoom percentage is shown in the toolbar status area

**2.2 Session Nodes**

A session node is the primary UI element. It is a floating card rendered
on the canvas that encapsulates the entire lifecycle of an OpenCode
session.

**2.2.1 Node Anatomy**

| **Region**      | **Description**                                                                                |
|-----------------|------------------------------------------------------------------------------------------------|
| Title bar       | Node title (editable inline), status indicator dot, color accent strip, minimize/close buttons |
| Status badge    | Pill showing Disconnected / Connecting / Ready / Running / Error with animated icon            |
| Session ID chip | Truncated session ID — click to copy. Hidden until a session is created                        |
| Message feed    | Scrollable chat history: user messages, AI responses, tool-use cards                           |
| Prompt bar      | Multi-line text input with Send button and model selector dropdown                             |
| Resize handle   | Bottom-right corner drag to resize the node card                                               |

**2.2.2 Node States**

| **State**        | **Color**    | **Behavior**                                                 |
|------------------|--------------|--------------------------------------------------------------|
| **Disconnected** | Gray         | No session assigned. Shows Create Session button.            |
| **Connecting**   | Orange       | Session creation in flight. Spinner animation on badge.      |
| **Idle / Ready** | Green        | Session exists, no active generation. Prompt bar enabled.    |
| **Running**      | Blue (pulse) | AI is generating. Prompt bar disabled. Abort button visible. |
| **Error**        | Red          | Last operation failed. Error message shown. Retry available. |

**2.2.3 Node Interactions**

- **Drag:** Click and drag the title bar to move the node. Position
  persists to UserDefaults.

- **Resize:** Drag the bottom-right resize handle. Min size 280×360pt.

- **Minimize:** Click the yellow minimize button. Node collapses to a
  slim 220×60pt pill showing title and status.

- **Close / Delete:** Click the red close button. Confirmation alert if
  the session has messages. Calls DELETE /session/:id.

- **Double-click title:** Activates inline text editing to rename the
  node. PATCH /session/:id is called on commit.

- **Right-click context menu:** Fork Session, Abort, Copy Session ID,
  Change Color, Duplicate Layout.

- **Long-press (200ms):** Elevates node to top of z-order. Visual spring
  pop animation.

**2.3 Canvas Toolbar**

A compact HStack toolbar at the top of the window contains:

- **Add Node button:** Inserts a new node at canvas center offset by a
  random jitter. (⌘N)

- **Auto Layout button:** Arranges all nodes in a responsive grid. (⌘⇧L)

- **Zoom In / Out:** Buttons and ⌘+ / ⌘− shortcuts

- **Reset View:** Recenters canvas and resets zoom to 1×. (⌘0)

- **Connection mode toggle:** Enables drawing edges between nodes to
  visualize relationships.

- **Server status indicator:** Green/red dot with server hostname:port.
  Clickable → Settings sheet.

- **Node count badge:** Shows active sessions / total nodes (e.g., 3/5
  active).

**2.4 Sidebar**

A collapsible left sidebar (toggle with ⌘⇧S or sidebar button) shows a
flat list of all nodes. Each row displays:

- Color dot + Node title

- Status badge pill

- Last activity timestamp (relative: '2m ago')

- Click to scroll canvas to the node and select it

- Drag to reorder in sidebar (does not affect canvas position)

**2.5 Settings**

Accessible via ⌘, or the app menu. Organized into tabs:

- **Server:** OpenCode server URL (default http://localhost:4096),
  optional Basic Auth credentials, reconnect button, connection health
  display.

- **Appearance:** Canvas background style (dot grid / line grid / none),
  node default size, default color for new nodes, font size in message
  feed.

- **Logging:** Log level selector (Debug / Info / Warning / Error),
  current log file path with reveal-in-Finder button, and Purge Logs
  button.

- **About:** App version, OpenCode server version, link to docs.

**3. Technical Architecture**

**3.1 Project Structure**

The project is a standard Swift Package Manager-structured Xcode
project. No CocoaPods or Carthage. External dependencies are minimized
to keep the binary lean and compile times fast.

| **Directory / File** | **Purpose**                                                                                               |
|----------------------|-----------------------------------------------------------------------------------------------------------|
| App/                 | App entry (@main), AppCommands (menu bar)                                                                 |
| Models/              | Pure Swift data models: CanvasNode, OCSession, OCMessage, NodeStatus, NodeColor, SSEEvent, NodeConnection |
| ViewModels/          | AppState (ObservableObject — canvas), SessionNodeViewModel (per-node), SettingsViewModel                  |
| Views/Canvas/        | CanvasView, CanvasBackground, ConnectionOverlay, CanvasToolbar                                            |
| Views/Session/       | SessionNodeView, NodeTitleBar, MessageFeedView, MessageBubble, PromptBarView, ToolUseCard                 |
| Views/Sidebar/       | SidebarView, SidebarNodeRow                                                                               |
| Views/Settings/      | SettingsView (TabView with Server, Appearance, Logging, About tabs)                                       |
| Views/Components/    | StatusBadge, NodeColorPicker, AnimatedStatusDot, ZoomControl, LoadingDots                                 |
| Services/            | OpenCodeServerManager (HTTP + SSE), PersistenceService                                                    |
| Logging/             | AppLogger (rolling file logger, OSLog integration)                                                        |
| Extensions/          | Color+Hex, CGPoint+Operators, View+Shake, String+Truncated                                                |

**3.2 State Architecture**

The application uses SwiftUI's native observation stack — @StateObject /
@ObservedObject / @EnvironmentObject — with no third-party state
management library.

**3.2.1 AppState**

A single @StateObject created at the app root and injected via
.environmentObject(). Holds:

- nodes: \[CanvasNode\] — source of truth for all nodes

- connections: \[NodeConnection\] — visual edges between nodes

- selectedNodeID: UUID? — currently focused node

- canvasOffset: CGSize, canvasScale: CGFloat — viewport transform

Mutations always go through AppState methods (never direct array
mutation from views). Key methods: addNode(), removeNode(id:),
updateNodePosition(id:position:), assignSession(nodeID:sessionID:),
autoLayout().

**3.2.2 SessionNodeViewModel**

One instance per node, owned by SessionNodeView via @StateObject.
Manages:

- inputText: String — current prompt draft

- messages: \[ChatMessage\] — rendered message list

- isStreaming: Bool — drives loading animation

- errorMessage: String?

Holds a reference to OpenCodeServerManager (passed in on init) and
subscribes to its SSE eventPublisher, filtering events by the node's
sessionID.

**3.2.3 OpenCodeServerManager**

Singleton @StateObject. Owns all HTTP communication and the global SSE
stream. Publishes:

- isConnected: Bool

- serverVersion: String

- connectionError: String?

- eventPublisher: AnyPublisher\<SSEEvent, Never\> — fan-out to all node
  VMs

On connection failure, automatically retries with 3-second backoff. SSE
stream reconnects on drop.

**3.3 Networking Layer**

**3.3.1 HTTP Client**

Built directly on URLSession async/await. No third-party HTTP library.
Generic helper methods handle encoding, decoding (JSONDecoder with
.millisecondsSince1970 date strategy), and HTTP error validation.

| **Method** | **Endpoint**                 | **Used For**                                                   |
|------------|------------------------------|----------------------------------------------------------------|
| GET        | /global/health               | Polling health check & server version on startup and reconnect |
| GET        | /event (SSE)                 | Global SSE stream — all real-time session events               |
| GET        | /session                     | List sessions on reconnect to reconcile with persisted nodes   |
| POST       | /session                     | Create a new OpenCode session when node spawns                 |
| DELETE     | /session/:id                 | Destroy session when node is closed                            |
| PATCH      | /session/:id                 | Rename session when node title is edited                       |
| POST       | /session/:id/prompt_async    | Send user message (non-blocking, returns 204)                  |
| POST       | /session/:id/abort           | Stop active generation                                         |
| POST       | /session/:id/fork            | Fork session at a given message                                |
| GET        | /session/:id/message         | Load full message history on reconnect                         |
| POST       | /session/:id/permissions/:id | Respond to permission prompts in tool use                      |

**3.3.2 SSE Stream**

The SSE stream is handled using URLSession.bytes(for:), iterating lines
asynchronously. The parser maintains per-event state (eventType,
dataBuffer) and dispatches fully assembled SSEEvent values through a
PassthroughSubject. Each SessionNodeViewModel subscribes and filters by
its sessionID extracted from the event payload.

SSE event types the app handles:

- server.connected — marks stream as live, resets retry counter

- session.updated — updates node status (running/idle)

- message.part — streams AI text tokens into the message bubble

- message.completed — finalizes the streaming message

- session.error — sets node status to .error, displays error message

- permission.requested — shows in-node permission approval UI for tool
  use

**3.4 Canvas Rendering**

**3.4.1 Coordinate System**

The canvas uses a ZStack with a GeometryReader providing the visible
frame. A ScaledOffsetModifier custom ViewModifier applies the
canvasScale (via .scaleEffect) and canvasOffset (via .offset) to the
node container. Nodes render at their stored canvas coordinates; the
transform converts them to screen space.

Node positions are stored in canvas-space (untransformed) coordinates.
When placed, the screen tap location is converted to canvas space:

**canvasPoint = (screenPoint - canvasOffset) / canvasScale**

**3.4.2 Node Drag**

Each node uses a DragGesture attached to its title bar. The gesture
computes delta in screen space and converts it to canvas-space delta
(dividing by canvasScale) before calling
appState.updateNodePosition(id:position:). This keeps drag speed
consistent at any zoom level.

**3.4.3 Connection Overlay**

Node connections are drawn on a Canvas (SwiftUI Canvas, not the app's
canvas view) layered beneath all node cards. On each render pass, the
overlay iterates connections and draws a cubic Bezier curve from the
right edge of the source node to the left edge of the target node.
Control points are offset horizontally by 80pt in canvas space to create
a smooth arc.

**3.4.4 Performance**

- Nodes use equatable diffing (Equatable conformance on CanvasNode) so
  SwiftUI only redraws changed nodes

- The connection overlay redraws on canvas geometry changes and node
  position changes only

- Message feeds use LazyVStack to avoid rendering offscreen bubbles

- Images (if any) in messages are loaded lazily with AsyncImage

- Canvas gestures use .simultaneous gesture composition to avoid
  blocking scroll on nodes

**3.5 Logging System**

**3.5.1 AppLogger**

AppLogger is a final class singleton (AppLogger.shared) initialized at
app launch in the @main struct's init(). It wraps both Apple's OSLog
framework (for Console.app integration) and file-based rolling logs.

**Log directory:** ~/Library/Logs/OpenCanvas/

**3.5.2 Rolling File Strategy**

- Active log file: OpenCanvas.log

- On exceeding 5 MB, the active file is renamed to
  OpenCanvas-{unix_timestamp}.log

- A maximum of 5 archived files are retained; oldest are deleted on
  rotation

- All file I/O is dispatched on a dedicated serial DispatchQueue
  (com.opencanvas.logger, .utility QoS) to avoid blocking the main
  thread

**3.5.3 Log Categories**

| **Category** | **Logged Events**                                                                                |
|--------------|--------------------------------------------------------------------------------------------------|
| .app         | App launch/quit, window lifecycle, menu actions, user preference changes                         |
| .canvas      | Node add/remove/move/minimize, connection add/remove, auto-layout, zoom changes                  |
| .session     | Session create/delete/rename, message send, abort, fork, permission responses                    |
| .network     | Every HTTP request (method + path), response status codes, JSON decode errors                    |
| .sse         | SSE stream connect/disconnect/reconnect, every event type received (data truncated to 100 chars) |
| .ui          | Significant UI state transitions: sidebar toggle, settings open, color picker changes            |
| .storage     | UserDefaults reads/writes for canvas persistence                                                 |

**3.5.4 Log Entry Format**

2025-09-14T10:23:45Z ℹ️ \[INFO\] \[Session\]
\[SessionNodeViewModel.swift:88\] sendMessage() → Sending to session
abc123: refactor...

Each entry contains: ISO-8601 timestamp, level emoji, level label,
category, source file:line, function name, and the message.

**4. UI/UX Design Specification**

**4.1 Visual Language**

The application uses a dark-forward aesthetic appropriate for a
developer tool. The canvas background is very dark (near-black) to make
the colorful node cards pop. Nodes use per-node gradient themes (blue,
purple, green, orange, pink, teal) for quick visual identification.

- **Font:** SF Pro Display / SF Pro Text (system font). Monospaced
  sections use SF Mono.

- **Corner radius:** 16pt on nodes, 8pt on badges and buttons, 4pt on
  chips.

- **Shadows:** Nodes cast a 24pt radius shadow at 40% opacity in their
  accent color. Selected node has a more intense glow.

- **Blur:** The toolbar and sidebar use .ultraThinMaterial background to
  maintain context while staying out of the way.

**4.2 Animations**

| **Trigger**           | **Animation**                                     | **Curve / Duration**                          |
|-----------------------|---------------------------------------------------|-----------------------------------------------|
| Node added to canvas  | Scale 0.7→1.0, opacity 0→1                        | .spring(response: 0.4, dampingFraction: 0.7)  |
| Node removed          | Scale 1.0→0.7, opacity 1→0                        | .easeInOut(duration: 0.2)                     |
| Node minimize/expand  | Height collapse with scale on content             | .spring(response: 0.35, dampingFraction: 0.8) |
| Node drag lift        | Scale 1.0→1.03, shadow intensify                  | .easeOut(duration: 0.12)                      |
| Node drop             | Scale 1.03→1.0                                    | .spring(response: 0.3)                        |
| Status badge change   | Cross-fade                                        | .easeInOut(duration: 0.25)                    |
| Running state pulse   | Repeating scale 1.0→1.08→1.0 on badge dot         | .easeInOut(duration: 0.9).repeatForever       |
| Canvas zoom (buttons) | Scale + offset interpolation                      | .spring(response: 0.4)                        |
| Auto layout           | All nodes animate to new positions simultaneously | .spring(response: 0.5)                        |
| Sidebar show/hide     | Slide in from left                                | .spring(response: 0.3, dampingFraction: 0.85) |
| New message bubble    | Slide up + fade in                                | .easeOut(duration: 0.2)                       |
| Error shake           | Horizontal shake on node card                     | Custom shake modifier, 0.5s total             |

**4.3 Keyboard Shortcuts**

| **Shortcut**        | **Action**                                              |
|---------------------|---------------------------------------------------------|
| ⌘N                  | Add new session node at canvas center                   |
| ⌘W                  | Close selected node (with confirmation if has messages) |
| ⌘⇧S                 | Toggle sidebar                                          |
| ⌘,                  | Open Settings                                           |
| ⌘0                  | Reset canvas view (zoom 1×, center)                     |
| ⌘+ / ⌘−             | Zoom in / out                                           |
| ⌘⇧L                 | Auto-layout all nodes                                   |
| ⌘K (⌘⇧K)            | Clear canvas (with confirmation)                        |
| ⌘↩ (in prompt bar)  | Send message                                            |
| Esc (in prompt bar) | Cancel / clear prompt                                   |
| ⌘⇧A                 | Abort running session in selected node                  |
| ⌘F                  | Fork selected node's session                            |
| Tab                 | Cycle focus to next node                                |

**4.4 Context Menu Actions (Right-click on Node)**

- Rename — activates inline title editing

- Change Color — opens color picker popover with 6 theme options

- Duplicate Layout — creates a new node at an offset, same title + color
  but no session

- Fork Session — calls POST /session/:id/fork, creates child node

- Copy Session ID — copies to pasteboard

- View Logs for Session — opens log viewer filtered to this session ID

- Abort — calls POST /session/:id/abort

- Close — deletes node and session

**5. Data & Persistence**

**5.1 What Is Persisted**

The application does not maintain a database. Canvas layout state is
persisted to UserDefaults using a lightweight serialized form. Message
history is not persisted locally — it is re-fetched from the OpenCode
server on reconnect.

| **Key**               | **Type**            | **Contents**                                 |
|-----------------------|---------------------|----------------------------------------------|
| canvasNodes           | \[\[String: Any\]\] | id, title, x, y, sessionID, color, minimized |
| serverURL             | String              | OpenCode server base URL                     |
| sidebarVisible        | Bool                | Sidebar open/closed preference               |
| canvasBackgroundStyle | String              | dots / lines / none                          |
| defaultNodeColor      | String              | NodeColor rawValue for new nodes             |
| logLevel              | String              | Minimum log level to write to file           |

**5.2 Reconciliation on Reconnect**

When the app launches with persisted nodes that have sessionIDs, it
calls GET /session to fetch all live sessions from the OpenCode server.
Each persisted node is reconciled:

- Session ID found in server response → node status set to .idle,
  message history fetched

- Session ID not found (server restarted, session deleted) → node status
  set to .disconnected, Create Session button shown

This gives users a soft-recovery experience — their canvas layout is
always preserved even if the OpenCode server was restarted.

**5.3 Session Lifecycle Across App Restarts**

|       |                                                                                                                                                                                                                                                                                                       |
|-------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **ℹ** | OpenCode sessions are server-side entities. The app does not own their lifecycle beyond initiating create/delete. If the server is shut down and restarted, sessions may or may not persist depending on the OpenCode server's own storage. The app handles both cases gracefully via reconciliation. |

**6. Error Handling & Resilience**

**6.1 Network Errors**

- **Server unreachable at launch:** Canvas loads normally with all nodes
  in .disconnected state. A banner at the bottom of the window says
  "OpenCode server offline — retrying…"

- **HTTP 4xx from API:** The specific node that triggered the call
  enters .error state. Error message extracted from response body and
  shown in node.

- **SSE stream drops:** 2-second reconnect delay, then re-attempt. If 3
  consecutive failures, marks isConnected = false and shows global
  banner.

- **Health check polling:** 3-second retry interval. Backs off to 10
  seconds after 5 failures.

**6.2 User-Facing Error UI**

- Errors surface inline within the affected node — not as modal alerts

- Each node has an error banner area just above the prompt bar

- A Retry button calls the failed operation again

- Persistent errors show a "View Logs" link that opens the log file in
  Console.app

**6.3 Crash Safety**

- Canvas positions are persisted to UserDefaults after every mutating
  operation, not on a timer — no data loss on unexpected exit

- NSApp.terminate is intercepted to flush any buffered log writes before
  exit

**7. System Requirements & Dependencies**

**7.1 Minimum Requirements**

|                  |                                                                                                     |
|------------------|-----------------------------------------------------------------------------------------------------|
| **macOS**        | 14.0 (Sonoma) or later                                                                              |
| **Xcode**        | 15.0 or later (Swift 5.9)                                                                           |
| **Architecture** | Apple Silicon (arm64) and Intel (x86_64) via Universal Binary                                       |
| **OpenCode**     | opencode serve running locally or on network — any version supporting /global/health and SSE /event |
| **RAM**          | ~50 MB baseline; grows with number of active nodes and message history                              |

**7.2 External Dependencies**

|       |                                                                                                                                                                                                         |
|-------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **ℹ** | The application intentionally has zero Swift Package Manager dependencies for networking, state management, or UI. All functionality is built on Apple frameworks: SwiftUI, Combine, Foundation, OSLog. |

|                      |                                                                                      |
|----------------------|--------------------------------------------------------------------------------------|
| **SwiftUI**          | All UI rendering, navigation, animations, layout                                     |
| **Combine**          | SSE event fan-out via PassthroughSubject, Cancellable management                     |
| **Foundation**       | URLSession (HTTP + SSE bytes stream), JSONDecoder/Encoder, UserDefaults, FileManager |
| **OSLog**            | Structured logging to Console.app alongside file logging                             |
| **AppKit (limited)** | NSApplication for terminate interception, NSPasteboard for Copy Session ID           |

**7.3 Entitlements & Sandbox**

- App Sandbox: Enabled

- com.apple.security.network.client: true — outbound HTTP to OpenCode
  server

- com.apple.security.files.user-selected.read-write: true — for log
  directory access via Settings \> Reveal in Finder

- No microphone, camera, or other sensitive entitlements required

**8. Open Questions & Future Considerations**

**8.1 Open Questions**

- **Q1:** Should the app support connecting to multiple OpenCode servers
  simultaneously (e.g., local + remote), or always a single server at a
  time?

- **Q2:** Should message history be persisted locally (e.g., in SQLite)
  so it survives server restarts, or remain server-authoritative only?

- **Q3:** Should node connections (edges) have semantic meaning (e.g.,
  "this node's output feeds into that node's prompt") or remain purely
  visual annotations?

- **Q4:** What is the maximum practical number of simultaneous active
  sessions before the SSE stream or server becomes a bottleneck?

**8.2 Future Feature Candidates**

- **Canvas templates:** Pre-arranged node layouts for common workflows
  (e.g., "Refactor + Tests + PR Review" trio)

- **Session chaining:** Automatically pipe the output of one session as
  input to a connected node

- **Snapshot & restore:** Export the full canvas state (layout + session
  IDs) to a JSON file and import on another machine

- **Menu bar agent:** A compact menu bar popover for quick session
  access without opening the full canvas

- **Markdown rendering:** Render AI response text as rich Markdown in
  message bubbles using AttributedString

- **File diff viewer:** Inline display of GET /session/:id/diff results
  as a mini side-by-side diff in the node

- **Node groups:** Ability to frame a set of nodes in a labeled group
  rectangle for organizational purposes

- **mDNS discovery:** Auto-discover opencode serve instances on the
  local network using the --mdns flag

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p><strong>RFC-001 · OpenCanvas</strong></p>
<p>Document status: Draft · Platform: macOS 14.0+ · Swift 5.9 /
SwiftUI</p></td>
</tr>
</tbody>
</table>
