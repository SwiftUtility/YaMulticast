// Copyright 2023 Yandex LLC. All rights reserved.

@testable import YaMulticast

import XCTest

final class MapTests: XCTestCase {
  func test_All() async {
    await repeated(500) {
      let dutyKeeper = Duty.Keeper()
      var duty = dutyKeeper.start()
      let node = Node<Int>.cold(duty: &duty)
      let ref = [Int](0..<10)
      ref.forEach(node.send(_:))
      node.finish()
      let consumer = node.cast()
        .map { $0 * 10 }
        .consume(duty: &duty)
      dutyKeeper.finish(duty: &duty)
      await ref
        .map { $0 * 10 }
        .check(consumer)
    }
  }

  func test_CompactMap() async {
    await repeated(500) {
      let dutyKeeper = Duty.Keeper()
      var duty = dutyKeeper.start()
      let node = Node<Int?>.cold(duty: &duty)
      let ref = [Int](0..<10)
      ref.flatMap { [Optional($0), nil] }.forEach(node.send(_:))
      node.finish()
      let consumer = node.cast()
        .compactMap { $0 }
        .consume(duty: &duty)
      dutyKeeper.finish(duty: &duty)
      await ref.check(consumer)
    }
  }

  func test_DistictLast() async {
    await repeated(500) {
      let dutyKeeper = Duty.Keeper()
      var duty = dutyKeeper.start()
      let node = Node<Int>.cold(duty: &duty)
      let ref = [0, 0, 1, 0, 2, 2, 3, 4]
      ref.forEach(node.send(_:))
      node.finish()
      let consumer = node.cast()
        .distinctLast()
        .consume(duty: &duty)
      dutyKeeper.finish(duty: &duty)
      await [0, 1, 0, 2, 3, 4].check(consumer)
    }
  }

  func test_Filter() async {
    await repeated(500) {
      let dutyKeeper = Duty.Keeper()
      var duty = dutyKeeper.start()
      let node = Node<Int>.cold(duty: &duty)
      let ref = [Int](0..<10)
      ref.forEach(node.send(_:))
      node.finish()
      let consumer = node.cast()
        .filter { $0 % 2 == 0 }
        .consume(duty: &duty)
      dutyKeeper.finish(duty: &duty)
      await ref
        .filter { $0 % 2 == 0 }
        .check(consumer)
    }
  }

  func test_Scan() async {
    await repeated(500) {
      let dutyKeeper = Duty.Keeper()
      var duty = dutyKeeper.start()
      let node = Node<Int>.cold(duty: &duty)
      var ref = [Int](0..<10)
      ref.forEach(node.send(_:))
      node.finish()
      let consumer = node.cast()
        .scan(100) { $0 + $1 }
        .consume(duty: &duty)
      dutyKeeper.finish(duty: &duty)
      var total = 100
      for index in ref.indices {
        total += ref[index]
        ref[index] = total
      }
      await ref.check(consumer)
    }
  }

  func test_ScanInto() async {
    await repeated(500) {
      let dutyKeeper = Duty.Keeper()
      var duty = dutyKeeper.start()
      let node = Node<Int>.cold(duty: &duty)
      var ref = [Int](0..<10)
      ref.forEach(node.send(_:))
      node.finish()
      let consumer = node.cast()
        .scan(into: 100) { $0 += $1 }
        .consume(duty: &duty)
      dutyKeeper.finish(duty: &duty)
      var total = 100
      for index in ref.indices {
        total += ref[index]
        ref[index] = total
      }
      await ref.check(consumer)
    }
  }

  func test_Empty() async {
    await repeated(500) {
      let dutyKeeper = Duty.Keeper()
      var duty = dutyKeeper.start()
      let node = Node<Int>.cold(duty: &duty)
      node.finish()
      let consumer = node.cast()
        .map { $0 * 10 }
        .consume(duty: &duty)
      dutyKeeper.finish(duty: &duty)
      await [].check(consumer)
    }
  }

  func test_Cancel() async {
    await repeated(500) {
      let ref = [Int](0..<10)
      let node = Node<Int>.warm()
      let consumer: Consumer<Int>
      do {
        let dutyKeeper = Duty.Keeper()
        var duty = dutyKeeper.start()
        let wait = AsyncStream<Never>.makeStream()
        let actions = ref.map { value in { node.send(value) } } + [wait.continuation.finish]
        consumer = node.cast()
          .map { $0 * 10 }
          .consume(duty: &duty, finished: false, actions: actions)
        dutyKeeper.finish(duty: &duty)
        for await _ in wait.stream {}
      }
      await ref
        .map { $0 * 10 }
        .check(consumer)
    }
  }
}
