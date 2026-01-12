import Foundation

protocol UnblurServiceProtocol {
    func getUnblurState() -> (isActive: Bool, expiresAt: Date?)
    func startUnblurTimer()
}

final class UnblurService: UnblurServiceProtocol {
    
    // UserDefaults keys
    private let kUnblurExpiresAt = "unblur_expires_at"
    
    init() {}
    
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
}
