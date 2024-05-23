// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

extension Core {
  final class Pipe<T: Sendable>: Sendable {
    let stream: AsyncStream<Event>
    let continuation: AsyncStream<Event>.Continuation

    init() {
      defer { Tracker.track(self) }
      (self.stream, self.continuation) = AsyncStream.makeStream(bufferingPolicy: .unbounded)
    }

    @discardableResult @Sendable func send(_ value: T) -> Int? {
      if case let .enqueued(remaining: remaining) = continuation.yield(.advance(value)) {
        remaining
      } else {
        nil
      }
    }

    @Sendable func finish() { continuation.yield(.finish) }
    @Sendable func cancel() { continuation.finish() }

    @Sendable func start(priority: TaskPriority, produce: @escaping Job) {
      continuation.yield(.start(priority, produce))
    }

    enum Event {
      case start(TaskPriority, Job)
      case advance(T)
      case finish
    }
  }
}
