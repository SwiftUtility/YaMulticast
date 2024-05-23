// Copyright 2023 Yandex LLC. All rights reserved.

@testable import YaMulticast

import XCTest

final class NodeTests: XCTestCase {
  func test_NodeActors() async {
    await repeated(50000) {
      let ref = [Int](0..<10)
      let dutyKeeper = Duty.Keeper()
      var duty = dutyKeeper.start()
      let target = TargetActor(duty: &duty, count: ref.count)
      let source = SourceActor(duty: &duty)
      duty.bind(source.output, to: target.input)
      dutyKeeper.finish(duty: &duty)
      source.send(ints: ref)
      for await _ in target.channel.stream {}
      let ints = await target.ints
      XCTAssertEqual(ints, ref.map { $0 + 1 })
    }
  }

  func test_NodeWrappers() async {
    await repeated(500) { @MainActor in
      let ref = [Int](0..<10)
      let controller = Controller.make(count: ref.count)
      controller.viewDidLoad()
      controller.scope.source.send(ints: ref)
      for await _ in controller.scope.target.channel.stream {}
      let ints = controller.scope.target.ints
      XCTAssertEqual(ints, ref.map { $0 + 1 })
    }
  }
}
