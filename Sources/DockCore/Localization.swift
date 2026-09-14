import Foundation
import Synchronization

public enum AppLanguage: String, Codable, CaseIterable, Sendable {
    case system, english = "en", korean = "ko"

    public func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard self == .system else { return self }
        let primary = preferredLanguages.first?.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first
        return primary == "ko" ? .korean : .english
    }

    public var title: String {
        switch self {
        case .system: L10n.text("Follow System")
        case .english: "English"
        case .korean: "한국어"
        }
    }
}

/// Retains interpolation arguments separately so names and OS-provided errors remain untouched.
public struct LocalizedText: ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
    public var key: String
    public var arguments: [String]
    public init(stringLiteral value: String) { key = value; arguments = [] }
    public init(stringInterpolation: StringInterpolation) {
        key = stringInterpolation.key
        arguments = stringInterpolation.arguments
    }
    public struct StringInterpolation: StringInterpolationProtocol {
        var key = ""
        var arguments: [String] = []
        public init(literalCapacity: Int, interpolationCount: Int) {
            key.reserveCapacity(literalCapacity)
            arguments.reserveCapacity(interpolationCount)
        }
        public mutating func appendLiteral(_ literal: String) { key += literal }
        public mutating func appendInterpolation<T>(_ value: T) {
            key += "{\(arguments.count)}"
            arguments.append(String(describing: value))
        }
    }
}

public enum L10n {
    private static let selected = Mutex(AppLanguage.system.resolved())
    public static func use(_ language: AppLanguage) { selected.withLock { $0 = language.resolved() } }
    public static func text(_ value: LocalizedText) -> String {
        render(value, language: selected.withLock { $0 })
    }
    public static func render(_ value: LocalizedText, language: AppLanguage) -> String {
        let template = language.resolved() == .korean ? korean[value.key] ?? value.key : value.key
        // Replace tokens in the template only; never interpret tokens inside external names.
        var result = "", cursor = template.startIndex
        while cursor < template.endIndex {
            if template[cursor] == "{", let end = template[cursor...].firstIndex(of: "}"),
               let index = Int(template[template.index(after: cursor)..<end]), value.arguments.indices.contains(index) {
                result += value.arguments[index]
                cursor = template.index(after: end)
            } else {
                result.append(template[cursor])
                cursor = template.index(after: cursor)
            }
        }
        return result
    }
}
