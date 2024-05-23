import Foundation

extension Core {
  final class UniqueKey: @unchecked Sendable, Hashable {
    private(set) lazy var id = ObjectIdentifier(self)

    public init() {
      defer { Tracker.track(self) }
      _ = id
    }

    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
    public static func ==(lhs: UniqueKey, rhs: UniqueKey) -> Bool { lhs.id == rhs.id }
  }
}
