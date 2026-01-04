import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    var coordinator: AppCoordinator?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let window = UIWindow(windowScene: windowScene)
        
        // DI Setup
        let coreDataStack = CoreDataStack.shared
        let apiService = MockAPIService()
        let repository = LikesRepository(api: apiService, coreData: coreDataStack)
        
        // Navigation
        let navController = UINavigationController()
        coordinator = AppCoordinator(navigationController: navController)
        
        let viewModel = LikesViewModel(repository: repository, api: apiService, coordinator: coordinator)
        let viewController = LikesViewController(viewModel: viewModel)
        
        navController.viewControllers = [viewController]
        
        window.rootViewController = navController
        window.makeKeyAndVisible()
        self.window = window
    }

    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {
        CoreDataStack.shared.saveContext()
    }
}