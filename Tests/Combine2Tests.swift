// Copyright 2023 Yandex LLC. All rights reserved.

@testable import YaMulticast

import XCTest

final class Combine2Tests: XCTestCase {
  func test_Empty1() async {
    await repeated(500) {
      let dutyKeeper = Duty.Keeper()
      var duty = dutyKeeper.start()
      let node1 = Node<Int>.cold(duty: &duty)
      let node2 = Node<Int>.cold(duty: &duty)
      let ref = [Int](0..<10)
      ref.forEach(node1.send(_:))
      node1.finish()
      node2.finish()
      let consumer = Cast
        .combineLatest(
          node1.cast(),
          node2.cast(),
          { $0 + $1 }
        )
        .consume(duty: &duty)
      dutyKeeper.finish(duty: &duty)
      await [].check(consumer)
    }
  }

  func test_One1() async {
    await repeated(500) {
      let dutyKeeper = Duty.Keeper()
      var duty = dutyKeeper.start()
      let node1 = Node<Int>.cold(duty: &duty)
      let node2 = Node<Int>.cold(duty: &duty)
      let ref = [Int](0..<10)
      var actions = ref.map { value in { node1.send(value) } }
      actions[0] = {
        node1.send(0)
        node2.send(1000)
        node2.finish()
      }
      actions.append { node1.finish() }
      let consumer = Cast
        .combineLatest(
          node1.cast(),
          node2.cast(),
          { $0 + $1 }
        )
        .consume(duty: &duty, actions: actions)
      dutyKeeper.finish(duty: &duty)
      await ref.map { $0 + 1000 }.check(consumer)
    }
  }

  func test_Two1() async {
    await repeated(500) {
      let dutyKeeper = Duty.Keeper()
      var duty = dutyKeeper.start()
      let node1 = Node<Int>.cold(duty: &duty)
      let node2 = Node<Int>.cold(duty: &duty)
      let ref = [Int](0..<10)
      var actions = ref.map { value in { node1.send(value) } }
      actions += ref.map { value in { node1.send(value) } }
      actions[0] = {
        node1.send(0)
        node2.send(1000)
      }
      actions[10] = {
        node2.send(2000)
        node2.finish()
      }
      actions.append { node1.finish() }
      let consumer = Cast
        .combineLatest(
          node1.cast(),
          node2.cast(),
          { $0 + $1 }
        )
        .consume(duty: &duty, actions: actions)
      dutyKeeper.finish(duty: &duty)
      var result = ref.map { $0 + 1000 } + ref.map { $0 + 2000 }
      result[10] = 2009
      await result.check(consumer)
    }
  }

  func test_Cancel1() async {
    await repeated(500) {
      let ref = [Int](0..<10)
      let node1 = Node<Int>.warm()
      let node2 = Node<Int>.warm()
      let consumer: Consumer<Int>
      do {
        let dutyKeeper = Duty.Keeper()
        var duty = dutyKeeper.start()
        let wait = AsyncStream<Never>.makeStream()
        var actions = ref.map { value in { node1.send(value) } }
        actions[0] = {
          node1.send(0)
          node2.send(1000)
          node2.finish()
        }
        actions.append(wait.continuation.finish)
        consumer = Cast
          .combineLatest(
            node1.cast(),
            node2.cast(),
            { $0 + $1 }
          )
          .consume(duty: &duty, finished: false, actions: actions)
        dutyKeeper.finish(duty: &duty)
        for await _ in wait.stream {}
      }
      await ref
        .map { $0 + 1000 }
        .check(consumer)
    }
  }

  func test_Empty2() async {
    await repeated(500) {
      let dutyKeeper = Duty.Keeper()
      var duty = dutyKeeper.start()
      let node1 = Node<Int>.cold(duty: &duty)
      let node2 = Node<Int>.cold(duty: &duty)
      let ref = [Int](0..<10)
      node1.finish()
      ref.forEach(node2.send(_:))
      node2.finish()
      let consumer = Cast
        .combineLatest(
          node1.cast(),
          node2.cast(),
          { $0 + $1 }
        )
        .consume(duty: &duty)
      dutyKeeper.finish(duty: &duty)
      await [].check(consumer)
    }
  }

