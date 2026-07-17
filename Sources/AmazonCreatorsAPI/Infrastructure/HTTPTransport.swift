import Foundation

protocol HTTPTransport: Sendable {

    func send(_ request: URLRequest) async throws -> TransportResponse
}

struct TransportResponse: Sendable {

    let data: Data
    let statusCode: Int
    let headers: [String: String]
}

struct URLSessionTransport: HTTPTransport {

    func send(_ request: URLRequest) async throws -> TransportResponse {
        let result: (Data, URLResponse)

        do {
            result = try await URLSession.shared.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw AmazonCreatorsError.transport(error.localizedDescription)
        }

        guard let response = result.1 as? HTTPURLResponse else {
            throw AmazonCreatorsError.transport("A resposta recebida não é HTTP.")
        }

        let headers = response.allHeaderFields.reduce(into: [String: String]()) { partialResult, field in
            guard let key = field.key as? String else {
                return
            }

            partialResult[key] = String(describing: field.value)
        }

        return TransportResponse(data: result.0, statusCode: response.statusCode, headers: headers)
    }
}

actor RequestScheduler {

    private let clock: ContinuousClock
    private let spacing: Duration
    private var nextAllowedRequest: ContinuousClock.Instant?

    init(requestsPerSecond: Int) {
        clock = ContinuousClock()
        spacing = .seconds(1 / Double(max(1, requestsPerSecond)))
        nextAllowedRequest = nil
    }

    func waitForPermission() async throws {
        let now = clock.now
        let scheduledRequest: ContinuousClock.Instant

        if let nextAllowedRequest, nextAllowedRequest > now {
            scheduledRequest = nextAllowedRequest
        } else {
            scheduledRequest = now
        }

        nextAllowedRequest = scheduledRequest.advanced(by: spacing)

        if scheduledRequest > now {
            try await Task.sleep(for: now.duration(to: scheduledRequest))
        }
    }
}

actor ResponseCache {

    private struct Entry: Sendable {

        let data: Data
        let expiration: Date
        let lastAccess: UInt64
    }

    private let maximumEntries: Int
    private var entries: [String: Entry]
    private var lastAccess: UInt64

    init(maximumEntries: Int = 256) {
        self.maximumEntries = max(1, maximumEntries)
        entries = [:]
        lastAccess = 0
    }

    func value(for key: String) -> Data? {
        guard let entry = entries[key] else {
            return nil
        }

        guard entry.expiration > .now else {
            entries[key] = nil

            return nil
        }

        entries[key] = Entry(data: entry.data, expiration: entry.expiration, lastAccess: nextAccess())

        return entry.data
    }

    func store(_ data: Data, for key: String, ttl: TimeInterval) {
        removeExpiredEntries()
        entries[key] = Entry(data: data, expiration: .now.addingTimeInterval(ttl), lastAccess: nextAccess())

        removeLeastRecentlyUsedEntriesIfNeeded()
    }

    private func nextAccess() -> UInt64 {
        lastAccess &+= 1

        return lastAccess
    }

    private func removeExpiredEntries() {
        let expiredKeys = entries.compactMap { key, entry in
            entry.expiration <= .now ? key : nil
        }

        for key in expiredKeys {
            entries[key] = nil
        }
    }

    private func removeLeastRecentlyUsedEntriesIfNeeded() {
        while entries.count > maximumEntries {
            guard let key = entries.min(by: { $0.value.lastAccess < $1.value.lastAccess })?.key else {
                return
            }

            entries[key] = nil
        }
    }
}
