// Copyright 2023 Yandex LLC. All rights reserved.

@testable import YaMulticast

import XCTest

final class PrependTests: XCTestCase {
  func test_Each() async {
    await repeated(500) {
      let dutyKeeper = Duty.Keeper()
      var duty = dutyKeeper.start()
      let ref = [Int](0..<10)
      let node = Node<Int>.cold(duty: &duty)
      node.send(10)
      node.finish()
      let consumer = node.cast()
        .prepend(each: ref)
        .consume(duty: &duty)
      dutyKeeper.finish(duty: &duty)
      await (ref + [10]).check(consumer)
    }
  }

  func test_Empty() async {
    await repeated(500) {
      let dutyKeeper = Duty.Keeper()
      var duty = dutyKeeper.start()
      let node = Node<Int>.cold(duty: &duty)
      node.finish()
      let cast = node.cast()
        .prepend(1, 2)
        .consume(duty: &duty)
      dutyKeeper.finish(duty: &duty)
      await [1, 2].check(cast)
    }
  }

  func test_Some() async {
    await repeated(500) {
      let dutyKeeper = Duty.Keeper()
      var duty = dutyKeeper.start()
      let node = Node<Int>.cold(duty: &duty)
      node.send(3)
      node.finish()
      let consumer = node.cast()
        .prepend(1, 2)
        .consume(duty: &duty)
      dutyKeeper.finish(duty: &duty)
      await [1, 2, 3].check(consumer)
    }
  }

  func test_Cancel() async {
    await repeated(500) {
      let ref = [Int](0..<5)
      let node = Node<Int>.warm()
      let consumer: Consumer<Int>
      do {
        let dutyKeeper = Duty.Keeper()
        var duty = dutyKeeper.start()
        let wait = AsyncStream<Never>.makeStream()
        let actions = ref.map { _ in {} } + [wait.continuation.finish]
        consumer = node.cast()
          .prepend(each: 0..<5)
          .consume(duty: &duty, finished: false, actions: actions)
        dutyKeeper.finish(duty: &duty)
        for await _ in wait.stream {}
      }
      await ref.check(consumer)
    }
  }
}
