//
// Copyright (c) Vatsal Manot
//

import Merge
import SwiftUIX

public enum ViewReactorActionOrPlan<R: ViewReactor> {
    case action(R.Action)
    case plan(R.Plan)
}

/// A subscriber that attaches to a `ViewReactorTaskPublisher`.
public class ViewReactorTaskSubscriber<R: ViewReactor>: TaskSubscriber<Void, Error> {
    public typealias ActionOrPlan = ViewReactorActionOrPlan<R>
    
    private var reactor: R
    private var actionOrPlan: ActionOrPlan
    private var _cancellable: RetainUntilCancel<CancellableRetain<ViewReactorTaskSubscriber>>!
    private var cancellable: AnyCancellable!
    
    public init(reactor: R, actionOrPlan: ActionOrPlan) {
        self.reactor = reactor
        self.actionOrPlan = actionOrPlan
        
        super.init()
        
        self._cancellable = .init(.init(self))
        self.cancellable = .init(_cancellable)
        
        reactor.cancellables.insert(cancellable)
    }
    
    public convenience init(reactor: R, action: R.Action) {
        self.init(reactor: reactor, actionOrPlan: .action(action))
    }
    
    public convenience init(reactor: R, plan: R.Plan) {
        self.init(reactor: reactor, actionOrPlan: .plan(plan))
    }
    
    override public func receive(subscription: Task<Void, Error>) {
        switch actionOrPlan {
            case let .action(action):
                subscription.name = .init(action)
            case let .plan(plan):
                subscription.name = plan.createTaskName()
        }

        subscription.request(.unlimited)
        
        reactor.environment.taskManager?.taskStarted(subscription)
    }
    
    override public func receive(_ input: Input) -> Subscribers.Demand {
        return .unlimited
    }
    
    override public func receive(completion: Subscribers.Completion<Failure>) {
        reactor.environment.taskManager?.taskEnded(subscription!)
        
        _cancellable.cancel()
        _cancellable = nil
        
        cancellable.cancel()
        cancellable = nil
    }
}
