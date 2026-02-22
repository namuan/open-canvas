import Foundation

struct OCSession: Codable, Identifiable, Sendable {
    let id: String
    let slug: String?
    let projectID: String?
    let directory: String?
    let title: String?
    let version: String?
    let time: OCTime?
    
    enum CodingKeys: String, CodingKey {
        case id
        case slug
        case projectID
        case directory
        case title
        case version
        case time
    }
    
    var createdAt: Date? {
        time?.created
    }
}

struct OCTime: Codable, Sendable {
    let created: Date?
    let updated: Date?
}

struct OCSessionCreateRequest: Codable, Sendable {
    let title: String?
    
    init(title: String? = nil) {
        self.title = title
    }
}

struct OCSessionPatchRequest: Codable, Sendable {
    let title: String
}
