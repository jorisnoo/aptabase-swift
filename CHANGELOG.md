## 0.5.0

**Breaking changes**

* `AnyCodableValue` renamed to `EventValue` — shorter and clearer for the public API
* `EventValue.float(Float)` case removed — use `.double(Double)` instead (float literals already produced `.double`)
* `initialize(appKey:with:)` renamed to `initialize(appKey:options:)` for clarity
* `stopPolling()` is now `async` — flushes events synchronously instead of fire-and-forget

**Improvements**

* Merged `EventDispatcher` actor into `AptabaseClient` — eliminates unnecessary `Task` hop per event, simpler architecture
* Protected `Aptabase` singleton state with `OSAllocatedUnfairLock` — fixes potential data race on concurrent `initialize()`/`trackEvent()` calls
* Replaced `nonisolated(unsafe)` properties with lock-protected state
* Fixed polling loop to use structured cancellation instead of redundant `isCancelled` checks
* Replaced `NSError` with typed `DispatchError` enum
* JSON encoder is now a `static let` (shared, created once)
* 4xx HTTP errors now log at `.error` level instead of `.warning`
* `EventValue` conforms to `Equatable`
* Removed misleading `[weak self]` from notification task (singleton never deallocates)

## 0.4.0

**Breaking changes — Swift 6 modernization**

* Requires Swift 6.0+ and Xcode 16+
* Minimum platform versions raised to iOS 17 / macOS 14 / watchOS 10 / tvOS 17 / visionOS 1
* Dropped Objective-C support — all `@objc` annotations and `NSObject` inheritance removed
* Dropped CocoaPods support — use Swift Package Manager instead
* `TrackingMode` is now an enum with `.debug`, `.release`, `.readFromEnvironment` (previously `.asDebug`, `.asRelease`)
* `InitOptions` is now a struct with `Double?` for `flushInterval` (previously `NSNumber?`)
* `trackEvent` now takes `[String: AnyCodableValue]` properties — use literal syntax (`["key": "value", "count": 42]`) or explicit cases (`.integer(n)`, `.string(s)`, etc.)
* The `Value` protocol has been removed
* `AnyCodableValue` is now public and conforms to `Sendable` and `ExpressibleBy*Literal` protocols

**Bug fixes**

* Fixed race condition in `ConcurrentQueue.dequeue()` — eliminated by converting to actor isolation
* Fixed thread-unsafe mutations of `sessionId`, `lastTouched`, and `pauseFlushTimer` in `AptabaseClient` — fixed by converting to actor
* Fixed force-unwrap on `URL(string:)!` in `EventDispatcher` — now uses failable init
* Fixed `AnyCodableValue.null` recursive encode that would crash if reached — case removed
* Fixed deprecated `Locale.current.languageCode` — replaced with `Locale.current.language.languageCode?.identifier`
* Fixed unused `TVUIKit` import on tvOS — replaced with `UIKit`

**Internal improvements**

* `AptabaseClient` and `EventDispatcher` converted from classes to actors
* `Aptabase` is now `Sendable` — safe to use from any isolation context
* Timer-based polling replaced with structured `Task` + `Task.sleep(for:)` loop
* Session timeout uses `ContinuousClock` and `Duration` for monotonic timing
* `NotificationCenter` observers use async `notifications(named:)` sequences
* `os.Logger` replaces `debugPrint` for structured logging

## 0.3.11

* Reverts previous change which caused RELEASE data not to show up
* Adds an option to explicitly set the tracking mode to Debug or Release. Not setting this option will fallback to the previous reading of environment value.

- Setting to release
`Aptabase.shared.initialize(appKey: "", options: InitOptions(trackingMode: .asRelease))`

- Setting to debug
`Aptabase.shared.initialize(appKey: "", options: InitOptions(trackingMode: .asDebug))`

- Setting omitting the value, same as setting to `.readFromEnvironment`:
`Aptabase.shared.initialize(appKey: "")`
`Aptabase.shared.initialize(appKey: "", options: InitOptions(trackingMode: .readFromEnvironment))`

## 0.3.10

* Fix isDebug environment for multiple non RELEASE build configs https://github.com/aptabase/aptabase-swift/pull/24

## 0.3.9

* Fix device model for Mac https://github.com/aptabase/aptabase-swift/pull/22
* Fix application hang/crash https://github.com/aptabase/aptabase-swift/pull/19

## 0.3.8

* Add `deviceModel`

## 0.3.7

* Add support for visionOS

## 0.3.6

* Fix bad formatting in podspec

## 0.3.5

* Only include .h, .m, .swift files in the podspec

## 0.3.4

* Use new session id format

## 0.3.3

* Added Privacy Manifest (PrivacyInfo.xcprivacy)

## 0.3.2

* Dropped support for Swift 5.6
* Added automated tests for Xcode 14+

## 0.3.1

* Restore support for watchOS 7+

## 0.3.0

* Migrated to new event batching and background flush for tracking, the result is lower resource usage and better support for offline events.
* Refactor Xcode project and examples

## 0.2.3

* support for macOS Catalyst (thanks @manucheri)

## 0.2.2

* Fix compile issues on Swift 5.6 (thanks @manucheri)

## 0.2.1

* Added DocC support (thanks @manucheri)

## 0.2.0

* Added support for ObjC

## 0.1.0

* General refactor
* Explicitly define what types are allowed for custom properties

## 0.0.7

* Added support for CocoaPods

## 0.0.6

* Added support for automatic segregation of Debug/Release data source

## 0.0.5

* Ability to set custom hosts for self hosted servers

## 0.0.4

* Updated to new API endpoints

## 0.0.3

* Moved from static functions to the 'shared' singleton pattern.
