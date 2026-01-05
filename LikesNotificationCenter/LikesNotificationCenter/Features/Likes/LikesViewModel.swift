import Foundation
import Combine
import CoreData

final class LikesViewModel {
    
    // MARK: - Inputs
    enum Input {
        case viewDidLoad
        case pullToRefresh
        case loadMore
        case like(String)
        case pass(String)
        case unblurAllTapped
        case segmentChanged(Int) // 0: Liked You (Incoming), 1: Mutual
    }
    
    // MARK: - Outputs
    @Published var items: [UserCellViewModel] = []
    @Published var isUnblurActive: Bool = false
    @Published var unblurTimeRemaining: String? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isFeatureEnabled: Bool = true
    @Published var currentFilter: UserProfile.Status = .incoming
    
    // MARK: - Computed Properties
    var areProfilesBlurred: Bool {
        if currentFilter == .mutual { return false }
        return !isUnblurActive
    }
    
    var areButtonsVisible: Bool {
        return currentFilter == .incoming
    }
    
    // MARK: - Dependencies
    private let repository: LikesRepositoryProtocol
    private let api: APIServiceProtocol
    private weak var coordinator: LikesCoordinatorProtocol?
    
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?
    
    // MARK: - Init
    init(repository: LikesRepositoryProtocol, api: APIServiceProtocol = MockAPIService(), coordinator: LikesCoordinatorProtocol?) {
        self.repository = repository
        self.api = api
        self.coordinator = coordinator
        
        setupBindings()
    }
    
    private func setupBindings() {
        // Observe Filter Change
        $currentFilter
            .removeDuplicates()
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.isLoading = true
            })
            .map { [unowned self] status in
                self.repository.likesPublisher(status: status)
            }
            .switchToLatest()
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .map { profiles in
                profiles.map { profile in
                    UserCellViewModel(
                        id: profile.id,
                        name: profile.name,
                        photoURL: profile.photoURL
                    )
                }
            }
            .receive(on: DispatchQueue.main)
            .handleEvents(receiveOutput: { [weak self] _ in
                self?.isLoading = false
            })
            .assign(to: \.items, on: self)
            .store(in: &cancellables)
    }

    // MARK: - Actions
    func send(_ input: Input) {
        switch input {
        case .viewDidLoad:
            fetchFeatureFlag()
            refresh()
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
        case .segmentChanged(let index):
            // 0 -> Incoming, 1 -> Mutual
            currentFilter = (index == 0) ? .incoming : .mutual
        }
    }
    
    // MARK: - Private Logic
    
    private func fetchFeatureFlag() {
        Task {
            do {
                let enabled = try await api.fetchFeatureFlag()
                await MainActor.run {
                     self.isFeatureEnabled = enabled
                     self.checkUnblurState() 
                }
            } catch {
                print("Failed to fetch feature flag: \(error)")
            }
        }
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
        
        // Flag = True -> Blur is ON (default).
        // Flag = False -> Blur is OFF.
        
        guard isFeatureEnabled else {
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
    
    func viewModel(for id: String) -> UserCellViewModel? {
        return items.first { $0.id == id }
    }
}
