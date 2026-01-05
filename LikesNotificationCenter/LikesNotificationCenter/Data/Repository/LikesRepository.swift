import Foundation
import CoreData
import Combine

protocol LikesRepositoryProtocol {
    func refresh() async throws
    func loadMore() async throws
    func likeUser(userId: String) async throws
    func passUser(userId: String) async throws
    func getUnblurState() -> (isActive: Bool, expiresAt: Date?)
    func startUnblurTimer()
    func likesPublisher(status: UserProfile.Status) -> AnyPublisher<[UserProfile], Never>
}

final class LikesRepository: LikesRepositoryProtocol {
    
    private let api: APIServiceProtocol
    private let coreData: CoreDataStack
    private var currentCursor: String?
    private var isFetching = false
    
    // UserDefaults keys
    private let kUnblurExpiresAt = "unblur_expires_at"
    
    init(api: APIServiceProtocol = MockAPIService(), coreData: CoreDataStack = .shared) {
        self.api = api
        self.coreData = coreData
    }
    
    // MARK: - Data Sync
    
    func refresh() async throws {
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }
        
        let response = try await api.fetchLikes(limit: 20, cursor: nil)
        self.currentCursor = response.nextCursor
        
        coreData.performBackgroundTask { context in
            self.saveUsers(response.data, context: context)
        }
    }
    
    func loadMore() async throws {
        guard !isFetching, let cursor = currentCursor else { return }
        isFetching = true
        defer { isFetching = false }
        
        let response = try await api.fetchLikes(limit: 20, cursor: cursor)
        self.currentCursor = response.nextCursor
        
        coreData.performBackgroundTask { context in
            self.saveUsers(response.data, context: context)
        }
    }
    
    private func saveUsers(_ users: [UserDTO], context: NSManagedObjectContext) {
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        for dto in users {
            let request = NSFetchRequest<UserProfile>(entityName: UserProfile.entityName)
            request.predicate = NSPredicate(format: "id == %@", dto.id)
            
            let profile: UserProfile
            if let result = try? context.fetch(request).first {
                profile = result
            } else {
                profile = UserProfile(context: context)
                profile.id = dto.id
                profile.status = UserProfile.Status.incoming.rawValue
            }
            
            profile.name = dto.name
            profile.photoURL = dto.photoURL
            profile.createdAt = dto.createdAt
        }
        
        if context.hasChanges {
            try? context.save()
        }
    }
    
    // MARK: - Actions
    
    func likeUser(userId: String) async throws {
        // 1. Optimistic Update: Move to Mutual
        await updateStatus(userId: userId, status: .mutual)
        
        do {
            // 2. Call API
            try await api.performAction(userId: userId, action: "like")
        } catch {
            // 3. Rollback on failure: Move back to Incoming
            print("Like failed, rolling back: \(error)")
            await updateStatus(userId: userId, status: .incoming)
            throw error
        }
    }
    
    func passUser(userId: String) async throws {
        // 1. Optimistic Update: Move to Passed (Removed from view)
        await updateStatus(userId: userId, status: .passed)
        
        do {
            // 2. Call API
            try await api.performAction(userId: userId, action: "pass")
        } catch {
            // 3. Rollback on failure: Move back to Incoming
            print("Pass failed, rolling back: \(error)")
            await updateStatus(userId: userId, status: .incoming)
            throw error
        }
    }
    
    private func updateStatus(userId: String, status: UserProfile.Status) async {
        coreData.performBackgroundTask { context in
            let request = NSFetchRequest<UserProfile>(entityName: UserProfile.entityName)
            request.predicate = NSPredicate(format: "id == %@", userId)
            
            if let profile = try? context.fetch(request).first {
                profile.status = status.rawValue
                try? context.save()
            }
        }
    }
    
    // MARK: - Unblur Timer
    
    func getUnblurState() -> (isActive: Bool, expiresAt: Date?) {
        guard let date = UserDefaults.standard.object(forKey: kUnblurExpiresAt) as? Date else {
            return (false, nil)
        }
        
        if date > Date() {
            return (true, date)
        } else {
            return (false, nil)
        }
    }
    
    func startUnblurTimer() {
        let expirationDate = Date().addingTimeInterval(120) // 2 minutes
        UserDefaults.standard.set(expirationDate, forKey: kUnblurExpiresAt)
    }
    
    // MARK: - Reactive Data Source

    func likesPublisher(status: UserProfile.Status) -> AnyPublisher<[UserProfile], Never> {
        let request = NSFetchRequest<UserProfile>(entityName: UserProfile.entityName)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        request.predicate = NSPredicate(format: "status == %d", status.rawValue)
        
        let frc = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: coreData.context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        return FRCPublisher(controller: frc).eraseToAnyPublisher()
    }
}
