import Foundation

/// An error no client really throws, for a call that fails.
struct Boom: Error {}

/// A switch a test flips between two calls of the same client.
final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    var isOn: Bool {
        get { lock.withLock { value } }
        set { lock.withLock { value = newValue } }
    }
}

/// What a client was asked, in order.
final class Calls: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [String] = []

    func record(_ call: String) { lock.withLock { items.append(call) } }
    var all: [String] { lock.withLock { items } }
}
