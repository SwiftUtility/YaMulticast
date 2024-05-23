// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

extension Core {
  final class ForEach<T: Sendable> {
    let gage: Gage?
    let upstream: Subscribe<T>
    let heat: Heat?
    let start: Start?
    let emit: Emit?
    let terminate: Terminate?
    let cancel: Cancel?
    let finish: Finish?

    init(
      gage: Gage?,
      upstream: @escaping Subscribe<T>,
      heat: Heat?,
      start: Start?,
      emit: Emit?,
      terminate: Terminate?,
      cancel: Cancel?,
      finish: Finish?
    ) {
      defer { Tracker.track(self) }
      self.gage = gage
      self.upstream = upstream
      self.heat = heat
      self.start = start
      self.emit = emit
      self.terminate = terminate
      self.cancel = cancel
      self.finish = finish
    }

    @Sendable func subscribe(gage: Gage?, priority: TaskPriority, downstream: Pipe<T>) async {
      guard !Task.isCancelled else { return }
      await heat?()
      let producer = Producer(gage, downstream, start, emit, terminate, cancel, finish)
      downstream.start(priority: priority, produce: producer.produce)
      await upstream(self.gage, priority, producer.upstream)
    }

    typealias Heat = @Sendable () async -> Void
    typealias Start = @Sendable () async -> Void
    typealias Emit = @Sendable (T) async -> Void
    typealias Terminate = @Sendable (Bool) async -> Void
    typealias Cancel = @Sendable () async -> Void
    typealias Finish = @Sendable () async -> Void

    actor Producer {
      let upstream: Pipe<T> = .init()
      let downstream: Pipe<T>
      let start: Start?
      let emit: Emit?
      let terminate: Terminate?
      let cancel: Cancel?
      let finish: Finish?
      var gager: Gager

      init(
        _ gage: Gage?,
        _ downstream: Pipe<T>,
        _ start: Start?,
        _ emit: Emit?,
        _ terminate: Terminate?,
        _ cancel: Cancel?,
        _ finish: Finish?
      ) {
        defer { Tracker.track(self) }
        self.gager = Gager(gage: gage)
        self.downstream = downstream
        self.start = start
        self.emit = emit
        self.terminate = terminate
        self.cancel = cancel
        self.finish = finish
      }

      @Sendable func produce() async {
        await withTaskCancellationHandler(operation: {
          var task: Task<Void, Never>?
          precess: for await event in upstream.stream {
            switch event {
            case let .start(priority, job):
              await start?()
              task = Tracker.detach(priority: priority, precancelled: true, job)
              guard !Task.isCancelled else { break precess }
            case let .advance(value):
              guard !Task.isCancelled, let remaining = downstream.send(value)
              else { break precess }
              gager.report(remaining: remaining)
              await emit?(value)
            case .finish:
              task?.cancel()
              downstream.finish()
              downstream.cancel()
              await terminate?(true)
              await finish?()
              return
            }
          }
          task?.cancel()
          downstream.cancel()
          await terminate?(false)
          await cancel?()
        }, onCancel: upstream.cancel)
      }
    }
  }
}
