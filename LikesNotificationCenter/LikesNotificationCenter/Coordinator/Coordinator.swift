import UIKit

protocol Coordinator: AnyObject {
    var navigationController: UINavigationController { get set }
    func start()
}

protocol LikesCoordinatorProtocol: Coordinator {
    func showMutuals()
}

class AppCoordinator: LikesCoordinatorProtocol {
    var navigationController: UINavigationController
    
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    
    func start() {
        // Will be implemented when the ViewController is ready
    }
    
    func showMutuals() {
        // Will navigate to the Mutuals tab/screen
    }
}
