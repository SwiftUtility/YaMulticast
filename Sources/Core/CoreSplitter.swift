// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

extension Core {
  actor Splitter<T: Sendable> {
    let reply: Int
    let limit: Int?
    var started: Bool
    var cursor: Int = 0
    var finished: Bool = false
    var values: [T] = []
    var orders: [Set<UniqueKey>] = [[]]
    var pushers: [UniqueKey: Pusher] = [:]

    init(reply: UInt32, started: Bool, limit: Int?) {
      defer { Tracker.track(self) }
      self.limit = if let limit, limit > 0 { limit } else { nil }
      self.reply = Int(reply)
      self.started = started
    }

    func start() {
      guard !started else { return }
      started = true
      defer { clean() }
      guard let value = values.first, var order = orders.first else {
        if finished { orders[0].forEach(unregister(key:)) }
        return
      }
      var preorder = Set<UniqueKey>()
      for key in order {
        guard let pusher = pushers[key] else { continue }
        pusher.ready = false
        pusher.cursor += 1
        pusher.continuation.yield(value)
        order.remove(key)
        preorder.insert(key)
      }
      orders[0] = order
      orders[1] = preorder
    }

    func finish() {
      finished = true
      let position = values.count
      var keys = orders[position]
      for key in keys {
        guard let pusher = pushers.removeValue(forKey: key) else { continue }
        pusher.continuation.finish()
        keys.remove(key)
      }
      orders[position] = keys
      if started { clean() }
    }

    func push(value: T) {
      guard started else {
        orders.append([])
        values.append(value)
        return
      }
      let position = values.count
      var order = orders[position]
      var preorder = Set<UniqueKey>()
      for key in order {
        guard let pusher = pushers[key], pusher.ready else { continue }
        pusher.cursor += 1
        pusher.ready = false
        order.remove(key)
        preorder.insert(key)
        pusher.continuation.yield(value)
      }
      orders[position] = order
      orders.append(preorder)
      values.append(value)
      clean()
      let count = values.count - reply
      if let limit, count > limit {
        for key in orders[reply] {
          guard let gage = pushers[key]?.gage else { continue }
          gage.report(limit: limit)
          pushers[key]?.gage = nil
        }
      }
    }

    func prepare(key: UniqueKey) {
      guard started else { return }
      guard let pusher = pushers[key] else { return }
      let position = pusher.cursor - cursor
      if position < values.count {
        orders[position].remove(key)
        pusher.cursor += 1
        orders[position + 1].insert(key)
        pusher.ready = false
        pusher.continuation.yield(values[position])
        clean()
      } else if finished {
        orders[position].remove(key)
        pushers[key] = nil
        pusher.continuation.finish()
        clean()
      } else {
        pusher.ready = true
      }
    }

    func clean() {
      let threshold = values.count - reply
      var advance = 0
      while advance < threshold, orders[advance].isEmpty { advance += 1 }
      cursor += advance
      values.removeFirst(advance)
      orders.removeFirst(advance)
    }

    func register(key: UniqueKey, gage: Gage?) -> (AsyncStream<T>, Pusher) {
      let offset = started ? max(0, values.count - reply) : 0
      let (stream, continuation) = AsyncStream<T>.makeStream(bufferingPolicy: .unbounded)
      let pusher = Pusher(continuation: continuation, cursor: cursor + offset, gage: gage)
      pushers[key] = pusher
      orders[offset].insert(key)
      return (stream, pusher)
    }

    func unregister(key: UniqueKey) {
      guard let pusher = pushers.removeValue(forKey: key) else { return }
      orders[pusher.cursor - cursor].remove(key)
      clean()
      pusher.continuation.finish()
    }

    @Sendable func start(
      gageUp: Gage?,
      gageDown: Gage?,
      priority: TaskPriority,
      pipe: Pipe<T>
    ) async {
      guard !Task.isCancelled else { return }
      let key = UniqueKey()
      let (stream, _) = register(key: key, gage: gageUp)
      pipe.start(priority: priority) {
        var gageDown = gageDown
        defer { pipe.cancel() }
        for await value in stream {
          guard let remaining = pipe.send(value) else { break }
          if let gage = gageDown, gage.report(remaining: remaining) { gageDown = nil }
          await self.prepare(key: key)
        }
        pipe.finish()
        await self.unregister(key: key)
      }
    }

    @Sendable func start(
      key id: UniqueKey,
      stop: @escaping Stop,
      sink: Sink<T>,
      gage: Gage?
    ) async -> Work? {
      guard !Task.isCancelled else { return nil }
      let key = UniqueKey()
      let (stream, pusher) = register(key: key, gage: gage)
      return Work(priority: sink.priority, operation: {
        await withTaskCancellationHandler(
          operation: {
            for await value in stream {
              guard !Task.isCancelled else { break }
              await sink.send(value)
              await self.prepare(key: key)
            }
            await self.unregister(key: key)
            if !Task.isCancelled { await stop(id) }
          },
          onCancel: pusher.finish
        )
      })
    }

    final class Pusher: @unchecked Sendable {
      let continuation: AsyncStream<T>.Continuation
      var cursor: Int
      var ready: Bool = true
      var gage: Gage?

      init(continuation: AsyncStream<T>.Continuation, cursor: Int, gage: Gage?) {
        defer { Tracker.track(self) }
        self.continuation = continuation
        self.cursor = cursor
        self.gage = gage
      }

      @Sendable func finish() { continuation.finish() }
    }
  }
}
