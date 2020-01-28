//
// Copyright (c) Vatsal Manot
//

import SwiftUIX

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

extension UIViewController {
    public func trigger(
        _ transition: ViewTransition,
        animated: Bool,
        completion: @escaping () -> ()
    ) throws {
        switch transition.payload {
            case .present(let view): do {
                presentOnTop(view, named: transition.payloadViewName, animated: animated) {
                    completion()
                }
            }
            
            case .replacePresented(let view): do {
                if let viewController = topMostPresentedViewController?.presentingViewController {
                    viewController.dismiss { // FIXME: Does not respect `animated`!
                        viewController.presentOnTop(view, named: transition.payloadViewName, animated: animated) {
                            completion()
                        }
                    }
                } else {
                    self.presentOnTop(view, named: transition.payloadViewName, animated: animated) {
                        completion()
                    }
                }
            }
            
            case .dismiss: do {
                guard presentedViewController != nil else {
                    throw ViewRouterError.transitionError(.nothingToDismiss)
                }
                
                dismiss(animated: animated) {
                    completion()
                }
            }
            
            case .dismissView(let name): do {
                dismissView(named: name) { // FIXME: Does not respect `animated`!
                    completion()
                }
            }
            
            case .push(let view): do {
                guard let viewController = self as? UINavigationController else {
                    throw ViewRouterError.transitionError(.notANavigationController)
                }
                
                viewController.pushViewController(CocoaHostingController(rootView: view), animated: animated) {
                    completion()
                }
            }
            
            case .pop: do {
                guard let viewController = self as? UINavigationController else {
                    throw ViewRouterError.transitionError(.notANavigationController)
                }
                
                viewController.popViewController(animated: animated) {
                    completion()
                }
            }
            
            case .set(let view): do {
                if topMostPresentedViewController != nil {
                    dismiss { // FIXME: Does not respect `animated`!
                        self.presentOnTop(view, named: transition.payloadViewName, animated: true) {
                            completion()
                        }
                    }
                } else if let viewController = self as? UINavigationController {
                    viewController.setViewControllers([CocoaHostingController(rootView: view)], animated: animated)
                    
                    completion()
                } else if let window = self.view.window, window.rootViewController === self {
                    window.rootViewController = CocoaHostingController(rootView: view)
                    
                    completion()
                }
            }
            
            case .linear(var transitions): do {
                guard !transitions.isEmpty else {
                    return completion()
                }
                
                var _error: Error?
                
                try trigger(transitions.removeFirst(), animated: animated) {
                    do {
                        try self.trigger(.linear(transitions), animated: animated) {
                            completion()
                        }
                    } catch {
                        _error = error
                    }
                }
                
                if let error = _error {
                    throw error
                }
            }
            
            case .dynamic: do {
                fatalError()
            }
        }
    }
    
    public func presentOnTop<V: View>(
        _ view: V,
        named viewName: ViewName?,
        animated: Bool,
        completion: (() -> Void)? = nil
    ) {
        topMostViewController.present(
            view,
            named: viewName,
            onDismiss: nil,
            style: .automatic,
            completion: completion
        )
    }
}

extension ViewTransition {
    func triggerPublisher<VC: ViewCoordinator>(in window: UIWindow, animated: Bool, coordinator: VC) -> AnyPublisher<ViewTransitionContext, ViewRouterError> {
        let transition = mergeCoordinator(coordinator)
        
        if case .dynamic(let trigger) = transition.payload {
            return trigger()
        }
        
        return Future { attemptToFulfill in
            switch transition.payload {
                case .set(let view): do {
                    window.rootViewController = CocoaHostingController(rootView: view)
                }
                
                default: do {
                    do {
                        try window.rootViewController!.trigger(transition, animated: animated) {
                            attemptToFulfill(.success(self))
                        }
                    } catch {
                        attemptToFulfill(.failure(.init(error)))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

extension ViewTransition {
    func triggerPublisher<VC: ViewCoordinator>(in controller: UIViewController, animated: Bool, coordinator: VC) -> AnyPublisher<ViewTransitionContext, ViewRouterError> {
        let transition = mergeCoordinator(coordinator)
        
        if case .dynamic(let trigger) = transition.payload {
            return trigger()
        }
        
        return Future { attemptToFulfill in
            do {
                try controller.trigger(transition, animated: animated) {
                    attemptToFulfill(.success(transition))
                }
            } catch {
                attemptToFulfill(.failure(.init(error)))
            }
        }
        .eraseToAnyPublisher()
    }
}

#endif