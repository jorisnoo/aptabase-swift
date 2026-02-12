import Foundation

#if os(iOS) || os(visionOS)
import UIKit
#elseif os(macOS)
import AppKit
#elseif os(watchOS)
import WatchKit
#elseif os(tvOS)
import UIKit
#endif

struct EnvironmentInfo: Sendable {
    let isDebug: Bool
    let osName: String
    let osVersion: String
    let locale: String
    let appVersion: String
    let appBuildNumber: String
    let deviceModel: String

    static func current(trackingMode: TrackingMode = .readFromEnvironment) -> EnvironmentInfo {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let appBuildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String

        let isDebug: Bool = switch trackingMode {
        case .debug:
            true
        case .release:
            false
        case .readFromEnvironment:
            environmentIsDebug
        }

        return EnvironmentInfo(
            isDebug: isDebug,
            osName: osName,
            osVersion: osVersion,
            locale: Locale.current.language.languageCode?.identifier ?? "",
            appVersion: appVersion ?? "",
            appBuildNumber: appBuildNumber ?? "",
            deviceModel: deviceModel
        )
    }

    private static var environmentIsDebug: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    private static var osName: String {
        #if os(macOS) || targetEnvironment(macCatalyst)
        "macOS"
        #elseif os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return "iPadOS"
        }
        return "iOS"
        #elseif os(watchOS)
        "watchOS"
        #elseif os(tvOS)
        "tvOS"
        #elseif os(visionOS)
        "visionOS"
        #else
        ""
        #endif
    }

    private static var osVersion: String {
        #if os(macOS) || targetEnvironment(macCatalyst)
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        #elseif os(iOS) || os(tvOS) || os(visionOS)
        UIDevice.current.systemVersion
        #elseif os(watchOS)
        WKInterfaceDevice.current().systemVersion
        #else
        ""
        #endif
    }

    private static var deviceModel: String {
        #if os(macOS) || targetEnvironment(macCatalyst)
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        if size > 0 {
            var model = [CChar](repeating: 0, count: size)
            sysctlbyname("hw.model", &model, &size, nil, 0)
            let deviceModel = model.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
            if !deviceModel.isEmpty {
                return deviceModel
            }
        }
        #endif

        if let simulatorModelIdentifier = ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulatorModelIdentifier
        } else {
            var systemInfo = utsname()
            if uname(&systemInfo) == 0 {
                let identifier = withUnsafePointer(to: &systemInfo.machine) { ptr in
                    ptr.withMemoryRebound(to: CChar.self, capacity: 1) { machinePtr in
                        String(cString: machinePtr)
                    }
                }
                return identifier
            }
            return ""
        }
    }
}
