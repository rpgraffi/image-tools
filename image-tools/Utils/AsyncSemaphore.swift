import Foundation

actor AsyncSemaphore {
    private let limit: Int
    private var permits: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        let clamped = max(1, value)
        self.limit = clamped
        self.permits = clamped
    }

    func acquire() async {
        if permits > 0 {
            permits -= 1
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        if !waiters.isEmpty {
            let continuation = waiters.removeFirst()
            continuation.resume()
        } else {
            permits = min(permits + 1, limit)
        }
    }
}

