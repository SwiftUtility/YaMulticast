// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

/// Async sequence reciever wrapper.
///
/// - It retains underlying send method.
/// - It utilises priority specified, and pass it upstream untill it is overwritten.
public final class Sink<Value: Sendable>: Sendable {
  let priority: TaskPriority
  let send: Send

  public init(priority: TaskPriority = .userInitiated, send: @escaping Send) {
    defer { Tracker.track(self) }
    self.priority = priority
    self.send = send
  }

  public typealias Send = @Sendable (Value) async -> Void
}
