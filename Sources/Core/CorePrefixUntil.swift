// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

extension Core {
  final class PrefixUntil<T: Sendable, U: Sendable> {
    let gage: Gage?
    let upstream: Subscribe<T>
    let until: Subscribe<U>

    init(gage: Gage?, upstream: @escaping Subscribe<T>, until: @escaping Subscribe<U>) {
      defer { Tracker.track(self) }
      self.gage = gage
      self.upstream = upstream
      self.until = until
    }

    @Sendable func subscribe(gage: Gage?, priority: TaskPriority, downstream: Pipe<T>) async {
      guard !Task.isCancelled else { return }
      let producer = Producer(gage, downstream)
      downstream.start(priority: priority, produce: producer.produce)
      await until(nil, priority, producer.until)
      await upstream(self.gage, priority, producer.upstream)
    }

    actor Producer {
      let upstream: Pipe<T> = .init()
      let until: Pipe<U> = .init()
      let downstream: Pipe<T>
      let source: AsyncStream<T?>.Continuation
      let target: AsyncStream<T?>
      var gager: Gager

      init(_ gage: Gage?, _ downstream: Pipe<T>) {
        defer { Tracker.track(self) }
        self.gager = Gager(gage: gage)
        self.downstream = downstream
        (self.target, self.source) = AsyncStream.makeStream(bufferingPolicy: .unbounded)
      }

      @Sendable func processUpstream() async {
        await withTaskCancellationHandler(operation: {
          var task: Task<Void, Never>?
          defer { task?.cancel() }
          for await event in upstream.stream {
            switch event {
            case let .start(priority, job):
              task = Tracker.detach(priority: priority, precancelled: true, job)
              guard !Task.isCancelled else { return }
            case let .advance(value):
              guard !Task.isCancelled else { return }
              guard case .enqueued = source.yield(value) else { return }
            case .finish:
              source.yield(nil)
              source.finish()
              return
            }
          }
        }, onCancel: upstream.cancel)
      }

      @Sendable func processUntill() async {
        await withTaskCancellationHandler(operation: {
          var task: Task<Void, Never>?
          defer { task?.cancel() }
          for await event in until.stream {
            switch event {
            case let .start(priority, job):
              task = Tracker.detach(priority: priority, precancelled: true, job)
              guard !Task.isCancelled else { return }
            case .advance, .finish:
              source.yield(nil)
              source.finish()
              return
            }
          }
        }, onCancel: until.cancel)
      }

      @Sendable nonisolated func stop() { source.finish() }

      @Sendable func produce() async {
        await withTaskCancellationHandler(operation: {
          await withTaskGroup(of: Void.self) { group in
            group.addTask(operation: processUntill)
            group.addTask(operation: processUpstream)
            defer {
              group.cancelAll()
              downstream.cancel()
            }
            for await value in target {
              guard !Task.isCancelled else { return }
              guard let value else { return downstream.finish() }
              guard let remaining = downstream.send(value) else { return }
              gager.report(remaining: remaining)
            }
          }
        }, onCancel: stop)
      }
    }
  }
}
