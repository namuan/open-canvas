import Foundation
import Testing

let serverURL = "http://localhost:4097"

@Suite("OpenCode Integration Tests")
struct IntegrationTests {
    
    @Test("Server health check")
    func testHealthCheck() async throws {
        let url = URL(string: "\(serverURL)/global/health")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 5
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            Issue.record("Invalid response type")
            return
        }
        
        #expect(httpResponse.statusCode == 200, "Health check should return 200")
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let healthy = json?["healthy"] as? Bool ?? false
        #expect(healthy == true, "Server should be healthy")
        
        print("✅ Health check passed: \(String(data: data, encoding: .utf8) ?? "")")
    }
    
    @Test("SSE connection receives server.connected")
    func testSSEConnection() async throws {
        let url = URL(string: "\(serverURL)/event")!
        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 0
        
        print("📡 Connecting to SSE stream...")
        
        let (bytes, _) = try await URLSession.shared.bytes(for: request)
        
        var receivedConnected = false
        let timeout: TimeInterval = 3
        let startTime = Date()
        
        for try await line in bytes.lines {
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed > timeout {
                print("⏱️ Timeout after \(timeout)s")
                break
            }
            
            print("📥 SSE line: \(line)")
            
            if line.contains("server.connected") {
                receivedConnected = true
                break
            }
        }
        
        #expect(receivedConnected, "Should receive server.connected event")
        print("✅ SSE connection test passed")
    }
    
    @Test("Create session and send prompt, capture SSE events")
    func testCreateSessionAndPrompt() async throws {
        print("\n🚀 Starting full integration test...")
        
        // Step 1: Create a session
        print("📝 Creating session...")
        let createURL = URL(string: "\(serverURL)/session")!
        var createRequest = URLRequest(url: createURL)
        createRequest.httpMethod = "POST"
        createRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        createRequest.httpBody = "{}".data(using: .utf8)!
        
        let (createData, createResponse) = try await URLSession.shared.data(for: createRequest)
        
        guard let httpCreateResponse = createResponse as? HTTPURLResponse,
              httpCreateResponse.statusCode == 200 else {
            Issue.record("Failed to create session")
            return
        }
        
        let sessionJSON = try JSONSerialization.jsonObject(with: createData) as? [String: Any]
        guard let sessionID = sessionJSON?["id"] as? String else {
            Issue.record("No session ID in response")
            return
        }
        
        print("✅ Created session: \(sessionID)")
        
        // Step 2: Start SSE listener in background
        print("📡 Starting SSE listener...")
        var sseEvents: [(type: String, data: String)] = []
        var shouldStopSSE = false
        let sseTask = Task {
            let eventURL = URL(string: "\(serverURL)/event")!
            var eventRequest = URLRequest(url: eventURL)
            eventRequest.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            
            do {
                let (bytes, _) = try await URLSession.shared.bytes(for: eventRequest)
                var eventType: String?
                var dataBuffer: String = ""
                
                for try await line in bytes.lines {
                    if shouldStopSSE { break }
                    
                    if line.hasPrefix("event:") {
                        eventType = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                    } else if line.hasPrefix("data:") {
                        let data = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                        if !dataBuffer.isEmpty {
                            dataBuffer += "\n"
                        }
                        dataBuffer += data
                    } else if line.isEmpty && eventType != nil && !dataBuffer.isEmpty {
                        print("📥 SSE Event: \(eventType!) -> \(dataBuffer.prefix(100))...")
                        sseEvents.append((type: eventType!, data: dataBuffer))
                        eventType = nil
                        dataBuffer = ""
                    }
                }
            } catch {
                print("⚠️ SSE error: \(error)")
            }
        }
        
        // Wait for SSE to connect
        try await Task.sleep(for: .milliseconds(500))
        
        // Step 3: Send a prompt
        print("💬 Sending prompt...")
        let promptURL = URL(string: "\(serverURL)/session/\(sessionID)/prompt_async")!
        var promptRequest = URLRequest(url: promptURL)
        promptRequest.httpMethod = "POST"
        promptRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let promptBody: [String: Any] = [
            "parts": [["type": "text", "text": "Say 'hello world' and nothing else"]]
        ]
        promptRequest.httpBody = try JSONSerialization.data(withJSONObject: promptBody)
        
        let (_, promptResponse) = try await URLSession.shared.data(for: promptRequest)
        
        guard let httpPromptResponse = promptResponse as? HTTPURLResponse else {
            Issue.record("Invalid prompt response")
            return
        }
        
        print("📤 Prompt response status: \(httpPromptResponse.statusCode)")
        #expect(httpPromptResponse.statusCode == 204 || httpPromptResponse.statusCode == 200, "Prompt should succeed")
        
        // Step 4: Wait for SSE events
        print("⏳ Waiting for SSE events...")
        let waitStartTime = Date()
        let maxWait: TimeInterval = 30
        
        while Date().timeIntervalSince(waitStartTime) < maxWait {
            try await Task.sleep(for: .milliseconds(500))
            
            // Check if we got events related to our session
            let sessionEvents = sseEvents.filter { event in
                event.data.contains(sessionID) || event.type == "server.connected"
            }
            
            // Look for completion or idle status
            let hasCompletion = sessionEvents.contains { event in
                event.data.contains("\"type\":\"idle\"") || 
                event.type == "session.idle" ||
                event.type == "message.part.delta" ||
                event.type == "message.updated"
            }
            
            if hasCompletion {
                print("✅ Received completion event")
                break
            }
            
            print("   Waiting... (\(Int(Date().timeIntervalSince(waitStartTime)))s) - \(sseEvents.count) events so far")
        }
        
        shouldStopSSE = true
        sseTask.cancel()
        
        // Step 5: Analyze results
        print("\n📊 Results:")
        print("   Total SSE events: \(sseEvents.count)")
        print("   Event types: \(sseEvents.map(\.type))")
        
        for event in sseEvents {
            print("\n   Event: \(event.type)")
            print("   Data: \(event.data.prefix(200))...")
        }
        
        // Filter events for our session
        let sessionEvents = sseEvents.filter { $0.data.contains(sessionID) || $0.type == "server.connected" }
        print("\n   Events for our session: \(sessionEvents.count)")
        
        #expect(sseEvents.count > 0, "Should receive SSE events")
        #expect(sessionEvents.count > 0, "Should receive events for our session")
        
        // Cleanup: Delete session
        print("\n🧹 Cleaning up session...")
        let deleteURL = URL(string: "\(serverURL)/session/\(sessionID)")!
        var deleteRequest = URLRequest(url: deleteURL)
        deleteRequest.httpMethod = "DELETE"
        
        _ = try? await URLSession.shared.data(for: deleteRequest)
        print("✅ Session deleted")
        
        print("\n✅ Integration test completed")
    }
    
    @Test("Poll session status after prompt")
    func testPollSessionStatus() async throws {
        print("\n🔄 Testing session status polling...")
        
        // Create session
        let createURL = URL(string: "\(serverURL)/session")!
        var createRequest = URLRequest(url: createURL)
        createRequest.httpMethod = "POST"
        createRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        createRequest.httpBody = "{}".data(using: .utf8)!
        
        let (createData, _) = try await URLSession.shared.data(for: createRequest)
        let sessionJSON = try JSONSerialization.jsonObject(with: createData) as? [String: Any]
        guard let sessionID = sessionJSON?["id"] as? String else {
            Issue.record("No session ID")
            return
        }
        print("✅ Created session: \(sessionID)")
        
        // Send prompt
        let promptURL = URL(string: "\(serverURL)/session/\(sessionID)/prompt_async")!
        var promptRequest = URLRequest(url: promptURL)
        promptRequest.httpMethod = "POST"
        promptRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        promptRequest.httpBody = try JSONSerialization.data(withJSONObject: [
            "parts": [["type": "text", "text": "Say 'test' only"]]
        ])
        _ = try await URLSession.shared.data(for: promptRequest)
        print("📤 Sent prompt")
        
        // Poll status
        var statuses: [String] = []
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < 30 {
            let statusURL = URL(string: "\(serverURL)/session/status")!
            var statusRequest = URLRequest(url: statusURL)
            statusRequest.httpMethod = "GET"
            statusRequest.setValue("application/json", forHTTPHeaderField: "Accept")
            
            let (statusData, _) = try await URLSession.shared.data(for: statusRequest)
            let statusJSON = try JSONSerialization.jsonObject(with: statusData) as? [String: Any]
            
            if let sessionStatus = statusJSON?[sessionID] as? [String: Any],
               let status = sessionStatus["type"] as? String {
                statuses.append(status)
                print("   Status: \(status)")
                
                if status == "idle" {
                    print("✅ Session went idle")
                    break
                }
            }
            
            try await Task.sleep(for: .milliseconds(500))
        }
        
        // Get messages
        let messagesURL = URL(string: "\(serverURL)/session/\(sessionID)/message")!
        var messagesRequest = URLRequest(url: messagesURL)
        messagesRequest.httpMethod = "GET"
        messagesRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (messagesData, _) = try await URLSession.shared.data(for: messagesRequest)
        let messagesJSON = try JSONSerialization.jsonObject(with: messagesData) as? [[String: Any]]
        
        print("\n📨 Messages count: \(messagesJSON?.count ?? 0)")
        if let messages = messagesJSON {
            for msg in messages {
                if let info = msg["info"] as? [String: Any],
                   let role = info["role"] as? String {
                    print("   - \(role) message")
                }
            }
        }
        
        // Cleanup
        let deleteURL = URL(string: "\(serverURL)/session/\(sessionID)")!
        var deleteRequest = URLRequest(url: deleteURL)
        deleteRequest.httpMethod = "DELETE"
        _ = try? await URLSession.shared.data(for: deleteRequest)
        
        #expect(statuses.contains("busy") || statuses.contains("idle"), "Should see busy or idle status")
    }
}
