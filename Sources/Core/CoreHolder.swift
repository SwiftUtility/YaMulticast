// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

extension Core {
  actor Holder {
    let continuation: AsyncStream<[Start]>.Continuation
    let stream: AsyncStream<[Start]>
    var tasks: [UniqueKey: Task<Void, Never>] = [:]

    init() {
      defer { Tracker.track(self) }
      (stream, continuation) = AsyncStream<[Start]>.makeStream(bufferingPolicy: .unbounded)
    }

    @Sendable nonisolated func hold(duty: inout Duty) {
      let starts = duty.drain()
      guard !starts.isEmpty else { return }
      continuation.yield(starts)
    }

    @Sendable nonisolated func start() async {
      await withTaskCancellationHandler(operation: operation, onCancel: cancel)
    }

    @Sendable nonisolated func cancel() { continuation.finish() }
    @Sendable func stop(key: UniqueKey) async { tasks[key] = nil }
    @Sendable func operation() async {
      for await starts in stream {
        for start in starts.reversed() {
          let key = UniqueKey()
          guard let work = await start(key, stop(key:)) else { continue }
          tasks[key] = Tracker
            .detach(priority: work.priority, precancelled: true, work.operation)
        }
      }
      for task in tasks.values { task.cancel() }
      tasks = [:]
    }
  }
}
