import Foundation

/// Allowed output frame-rate caps when down-converting higher-FPS sources.
public enum VideoFPSCapPreset: Int, CaseIterable, Sendable {
    case fps60 = 60
    case fps30 = 30
    case fps24 = 24
    case fps15 = 15

    public static let allowedValues: [Int] = [60, 30, 24, 15]

    /// Default persisted value when the user enables a cap without a stored choice yet.
    public static let defaultStoredFPS: Int = 30

    /// Snap unknown stored ints to the nearest supported cap.
    public static func normalizeStored(_ raw: Int) -> Int {
        if allowedValues.contains(raw) { return raw }
        return allowedValues.min(by: { abs($0 - raw) < abs($1 - raw) }) ?? defaultStoredFPS
    }

    /// ``nil`` = keep source timing (cap off, unknown nominal FPS ≤ cap).
    /// Non-nil when compression attaches a capped video composition frame duration.
    public static func effectiveCapFPS(enabled: Bool, storedFPS: Int, sourceNominalFPS: Float) -> Int? {
        guard enabled else { return nil }
        let cap = normalizeStored(storedFPS)
        guard cap > 0 else { return nil }
        if sourceNominalFPS > 0, sourceNominalFPS <= Float(cap) {
            return nil
        }
        return cap
    }
}
