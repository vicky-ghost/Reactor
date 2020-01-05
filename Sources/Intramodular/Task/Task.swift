//
// Copyright (c) Vatsal Manot
//

import Merge
import SwiftUIX

open class OpaqueTask: CustomCombineIdentifierConvertible {
    
}

/// An opinionated definition of a task.
open class Task<Success, Error: Swift.Error>: OpaqueTask, ObservableObject {
    private let lock = OSUnfairLock()
    
    public let cancellables = Cancellables()
    public let objectWillChange = PassthroughSubject<Status, Never>()
    
    private var startTask: ((Task<Success, Error>) -> Void)?
    
    private var _status: Status = .idle
    
    public var status: Status {
        get {
            lock.synchronize {
                _status
            }
        } set {
            lock.synchronize {
                objectWillChange.send(newValue)
                
                _status = newValue
            }
        }
    }
    
    public required init(start: @escaping (Task<Success, Error>) -> ()) {
        self.startTask = start
    }
    
    public convenience init<S: Subscriber, Artifact>(
        publisher: TaskPublisher<Success, Error, Artifact>,
        subscriber: S
    ) where S.Input == Output, S.Failure == Failure {
        self.init(
            start: { (subscriber as! TaskSubscriber<Success, Error, Artifact>).receive(artifact: publisher.body($0)) }
        )
        
        let subject = PassthroughSubject<Output, Failure>()
        
        subject.handleEvents(
            receiveSubscription: { _ in subscriber.receive(subscription: self) },
            receiveOutput: { _ = subscriber.receive($0) },
            receiveCompletion: { subscriber.receive(completion: $0) }
        ).subscribe(storeIn: cancellables)
    }
}

extension Task {
    /// Publish task progress.
    public func progress(_ progress: Progress?) {
        send(.progress(progress))
    }
    
    /// Publish task success.
    public func succeed(with value: Success) {
        send(.success(value))
    }
    
    /// Publish task failure.
    public func fail(with error: Error) {
        send(completion: .failure(.error(error)))
    }
    
    /// Publish task cancellation.
    public func cancel() {
        send(completion: .failure(.canceled))
    }
    
    public func receive(_ status: Status) {
        switch status {
            case .idle:
                fatalError() // FIXME
            case .started:
                request(.max(1))
            case .progress(let progress):
                self.progress(progress)
            case .canceled:
                cancel()
            case .success(let success):
                succeed(with: success)
            case .error(let error):
                fail(with: error)
        }
    }
}

// MARK: - Extensions -

extension Task {
    public func map<T>(_ transform: @escaping (Success) -> T) -> Task<T, Error> {
        let result = Task<T, Error>(start: { _ in self.startTask?(self) })
        
        objectWillChange.handleOutput {
            result.receive($0.map(transform))
        }
        .subscribe(storeIn: cancellables)
        
        return result
    }
}

// MARK: - Protocol Implementations -

extension Task: Publisher {
    open func receive<S: Subscriber>(
        subscriber: S
    ) where S.Input == Output, S.Failure == Failure {
        objectWillChange
            .prefixUntil(after: { $0.isTerminal })
            .setFailureType(to: Failure.self)
            .flatMap({ status -> AnyPublisher<Output, Failure> in
                if let output = status.output {
                    return Just(output)
                        .setFailureType(to: Failure.self)
                        .eraseToAnyPublisher()
                } else {
                    return Fail<Output, Failure>(error: status.failure!)
                        .eraseToAnyPublisher()
                }
            }).receive(subscriber: subscriber)
    }
}

extension Task: Subject {
    public func send(_ value: Output) {
        status = .init(value)
    }
    
    public func send(completion: Subscribers.Completion<Failure>) {
        lock.synchronize {
            switch completion {
                case .finished: do {
                    if !_status.isTerminal {
                        fatalError()
                    }
                }
                case .failure(let failure):
                    _status = .init(failure)
            }
            
            objectWillChange.send(_status)
        }
    }
    
    public func send(subscription: Subscription) {
        subscription.request(.unlimited)
    }
}

extension Task: Subscription {
    public func request(_ demand: Subscribers.Demand) {
        guard demand != .none else {
            return
        }
        
        lock.synchronize {
            if !_status.isIdle {
                startTask?(self)
                startTask = nil
            }
            
            _status = .started
            
            objectWillChange.send(.started)
        }
    }
}
