import UIKit
import Combine

protocol Coordinator: AnyObject {
    var navigationController: UINavigationController { get set }
    func start()
}

protocol LikesCoordinatorProtocol: Coordinator { }

final class AppCoordinator: LikesCoordinatorProtocol {
    var navigationController: UINavigationController
    
    // Dependencies (could be injected, but creating here for simplicity)
    private lazy var coreDataStack = CoreDataStack.shared
    private lazy var apiService = MockAPIService()
    private lazy var repository = LikesRepository(api: apiService, coreData: coreDataStack)
    private lazy var unblurService = UnblurService()
    
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    
    func start() {
        let viewModel = LikesViewModel(repository: repository, unblurService: unblurService, api: apiService, coordinator: self)
        let viewController = LikesViewController(viewModel: viewModel)
        navigationController.setViewControllers([viewController], animated: false)
    }
}
