// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

extension Plug {
  /// Output Node wrapper. Owner instance has exclusive access to its Node. Clients have access to
  /// its Cast via Wireable.
  public final class Export<Value: Sendable>: Sendable {
    public let node: Node<Value>

    init(node: Node<Value>) {
      defer { Tracker.track(self) }
      self.node = node
    }

    /// Create hot instance.
    public static func warm(
      reply: UInt32 = 0,
      priority: TaskPriority = .userInitiated,
      gage: Int? = 100
    ) -> Export {
      Self(node: Node.warm(reply: reply, priority: priority, gage: gage))
    }

    /// Create cold instance and record heatup action.
    public static func cold(
      duty: inout Duty,
      reply: UInt32 = 0,
      priority: TaskPriority = .userInitiated,
      gage: Int? = 100
    ) -> Export {
      Self(node: Node.cold(duty: &duty, reply: reply, priority: priority, gage: gage))
    }

    /// Terminates downstream cast.
    @Sendable public func finish() { node.finish() }
    /// Terminates downstream cast.
    @Sendable public func terminate(finished: Bool) { node.terminate(finished: finished) }
    /// Expose receiver interface.
    public var sink: Sink<Value> { node.sink }
    /// Send element downstream after heatup.
    public func send(_ value: Value) { node.send(value) }
    /// Send void downstream after heatup.
    public func fire() where Value == Void { node.fire() }
  }
}
