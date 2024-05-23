// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

extension Core {
  final class Emit<C: Collection> where C.Element: Sendable {
    let values: C

    init(values: C) {
      defer { Tracker.track(self) }
      self.values = values
    }

    @Sendable func subscribe(
      gage _: Gage?,
      priority: TaskPriority,
      downstream: Pipe<C.Element>
    ) async {
      guard !Task.isCancelled else { return }
      let producer = Producer(downstream, values)
      downstream.start(priority: priority, produce: producer.produce)
    }

    actor Producer {
      let downstream: Pipe<C.Element>
      var values: [C.Element]

      init(_ downstream: Pipe<C.Element>, _ values: C) {
        defer { Tracker.track(self) }
        self.downstream = downstream
        self.values = values.reversed()
      }

      @Sendable func produce() async {
        defer { downstream.cancel() }
        while let value = values.popLast() {
          guard downstream.send(value) != nil else { return }
        }
        downstream.finish()
      }
    }
  }
}
