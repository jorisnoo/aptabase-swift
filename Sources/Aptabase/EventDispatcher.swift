import Foundation
import OSLog

struct Event: Encodable, Sendable {
    let timestamp: Date
    let sessionId: String
    let eventName: String
    let systemProps: SystemProps
    let props: [String: AnyCodableValue]?

    struct SystemProps: Encodable, Sendable {
        let isDebug: Bool
        let locale: String
        let osName: String
        let osVersion: String
        let appVersion: String
        let appBuildNumber: String
        let sdkVersion: String
        let deviceModel: String
    }
}

protocol URLSessionProtocol: Sendable {
    func data(for: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

actor EventDispatcher {
    private static let logger = Logger(subsystem: "com.aptabase", category: "EventDispatcher")

    private var events: [Event] = []
    private let maximumBatchSize = 25
    private let headers: [String: String]
    private let apiUrl: URL
    private let session: URLSessionProtocol

    init?(appKey: String, baseUrl: String, env: EnvironmentInfo, session: URLSessionProtocol = URLSession.shared) {
        guard let url = URL(string: "\(baseUrl)/api/v0/events") else {
            Self.logger.error("Invalid base URL: \(baseUrl)")
            return nil
        }

        self.session = session
        self.apiUrl = url
        self.headers = [
            "Content-Type": "application/json",
            "App-Key": appKey,
            "User-Agent": "\(env.osName)/\(env.osVersion) \(env.locale)"
        ]
    }

    func enqueue(_ newEvent: Event) {
        events.append(newEvent)
    }

    func enqueue(_ newEvents: [Event]) {
        events.append(contentsOf: newEvents)
    }

    func flush() async {
        if events.isEmpty {
            return
        }

        var failedEvents: [Event] = []
        while !events.isEmpty {
            let count = min(maximumBatchSize, events.count)
            let eventsToSend = Array(events.prefix(count))
            events.removeFirst(count)

            do {
                try await sendEvents(eventsToSend)
            } catch {
                failedEvents.append(contentsOf: eventsToSend)
            }
        }

        if !failedEvents.isEmpty {
            events.append(contentsOf: failedEvents)
        }
    }

    private func sendEvents(_ events: [Event]) async throws {
        if events.isEmpty {
            return
        }

        do {
            let body = try encoder.encode(events)

            var request = URLRequest(url: apiUrl)
            request.httpMethod = "POST"
            request.allHTTPHeaderFields = headers
            request.httpBody = body

            let (data, response) = try await session.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            if statusCode < 300 {
                return
            }

            let responseText = String(data: data, encoding: .utf8) ?? ""
            let reason = "\(statusCode) \(responseText)"

            if statusCode < 500 {
                Self.logger.warning("Failed to send \(events.count) events: \(reason). Will not retry.")
                return
            }

            throw NSError(domain: "AptabaseError", code: statusCode, userInfo: ["reason": reason])
        } catch {
            Self.logger.error("Failed to send \(events.count) events: \(error)")
            throw error
        }
    }

    private var encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = TimeZone(identifier: "UTC")
        encoder.dateEncodingStrategy = .formatted(formatter)
        return encoder
    }()
}
