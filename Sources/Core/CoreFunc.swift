// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

extension Core {
  enum Func {
    static func map<T, U>(
      _ transform: @escaping @Sendable (T) async -> U
    ) -> (T) async -> [U] {
      { await [transform($0)] }
    }

    static func compactMap<T, U>(
      _ transform: @escaping @Sendable (T) async -> U?
    ) -> (T) async -> [U] {
      { value in
        if let value = await transform(value) { [value] } else { [] }
      }
    }

    static func distinct<T>(
      _ checkEqual: @escaping (T, T) async -> Bool
    ) -> (T) async -> [T] {
      var last: T?
      return { next in
        guard let prev = last else {
          last = next
          return [next]
        }
        guard await !checkEqual(prev, next) else { return [] }
        last = next
        return [next]
      }
    }

    static func filter<T>(
      _ include: @escaping @Sendable (T) async -> Bool
    ) -> (T) async -> [T] {
      { value in
        if await include(value) { [value] } else { [] }
      }
    }

    static func scan<T, U>(
      _ seed: U,
      _ update: @escaping @Sendable (U, T) async -> U
    ) -> (T) async -> [U] {
      var seed = seed
      return { value in
        seed = await update(seed, value)
        return [seed]
      }
    }

    static func scanInto<T, U>(
      _ seed: U,
      _ update: @escaping @Sendable (inout U, T) async -> Void
    ) -> (T) async -> [U] {
      var seed = seed
      return { value in
        await update(&seed, value)
        return [seed]
      }
    }

    @Sendable static func never(
      gage _: Gage?,
      priority: TaskPriority,
      downstream: Pipe<some Sendable>
    ) {
      downstream.start(priority: priority, produce: {})
    }

    @Sendable static func empty(
      gage _: Gage?,
      priority: TaskPriority,
      downstream: Pipe<some Sendable>
    ) {
      downstream.start(priority: priority, produce: downstream.finish)
    }

    @Sendable static func identity<I1, I2>(i1: I1, i2: I2) -> (I1, I2) { (i1, i2) }
  }
}