  func test_One2() async {
    await repeated(500) {
      let dutyKeeper = Duty.Keeper()
      var duty = dutyKeeper.start()
      let node1 = Node<Int>.cold(duty: &duty)
      let node2 = Node<Int>.cold(duty: &duty)
      let ref = [Int](0..<10)
      var actions = ref.map { value in { node2.send(value) } }
      actions[0] = {
        node2.send(0)
        node1.send(1000)
        node1.finish()
      }
      actions.append { node2.finish() }
      let consumer = Cast
        .combineLatest(
          node2.cast(),
          node1.cast(),
          { $0 + $1 }
        )
        .consume(duty: &duty, actions: actions)
      dutyKeeper.finish(duty: &duty)
      await ref.map { $0 + 1000 }.check(consumer)
    }
  }

  func test_Two2() async {
    await repeated(500) {
      let dutyKeeper = Duty.Keeper()
      var duty = dutyKeeper.start()
      let node1 = Node<Int>.cold(duty: &duty)
      let node2 = Node<Int>.cold(duty: &duty)
      let ref = [Int](0..<10)
      var actions = ref.map { value in { node2.send(value) } }
      actions += ref.map { value in { node2.send(value) } }
      actions[0] = {
        node2.send(0)
        node1.send(1000)
      }
      actions[10] = {
        node1.send(2000)
        node1.finish()
      }
      actions.append { node2.finish() }
      let consumer = Cast
        .combineLatest(
          node1.cast(),
          node2.cast(),
          { $0 + $1 }
        )
        .consume(duty: &duty, actions: actions)
      dutyKeeper.finish(duty: &duty)
      var result = ref.map { $0 + 1000 } + ref.map { $0 + 2000 }
      result[10] = 2009
      await result.check(consumer)
    }
  }

  func test_Cancel2() async {
    await repeated(500) {
      let ref = [Int](0..<10)
      let node1 = Node<Int>.warm()
      let node2 = Node<Int>.warm()
      let consumer: Consumer<Int>
      do {
        let dutyKeeper = Duty.Keeper()
        var duty = dutyKeeper.start()
        let wait = AsyncStream<Never>.makeStream()
        var actions = ref.map { value in { node2.send(value) } }
        actions[0] = {
          node2.send(0)
          node1.send(1000)
          node1.finish()
        }
        actions.append(wait.continuation.finish)
        consumer = Cast
          .combineLatest(
            node1.cast(),
            node2.cast(),
            { $0 + $1 }
          )
          .consume(duty: &duty, finished: false, actions: actions)
        dutyKeeper.finish(duty: &duty)
        for await _ in wait.stream {}
      }
      await ref
        .map { $0 + 1000 }
        .check(consumer)
    }
  }

  func test_CancelAll() async {
    await repeated(500) {
      let ref = [Int](0..<10)
      let node1 = Node<Int>.warm()
      let node2 = Node<Int>.warm()
      let consumer: Consumer<Int>
      do {
        let dutyKeeper = Duty.Keeper()
        var duty = dutyKeeper.start()
        let wait = AsyncStream<Never>.makeStream()
        var actions = ref.map { value in { node2.send(value) } }
        actions[0] = {
          node2.send(0)
          node1.send(1000)
        }
        actions.append(wait.continuation.finish)
        consumer = Cast
          .combineLatest(
            node1.cast(),
            node2.cast(),
            { $0 + $1 }
          )
          .consume(duty: &duty, finished: false, actions: actions)
        dutyKeeper.finish(duty: &duty)
        for await _ in wait.stream {}
      }
      await ref
        .map { $0 + 1000 }
        .check(consumer)
    }
  }
}
