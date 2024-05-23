// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

/// Protocol to expose public controller API.
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
@dynamicMemberLookup public protocol Scopeable {
  associatedtype Scope
  /// Implementation detail.
  static var plug: Plug.Scope<Self> { get }
  /// Expose underlying Scope receiver interface.
  subscript<T: Sendable>(dynamicMember _: KeyPath<Scope, Plug.Gainer<T>>) -> Sink<T> { get }
  /// Expose underlying Scope producer interface.
  subscript<T: Sendable>(dynamicMember _: KeyPath<Scope, Plug.Sender<T>>) -> Multicast<T> { get }
  /// Expose underlying Wireable receiver interface.
  subscript<T: Sendable>(dynamicMember _: KeyPath<Scope, Plug.Import<T>>) -> Sink<T> { get }
  /// Expose underlying Wireable producer interface.
  subscript<T: Sendable>(dynamicMember _: KeyPath<Scope, Plug.Export<T>>) -> Multicast<T> { get }
}

extension Scopeable {
  public subscript<T: Sendable>(
    dynamicMember keyPath: KeyPath<Scope, Plug.Gainer<T>>
  ) -> Sink<T> {
    self[keyPath: Self.plug.scope].value[keyPath: keyPath].node.sink
  }

  public subscript<T: Sendable>(
    dynamicMember keyPath: KeyPath<Scope, Plug.Sender<T>>
  ) -> Multicast<T> {
    self[keyPath: Self.plug.scope].value[keyPath: keyPath].node.multicast
  }

  public subscript<T: Sendable>(
    dynamicMember keyPath: KeyPath<Scope, Plug.Import<T>>
  ) -> Sink<T> {
    self[keyPath: Self.plug.scope].value[keyPath: keyPath].node.sink
  }

  public subscript<T: Sendable>(
    dynamicMember keyPath: KeyPath<Scope, Plug.Export<T>>
  ) -> Multicast<T> {
    self[keyPath: Self.plug.scope].value[keyPath: keyPath].node.multicast
  }
}
