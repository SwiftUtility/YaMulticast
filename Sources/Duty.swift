// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

/// Temporary subscriptions storage.
///
/// - It records subscription instructions to apply it later in reversed order.
public struct Duty {
  var fund: Core.Fund

  /// Register an action to perform upon each emited item of Multicast.
  /// See [Subscribe on reactivex.io](https://reactivex.io/documentation/operators/subscribe.html)
  public mutating func bind<T: Sendable>(
    _ cast: Multicast<T>,
    limit: Int? = 100,
    file: StaticString = #fileID,
    line: UInt = #line,
    to sink: Sink<T>
  ) {
    let gage = Core.Gage(limit: limit, file: file, line: line)
    starts.append { key, stop in
      await cast.splitter.start(key: key, stop: stop, sink: sink, gage: gage)
    }
  }

  var starts: [Core.Start] {
    get { fund.starts }
    set {
      if isKnownUniquelyReferenced(&fund) { fund.starts = newValue }
      else { fund = fund.copy(starts: newValue) }
    }
  }

  mutating func drain() -> [Core.Start] {
    defer { starts = [] }
    return starts
  }
}

// MARK: Helpers

extension Duty {
  public mutating func bind<T: Sendable>(
    _ cast: Multicast<T>,
    priority: TaskPriority = .userInitiated, to send: @escaping Sink<T>.Send
  ) {
    bind(cast, to: Sink(priority: priority, send: send))
  }
}
