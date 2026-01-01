import CoreData

final class CoreDataStack {
    static let shared = CoreDataStack()
    
    private init() {}
    
    private lazy var managedObjectModel: NSManagedObjectModel = {
        let model = NSManagedObjectModel()
        
        let entity = NSEntityDescription()
        entity.name = UserProfile.entityName
        entity.managedObjectClassName = NSStringFromClass(UserProfile.self)
        
        let idAttr = NSAttributeDescription()
        idAttr.name = "id"
        idAttr.attributeType = .stringAttributeType
        idAttr.isOptional = false
        
        let nameAttr = NSAttributeDescription()
        nameAttr.name = "name"
        nameAttr.attributeType = .stringAttributeType
        nameAttr.isOptional = false
        
        let photoURLAttr = NSAttributeDescription()
        photoURLAttr.name = "photoURL"
        photoURLAttr.attributeType = .stringAttributeType
        photoURLAttr.isOptional = false
        
        let statusAttr = NSAttributeDescription()
        statusAttr.name = "status"
        statusAttr.attributeType = .integer16AttributeType
        statusAttr.isOptional = false
        statusAttr.defaultValue = 0
        
        let createdAtAttr = NSAttributeDescription()
        createdAtAttr.name = "createdAt"
        createdAtAttr.attributeType = .dateAttributeType
        createdAtAttr.isOptional = false
        
        entity.properties = [idAttr, nameAttr, photoURLAttr, statusAttr, createdAtAttr]
        
        model.entities = [entity]
        return model
    }()
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "LikesNotificationCenter", managedObjectModel: managedObjectModel)
        container.loadPersistentStores { description, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return container
    }()
    
    var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    func saveContext() {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        persistentContainer.performBackgroundTask(block)
    }
}
