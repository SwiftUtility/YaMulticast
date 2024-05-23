// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

/// Async sequence wrapper.
///
/// - It is safe to store as property.
/// - It can be subscribed multiple times.
/// - It will start emmiting elements when underlying producer(Node) is heated.
/// - It will reply amount of elements configured by underlying producer.
/// - It will finish when underlying producer is deallocated.
/// - Subscribers will continue to recieve already generated elements after underlying producer is
/// deallocated.
public final class Multicast<Value: Sendable>: Sendable {
  let splitter: Core.Splitter<Value>

  init(splitter: Core.Splitter<Value>) {
    defer { Tracker.track(self) }
    self.splitter = splitter
  }

  public func cast(
    file: StaticString = #fileID,
    line: UInt = #line,
    gage: Int? = 100
  ) -> Cast<Value> {
    let gage = Core.Gage(limit: gage, file: file, line: line)
    return Cast { [splitter] gageDown, priority, downstream in
      await splitter.start(gageUp: gage, gageDown: gageDown, priority: priority, pipe: downstream)
    }
  }
}
