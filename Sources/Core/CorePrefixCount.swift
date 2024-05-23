// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

extension Core {
  final class PrefixCount<T: Sendable> {
    let gage: Gage?
    let upstream: Subscribe<T>
    let count: Int

    init(gage: Gage?, upstream: @escaping Subscribe<T>, count: Int) {
      defer { Tracker.track(self) }
      self.gage = gage
      self.upstream = upstream
      self.count = count
    }

    @Sendable func subscribe(gage: Gage?, priority: TaskPriority, downstream: Pipe<T>) async {
      guard !Task.isCancelled else { return }
      let producer = Producer(gage, downstream, count)
      downstream.start(priority: priority, produce: producer.produce)
      await upstream(self.gage, priority, producer.upstream)
    }

    actor Producer {
      let upstream: Pipe<T> = .init()
      let downstream: Pipe<T>
      var count: Int
      var gager: Gager

      init(_ gage: Gage?, _ downstream: Pipe<T>, _ count: Int) {
        defer { Tracker.track(self) }
        self.gager = Gager(gage: gage)
        self.downstream = downstream
        self.count = count
      }

      @Sendable func produce() async {
        await withTaskCancellationHandler(operation: {
          var task: Task<Void, Never>?
          defer {
            task?.cancel()
            downstream.cancel()
          }
          for await event in upstream.stream {
            switch event {
            case let .start(priority, job):
              task = Tracker.detach(priority: priority, precancelled: true, job)
              guard !Task.isCancelled else { return }
              guard count > 0 else { return downstream.finish() }
            case let .advance(value):
              guard !Task.isCancelled else { return }
              guard let remaining = downstream.send(value) else { return }
              gager.report(remaining: remaining)
              count -= 1
              guard count > 0 else { return downstream.finish() }
            case .finish: return downstream.finish()
            }
          }
        }, onCancel: upstream.cancel)
      }
    }
  }
}
