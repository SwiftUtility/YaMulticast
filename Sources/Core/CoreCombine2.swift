// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

extension Core {
  final class Combine2<I1: Sendable, I2: Sendable, O: Sendable> {
    let gageup: Gage?
    let upstream1: Subscribe<I1>
    let upstream2: Subscribe<I2>
    let transform: Transform

    init(
      gageup: Gage?,
      upstream1: @escaping Subscribe<I1>,
      upstream2: @escaping Subscribe<I2>,
      transform: @escaping Transform
    ) {
      defer { Tracker.track(self) }
      self.gageup = gageup
      self.upstream1 = upstream1
      self.upstream2 = upstream2
      self.transform = transform
    }

    @Sendable func subscribe(gage: Gage?, priority: TaskPriority, downstream: Pipe<O>) async {
      guard !Task.isCancelled else { return }
      let producer = Producer(up: gageup, down: gage, downstream, transform)
      downstream.start(priority: priority, produce: producer.produce)
      await upstream1(nil, priority, producer.upstream1)
      await upstream2(nil, priority, producer.upstream2)
    }

    typealias Transform = (I1, I2) async -> O

    actor Producer {
      let upstream1: Pipe<I1> = .init()
      let upstream2: Pipe<I2> = .init()
      let source: AsyncStream<(I1, I2)?>.Continuation
      let target: AsyncStream<(I1, I2)?>
      let downstream: Pipe<O>
      let transform: Transform
      var up: Gager
      var down: Gager
      var value1: I1?
      var value2: I2?
      var active: Int = 2

      init(
        up: Gage?,
        down: Gage?,
        _ downstream: Pipe<O>,
        _ transform: @escaping Transform
      ) {
        defer { Tracker.track(self) }
        self.up = Gager(gage: up)
        self.down = Gager(gage: down)
        self.downstream = downstream
        self.transform = transform
        (self.target, self.source) = AsyncStream<(I1, I2)?>.makeStream(bufferingPolicy: .unbounded)
      }

      @Sendable func process1() async {
        await withTaskCancellationHandler(operation: {
          var task: Task<Void, Never>?
          defer { task?.cancel() }
          for await event in upstream1.stream {
            switch event {
            case let .start(priority, job):
              task = Tracker.detach(priority: priority, precancelled: true, job)
              guard !Task.isCancelled else { return }
            case let .advance(value):
              value1 = value
              guard deliver() else { return }
            case .finish:
              active -= 1
              if value1 != nil, active > 0 { return } else {
                source.yield(nil)
                return source.finish()
              }
            }
          }
        }, onCancel: upstream1.cancel)
      }

      @Sendable func process2() async {
        await withTaskCancellationHandler(operation: {
          var task: Task<Void, Never>?
          defer { task?.cancel() }
          for await event in upstream2.stream {
            switch event {
            case let .start(priority, job):
              task = Tracker.detach(priority: priority, precancelled: true, job)
              guard !Task.isCancelled else { return }
            case let .advance(value):
              value2 = value
              guard deliver() else { return }
            case .finish:
              active -= 1
              if value2 != nil, active > 0 { return } else {
                source.yield(nil)
                return source.finish()
              }
            }
          }
        }, onCancel: upstream2.cancel)
      }

      func deliver() -> Bool {
        guard !Task.isCancelled else { return false }
        guard let value1, let value2 else { return true }
        guard case let .enqueued(remaining: remaining) = source.yield((value1, value2))
        else { return false }
        up.report(remaining: remaining)
        return true
      }

      @Sendable nonisolated func stop() { source.finish() }

      @Sendable func produce() async {
        await withTaskCancellationHandler(operation: {
          await withTaskGroup(of: Void.self) { group in
            group.addTask(operation: process1)
            group.addTask(operation: process2)
            defer {
              group.cancelAll()
              downstream.cancel()
            }
            for await value in target {
              guard !Task.isCancelled else { return }
              guard let value else { return downstream.finish() }
              let result = await transform(value.0, value.1)
              guard let remaining = downstream.send(result) else { return }
              down.report(remaining: remaining)
            }
          }
        }, onCancel: stop)
      }
    }
  }
}
