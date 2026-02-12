public struct InitOptions: Sendable {
    public let host: String?
    public let flushInterval: Double?
    public let trackingMode: TrackingMode

    public init(host: String? = nil, flushInterval: Double? = nil, trackingMode: TrackingMode = .readFromEnvironment) {
        self.host = host
        self.flushInterval = flushInterval
        self.trackingMode = trackingMode
    }
}
