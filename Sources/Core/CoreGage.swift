// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

extension Core {
  final class Gage: Sendable {
    let limit: Int
    let file: StaticString
    let line: UInt
    let call: StaticString

    init?(limit: Int?, file: StaticString, line: UInt, call: StaticString = #function) {
      guard let limit, limit > 0 else { return nil }
      defer { Tracker.track(self) }
      self.limit = limit
      self.file = file
      self.line = line
      self.call = call
    }

    func report(remaining: Int) -> Bool {
      guard Int.max - remaining > limit else { return false }
      report(limit: limit)
      return true
    }

    func report(limit: Int) {
      Tracker.report("It's over \(limit)", file: file, line: line, call: call)
    }
  }

  struct Gager {
    var gage: Gage?

    mutating func report(remaining: Int) {
      guard let gage else { return }
      guard Int.max - remaining > gage.limit else { return }
      gage.report(limit: gage.limit)
      self.gage = nil
    }
  }
}
