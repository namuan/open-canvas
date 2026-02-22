# OpenCanvas

A native macOS desktop application that provides an infinite, zoomable canvas where developers can create, arrange, and
manage multiple OpenCode AI sessions simultaneously.

## Overview

OpenCanvas is a powerful tool for developers who want to run parallel AI coding tasks without context-switching between
terminal windows. Each session is represented as an interactive node on the canvas — a draggable card that owns its own
OpenCode server session, chat history, and real-time status.

## Features

- **Multi-Session Management**: Run many AI coding sessions in parallel
- **Visual Workspace**: Infinite zoomable canvas with draggable nodes
- **Real-time Updates**: SSE event streams for instant status changes
- **Session Isolation**: Each node owns exactly one OpenCode session
- **Persistent Layout**: Nodes remember their positions between app launches
- **Connection Visualization**: Draw edges between nodes to show relationships
- **Native macOS Experience**: Full SwiftUI with macOS design idioms

## Quick Start

### Prerequisites

- macOS 14.0+ (Sonoma)
- Swift 5.9+
- OpenCode server running locally

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/namuan/open-canvas.git
   cd open-canvas
   ```

2. Build and run the application:
   ```bash
   swift build
   ./.build/debug/OpenCanvas
   ```

### Setup

1. Ensure your OpenCode server is running:
   ```bash
   opencode serve
   ```

2. Launch OpenCanvas
3. The app will automatically connect to `http://localhost:4096`

## Usage

### Creating Sessions

- **Add New Node**: Click the "+" button in the toolbar or press `Cmd+N`
- **Auto Layout**: Arrange all nodes in a responsive grid with `Cmd+Shift+L`
- **Drag & Drop**: Click and drag nodes to reposition them on the canvas

### Managing Sessions

- **Rename**: Double-click a node's title to edit inline
- **Minimize**: Click the yellow minimize button to collapse nodes
- **Close**: Click the red close button to delete a session
- **Fork**: Right-click a node and select "Fork Session" to create a child session
- **Change Color**: Right-click and select "Change Color" for visual organization

### Keyboard Shortcuts

| Shortcut               | Action                       |
|------------------------|------------------------------|
| `Cmd+N`                | Add new session node         |
| `Cmd+W`                | Close selected node          |
| `Cmd+,`                | Open Settings                |
| `Cmd+0`                | Reset canvas view            |
| `Cmd++` / `Cmd+-`      | Zoom in/out                  |
| `Cmd+Shift+L`          | Auto-layout all nodes        |
| `Cmd+K`                | Clear canvas                 |
| `Cmd+Return`           | Send message                 |
| `Esc`                  | Cancel/clear prompt          |
| `Cmd+Shift+A`          | Abort running session        |
| `Cmd+F`                | Fork selected node's session |
| `Tab`                  | Cycle focus to next node     |
| `Backspace` / `Delete` | Delete selected node(s)      |

## Architecture

### Project Structure

```
Sources/OpenCanvas/
├── App/                 # App entry point and commands
├── Models/              # Data models (CanvasNode, OCSession, OCMessage, etc.)
├── ViewModels/          # State management (AppState, SessionNodeViewModel, etc.)
├── Views/Canvas/        # Canvas rendering and toolbar
├── Views/Session/       # Session node UI components
├── Views/Settings/      # Settings interface
├── Views/Components/    # Reusable UI components
├── Services/            # Networking and persistence
└── Logging/             # Application logging
```

### State Management

The application uses SwiftUI's native observation stack with @StateObject, @ObservedObject, and @EnvironmentObject. The
AppState object serves as the single source of truth for all nodes and canvas state.

### Networking

- **HTTP Client**: Built on URLSession async/await
- **SSE Stream**: Real-time event handling using URLSession.bytes(for:)
- **API Endpoints**: /session, /session/:id/prompt_async, /session/:id/sse, etc.

## Development

### Requirements

- Xcode 15+ (for SwiftUI features)
- Swift Package Manager
- macOS 14.0+ SDK

### Building

```bash
# Build the project
swift build

# Run tests
swift test

# Build for release
swift build -c release
```

### Code Style

The project follows Swift style guidelines with:

- SwiftLint for code quality
- SwiftUI best practices
- SwiftUI Concurrency for async operations
- Codable for all data models

## Configuration

### Server Settings

OpenCanvas connects to a locally running OpenCode server by default at `http://localhost:4096`. You can configure:

- Server URL
- Basic authentication credentials
- Connection health monitoring

### Appearance

Customize the canvas appearance:

- Background style (dot grid, line grid, none)
- Default node size and color
- Font size in message feeds

### Logging

Extensive file-based logging with rolling logs under `~/Library/Logs/OpenCanvas/` for debugging and observability.

## Troubleshooting

### Common Issues

1. **Connection Failed**: Ensure OpenCode server is running on localhost:4096
2. **Nodes Not Responding**: Check network connectivity and server status
3. **Performance Issues**: Reduce canvas zoom level or node count

### Debug Mode

Enable debug logging in Settings → Logging to get detailed information about:

- Network requests and responses
- SSE event stream processing
- Canvas rendering operations
- State changes

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

### Development Guidelines

- Follow SwiftUI best practices
- Use async/await for all asynchronous operations
- Implement proper error handling
- Write unit tests for new functionality
- Update documentation as needed

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
