import Foundation
import Testing
@testable import Aptabase

final class MockURLSession: URLSessionProtocol, @unchecked Sendable {
    var requestCount: Int = 0
    var statusCode: Int = 200

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requestCount += 1

        let data = "{}".data(using: .utf8)!
        let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        return (data, response)
    }
}

@Suite struct EventDispatcherTests {
    let env = EnvironmentInfo(
        isDebug: true,
        osName: "iOS",
        osVersion: "17.0",
        locale: "en",
        appVersion: "1.0.0",
        appBuildNumber: "1",
        deviceModel: "iPhone16,2"
    )

    @Test func flushEmptyQueue() async {
        let session = MockURLSession()
        let dispatcher = EventDispatcher(
            appKey: "A-DEV-000",
            baseUrl: "http://localhost:3000",
            env: env,
            session: session
        )!

        await dispatcher.flush()
        #expect(session.requestCount == 0)
    }

    @Test func flushSingleItem() async {
        let session = MockURLSession()
        let dispatcher = EventDispatcher(
            appKey: "A-DEV-000",
            baseUrl: "http://localhost:3000",
            env: env,
            session: session
        )!

        await dispatcher.enqueue(newEvent("app_started"))
        await dispatcher.flush()
        #expect(session.requestCount == 1)
    }

    @Test func flushShouldBatchMultipleItems() async {
        let session = MockURLSession()
        let dispatcher = EventDispatcher(
            appKey: "A-DEV-000",
            baseUrl: "http://localhost:3000",
            env: env,
            session: session
        )!

        await dispatcher.enqueue(newEvent("app_started"))
        await dispatcher.enqueue(newEvent("item_created"))
        await dispatcher.enqueue(newEvent("item_deleted"))

        await dispatcher.flush()
        #expect(session.requestCount == 1)

        await dispatcher.flush()
        #expect(session.requestCount == 1)
    }

    @Test func flushShouldRetryAfterFailure() async {
        let session = MockURLSession()
        let dispatcher = EventDispatcher(
            appKey: "A-DEV-000",
            baseUrl: "http://localhost:3000",
            env: env,
            session: session
        )!

        await dispatcher.enqueue(newEvent("app_started"))
        await dispatcher.enqueue(newEvent("item_created"))
        await dispatcher.enqueue(newEvent("item_deleted"))

        session.statusCode = 500
        await dispatcher.flush()
        #expect(session.requestCount == 1)

        session.statusCode = 200
        await dispatcher.flush()
        #expect(session.requestCount == 2)
    }

    private func newEvent(_ eventName: String) -> Event {
        Event(
            timestamp: Date(),
            sessionId: UUID().uuidString,
            eventName: eventName,
            systemProps: Event.SystemProps(
                isDebug: env.isDebug,
                locale: env.locale,
                osName: env.osName,
                osVersion: env.osVersion,
                appVersion: env.appVersion,
                appBuildNumber: env.appBuildNumber,
                sdkVersion: "aptabase-swift@0.0.0",
                deviceModel: env.deviceModel
            ),
            props: nil
        )
    }
}
