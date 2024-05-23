// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

extension Core {
  final class Bind<T: Sendable> {
    let gage: Gage?
    let upstream: Subscribe<T>
    let sink: Sink<T>

    init(
      gage: Gage?,
      upstream: @escaping Subscribe<T>,
      sink: Sink<T>
    ) {
      defer { Tracker.track(self) }
      self.gage = gage
      self.upstream = upstream
      self.sink = sink
    }

    @Sendable func work(
      key: UniqueKey,
      stop: @escaping Stop
    ) async -> Work? {
      guard !Task.isCancelled else { return nil }
      let producer = Producer(gage, key, stop, sink)
      await upstream(self.gage, sink.priority, producer.upstream)
      return Work(priority: sink.priority, operation: producer.produce)
    }

    actor Producer {
      let upstream: Pipe<T> = .init()
      let key: UniqueKey
      let stop: Stop
      let sink: Sink<T>
      var gager: Gager

      init(
        _ gage: Gage?,
        _ key: UniqueKey,
        _ stop: @escaping Stop,
        _ sink: Sink<T>
      ) {
        defer { Tracker.track(self) }
        self.gager = Gager(gage: gage)
        self.key = key
        self.stop = stop
        self.sink = sink
      }

      @Sendable func produce() async {
        await withTaskCancellationHandler(operation: {
          var task: Task<Void, Never>?
          defer { task?.cancel() }
          for await value in upstream.stream {
            switch value {
            case let .start(priority, job):
              task = Tracker.detach(priority: priority, precancelled: true, job)
              guard !Task.isCancelled else { return }
            case let .advance(value):
              guard !Task.isCancelled else { return }
              await sink.send(value)
            case .finish: return if !Task.isCancelled { await stop(key) } else { () }
            }
          }
        }, onCancel: upstream.finish)
      }
    }
  }
}
