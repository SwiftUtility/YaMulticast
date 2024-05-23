// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

extension Core {
  final class PrefixWhile<T: Sendable> {
    let gage: Gage?
    let upstream: Subscribe<T>
    let include: Include

    init(gage: Gage?, upstream: @escaping Subscribe<T>, include: @escaping Include) {
      defer { Tracker.track(self) }
      self.gage = gage
      self.upstream = upstream
      self.include = include
    }

    @Sendable func subscribe(gage: Gage?, priority: TaskPriority, downstream: Pipe<T>) async {
      guard !Task.isCancelled else { return }
      let producer = Producer(gage, downstream, include)
      downstream.start(priority: priority, produce: producer.produce)
      await upstream(self.gage, priority, producer.upstream)
    }

    typealias Include = @Sendable (T) async -> Bool

    actor Producer {
      let upstream: Pipe<T> = .init()
      let downstream: Pipe<T>
      let include: Include
      var gager: Gager

      init(_ gage: Gage?, _ downstream: Pipe<T>, _ include: @escaping Include) {
        defer { Tracker.track(self) }
        self.gager = Gager(gage: gage)
        self.downstream = downstream
        self.include = include
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
            case let .advance(value):
              guard !Task.isCancelled else { return }
              guard await include(value) else { return downstream.finish() }
              guard let remaining = downstream.send(value) else { return }
              gager.report(remaining: remaining)
            case .finish: return downstream.finish()
            }
          }
        }, onCancel: upstream.cancel)
      }
    }
  }
}
