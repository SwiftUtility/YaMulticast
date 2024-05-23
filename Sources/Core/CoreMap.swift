// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

extension Core {
  final class Map<I: Sendable, O: Sendable> {
    let gage: Gage?
    let upstream: Subscribe<I>
    let transform: Transform

    init(gage: Gage?, upstream: @escaping Subscribe<I>, transform: @escaping Transform) {
      defer { Tracker.track(self) }
      self.gage = gage
      self.upstream = upstream
      self.transform = transform
    }

    @Sendable func subscribe(gage: Gage?, priority: TaskPriority, downstream: Pipe<O>) async {
      guard !Task.isCancelled else { return }
      let producer = Producer(gage, downstream, transform)
      downstream.start(priority: priority, produce: producer.produce)
      await upstream(self.gage, priority, producer.upstream)
    }

    typealias Transform = (I) async -> [O]

    actor Producer {
      let upstream: Pipe<I> = .init()
      let downstream: Pipe<O>
      let transform: Transform
      var gager: Gager

      init(_ gage: Gage?, _ downstream: Pipe<O>, _ transform: @escaping Transform) {
        defer { Tracker.track(self) }
        self.gager = Gager(gage: gage)
        self.downstream = downstream
        self.transform = transform
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
              let value = await transform(value)
              for value in value {
                guard let remaining = downstream.send(value) else { return }
                gager.report(remaining: remaining)
              }
            case .finish: return downstream.finish()
            }
          }
        }, onCancel: upstream.cancel)
      }
    }
  }
}
