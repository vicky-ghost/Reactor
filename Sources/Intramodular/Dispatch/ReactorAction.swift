//
// Copyright (c) Vatsal Manot
//

import Merge
import SwiftUIX
import Task

public protocol opaque_ReactorAction: opaque_ReactorDispatchItem {
    
}

public protocol ReactorAction: opaque_ReactorAction, ReactorDispatchItem {
    
}

// MARK: - Helpers -

/// A control which dispatches a reactor action when triggered.
public struct ReactorDispatchActionButton<Label: View>: View {
    @usableFromInline
    let action: TaskName
    
    @usableFromInline
    let dispatch: () -> Task<Void, Error>
    
    @usableFromInline
    let label: Label
    
    @inlinable
    public init<R: ViewReactor>(
        action: R.Action,
        reactor: R,
        label: () -> Label
    ) {
        self.action = action.createTaskName()
        self.dispatch = { reactor.dispatch(action) }
        self.label = label()
    }
    
    @inlinable
    public var body: some View {
        TaskButton(action: dispatch, label: { label })
            .taskName(action)
    }
}

extension ViewReactor {
    @inlinable
    public func taskButton<Label: View>(
        for action: Action,
        @ViewBuilder label: () -> Label
    ) -> some View {
        ReactorDispatchActionButton(action: action, reactor: self, label: label)
    }
}
