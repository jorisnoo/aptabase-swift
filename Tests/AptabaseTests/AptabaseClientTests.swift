import Foundation
import Testing
@testable import Aptabase

final class MockURLSession: URLSessionProtocol, @unchecked Sendable {
    var requestCount: Int = 0
    var lastRequestBody: Data?
    var statusCode: Int = 200

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requestCount += 1
        lastRequestBody = request.httpBody

        let data = "{}".data(using: .utf8)!
        let response = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        return (data, response)
    }
}

@Suite struct AptabaseClientTests {
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
        let client = AptabaseClient(
            appKey: "A-DEV-000",
            baseUrl: "http://localhost:3000",
            env: env,
            options: nil,
            session: session
        )!

        await client.flush()
        #expect(session.requestCount == 0)
    }

    @Test func flushSingleItem() async {
        let session = MockURLSession()
        let client = AptabaseClient(
            appKey: "A-DEV-000",
            baseUrl: "http://localhost:3000",
            env: env,
            options: nil,
            session: session
        )!

        await client.trackEvent("app_started")
        await client.flush()
        #expect(session.requestCount == 1)
    }

    @Test func flushShouldBatchMultipleItems() async {
        let session = MockURLSession()
        let client = AptabaseClient(
            appKey: "A-DEV-000",
            baseUrl: "http://localhost:3000",
            env: env,
            options: nil,
            session: session
        )!

        await client.trackEvent("app_started")
        await client.trackEvent("item_created")
        await client.trackEvent("item_deleted")

        await client.flush()
        #expect(session.requestCount == 1)

        await client.flush()
        #expect(session.requestCount == 1)
    }

    @Test func flushShouldRetryAfterServerError() async {
        let session = MockURLSession()
        let client = AptabaseClient(
            appKey: "A-DEV-000",
            baseUrl: "http://localhost:3000",
            env: env,
            options: nil,
            session: session
        )!

        await client.trackEvent("app_started")
        await client.trackEvent("item_created")
        await client.trackEvent("item_deleted")

        session.statusCode = 500
        await client.flush()
        #expect(session.requestCount == 1)

        session.statusCode = 200
        await client.flush()
        #expect(session.requestCount == 2)
    }

    @Test func clientErrorShouldNotRetry() async {
        let session = MockURLSession()
        let client = AptabaseClient(
            appKey: "A-DEV-000",
            baseUrl: "http://localhost:3000",
            env: env,
            options: nil,
            session: session
        )!

        await client.trackEvent("app_started")

        session.statusCode = 400
        await client.flush()
        #expect(session.requestCount == 1)

        session.statusCode = 200
        await client.flush()
        #expect(session.requestCount == 1)
    }

    @Test func trackEventWithProps() async {
        let session = MockURLSession()
        let client = AptabaseClient(
            appKey: "A-DEV-000",
            baseUrl: "http://localhost:3000",
            env: env,
            options: nil,
            session: session
        )!

        await client.trackEvent("screen_view", with: ["name": "Settings", "count": 42])
        await client.flush()
        #expect(session.requestCount == 1)
        #expect(session.lastRequestBody != nil)
    }

}

@Suite struct EventValueTests {
    @Test func equatable() {
        #expect(EventValue.integer(42) == EventValue.integer(42))
        #expect(EventValue.integer(42) != EventValue.integer(99))
        #expect(EventValue.string("hello") == EventValue.string("hello"))
        #expect(EventValue.double(3.14) == EventValue.double(3.14))
        #expect(EventValue.boolean(true) == EventValue.boolean(true))
        #expect(EventValue.boolean(true) != EventValue.boolean(false))
    }

    @Test func expressibleByLiterals() {
        let str: EventValue = "hello"
        #expect(str == .string("hello"))

        let int: EventValue = 42
        #expect(int == .integer(42))

        let dbl: EventValue = 3.14
        #expect(dbl == .double(3.14))

        let bool: EventValue = true
        #expect(bool == .boolean(true))
    }
}
