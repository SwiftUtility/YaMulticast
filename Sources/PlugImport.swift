// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

extension Plug {
  /// Output Node wrapper. Owner instance has exclusive access to its Node. Clients have access to
  /// its Sink via Wireable.
  public final class Import<Value: Sendable>: Sendable {
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
    ) -> Import {
      Self(node: Node.warm(reply: reply, priority: priority, gage: gage))
    }

    /// Create cold instance and record heatup action.
    public static func cold(
      duty: inout Duty,
      reply: UInt32 = 0,
      priority: TaskPriority = .userInitiated,
      gage: Int? = 100
    ) -> Import {
      Self(node: Node.cold(duty: &duty, reply: reply, priority: priority, gage: gage))
    }

    /// Expose Cast interface.
    public func cast(
      file: StaticString = #fileID,
      line: UInt = #line,
      gage: Int? = 100
    ) -> Cast<Value> {
      node.multicast.cast(file: file, line: line, gage: gage)
    }
  }
}
