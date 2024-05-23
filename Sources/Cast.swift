// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

/// Lazy async sequence wrapper.
///
/// - Storing as property leads to **retain cycles** consider returning as result of function call.
/// - Each subscription creates separate pipeline.
/// - It will start activities upon subscription, **NOT** upon creation.
/// - It will free all resources upon completion or cancellation.
public final class Cast<Value: Sendable>: Sendable {
  let upstream: Core.Subscribe<Value>

  init(_ upstream: @escaping Core.Subscribe<Value>) {
    defer { Tracker.track(self) }
    self.upstream = upstream
  }

  /// When an item is emitted by either of Casts, emit the latest items emitted by each Cast.
  /// See [CombineLatest on
  /// reactivex.io](https://reactivex.io/documentation/operators/combinelatest.html)
  public static func combineLatest<T1: Sendable, T2: Sendable>(
    _ cast1: Cast<T1>,
    _ cast2: Cast<T2>,
    _ transform: @escaping @Sendable (T1, T2) async -> Value,
    file: StaticString = #fileID,
    line: UInt = #line,
    gage: Int? = 100
  ) -> Cast<Value> {
    let combine = Core.Combine2(
      gageup: Core.Gage(limit: gage, file: file, line: line),
      upstream1: cast1.upstream,
      upstream2: cast2.upstream,
      transform: transform
    )
    return Cast<Value>(combine.subscribe(gage:priority:downstream:))
  }

  /// When an item is emitted by either of Casts, emit the latest items emitted by each Cast.
  /// See [CombineLatest on
  /// reactivex.io](https://reactivex.io/documentation/operators/combinelatest.html)
  public static func combineLatest<T1: Sendable, T2: Sendable>(
    _ cast1: Cast<T1>,
    _ cast2: Cast<T2>,
    file: StaticString = #fileID,
    line: UInt = #line,
    gage: Int? = 100
  ) -> Cast<Value> where Value == (T1, T2) {
    let combine = Core.Combine2(
      gageup: Core.Gage(limit: gage, file: file, line: line),
      upstream1: cast1.upstream,
      upstream2: cast2.upstream,
      transform: Core.Func.identity(i1:i2:)
    )
    return Cast<Value>(combine.subscribe(gage:priority:downstream:))
  }

  /// Create a Cast that emits a particular item.
  /// See [Just on reactivex.io](https://reactivex.io/documentation/operators/just.html)
  public static func emit(
    _ values: Value...
  ) -> Cast<Value> {
    let emit = Core.Emit(values: values)
    return Cast<Value>(emit.subscribe(gage:priority:downstream:))
  }

  /// Convert various other objects and data types into Cast.
  /// See [From on reactivex.io](https://reactivex.io/documentation/operators/from.html)
  public static func emit(
    each values: some Collection<Value>
  ) -> Cast<Value> {
    guard !values.isEmpty else { return empty }
    let emit = Core.Emit(values: values)
    return Cast<Value>(emit.subscribe(gage:priority:downstream:))
  }

  /// Create an Cast that emits a particular item or terminates.
  /// See [Just on reactivex.io](https://reactivex.io/documentation/operators/just.html)
  public static func emit(
    may value: Value?
  ) -> Cast<Value> {
    if let value { emit(value) } else { empty }
  }

  /// Create an Cast that emits no items but terminates normally.
  /// See [Empty on
  /// reactivex.io](https://reactivex.io/documentation/operators/empty-never-throw.html)
  public static var empty: Cast<Value> {
    Cast<Value>(Core.Func.empty(gage:priority:downstream:))
  }

  /// Create an Cast that emits no items and does not terminate.
  /// See [Never on
  /// reactivex.io](https://reactivex.io/documentation/operators/empty-never-throw.html)
  public static var never: Cast<Value> {
    Cast<Value>(Core.Func.never(gage:priority:downstream:))
  }

  /// Register an action to perform upon each emited item of Cast.
  /// See [Subscribe on reactivex.io](https://reactivex.io/documentation/operators/subscribe.html)
  public func bind(
    duty: inout Duty,
    to sink: Sink<Value>,
    file: StaticString = #fileID,
    line: UInt = #line,
    gage: Int? = 100
  ) {
    let gage = Core.Gage(limit: gage, file: file, line: line)
    let bind = Core.Bind(gage: gage, upstream: upstream, sink: sink)
    duty.starts.append(bind.work(key:stop:))
  }
}
