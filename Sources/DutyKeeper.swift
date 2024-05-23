// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

extension Duty {
  /// Permanent subscriptions storage.
  ///
  /// - It stops underlying tasks when deallocated.
  /// - It is bad practice to store it in buisiness logic units.
  /// - It is forbidden to escape.
  public final class Keeper: Sendable {
    let holder: Core.Holder
    let task: Task<Void, Never>

    deinit { task.cancel() }

    /// Create instance.
    public init(priority: TaskPriority = .high) {
      defer { Tracker.track(self) }
      self.holder = Core.Holder()
      self.task = Tracker.detach(priority: priority, precancelled: false, holder.start)
    }

    /// Start subscribe transaction.
    ///
    /// ```swift
    /// class ServiceOwner {
    ///   let dutyKeeper: Duty.Keeper
    ///   let externalService: ExternalService
    ///   let localService: LocalService
    ///
    ///   init(externalService: ExternalService) {
    ///     var duty = dutyKeeper.start()
    ///     defer {
    ///       // here subscribe process begins in reverse order
    ///       dutyKeeper.finish(duty: &duty)
    ///     }
    ///     self.externalService = externalService
    ///     // Create private nodes
    ///     self.localService = LocalService(duty: &duty)
    ///     // Build internal pipelines
    ///     localService.start(duty: &duty)
    ///     duty.bind(localService.errorCast, to: externalService.errorSink)
    ///     duty.bind(externalService.eventCast, to: localService.eventSink)
    ///   }
    /// }
    /// ```
    public func start(
      file: StaticString = #fileID,
      line: UInt = #line,
      call: StaticString = #function
    ) -> Duty {
      Duty(fund: .init(file: file, line: line, call: call))
    }

    /// Finish subscribe transaction.
    public func finish(duty: inout Duty) { holder.hold(duty: &duty) }

    /// Create syncronous subscribe transaction.
    public func keepSync<T>(
      as _: T.Type = T.self,
      file: StaticString = #fileID,
      line: UInt = #line,
      call: StaticString = #function,
      _ bind: (inout Duty) -> T
    ) -> T {
      var duty = Duty(fund: .init(file: file, line: line, call: call))
      defer { holder.hold(duty: &duty) }
      return bind(&duty)
    }

    /// Create asyncronous subscribe transaction.
    public func keep<T>(
      as _: T.Type = T.self,
      file: StaticString = #fileID,
      line: UInt = #line,
      call: StaticString = #function,
      _ bind: (inout Duty) async -> T
    ) async -> T {
      var duty = Duty(fund: .init(file: file, line: line, call: call))
      defer { holder.hold(duty: &duty) }
      return await bind(&duty)
    }

    /// Finish scope subscribe transaction.
    @MainActor public func keep(
      scope: Duty.Scope<some Sendable>,
      bind: (inout Duty) -> Void,
      file: StaticString = #file,
      line: UInt = #line,
      call: StaticString = #function
    ) {
      guard !scope.bound
      else { return Tracker.report("Bound twice", file: file, line: line, call: call) }
      bind(&scope.duty)
      scope.bound = true
      holder.hold(duty: &scope.duty)
    }
  }
}
