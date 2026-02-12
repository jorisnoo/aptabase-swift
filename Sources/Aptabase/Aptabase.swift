import Foundation
import OSLog
import os

#if os(iOS) || os(visionOS)
import UIKit
#elseif os(macOS)
import AppKit
#elseif os(watchOS)
import WatchKit
#elseif os(tvOS)
import UIKit
#endif

public final class Aptabase: Sendable {
    private static let logger = Logger(subsystem: "com.aptabase", category: "Aptabase")

    private struct State {
        var client: AptabaseClient?
        var notificationTask: Task<Void, Never>?
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    public static let shared = Aptabase()

    private let hosts: [String: String] = [
        "US": "https://us.aptabase.com",
        "EU": "https://eu.aptabase.com",
        "DEV": "http://localhost:3000",
        "SH": ""
    ]

    public func initialize(appKey: String, options: InitOptions? = nil) {
        let parts = appKey.components(separatedBy: "-")
        if parts.count != 3 || hosts[parts[1]] == nil {
            Self.logger.error("The Aptabase App Key \(appKey) is invalid. Tracking will be disabled.")
            return
        }

        guard let baseUrl = getBaseUrl(parts[1], options?.host) else {
            return
        }

        let trackingMode = options?.trackingMode ?? .readFromEnvironment
        let env = EnvironmentInfo.current(trackingMode: trackingMode)

        guard let client = AptabaseClient(appKey: appKey, baseUrl: baseUrl, env: env, options: options) else {
            Self.logger.error("Failed to create AptabaseClient. Tracking will be disabled.")
            return
        }

        state.withLock {
            $0.client = client
        }

        observeLifecycle(client: client)
    }

    public func trackEvent(_ eventName: String, with props: [String: EventValue] = [:]) {
        guard let client = state.withLock({ $0.client }) else { return }

        Task { await client.trackEvent(eventName, with: props) }
    }

    public func flush() {
        guard let client = state.withLock({ $0.client }) else { return }

        Task { await client.flush() }
    }

    private func observeLifecycle(client: AptabaseClient) {
        state.withLock {
            $0.notificationTask?.cancel()
        }

        let task = Task {
            #if os(tvOS) || os(iOS) || os(visionOS)
            let foreground = UIApplication.willEnterForegroundNotification
            let background = UIApplication.didEnterBackgroundNotification
            #elseif os(macOS)
            let foreground = NSApplication.didBecomeActiveNotification
            let background = NSApplication.willTerminateNotification
            #elseif os(watchOS)
            let foreground = WKExtension.applicationWillEnterForegroundNotification
            let background = WKExtension.applicationDidEnterBackgroundNotification
            #endif

            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await _ in NotificationCenter.default.notifications(named: foreground) {
                        await client.startPolling()
                    }
                }
                group.addTask {
                    for await _ in NotificationCenter.default.notifications(named: background) {
                        await client.stopPolling()
                    }
                }
            }
        }

        state.withLock {
            $0.notificationTask = task
        }
    }

    private func getBaseUrl(_ region: String, _ host: String?) -> String? {
        if let host {
            return host
        }

        guard let baseURL = hosts[region], !baseURL.isEmpty else {
            Self.logger.error("Host parameter must be defined when using Self-Hosted App Key. Tracking will be disabled.")
            return nil
        }

        return baseURL
    }
}
