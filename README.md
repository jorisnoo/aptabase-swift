![Aptabase](https://aptabase.com/og.png)

# Swift SDK for Aptabase

This is a cleaned-up fork of [aptabase/aptabase-swift](https://github.com/aptabase/aptabase-swift) with Swift 6 modernization, a simplified single-actor architecture, and thread-safety fixes. See [CHANGELOG.md](CHANGELOG.md) for details.

Instrument your apps with Aptabase, an Open Source, Privacy-First and Simple Analytics for Mobile, Desktop and Web Apps.

## Requirements

- Swift 6.0+
- iOS 17+ / macOS 14+ / watchOS 10+ / tvOS 17+ / visionOS 1+
- Xcode 16+

## Install

#### Option 1: Swift Package Manager

Add the following lines to your `Package.swift` file:

```swift
let package = Package(
    ...
    dependencies: [
        ...
        .package(url: "https://github.com/aptabase/aptabase-swift.git", from: "0.5.0"),
    ],
    targets: [
        .target(
            name: "MyApp",
            dependencies: ["Aptabase"]
        )
    ]
)
```

#### Option 2: Adding package dependencies with Xcode

Use this [guide](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app) to add `aptabase-swift` to your project. Use https://github.com/aptabase/aptabase-swift for the URL when Xcode asks.

## Usage

> If you're targeting macOS, you must first enable the `Outgoing Connections (Client)` checkbox under the `App Sandbox` section.

First, you need to get your `App Key` from Aptabase, you can find it in the `Instructions` menu on the left side menu.

Initialized the SDK as early as possible in your app, for example:

```swift
import SwiftUI
import Aptabase

@main
struct ExampleApp: App {
    init() {
        Aptabase.shared.initialize(appKey: "<YOUR_APP_KEY>")
    }

    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}
```

You can also pass `InitOptions` to customize the SDK:

```swift
let options = InitOptions(host: "https://your-self-hosted-instance.com")
Aptabase.shared.initialize(appKey: "<YOUR_APP_KEY>", options: options)
```

Afterward, you can start tracking events with `trackEvent`:

```swift
import Aptabase

Aptabase.shared.trackEvent("app_started") // An event with no properties
Aptabase.shared.trackEvent("screen_view", with: ["name": "Settings"]) // An event with a custom property
```

Custom properties use the `EventValue` type, which conforms to string, integer, float, and boolean literal protocols. Literals are inferred automatically, but variables need explicit wrapping:

```swift
let screenName = "Settings"
Aptabase.shared.trackEvent("screen_view", with: ["name": .string(screenName)])
Aptabase.shared.trackEvent("items_loaded", with: ["count": .integer(items.count)])
```

A few important notes:

1. The SDK will automatically enhance the event with some useful information, like the OS, the app version, and other things.
2. You're in control of what gets sent to Aptabase. This SDK does not automatically track any events, you need to call `trackEvent` manually.
   - Because of this, it's generally recommended to at least track an event at startup
3. The `trackEvent` function is a non-blocking operation as it runs in the background.
4. Custom properties support strings, integers, doubles, and booleans via `EventValue`

## Preparing for Submission to Apple App Store

When submitting your app to the Apple App Store, you'll need to fill out the `App Privacy` form. You can find all the answers on our [How to fill out the Apple App Privacy when using Aptabase](https://aptabase.com/docs/apple-app-privacy) guide.
