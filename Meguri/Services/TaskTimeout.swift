import Foundation

/// Races `operation` against a `duration` sleep and returns whichever finishes first,
/// treating a timeout as `nil`. The loser is cancelled.
func withTimeout<T: Sendable>(
    _ duration: Duration,
    operation: @Sendable @escaping () async -> T?
) async -> T? {
    await withTaskGroup(of: T?.self) { group in
        group.addTask { await operation() }
        group.addTask {
            try? await Task.sleep(for: duration)
            return nil
        }
        let first = await group.next().flatMap { $0 }
        group.cancelAll()
        return first
    }
}
