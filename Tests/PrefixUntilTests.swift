// Copyright 2023 Yandex LLC. All rights reserved.

@testable import YaMulticast

import XCTest

final class PrefixUntilTests: XCTestCase {
  func test_StopByEvent() async {
    await repeated(500) {
      let dutyKeeper = Duty.Keeper()
      var duty = dutyKeeper.start()
      let ints = Node<Int>.cold(duty: &duty)
      let stops = Node<Void>.cold(duty: &duty)
      var actions = (0..<10).map { value in { ints.send(value) } }
      actions.append(stops.fire)
      let consumer = ints.cast()
        .prefix(until: stops.cast())
        .consume(duty: &duty, actions: actions)
      dutyKeeper.finish(duty: &duty)
      await [Int](0..<10).check(consumer)
    }
  }

  func test_StopByFinish() async {
    await repeated(500) {
      let dutyKeeper = Duty.Keeper()
      var duty = dutyKeeper.start()
      let ints = Node<Int>.cold(duty: &duty)
      let stops = Node<Void>.cold(duty: &duty)
      var actions = (0..<10).map { value in { ints.send(value) } }
      actions.append(stops.finish)
      let consumer = ints.cast()
        .prefix(until: stops.cast())
        .consume(duty: &duty, actions: actions)
      dutyKeeper.finish(duty: &duty)
      await [Int](0..<10).check(consumer)
    }
  }

  func test_All() async {
    await repeated(500) {
      let dutyKeeper = Duty.Keeper()
      var duty = dutyKeeper.start()
      let ints = Node<Int>.cold(duty: &duty)
      let stops = Node<Void>.cold(duty: &duty)
      var actions = (0..<10).map { value in { ints.send(value) } }
      actions.append(ints.finish)
      let consumer = ints.cast()
        .prefix(until: stops.cast())
        .consume(duty: &duty, actions: actions)
      dutyKeeper.finish(duty: &duty)
      await [Int](0..<10).check(consumer)
    }
  }

  func test_Empty() async {
    await repeated(500) {
      let dutyKeeper = Duty.Keeper()
      var duty = dutyKeeper.start()
      let ints = Node<Int>.cold(duty: &duty)
      let stops = Node<Void>.cold(duty: &duty)
      ints.finish()
      let consumer = ints.cast()
        .prefix(until: stops.cast())
        .consume(duty: &duty)
      dutyKeeper.finish(duty: &duty)
      await [].check(consumer)
    }
  }

  func test_Cancel() async {
    await repeated(500) {
      let ref = [Int](0..<5)
      let ints = Node<Int>.warm()
      let stops = Node<Void>.warm()
      let consumer: Consumer<Int>
      do {
        let dutyKeeper = Duty.Keeper()
        var duty = dutyKeeper.start()
        let wait = AsyncStream<Never>.makeStream()
        let actions = ref.map { value in { ints.send(value) } } + [wait.continuation.finish]
        consumer = ints.cast()
          .prefix(until: stops.cast())
          .consume(duty: &duty, finished: false, actions: actions)
        dutyKeeper.finish(duty: &duty)
        for await _ in wait.stream {}
      }
      await ref.check(consumer)
    }
  }
}
