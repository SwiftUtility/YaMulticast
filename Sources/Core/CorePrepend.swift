// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

extension Core {
  final class Prepend<C: Collection> where C.Element: Sendable {
    let gage: Gage?
    let upstream: Subscribe<C.Element>
    let values: C

    init(gage: Gage?, upstream: @escaping Subscribe<C.Element>, values: C) {
      defer { Tracker.track(self) }
      self.gage = gage
      self.upstream = upstream
      self.values = values
    }

    @Sendable func subscribe(
      gage: Gage?,
      priority: TaskPriority,
      downstream: Pipe<C.Element>
    ) async {
      guard !Task.isCancelled else { return }
      let producer = Producer(gage, downstream, values)
      downstream.start(priority: priority, produce: producer.produce)
      await upstream(self.gage, priority, producer.upstream)
    }

    actor Producer {
      let upstream: Pipe<C.Element> = .init()
      let downstream: Pipe<C.Element>
      var values: [C.Element]
      var gager: Gager
      var active = true

      init(_ gage: Gage?, _ downstream: Pipe<C.Element>, _ values: C) {
        defer { Tracker.track(self) }
        self.gager = Gager(gage: gage)
        self.downstream = downstream
        self.values = values.reversed()
      }

      @Sendable func produce() async {
        await withTaskCancellationHandler(operation: {
          while let value = values.popLast() {
            guard downstream.send(value) == nil else { continue }
            active = false
            values = []
          }
          var task: Task<Void, Never>?
          defer {
            task?.cancel()
            downstream.cancel()
          }
          for await event in upstream.stream {
            switch event {
            case let .start(priority, job):
              task = Tracker.detach(priority: priority, precancelled: true, job)
              guard active, !Task.isCancelled else { return }
            case let .advance(value):
              guard !Task.isCancelled, let remaining = downstream.send(value) else { return }
              gager.report(remaining: remaining)
            case .finish: return downstream.finish()
            }
          }
        }, onCancel: upstream.cancel)
      }
    }
  }
}
