import Foundation
import OSLog

actor AptabaseClient {
    private static let sdkVersion = "aptabase-swift@0.4.0"
    private static let sessionTimeout: Duration = .seconds(3600)
    private static let logger = Logger(subsystem: "com.aptabase", category: "AptabaseClient")

    private var sessionId = AptabaseClient.newSessionId()
    private var lastTouched = ContinuousClock.now
    private let dispatcher: EventDispatcher
    private let env: EnvironmentInfo
    private let flushInterval: Duration
    private var flushTask: Task<Void, Never>?

    init?(appKey: String, baseUrl: String, env: EnvironmentInfo, options: InitOptions?) {
        let interval = options?.flushInterval ?? (env.isDebug ? 2.0 : 60.0)
        self.flushInterval = .seconds(interval)
        self.env = env

        guard let dispatcher = EventDispatcher(appKey: appKey, baseUrl: baseUrl, env: env) else {
            return nil
        }
        self.dispatcher = dispatcher
    }

    func trackEvent(_ eventName: String, with props: [String: AnyCodableValue] = [:]) {
        let now = ContinuousClock.now
        if lastTouched.duration(to: now) > Self.sessionTimeout {
            sessionId = Self.newSessionId()
        }
        lastTouched = now

        let evt = Event(
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
        )

        Task { await dispatcher.enqueue(evt) }
    }

    func startPolling() {
        stopPolling()

        flushTask = Task { [flushInterval] in
            while !Task.isCancelled {
                try? await Task.sleep(for: flushInterval)
                if Task.isCancelled { break }
                await flush()
            }
        }
    }

    func stopPolling() {
        flushTask?.cancel()
        flushTask = nil

        Task { await flush() }
    }

    func flush() async {
        await dispatcher.flush()
    }

    private static func newSessionId() -> String {
        let epochInSeconds = UInt64(Date().timeIntervalSince1970)
        let random = UInt64.random(in: 0...99999999)
        return String(epochInSeconds * 100000000 + random)
    }
}
