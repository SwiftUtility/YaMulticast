// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

/// Async sequence producer and receiver in one.
///
/// - It completes when deallocated.
/// - It utilises priority specified, and pass it upstream untill it is overwritten.
/// - Its subscribers receive elements each with its own speed.
/// - It is implementation detail, for public API expose either its Sink or Multicast.
public final class Node<Value: Sendable>: Sendable {
  let continuation: AsyncStream<Value>.Continuation
  let priority: TaskPriority
  let splitter: Core.Splitter<Value>

  deinit { continuation.finish() }

  init(reply: UInt32, started: Bool, priority: TaskPriority, limit: Int?) {
    defer { Tracker.track(self) }
    let (stream, continuation) = AsyncStream<Value>.makeStream(bufferingPolicy: .unbounded)
    self.continuation = continuation
    self.splitter = .init(reply: reply, started: started, limit: limit)
    self.priority = priority

    Tracker.detach(priority: priority, precancelled: false) { [splitter] in
      for await value in stream {
        await splitter.push(value: value)
      }
      await splitter.finish()
    }
  }

  /// Create hot instance.
  public static func warm(
    reply: UInt32 = 0,
    priority: TaskPriority = .userInitiated,
    gage: Int? = 100
  ) -> Node {
    Node(reply: reply, started: true, priority: priority, limit: gage)
  }

  /// Create cold instance and record heatup action.
  public static func cold(
    duty: inout Duty,
    reply: UInt32 = 0,
    priority: TaskPriority = .userInitiated,
    gage: Int? = 100
  ) -> Node {
    let result = Node(reply: reply, started: false, priority: priority, limit: gage)
    duty.starts.append { [splitter = result.splitter] _, _ in
      await splitter.start()
      return nil
    }
    return result
  }

  /// Expose receiver interface.
  public var sink: Sink<Value> { Sink(priority: priority, send: send(_:)) }
  /// Terminates downstream cast.
  @Sendable public func finish() { continuation.finish() }
  /// Terminates downstream cast.
  @Sendable public func terminate(finished _: Bool) { continuation.finish() }
  /// Send element downstream after heatup.
  @Sendable public func send(_ value: Value) { continuation.yield(value) }
  /// Send void downstream after heatup.
  @Sendable public func fire() where Value == Void { continuation.yield(()) }
  /// Expose producer interface.
  public var multicast: Multicast<Value> { Multicast(splitter: splitter) }
  /// Expose Cast interface.
  public func cast(
    file: StaticString = #fileID,
    line: UInt = #line,
    gage: Int? = 100
  ) -> Cast<Value> {
    multicast.cast(file: file, line: line, gage: gage)
  }
}
