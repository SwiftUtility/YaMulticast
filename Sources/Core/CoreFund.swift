// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

extension Core {
  final class Fund {
    let file: StaticString
    let line: UInt
    let call: StaticString
    var starts: [Start]

    deinit {
      if !starts.isEmpty {
        Tracker.report("Skip \(starts.count) subscriptions", file: file, line: line, call: call)
      }
    }

    init(file: StaticString, line: UInt, call: StaticString, starts: [Start] = []) {
      defer { Tracker.track(self) }
      self.file = file
      self.line = line
      self.call = call
      self.starts = starts
    }

    func copy(starts: [Start]) -> Fund {
      .init(file: file, line: line, call: call, starts: starts)
    }
  }
}
