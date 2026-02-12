import Foundation

public enum EventValue: Sendable, Encodable, Equatable {
    case integer(Int)
    case string(String)
    case double(Double)
    case boolean(Bool)

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .integer(x):
            try container.encode(x)
        case let .string(x):
            try container.encode(x)
        case let .double(x):
            try container.encode(x)
        case let .boolean(x):
            try container.encode(x)
        }
    }
}

extension EventValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension EventValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .integer(value)
    }
}

extension EventValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension EventValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .boolean(value)
    }
}
