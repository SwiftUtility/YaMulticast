// Copyright 2023 Yandex LLC. All rights reserved.

@testable import YaMulticast

import XCTest

func repeated(_ count: Int, test: @escaping @Sendable () async -> Void) async {
  let leakers = await Tracker.Leaker.capture {
    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<count {
        group.addTask {
          let count = await Tracker.Waiter.wait(operation: test)
          XCTAssert(count > 0)
        }
      }
    }
  }
  XCTAssert(leakers.count > 0)
  for leaker in leakers { XCTAssertNil(leaker.object) }
}

extension Cast {
  func consume(
    duty: inout Duty,
    finished: Bool = true,
    actions: [() -> Void] = []
  ) -> Consumer<Value> where Value: Comparable {
    let consumer = Consumer<Value>(finished: finished, actions: actions)
    self
      .forEach(
        emit: consumer.emit(value:),
        heat: consumer.heat,
        start: consumer.start,
        terminate: consumer.stop(finished:)
      )
      .bind(duty: &duty, to: Sink(send: consumer.consume(_:)))
    return consumer
  }
}

extension Array where Element: Comparable & Sendable {
  func check(_ consumer: Consumer<Element>) async {
    var result: [Element] = []
    for await value in consumer.channel.stream { result.append(value) }
    XCTAssertEqual(result, self)
    let isHeated = await consumer.isHeated
    XCTAssertTrue(isHeated)
    let isStarted = await consumer.isStarted
    XCTAssertTrue(isStarted)
    let isFinished = await consumer.isFinished
    XCTAssertTrue(isFinished)
  }
}

actor Consumer<T: Sendable & Comparable> {
  var actions: [() -> Void]
  let channel = AsyncStream<T>.makeStream()
  let shouldFinish: Bool
  var isStarted = false
  var isHeated = false
  var isFinished = false

  init(finished: Bool, actions: [() -> Void]) {
    var actions = actions
    actions.reverse()
    self.actions = actions
    self.shouldFinish = finished
  }

  @Sendable func heat() async {
    XCTAssertFalse(isHeated)
    XCTAssertFalse(isStarted)
    XCTAssertFalse(isFinished)
    isHeated = true
  }

  @Sendable func start() async {
    XCTAssertTrue(isHeated)
    XCTAssertFalse(isStarted)
    XCTAssertFalse(isFinished)
    isStarted = true
    actions.popLast()?()
  }

  @Sendable func emit(value: T) async {
    XCTAssertTrue(isHeated)
    XCTAssertTrue(isStarted)
    XCTAssertFalse(isFinished)
    channel.continuation.yield(value)
  }

  @Sendable func consume(_: T) async {
    actions.popLast()?()
  }

  @Sendable func stop(finished: Bool) async {
    XCTAssertTrue(isHeated)
    if finished { XCTAssertTrue(isStarted) }
    XCTAssertFalse(isFinished)
    XCTAssertEqual(shouldFinish, finished)
    isFinished = true
    channel.continuation.finish()
  }
}

struct SourceStruct: Wireable, Sendable {
  private let wire: Wire
  static let plug = Plug.Wire<SourceStruct>(\.wire)
  init(duty: inout Duty) { self.wire = Wire(duty: &duty) }
  func send(ints: [Int]) { ints.forEach(wire.output.send(_:)) }

  final class Wire: Sendable {
    let output: Plug.Export<Int>
    init(duty: inout Duty) { self.output = .cold(duty: &duty) }
  }
}

actor SourceActor: Wireable, Sendable {
  private let wire: Wire
  static let plug = Plug.Wire<SourceActor>(\.wire)
  init(duty: inout Duty) { self.wire = Wire(duty: &duty) }
  nonisolated func send(ints: [Int]) { ints.forEach(wire.output.send(_:)) }

  final class Wire: Sendable {
    let output: Plug.Export<Int>
    init(duty: inout Duty) { self.output = .cold(duty: &duty) }
  }
}

@MainActor final class TargetClass: Wireable, Sendable {
  var ints: [Int] = []
  let count: Int
  let channel = AsyncStream<Never>.makeStream()
  private let wire: Wire
  static let plug = Plug.Wire<TargetClass>(\.wire)

  nonisolated init(duty: inout Duty, count: Int) {
    self.count = count
    self.wire = Wire(duty: &duty)
    duty.bind(wire.input.node.multicast, to: .init(send: append(int:)))
  }

  @Sendable func append(int: Int) async {
    ints.append(int + 1)
    guard ints.count == count else { return }
    channel.continuation.finish()
  }

  final class Wire: Sendable {
    let input: Plug.Import<Int>
    init(duty: inout Duty) { self.input = .cold(duty: &duty) }
  }
}

actor TargetActor: Wireable, Sendable {
  var ints: [Int] = []
  let count: Int
  let channel = AsyncStream<Never>.makeStream()
  private let wire: Wire
  static let plug = Plug.Wire<TargetActor>(\.wire)

  init(duty: inout Duty, count: Int) {
    self.count = count
    self.wire = Wire(duty: &duty)
    duty.bind(wire.input.node.multicast, to: .init(send: { await self.append(int: $0) }))
  }

  func append(int: Int) {
    ints.append(int + 1)
    guard ints.count == count else { return }
    channel.continuation.finish()
  }

  final class Wire: Sendable {
    let input: Plug.Import<Int>
    init(duty: inout Duty) { self.input = .cold(duty: &duty) }
  }
}

@MainActor final class Controller: Scopeable {
  let scope: Duty.Scope<Scope>
  let keeper = Duty.Keeper()
  static let plug = Plug.Scope<Controller>(\.scope)

  init(scope: Duty.Scope<Scope>) {
    self.scope = scope
  }

  static func make(count: Int) -> Controller {
    let scope = Duty.Scope<Scope>.make { duty in Scope(duty: &duty, count: count) }
    return .init(scope: scope)
  }

  func viewDidLoad() {
    keeper.keep(scope: scope, bind: bind(duty:))
  }

  func bind(duty: inout Duty) {
    scope.source.output.cast().bind(duty: &duty, to: scope.target.input)
  }

  final class Scope: Sendable {
    let target: TargetClass
    let source: SourceStruct

    init(duty: inout Duty, count: Int) {
      self.target = .init(duty: &duty, count: count)
      self.source = .init(duty: &duty)
    }
  }
}
