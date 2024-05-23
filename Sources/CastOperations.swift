// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

extension Cast {
  /// When an item is emitted by either of Casts, emit the latest items emitted by each Cast.
  /// See [CombineLatest on
  /// reactivex.io](https://reactivex.io/documentation/operators/combinelatest.html)
  public func combineLatest<T1: Sendable, T2: Sendable>(
    _ cast: Cast<T1>,
    _ transform: @escaping @Sendable (Value, T1) async -> T2,
    file: StaticString = #fileID,
    line: UInt = #line,
    gage: Int? = 100
  ) -> Cast<T2> {
    let combine = Core.Combine2(
      gageup: Core.Gage(limit: gage, file: file, line: line),
      upstream1: upstream,
      upstream2: cast.upstream,
      transform: transform
    )
    return Cast<T2>(combine.subscribe(gage:priority:downstream:))
  }

  /// When an item is emitted by either of Casts, emit the latest items emitted by each Cast.
  /// See [CombineLatest on
  /// reactivex.io](https://reactivex.io/documentation/operators/combinelatest.html)
  public func combineLatest<T: Sendable>(
    _ cast: Cast<T>,
    file: StaticString = #fileID,
    line: UInt = #line,
    gage: Int? = 100
  ) -> Cast<(Value, T)> {
    let combine = Core.Combine2(
      gageup: Core.Gage(limit: gage, file: file, line: line),
      upstream1: upstream,
      upstream2: cast.upstream,
      transform: Core.Func.identity(i1:i2:)
    )
    return Cast<(Value, T)>(combine.subscribe(gage:priority:downstream:))
  }

  /// Emit only those items from a Cast that are not nil after conversion.
  /// See [Filter on reactivex.io](https://reactivex.io/documentation/operators/filter.html)
  public func compactMap<T: Sendable>(
    _ transform: @escaping @Sendable (Value) async -> T?,
    file: StaticString = #fileID,
    line: UInt = #line,
    gage: Int? = 100
  ) -> Cast<T> {
    let mapper = Core.Map(
      gage: Core.Gage(limit: gage, file: file, line: line),
      upstream: upstream,
      transform: Core.Func.compactMap(transform)
    )
    return Cast<T>(mapper.subscribe(gage:priority:downstream:))
  }

  /// Print debug info on every lifecycle event of source Cast.
  /// See [Do on reactivex.io](https://reactivex.io/documentation/operators/do.html)
  public func debug(
    _ mark: String? = nil,
    file: StaticString = #fileID,
    line: UInt = #line,
    gage: Int? = 100
  ) -> Cast<Value> {
    #if INTERNAL_BUILD
    let mark = mark ?? "\(file)#\(line)"
    let gage = Core.Gage(limit: gage, file: file, line: line)
    let forEach = Core.ForEach(
      gage: gage,
      upstream: upstream,
      heat: { print("\(mark) -> heat") },
      start: { print("\(mark) -> start") },
      emit: { print("\(mark) -> emit \($0)") },
      terminate: nil,
      cancel: { print("\(mark) -> cancel") },
      finish: { print("\(mark) -> finish") }
    )
    return Cast<Value>(forEach.subscribe(gage:priority:downstream:))
    #else
    return self
    #endif
  }

  /// Suppress immediate predecessor duplicate items emitted by a Cast.
  /// See [Distinct on reactivex.io](https://reactivex.io/documentation/operators/distinct.html)
  public func distinctLast(
    _ checkEqual: @escaping @Sendable (Value, Value) async -> Bool,
    file: StaticString = #fileID,
    line: UInt = #line,
    gage: Int? = 100
  ) -> Cast<Value> {
    let gage = Core.Gage(limit: gage, file: file, line: line)
    let mapper = Core.Map(
      gage: gage,
      upstream: upstream,
      transform: Core.Func.distinct(checkEqual)
    )
    return Cast<Value>(mapper.subscribe(gage:priority:downstream:))
  }

