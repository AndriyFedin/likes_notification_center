import Foundation

struct UserDTO: Codable {
    let id: String
    let name: String
    let photoURL: String
    let createdAt: Date
}

struct LikesResponse: Codable {
    let data: [UserDTO]
    let nextCursor: String?
}

protocol APIServiceProtocol {
    func fetchLikes(limit: Int, cursor: String?) async throws -> LikesResponse
    func fetchFeatureFlag() async throws -> Bool
    func performAction(userId: String, action: String) async throws
}

class MockAPIService: APIServiceProtocol {
    
    private let totalItems = 100
    
    func fetchLikes(limit: Int, cursor: String?) async throws -> LikesResponse {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 sec
        
        let startIndex = Int(cursor ?? "0") ?? 0
        let endIndex = min(startIndex + limit, totalItems)
        
        guard startIndex < totalItems else {
            return LikesResponse(data: [], nextCursor: nil)
        }
        
        let items: [UserDTO] = (startIndex..<endIndex).map { i in
            UserDTO(
                id: "user_\(i)",
                name: "User \(i)",
                photoURL: "https://robohash.org/\(i).png?set=set2",
                createdAt: Date().addingTimeInterval(TimeInterval(-i * 3600))
            )
        }
        
        let nextCursor = endIndex < totalItems ? "\(endIndex)" : nil
        return LikesResponse(data: items, nextCursor: nextCursor)
    }
    
    func fetchFeatureFlag() async throws -> Bool {
        try await Task.sleep(nanoseconds: 300_000_000)
        return true // Blur enabled by default
    }
    
    func performAction(userId: String, action: String) async throws {
        // Simulate success
        try await Task.sleep(nanoseconds: 200_000_000)
    }
}
