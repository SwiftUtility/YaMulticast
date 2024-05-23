// Copyright 2023 Yandex LLC. All rights reserved.

@testable import YaMulticast

import XCTest

final class PrefixWhileTests: XCTestCase {
  func test_Zero() async {
    await repeated(500) {
      let dutyKeeper = Duty.Keeper()
      var duty = dutyKeeper.start()
      let node = Node<Int>.cold(duty: &duty)
      (0..<10).forEach(node.send(_:))
      node.finish()
      let consumer = node.cast()
        .prefix(while: { _ in false })
        .consume(duty: &duty)
      dutyKeeper.finish(duty: &duty)
      await [].check(consumer)
    }
  }

  func test_Empty() async {
    await repeated(500) {
      let dutyKeeper = Duty.Keeper()
      var duty = dutyKeeper.start()
      let node = Node<Int>.cold(duty: &duty)
      node.finish()
      let consumer = node.cast()
        .prefix(while: { _ in true })
        .consume(duty: &duty)
      dutyKeeper.finish(duty: &duty)
      await [].check(consumer)
    }
  }

  func test_Less() async {
    await repeated(500) {
      let dutyKeeper = Duty.Keeper()
      var duty = dutyKeeper.start()
      let node = Node<Int>.cold(duty: &duty)
      (0..<5).forEach(node.send(_:))
      node.finish()
      let consumer = node.cast()
        .prefix(while: { $0 < 10 })
        .consume(duty: &duty)
      dutyKeeper.finish(duty: &duty)
      await [Int](0..<5).check(consumer)
    }
  }

  func test_More() async {
    await repeated(500) {
      let dutyKeeper = Duty.Keeper()
      var duty = dutyKeeper.start()
      let node = Node<Int>.cold(duty: &duty)
      (0..<10).forEach(node.send(_:))
      node.finish()
      let consumer = node.cast()
        .prefix(while: { $0 < 5 })
        .consume(duty: &duty)
      dutyKeeper.finish(duty: &duty)
      await [Int](0..<5).check(consumer)
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
        let actions = ref.map { value in { node.send(value) } } + [wait.continuation.finish]
        consumer = node.cast()
          .prefix(while: { $0 < 10 })
          .consume(duty: &duty, finished: false, actions: actions)
        dutyKeeper.finish(duty: &duty)
        for await _ in wait.stream {}
      }
      await ref.check(consumer)
    }
  }
}