  /// Suppress immediate predecessor duplicate items emitted by a Cast.
  /// See [Distinct on reactivex.io](https://reactivex.io/documentation/operators/distinct.html)
  public func distinctLast(
    file: StaticString = #fileID,
    line: UInt = #line,
    gage: Int? = 100
  ) -> Cast<Value> where Value: Equatable {
    let gage = Core.Gage(limit: gage, file: file, line: line)
    let mapper = Core.Map(
      gage: gage,
      upstream: upstream,
      transform: Core.Func.distinct(==)
    )
    return Cast<Value>(mapper.subscribe(gage:priority:downstream:))
  }

  /// Emit only those items from a Cast that pass a predicate test.
  /// See [Filter on reactivex.io](https://reactivex.io/documentation/operators/filter.html)
  public func filter(
    _ include: @escaping @Sendable (Value) async -> Bool,
    file: StaticString = #fileID,
    line: UInt = #line,
    gage: Int? = 100
  ) -> Cast<Value> {
    let gage = Core.Gage(limit: gage, file: file, line: line)
    let mapper = Core.Map(
      gage: gage,
      upstream: upstream,
      transform: Core.Func.filter(include)
    )
    return Cast<Value>(mapper.subscribe(gage:priority:downstream:))
  }

  /// Register an action to take upon each lifecycle event of source Cast.
  /// See [Do on reactivex.io](https://reactivex.io/documentation/operators/do.html)
  public func forEach(
    emit: (@Sendable (Value) async -> Void)? = nil,
    heat: (@Sendable () async -> Void)? = nil,
    start: (@Sendable () async -> Void)? = nil,
    terminate: (@Sendable (_ finished: Bool) async -> Void)? = nil,
    cancel: (@Sendable () async -> Void)? = nil,
    finish: (@Sendable () async -> Void)? = nil,
    file: StaticString = #fileID,
    line: UInt = #line,
    gage: Int? = 100
  ) -> Cast<Value> {
    var isNotEmpty = false
    isNotEmpty = isNotEmpty || heat != nil
    isNotEmpty = isNotEmpty || start != nil
    isNotEmpty = isNotEmpty || emit != nil
    isNotEmpty = isNotEmpty || terminate != nil
    isNotEmpty = isNotEmpty || cancel != nil
    isNotEmpty = isNotEmpty || finish != nil
    guard isNotEmpty else { return self }
    let gage = Core.Gage(limit: gage, file: file, line: line)
    let forEach = Core.ForEach(
      gage: gage,
      upstream: upstream,
      heat: heat,
      start: start,
      emit: emit,
      terminate: terminate,
      cancel: cancel,
      finish: finish
    )
    return Cast<Value>(forEach.subscribe(gage:priority:downstream:))
  }

  /// Transform the items emitted by a Cast by applying a function to each item.
  /// See [Map on reactivex.io](https://reactivex.io/documentation/operators/map.html)
  public func map<T: Sendable>(
    _ transform: @escaping @Sendable (Value) async -> T,
    file: StaticString = #fileID,
    line: UInt = #line,
    gage: Int? = 100
  ) -> Cast<T> {
    let gage = Core.Gage(limit: gage, file: file, line: line)
    let mapper = Core.Map(gage: gage, upstream: upstream, transform: Core.Func.map(transform))
    return Cast<T>(mapper.subscribe(gage:priority:downstream:))
  }

  /// Emit only the first n items emitted by a Cast.
  /// See [Take on reactivex.io](https://reactivex.io/documentation/operators/take.html)
  public func prefix(
    _ count: Int = 1,
    file: StaticString = #fileID,
    line: UInt = #line,
    gage: Int? = 100
  ) -> Cast<Value> {
    let gage = Core.Gage(limit: gage, file: file, line: line)
    let prefix = Core.PrefixCount(gage: gage, upstream: upstream, count: count)
    return Cast<Value>(prefix.subscribe(gage:priority:downstream:))
  }

  /// Mirror items emitted by a Cast until a specified condition becomes false.
  /// See [TakeWhile on reactivex.io](https://reactivex.io/documentation/operators/takewhile.html)
  public func prefix(
    while include: @escaping @Sendable (Value) async -> Bool,
    file: StaticString = #fileID,
    line: UInt = #line,
    gage: Int? = 100
  ) -> Cast<Value> {
    let gage = Core.Gage(limit: gage, file: file, line: line)
    let prefix = Core.PrefixWhile(gage: gage, upstream: upstream, include: include)
    return Cast<Value>(prefix.subscribe(gage:priority:downstream:))
  }

