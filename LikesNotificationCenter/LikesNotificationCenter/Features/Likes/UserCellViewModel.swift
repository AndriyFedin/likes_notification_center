import Foundation

struct UserCellViewModel: Hashable, Sendable {
    let id: String
    let name: String
    let photoURL: String
    
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    nonisolated static func == (lhs: UserCellViewModel, rhs: UserCellViewModel) -> Bool {
        return lhs.id == rhs.id
    }
}
