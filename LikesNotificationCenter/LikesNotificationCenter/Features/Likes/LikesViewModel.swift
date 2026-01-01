import Foundation
import Combine
import CoreData

class LikesViewModel {
    
    // MARK: - Inputs
    enum Input {
        case viewDidLoad
        case pullToRefresh
        case loadMore
        case like(String)
        case pass(String)
        case unblurAllTapped
    }
    
    // MARK: - Outputs
    @Published var isUnblurActive: Bool = false
    @Published var unblurTimeRemaining: String? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isFeatureEnabled: Bool = false // New Output for Feature Flag
    
    // MARK: - Dependencies
    private let repository: LikesRepositoryProtocol
    private let api: APIServiceProtocol // Need API for feature flag check directly or via repo
    
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?
    
    // MARK: - Init
    init(repository: LikesRepositoryProtocol, api: APIServiceProtocol = MockAPIService()) {
        self.repository = repository
        self.api = api
        
        setupTimerCheck()
    }
    
    private func setupTimerCheck() {
         // Logic will be triggered by viewDidLoad
    }

    // MARK: - Actions
    func send(_ input: Input) {
        switch input {
        case .viewDidLoad:
            fetchFeatureFlag()
            fetchData()
            checkUnblurState()
        case .pullToRefresh:
            refresh()
        case .loadMore:
            loadMoreData()
        case .like(let id):
            performLike(id)
        case .pass(let id):
            performPass(id)
        case .unblurAllTapped:
            activateUnblur()
        }
    }
    
    // MARK: - Private Logic
    
    private func fetchFeatureFlag() {
        Task {
            do {
                let enabled = try await api.fetchFeatureFlag()
                await MainActor.run {
                     self.isFeatureEnabled = enabled
                     // Re-evaluate blur state based on flag
                     self.checkUnblurState() 
                }
            } catch {
                print("Failed to fetch feature flag: \(error)")
            }
        }
    }

    private func fetchData() {
        refresh()
    }
    
    private func refresh() {
        isLoading = true
        Task {
            do {
                try await repository.refresh()
            } catch {
                self.errorMessage = error.localizedDescription
            }
            self.isLoading = false
        }
    }
    
    private func loadMoreData() {
        Task {
            try? await repository.loadMore()
        }
    }
    
    private func performLike(_ id: String) {
        Task {
            do {
                try await repository.likeUser(userId: id)
            } catch {
                self.errorMessage = "Failed to like user"
            }
        }
    }
    
    private func performPass(_ id: String) {
        Task {
            do {
                try await repository.passUser(userId: id)
            } catch {
                self.errorMessage = "Failed to pass user"
            }
        }
    }
    
    // MARK: - Unblur Timer Logic
    
    private func activateUnblur() {
        repository.startUnblurTimer()
        checkUnblurState()
    }
    
    private func checkUnblurState() {
        let state = repository.getUnblurState()
        
        // If feature is disabled, items might be permanently unblurred or blurred depending on requirements.
        // Assuming: If feature flag is OFF, items are always visible (unblurred).
        // If feature flag is ON, they are blurred unless timer is active.
        
        // Actually, requirement says: "Items in Liked You may be blurred depending on a feature flag."
        // Let's assume: Flag = True -> Blur is ON (default). Flag = False -> Blur is OFF.
        
        if !isFeatureEnabled {
             // If feature "Blur" is not enabled, then content is Unblurred (Active = true)
             // But we don't need a timer.
             isUnblurActive = true 
             stopCountdown()
             return
        }
        
        isUnblurActive = state.isActive
        
        if state.isActive, let expiresAt = state.expiresAt {
            startCountdown(expiresAt: expiresAt)
        } else {
            stopCountdown()
        }
    }
    
    private func startCountdown(expiresAt: Date) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            let remaining = expiresAt.timeIntervalSinceNow
            if remaining <= 0 {
                self?.stopCountdown()
                self?.isUnblurActive = false
            } else {
                self?.unblurTimeRemaining = self?.formatTime(remaining)
            }
        }
        // Fire immediately to set initial label
        let remaining = expiresAt.timeIntervalSinceNow
        if remaining > 0 {
             self.unblurTimeRemaining = self.formatTime(remaining)
        }
    }
    
    private func stopCountdown() {
        timer?.invalidate()
        timer = nil
        unblurTimeRemaining = nil
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d", m, s)
    }
}
