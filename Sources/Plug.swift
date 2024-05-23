// Copyright 2023 Yandex LLC. All rights reserved.

import Foundation

/// Wireable and Scopeable helpers namespace.
public enum Plug {
  /// Wireable implementation detail.
  public final class Wire<T: Wireable> {
    let wire: KeyPath<T, T.Wire>

    public init(_ wire: KeyPath<T, T.Wire>) { self.wire = wire }
  }

  /// Scopeable implementation detail.
  public final class Scope<T: Scopeable> {
    let scope: KeyPath<T, Duty.Scope<T.Scope>>

    public init(_ scope: KeyPath<T, Duty.Scope<T.Scope>>) { self.scope = scope }
  }
}
