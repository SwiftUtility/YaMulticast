// Copyright 2023 Yandex LLC. All rights reserved.

@testable import YaMulticast

import XCTest

final class EmitTests: XCTestCase {
  func test_All() async {
    await repeated(500) {
      let dutyKeeper = Duty.Keeper()
      var duty = dutyKeeper.start()
      let ref = [Int](0..<10)
      let consumer = Cast.emit(each: ref)
        .consume(duty: &duty)
      dutyKeeper.finish(duty: &duty)
      await ref.check(consumer)
    }
  }

  func test_MaySome() async {
    await repeated(500) {
      let dutyKeeper = Duty.Keeper()
      var duty = dutyKeeper.start()
      let consumer = Cast.emit(may: 0)
        .consume(duty: &duty)
      dutyKeeper.finish(duty: &duty)
      await [0].check(consumer)
    }
  }

  func test_MayNone() async {
    await repeated(500) {
      let dutyKeeper = Duty.Keeper()
      var duty = dutyKeeper.start()
      let consumer = Cast.emit(may: nil as Int?)
        .consume(duty: &duty)
      dutyKeeper.finish(duty: &duty)
      await [].check(consumer)
    }
  }

  func test_Empty() async {
    await repeated(500) {
      let dutyKeeper = Duty.Keeper()
      var duty = dutyKeeper.start()
      let ref = [Int]()
      let consumer = Cast.emit(each: ref)
        .consume(duty: &duty)
      dutyKeeper.finish(duty: &duty)
      await ref.check(consumer)
    }
  }

  func test_Never() async {
    await repeated(500) {
      let consumer: Consumer<Int>
      do {
        let dutyKeeper = Duty.Keeper()
        var duty = dutyKeeper.start()
        let wait = AsyncStream<Never>.makeStream()
        consumer = Cast.never
          .consume(duty: &duty, finished: false, actions: [wait.continuation.finish])
        dutyKeeper.finish(duty: &duty)
        for await _ in wait.stream {}
      }
      await [].check(consumer)
    }
  }
}
