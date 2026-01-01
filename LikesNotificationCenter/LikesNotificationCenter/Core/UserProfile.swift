import CoreData

@objc(UserProfile)
public class UserProfile: NSManagedObject {
    @NSManaged public var id: String
    @NSManaged public var name: String
    @NSManaged public var photoURL: String
    @NSManaged public var status: Int16 // 0: incoming, 1: mutual, 2: passed
    @NSManaged public var createdAt: Date
}

extension UserProfile {
    static var entityName: String { "UserProfile" }
    
    enum Status: Int16 {
        case incoming = 0
        case mutual = 1
        case passed = 2
    }
    
    var profileStatus: Status {
        get { Status(rawValue: status) ?? .incoming }
        set { status = newValue.rawValue }
    }
}