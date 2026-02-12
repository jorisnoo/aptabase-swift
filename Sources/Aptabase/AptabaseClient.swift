import Foundation
import OSLog

struct Event: Encodable, Sendable {
    let timestamp: Date
    let sessionId: String
    let eventName: String
    let systemProps: SystemProps
    let props: [String: EventValue]?

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

actor AptabaseClient {
    private static let sdkVersion = "aptabase-swift@0.5.0"
    private static let sessionTimeout: Duration = .seconds(3600)
    private static let logger = Logger(subsystem: "com.aptabase", category: "AptabaseClient")

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = TimeZone(identifier: "UTC")
        encoder.dateEncodingStrategy = .formatted(formatter)
        return encoder
    }()

    private var sessionId = AptabaseClient.newSessionId()
    private var lastTouched = ContinuousClock.now
    private let env: EnvironmentInfo
    private let flushInterval: Duration
    private var flushTask: Task<Void, Never>?

    private var events: [Event] = []
    private let maximumBatchSize = 25
    private let headers: [String: String]
    private let apiUrl: URL
    private let session: URLSessionProtocol

    private enum DispatchError: Error {
        case serverError(statusCode: Int, message: String)
    }

    init?(appKey: String, baseUrl: String, env: EnvironmentInfo, options: InitOptions?, session: URLSessionProtocol = URLSession.shared) {
        guard let url = URL(string: "\(baseUrl)/api/v0/events") else {
            Self.logger.error("Invalid base URL: \(baseUrl)")
            return nil
        }

        let interval = options?.flushInterval ?? (env.isDebug ? 2.0 : 60.0)
        self.flushInterval = .seconds(interval)
        self.env = env
        self.session = session
        self.apiUrl = url
        self.headers = [
            "Content-Type": "application/json",
            "App-Key": appKey,
            "User-Agent": "\(env.osName)/\(env.osVersion) \(env.locale)"
        ]
    }

    func trackEvent(_ eventName: String, with props: [String: EventValue] = [:]) {
        let now = ContinuousClock.now
        if lastTouched.duration(to: now) > Self.sessionTimeout {
            sessionId = Self.newSessionId()
        }
        lastTouched = now

        events.append(Event(
            timestamp: Date(),
            sessionId: sessionId,
            eventName: eventName,
            systemProps: Event.SystemProps(
                isDebug: env.isDebug,
                locale: env.locale,
                osName: env.osName,
                osVersion: env.osVersion,
                appVersion: env.appVersion,
                appBuildNumber: env.appBuildNumber,
                sdkVersion: Self.sdkVersion,
                deviceModel: env.deviceModel
            ),
            props: props
        ))
    }

    func startPolling() {
        stopPollingOnly()

        flushTask = Task { [flushInterval] in
            do {
                while true {
                    try await Task.sleep(for: flushInterval)
                    await flush()
                }
            } catch {}
        }
    }

    func stopPolling() async {
        stopPollingOnly()
        await flush()
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

    private func stopPollingOnly() {
        flushTask?.cancel()
        flushTask = nil
    }

    private func sendEvents(_ events: [Event]) async throws {
        do {
            let body = try Self.encoder.encode(events)

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
                Self.logger.error("Failed to send \(events.count) events: \(reason). Will not retry.")
                return
            }

            throw DispatchError.serverError(statusCode: statusCode, message: reason)
        } catch {
            Self.logger.error("Failed to send \(events.count) events: \(error)")
            throw error
        }
    }

    private static func newSessionId() -> String {
        let epochInSeconds = UInt64(Date().timeIntervalSince1970)
        let random = UInt64.random(in: 0...99999999)
        return String(epochInSeconds * 100000000 + random)
    }
}
