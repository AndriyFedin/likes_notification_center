import Foundation
import CoreData
import Combine

final class FRCSubscription<S: Subscriber, ResultType: NSFetchRequestResult>: NSObject, NSFetchedResultsControllerDelegate, Subscription where S.Input == [ResultType], S.Failure == Never {
    private var subscriber: S?
    private let controller: NSFetchedResultsController<ResultType>
    
    init(subscriber: S, controller: NSFetchedResultsController<ResultType>) {
        self.subscriber = subscriber
        self.controller = controller
        super.init()
        
        self.controller.delegate = self
        do {
            try self.controller.performFetch()
            if let objects = self.controller.fetchedObjects {
                 _ = subscriber.receive(objects)
            } else {
                 _ = subscriber.receive([])
            }
        } catch {
            print("FRC Fetch Error: \(error)")
        }
    }
    
    func request(_ demand: Subscribers.Demand) {
        // We push updates, so demand is ignored
    }
    
    func cancel() {
        subscriber = nil
        // Removing delegate stops updates
        controller.delegate = nil 
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        guard let objects = controller.fetchedObjects as? [ResultType] else { return }
        _ = subscriber?.receive(objects)
    }
}

public struct FRCPublisher<ResultType: NSFetchRequestResult>: Publisher {
    public typealias Output = [ResultType]
    public typealias Failure = Never
    
    private let controller: NSFetchedResultsController<ResultType>
    
    public init(controller: NSFetchedResultsController<ResultType>) {
        self.controller = controller
    }
    
    public func receive<S>(subscriber: S) where S : Subscriber, Never == S.Failure, [ResultType] == S.Input {
        let subscription = FRCSubscription(subscriber: subscriber, controller: controller)
        subscriber.receive(subscription: subscription)
    }
}
