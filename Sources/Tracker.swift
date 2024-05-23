//
//  File.swift
//  
//
//  Created by Vladimir Borodko on 23.05.2024.
//

import Foundation

public enum Tracker {
  @MainActor public static var sideEffect: SideEffect? = nil
#if INTERNAL_BUILD
  /// For test purposes only (to check all spawned tasks did complete)
  @TaskLocal static var trackTask: ((Task<Void, Never>) -> Void)?
  /// For test purposes only (to check all objects were deallocated)
  @TaskLocal static var trackObject: ((AnyObject) -> Void)?
#endif

  @inline(__always)
  static func track(_ object: AnyObject) {
#if INTERNAL_BUILD
    if let trackObject { trackObject(object) }
#endif
  }

  @discardableResult
  @inline(__always)
  static func detach(
    priority: TaskPriority,
    precancelled: Bool,
    _ operation: @escaping @Sendable () async -> Void
  ) -> Task<Void, Never> {
    let precancelled = precancelled && Task.isCancelled
#if INTERNAL_BUILD
    let trackTask = trackTask
    let trackObject = trackObject
    let result = Task.detached(priority: priority) {
      await $trackTask.withValue(trackTask) {
        await $trackObject.withValue(trackObject) {
          if precancelled { withUnsafeCurrentTask { $0?.cancel() } }
          await operation()
        }
      }
    }
    if let trackTask { trackTask(result) }
    return result
#else
    return Task.detached(priority: priority) {
      if precancelled { withUnsafeCurrentTask { $0?.cancel() } }
      await operation()
    }
#endif
  }

  static func report(_ what: String, file: StaticString, line: UInt, call: StaticString) {
    detach(priority: .high, precancelled: false) {
      if let sideEffect = await sideEffect {
        await sideEffect(.init(what: what, file: file, line: line, call: call))
      }
    }
  }

  public typealias SideEffect = (Report) async -> Void

  public struct Report: Sendable {
    public let what: String
    public let file: StaticString
    public let line: UInt
    public let call: StaticString
  }

#if INTERNAL_BUILD
  enum Waiter {
    static func wait(operation: @Sendable () async throws -> Void) async rethrows -> Int {
      let (stream, continuation) = AsyncStream<Task<Void, Never>?>.makeStream()
      func send(value: Task<Void, Never>?) { continuation.yield(value) }
      try await Tracker.$trackTask.withValue(send(value:), operation: operation)
      send(value: nil)
      var count = 0
      var tasks: [Task<Void, Never>] = []
      for await task in stream {
        if let task {
          count += 1
          tasks.append(task)
        } else if tasks.isEmpty {
          continuation.finish()
        } else {
          while let task = tasks.popLast() { await task.value }
          send(value: nil)
        }
      }
      return count
    }
  }

  class Leaker {
    weak var object: AnyObject?
    init(object: AnyObject) { self.object = object }

    static func capture(operation: @Sendable () async throws -> Void) async rethrows -> [Leaker] {
      let (stream, continuation) = AsyncStream<Leaker>.makeStream()
      func collect(object: AnyObject) { continuation.yield(.init(object: object)) }
      try await Tracker.$trackObject.withValue(collect(object:)) {
        try await operation()
        continuation.finish()
      }
      var leakers: [Leaker] = []
      for await leaker in stream { leakers.append(leaker) }
      return leakers
    }
  }
#endif
}
