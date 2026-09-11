import Foundation
import CoreGraphics

public enum DockEdge: String, CaseIterable, Codable, Sendable {
    case bottom, left, right

    public var title: String {
        switch self {
        case .bottom: "아래"
        case .left: "왼쪽"
        case .right: "오른쪽"
        }
    }
}

/// Coordinates are in AppKit points, including negative origins on secondary displays.
public enum DockLayout {
    public static func frame(in visibleFrame: CGRect, edge: DockEdge,
                             iconSize: Double, itemCount: Int, inset: Double) -> CGRect {
        let safeInset = max(0, min(inset, min(visibleFrame.width, visibleFrame.height) / 4))
        let icon = max(32, min(72, iconSize))
        let thickness = icon + 36
        let length = Double(max(1, itemCount)) * (icon + 12) + 76
        let horizontal = edge == .bottom
        let width = min(horizontal ? length : thickness, max(1, visibleFrame.width - safeInset * 2))
        let height = min(horizontal ? thickness : length, max(1, visibleFrame.height - safeInset * 2))
        switch edge {
        case .bottom:
            return CGRect(x: visibleFrame.midX - width / 2, y: visibleFrame.minY + safeInset,
                          width: width, height: height)
        case .left:
            return CGRect(x: visibleFrame.minX + safeInset, y: visibleFrame.midY - height / 2,
                          width: width, height: height)
        case .right:
            return CGRect(x: visibleFrame.maxX - safeInset - width, y: visibleFrame.midY - height / 2,
                          width: width, height: height)
        }
    }
}

public struct PinnedApplication: Codable, Equatable, Identifiable, Sendable {
    public var id: String { path }
    public let path: String
    public let bundleIdentifier: String?
    public let separatorID: UUID?
    public var isSeparator: Bool { separatorID != nil }
    public init(path: String, bundleIdentifier: String?) {
        self.path = path
        self.bundleIdentifier = bundleIdentifier
        separatorID = nil
    }
    public init(separatorID: UUID = UUID()) {
        self.separatorID = separatorID
        path = "everydock-separator://\(separatorID.uuidString)"
        bundleIdentifier = nil
    }
}

public struct DockPreferences: Codable, Equatable, Sendable {
    public var iconSize: Double = 48
    public var inset: Double = 10
    public var edge: DockEdge = .bottom
    public var showRunningApps = true
    public var showOnFullScreen = true
    public var hiddenDisplayIDs: Set<String> = []
    public var pinnedApps: [PinnedApplication] = []
    public var magnification: Double = 1.65
    public var manageNativeDock = true
    public var clickToMinimize = true
    public var followNativeSize = true
    public var showPreviews = true
    public var previewDelay = 0.55

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case iconSize, inset, edge, showRunningApps, showOnFullScreen, hiddenDisplayIDs, pinnedApps
        case magnification, manageNativeDock, clickToMinimize
        case followNativeSize, showPreviews, previewDelay
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        iconSize = try values.decodeIfPresent(Double.self, forKey: .iconSize) ?? 48
        inset = try values.decodeIfPresent(Double.self, forKey: .inset) ?? 10
        edge = try values.decodeIfPresent(DockEdge.self, forKey: .edge) ?? .bottom
        showRunningApps = try values.decodeIfPresent(Bool.self, forKey: .showRunningApps) ?? true
        showOnFullScreen = try values.decodeIfPresent(Bool.self, forKey: .showOnFullScreen) ?? true
        hiddenDisplayIDs = try values.decodeIfPresent(Set<String>.self, forKey: .hiddenDisplayIDs) ?? []
        pinnedApps = try values.decodeIfPresent([PinnedApplication].self, forKey: .pinnedApps) ?? []
        magnification = try values.decodeIfPresent(Double.self, forKey: .magnification) ?? 1.65
        manageNativeDock = try values.decodeIfPresent(Bool.self, forKey: .manageNativeDock) ?? true
        clickToMinimize = try values.decodeIfPresent(Bool.self, forKey: .clickToMinimize) ?? true
        followNativeSize = try values.decodeIfPresent(Bool.self, forKey: .followNativeSize) ?? true
        showPreviews = try values.decodeIfPresent(Bool.self, forKey: .showPreviews) ?? true
        previewDelay = try values.decodeIfPresent(Double.self, forKey: .previewDelay) ?? 0.55
        normalize()
    }

    public mutating func normalize() {
        iconSize = iconSize.isFinite ? min(72, max(32, iconSize)) : 48
        inset = inset.isFinite ? min(40, max(0, inset)) : 10
        magnification = magnification.isFinite ? min(4, max(1, magnification)) : 1.65
        previewDelay = previewDelay.isFinite ? min(2, max(0.2, previewDelay)) : 0.55
        var paths = Set<String>()
        var bundles = Set<String>()
        pinnedApps = pinnedApps.map { item in
            item.separatorID.map { PinnedApplication(separatorID: $0) } ?? item
        }.filter { app in
            guard paths.insert(app.path).inserted else { return false }
            guard let bundle = app.bundleIdentifier else { return true }
            return bundles.insert(bundle).inserted
        }
    }
}

/// One shared geometry contract for panel sizing, drawing, hover and utility tiles.
public enum DockMetrics {
    public static func aligned(_ frame: CGRect, scale: Double) -> CGRect {
        let scale = max(1, scale)
        return CGRect(x: (frame.minX * scale).rounded() / scale,
                      y: (frame.minY * scale).rounded() / scale,
                      width: (frame.width * scale).rounded() / scale,
                      height: (frame.height * scale).rounded() / scale)
    }

    public static let gap = 2.0
    public static let padding = 7.0
    public static let iconBaseline = 8.0
    public static let topPadding = 4.0
    public static let separatorSpace = 12.0
    public static let utilityCount = 3
    public static func length(iconSize: Double, appCount: Int, customSeparators: Int = 0, runningBoundary: Bool = false) -> Double {
        Double(appCount + utilityCount) * (iconSize + gap) - gap + padding * 2 + separatorSpace
            + Double(customSeparators) * (separatorSpace + gap) + (runningBoundary ? separatorSpace : 0)
    }
    public static func thickness(iconSize: Double) -> Double { iconSize + iconBaseline + topPadding }
    public static func reserve(iconSize: Double, magnification: Double) -> Double { iconSize * (magnification - 1) * 3.5 }
}

public enum DockMotion {
    /// Equal elapsed time produces equal easing at 60, 120 or variable Hz.
    public static func interpolation(elapsed: Double) -> Double { 1 - exp(-max(0, elapsed) * 20) }

    /// Cosine falloff keeps the magnification continuous at both ends of its radius.
    public static func scale(distance: Double, iconSize: Double, magnification: Double) -> Double {
        let radius = (iconSize + DockMetrics.gap) * 2.5
        let normalized = min(1, abs(distance) / radius)
        return 1 + (magnification - 1) * (cos(normalized * .pi) + 1) / 2
    }

    public static func bounce(elapsed: Double, iconSize: Double) -> Double {
        let cycle = elapsed.truncatingRemainder(dividingBy: 0.7) / 0.7
        return max(0, sin(cycle * .pi)) * iconSize * 0.42
    }
}
