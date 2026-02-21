#!/usr/bin/env swift

import Foundation

let serverURL = "http://localhost:4097"

func log(_ message: String) {
    print("[\(Date().ISO8601Format())] \(message)")
}

func testSSEAndPrompt() async throws {
    log("\n🚀 Starting SSE + Prompt integration test...")
    
    var sseEvents: [(type: String, data: String)] = []
    
    let sseTask = Task {
        let eventURL = URL(string: "\(serverURL)/event")!
        var eventRequest = URLRequest(url: eventURL)
        eventRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        log("📡 Starting SSE connection...")
        
        do {
            let (bytes, _) = try await URLSession.shared.bytes(for: eventRequest)
            
            for try await line in bytes.lines {
                // Server sends each event as a single "data:" line
                // No blank lines between events, no "event:" prefix
                if line.hasPrefix("data:") {
                    let data = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                    
                    // Parse the type from the JSON data
                    if let jsonData = data.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                       let type = json["type"] as? String {
                        log("📥 SSE Event: \(type)")
                        sseEvents.append((type: type, data: data))
                        
                        // Stop after session.idle
                        if type == "session.idle" {
                            log("Received session.idle")
                        }
                    }
                }
            }
            log("SSE stream ended normally")
        } catch {
            log("SSE error: \(error)")
        }
    }
    
    // Wait for SSE to establish
    try await Task.sleep(for: .milliseconds(500))
    
    // Create session
    log("📝 Creating session...")
    let createURL = URL(string: "\(serverURL)/session")!
    var createRequest = URLRequest(url: createURL)
    createRequest.httpMethod = "POST"
    createRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    createRequest.httpBody = "{}".data(using: .utf8)!
    
    let (createData, _) = try await URLSession.shared.data(for: createRequest)
    let sessionJSON = try JSONSerialization.jsonObject(with: createData) as? [String: Any]
    guard let sessionID = sessionJSON?["id"] as? String else {
        log("❌ No session ID in response")
        return
    }
    log("✅ Created session: \(sessionID)")
    
    // Send prompt
    log("💬 Sending prompt...")
    let promptURL = URL(string: "\(serverURL)/session/\(sessionID)/prompt_async")!
    var promptRequest = URLRequest(url: promptURL)
    promptRequest.httpMethod = "POST"
    promptRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    promptRequest.httpBody = try JSONSerialization.data(withJSONObject: [
        "parts": [["type": "text", "text": "Say 'hello world' and nothing else"]]
    ])
    
    let (_, promptResponse) = try await URLSession.shared.data(for: promptRequest)
    let httpResponse = promptResponse as? HTTPURLResponse
    log("📤 Prompt response status: \(httpResponse?.statusCode ?? 0)")
    
    // Wait for completion with timeout
    log("⏳ Waiting for session completion...")
    let waitStartTime = Date()
    let maxWait: TimeInterval = 45
    
    while Date().timeIntervalSince(waitStartTime) < maxWait {
        try await Task.sleep(for: .milliseconds(500))
        
        // Check for session.idle event
        if sseEvents.contains(where: { $0.type == "session.idle" }) {
            log("✅ Session completed (received session.idle)")
            break
        }
        
        // Check for error
        if sseEvents.contains(where: { $0.type == "session.error" }) {
            log("⚠️ Session had an error")
            break
        }
    }
    
    // Cancel SSE task
    sseTask.cancel()
    
    // Print results
    log("\n📊 Results:")
    log("Total SSE events: \(sseEvents.count)")
    
    for event in sseEvents {
        log("\n=== Event: \(event.type) ===")
        log("Data: \(event.data)")
    }
    
    let sessionEvents = sseEvents.filter { $0.data.contains(sessionID) }
    log("\nEvents for our session: \(sessionEvents.count)")
    
    // Cleanup
    log("\n🧹 Cleaning up session...")
    let deleteURL = URL(string: "\(serverURL)/session/\(sessionID)")!
    var deleteRequest = URLRequest(url: deleteURL)
    deleteRequest.httpMethod = "DELETE"
    _ = try? await URLSession.shared.data(for: deleteRequest)
    
    // Check if we got the expected events
    let hasServerConnected = sseEvents.contains { $0.type == "server.connected" }
    let hasSessionCreated = sseEvents.contains { $0.type == "session.created" }
    let hasSessionStatus = sseEvents.contains { $0.type == "session.status" }
    let hasSessionIdle = sseEvents.contains { $0.type == "session.idle" }
    
    log("\n📋 Event checklist:")
    log("  server.connected: \(hasServerConnected ? "✅" : "❌")")
    log("  session.created: \(hasSessionCreated ? "✅" : "❌")")
    log("  session.status: \(hasSessionStatus ? "✅" : "❌")")
    log("  session.idle: \(hasSessionIdle ? "✅" : "❌")")
    
    if sseEvents.count > 0 && sessionEvents.count > 0 {
        log("\n✅ Integration test PASSED")
    } else {
        log("\n❌ Integration test FAILED - not enough events received")
    }
}

// Run test
Task {
    do {
        try await testSSEAndPrompt()
    } catch {
        log("❌ Test error: \(error)")
    }
    exit(0)
}

RunLoop.main.run(until: Date(timeIntervalSinceNow: 60))
