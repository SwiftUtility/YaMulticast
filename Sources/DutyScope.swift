// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

extension Duty {
  /// Controller reactive state wrapper with two phase binding support.
  ///
  /// ```swift
  /// actor Formatter: Wireable, Sendable {
  ///   private let wire: Wire
  ///   static let plug = Plug.Wire<Formatter>(\.wire)
  ///
  ///   init(duty: inout Duty) {
  ///     self.wire = Wire(duty: &duty)
  ///     wire.input.cast()
  ///       .map { "Formatted value: \($0)" }
  ///       .bind(duty: &duty, to: wire.output.sink)
  ///   }
  ///
  ///   struct Wire {
  ///     let input: Plug.Import<Int>
  ///     let output: Plug.Export<String>
  ///
  ///     init(duty: inout Duty) {
  ///       self.input = .cold(duty: &duty)
  ///       self.output = .cold(duty: &duty)
  ///     }
  ///   }
  /// }
  ///
  /// @MainActor final class Screen: UIViewController, Scopeable, Sendable {
  ///   private let label: UILabel = .init(frame: .zero)
  ///   private let scope: Duty.Scope<Scope>
  ///   private let keeper = Duty.Keeper()
  ///   static let plug = Plug.Scope<Screen>(\.scope)
  ///
  ///   required init?(coder: NSCoder) { fatalError() }
  ///   init(scope: Duty.Scope<Scope>) {
  ///     self.scope = scope
  ///     super.init()
  ///   }
  ///
  ///   static func make(ints: Multicast<Int>) -> Screen {
  ///     let scope = Duty.Scope<Scope>.make { duty in Scope(duty: &duty, ints: ints) }
  ///     return Screen(scope: scope)
  ///   }
  ///
  ///   override func viewDidLoad() {
  ///     label.frame = view.bounds
  ///     view.addSubview(label)
  ///     keeper.keep(scope: scope, bind: bind(duty:))
  ///   }
  ///
  ///   func bind(duty: inout Duty) {
  ///     scope.formatter.output.cast().bind(duty: &duty, to: .init(send: { @MainActor [weak self]
  /// text in
  ///       self?.label.text = text
  ///     }))
  ///   }
  ///
  ///   final class Scope {
  ///     let formatter: Formatter
  ///
  ///     init(duty: inout Duty, ints: Multicast<Int>) {
  ///       self.formatter = Formatter(duty: &duty)
  ///       duty.bind(ints, to: formatter.input)
  ///     }
  ///   }
  /// }
  /// ```
  @dynamicMemberLookup
  @MainActor public final class Scope<Value: Sendable>: Sendable {
    let value: Value
    var duty: Duty
    var bound: Bool = false
    let file: StaticString
    let line: UInt
    let call: StaticString

    deinit {
      if !bound { Tracker.report("Not bound", file: file, line: line, call: call) }
    }

    nonisolated init(
      value: Value,
      duty: Duty,
      file: StaticString,
      line: UInt,
      call: StaticString
    ) {
      defer { Tracker.track(self) }
      self.value = value
      self.duty = duty
      self.file = file
      self.line = line
      self.call = call
    }

    /// Factory method to create state and start delayed subscribe transaction.
    public nonisolated static func make(
      _ makeValue: (inout Duty) -> Value,
      file: StaticString = #file,
      line: UInt = #line,
      call: StaticString = #function
    ) -> Scope {
      var duty = Duty(fund: .init(file: file, line: line, call: call))
      let value = makeValue(&duty)
      return .init(value: value, duty: consume duty, file: file, line: line, call: call)
    }

    public nonisolated subscript<T: Wireable>(
      dynamicMember keyPath: KeyPath<Value, T>
    ) -> T {
      value[keyPath: keyPath]
    }

    public nonisolated subscript<T: Wireable>(
      dynamicMember keyPath: KeyPath<Value, T?>
    ) -> T? {
      value[keyPath: keyPath]
    }

    public nonisolated subscript<T: Sendable>(
      dynamicMember keyPath: KeyPath<Value, Plug.Sender<T>>
    ) -> Plug.Sender<T> {
      value[keyPath: keyPath]
    }

    public nonisolated subscript<T: Sendable>(
      dynamicMember keyPath: KeyPath<Value, Plug.Gainer<T>>
    ) -> Plug.Gainer<T> {
      value[keyPath: keyPath]
    }

    public nonisolated subscript<T: Sendable>(
      dynamicMember keyPath: KeyPath<Value, Plug.Sender<T>?>
    ) -> Plug.Sender<T>? {
      value[keyPath: keyPath]
    }

    public nonisolated subscript<T: Sendable>(
      dynamicMember keyPath: KeyPath<Value, Plug.Gainer<T>?>
    ) -> Plug.Gainer<T>? {
      value[keyPath: keyPath]
    }
  }
}