  /// Discard any items emitted by a Cast after a second Cast emits an item or terminates.
  /// See [TakeUntil on reactivex.io](https://reactivex.io/documentation/operators/takeuntil.html)
  /// Mirror items emitted by a Cast until a specified condition becomes false.
  /// See [TakeWhile on reactivex.io](https://reactivex.io/documentation/operators/takewhile.html)
  public func prefix(
    until other: Cast<some Sendable>,
    file: StaticString = #fileID,
    line: UInt = #line,
    gage: Int? = 100
  ) -> Cast<Value> {
    let gage = Core.Gage(limit: gage, file: file, line: line)
    let prefix = Core.PrefixUntil(gage: gage, upstream: upstream, until: other.upstream)
    return Cast<Value>(prefix.subscribe(gage:priority:downstream:))
  }

  /// Emit a specified sequence of items before beginning to emit the items from the source Cast.
  /// See [StartWith on reactivex.io](https://reactivex.io/documentation/operators/startwith.html)
  public func prepend(
    _ values: Value...,
    file: StaticString = #fileID,
    line: UInt = #line,
    gage: Int? = 100
  ) -> Cast<Value> {
    let gage = Core.Gage(limit: gage, file: file, line: line)
    let prepend = Core.Prepend(gage: gage, upstream: upstream, values: values)
    return Cast<Value>(prepend.subscribe(gage:priority:downstream:))
  }

  /// Emit a specified sequence of items before beginning to emit the items from the source Cast.
  /// See [StartWith on reactivex.io](https://reactivex.io/documentation/operators/startwith.html)
  public func prepend(
    each values: some Collection<Value>,
    file: StaticString = #fileID,
    line: UInt = #line,
    gage: Int? = 100
  ) -> Cast<Value> {
    let gage = Core.Gage(limit: gage, file: file, line: line)
    let prepend = Core.Prepend(gage: gage, upstream: upstream, values: values)
    return Cast<Value>(prepend.subscribe(gage:priority:downstream:))
  }

  /// Apply a function to each item emitted by an Observable, sequentially, and emit each successive
  /// value.
  /// See [Scan on reactivex.io](https://reactivex.io/documentation/operators/scan.html)
  public func scan<T>(
    _ seed: T,
    _ accumulator: @escaping @Sendable (T, Value) -> T,
    file: StaticString = #fileID,
    line: UInt = #line,
    gage: Int? = 100
  ) -> Cast<T> {
    let mapper = Core.Map(
      gage: Core.Gage(limit: gage, file: file, line: line),
      upstream: upstream,
      transform: Core.Func.scan(seed, accumulator)
    )
    return Cast<T>(mapper.subscribe(gage:priority:downstream:))
  }

  /// Apply a function to each item emitted by a Cast, sequentially, and emit each successive value.
  /// See [Scan on reactivex.io](https://reactivex.io/documentation/operators/scan.html)
  public func scan<T: Sendable>(
    into seed: T,
    _ accumulator: @escaping @Sendable (inout T, Value) -> Void,
    file: StaticString = #fileID,
    line: UInt = #line,
    gage: Int? = 100
  ) -> Cast<T> {
    let mapper = Core.Map(
      gage: Core.Gage(limit: gage, file: file, line: line),
      upstream: upstream,
      transform: Core.Func.scanInto(seed, accumulator)
    )
    return Cast<T>(mapper.subscribe(gage:priority:downstream:))
  }

  /// Specify the TaskPriority for upstream Cast operations.
  /// See [SubscribeOn on
  /// reactivex.io](https://reactivex.io/documentation/operators/subscribeon.html)
  public func subscribe(priority: TaskPriority) -> Cast<Value> {
    Cast<Value> { [upstream] gage, _, downstream in
      await upstream(gage, priority, downstream)
    }
  }
}
