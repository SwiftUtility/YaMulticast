// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

enum Core {
  typealias Job = @Sendable () async -> Void
  typealias Stop = @Sendable (UniqueKey) async -> Void
  typealias Subscribe<T: Sendable> = @Sendable (Gage?, TaskPriority, Pipe<T>) async -> Void
  typealias Start = (_ key: UniqueKey, _ stop: @escaping Stop) async -> Work?
  typealias Advance<T: Sendable> = @Sendable () async -> [T?]

  struct Work {
    let priority: TaskPriority
    let operation: Job
  }
}
