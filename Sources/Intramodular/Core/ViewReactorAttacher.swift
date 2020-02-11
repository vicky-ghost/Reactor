//
// Copyright (c) Vatsal Manot
//

import Merge
import SwiftUIX

private struct ViewReactorAttacher<Reactor: ViewReactor>: ViewModifier {
    let reactor: () -> Reactor
    
    func body(content: Content) -> some View {
        content
            .environmentReactor(self.reactor())
            .taskPipeline(self.reactor().environment.taskPipeline)
    }
}

private struct IndirectViewReactorAttacher<Reactor: ViewReactor>: ViewModifier {
    let reactor: () -> Reactor
    
    func body(content: Content) -> some View {
        content
            .environmentObject(self.reactor().environment.object)
            .environmentReactor(self.reactor())
            .taskPipeline(self.reactor().environment.taskPipeline)
    }
}

// MARK: - API -

extension View {
    public func attach<R: ViewReactor>(
        _ reactor: @autoclosure @escaping () -> R
    ) -> some View {
        modifier(ViewReactorAttacher(reactor: reactor))
    }
    
    public func attach<R: ViewReactor>(
        indirect reactor: @autoclosure @escaping () -> R
    ) -> some View {
        modifier(IndirectViewReactorAttacher(reactor: reactor))
    }
}