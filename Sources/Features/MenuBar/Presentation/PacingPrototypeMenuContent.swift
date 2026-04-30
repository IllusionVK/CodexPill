import SwiftUI

enum PacingPrototypeVariant: String, CaseIterable, Identifiable {
    case inlineMarker
    case stackedGhost
    case rightBadgeBand
    case barOnlyTone
    case expandedDetail

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inlineMarker:
            return "Inline Marker"
        case .stackedGhost:
            return "Below Label Ghost"
        case .rightBadgeBand:
            return "Right Badge Band"
        case .barOnlyTone:
            return "Bar Only"
        case .expandedDetail:
            return "Expanded Detail"
        }
    }
}

struct PacingPrototypeSample: Identifiable {
    enum WindowKind {
        case session
        case weekly

        var title: String {
            switch self {
            case .session:
                return "Session"
            case .weekly:
                return "Weekly"
            }
        }

        var totalMinutes: Double {
            switch self {
            case .session:
                return 5 * 60
            case .weekly:
                return 7 * 24 * 60
            }
        }
    }

    let id = UUID()
    let title: String
    let kind: WindowKind
    let usedPercent: Double?
    let remainingMinutes: Double?

    var expectedPercent: Double? {
        guard let remainingMinutes else { return nil }
        let elapsed = 1 - min(max(remainingMinutes / kind.totalMinutes, 0), 1)
        return elapsed * 100
    }

    var deltaPoints: Double? {
        guard let usedPercent, let expectedPercent else { return nil }
        return usedPercent - expectedPercent
    }

    var severity: PacingSeverity {
        guard let deltaPoints else { return .missing }
        if deltaPoints >= 30 { return .severe }
        if deltaPoints >= 12 { return .over }
        if deltaPoints <= -12 { return .under }
        return .steady
    }

    var usageText: String {
        guard let usedPercent else { return "--" }
        return "\(Int(usedPercent.rounded()))% used"
    }

    var expectedText: String {
        guard let expectedPercent else { return "No reset" }
        return "\(Int(expectedPercent.rounded()))% expected"
    }

    var deltaText: String {
        guard let deltaPoints else { return "--" }
        let rounded = Int(deltaPoints.rounded())
        if rounded > 0 { return "+\(rounded)" }
        return "\(rounded)"
    }

    var resetText: String {
        guard let remainingMinutes else { return "No reset data" }
        if remainingMinutes < 60 {
            return "Resets in \(Int(max(1, remainingMinutes.rounded())))min"
        }
        if remainingMinutes < 24 * 60 {
            let hours = Int(remainingMinutes) / 60
            let minutes = Int(remainingMinutes) % 60
            return minutes == 0 ? "Resets in \(hours)h" : "Resets in \(hours)h\(String(format: "%02d", minutes))"
        }
        let days = Int(max(1, remainingMinutes / (24 * 60)))
        return "Resets in \(days)d"
    }
}

enum PacingSeverity {
    case under
    case steady
    case over
    case severe
    case missing

    var neutralWord: String {
        switch self {
        case .under:
            return "Room left"
        case .steady:
            return "On pace"
        case .over:
            return "Over pace"
        case .severe:
            return "High pace"
        case .missing:
            return "No pace"
        }
    }

    var friendlyWord: String {
        switch self {
        case .under:
            return "Plenty left"
        case .steady:
            return "Steady"
        case .over:
            return "Fast"
        case .severe:
            return "Very fast"
        case .missing:
            return "Unavailable"
        }
    }

    var color: Color {
        switch self {
        case .under:
            return .secondary
        case .steady:
            return .accentColor
        case .over:
            return .orange
        case .severe:
            return .red
        case .missing:
            return .secondary
        }
    }
}

struct PacingPrototypeMenuContent: View {
    let variant: PacingPrototypeVariant
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(variant.title)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(scopeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(Self.samples) { sample in
                PacingPrototypeRow(
                    sample: sample,
                    variant: variant,
                    accentColor: accentColor
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scopeText: String {
        switch variant {
        case .expandedDetail:
            return "Expanded only"
        default:
            return "Current cards"
        }
    }

    static let samples: [PacingPrototypeSample] = [
        .init(title: "Under", kind: .session, usedPercent: 20, remainingMinutes: 150),
        .init(title: "Near", kind: .weekly, usedPercent: 57, remainingMinutes: 3 * 24 * 60),
        .init(title: "Over", kind: .session, usedPercent: 70, remainingMinutes: 150),
        .init(title: "Severe", kind: .weekly, usedPercent: 92, remainingMinutes: 3 * 24 * 60),
        .init(title: "Missing", kind: .session, usedPercent: nil, remainingMinutes: nil)
    ]
}

private struct PacingPrototypeRow: View {
    let sample: PacingPrototypeSample
    let variant: PacingPrototypeVariant
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch variant {
            case .inlineMarker:
                inlineHeader(word: sample.severity.friendlyWord)
                PacingPrototypeBar(sample: sample, accentColor: accentColor, style: .expectedMarker)
            case .stackedGhost:
                Text("\(sample.title) \(sample.kind.title)")
                    .font(.caption.weight(.semibold))
                Text("\(sample.usageText) · \(sample.severity.neutralWord)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                PacingPrototypeBar(sample: sample, accentColor: accentColor, style: .ghostExpected)
            case .rightBadgeBand:
                HStack(alignment: .firstTextBaseline) {
                    Text("\(sample.title) \(sample.kind.title)")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text(sample.deltaText)
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(sample.severity.color)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(sample.severity.color.opacity(0.12)))
                }
                PacingPrototypeBar(sample: sample, accentColor: accentColor, style: .paceBand)
                Text(sample.resetText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            case .barOnlyTone:
                inlineHeader(word: "")
                PacingPrototypeBar(sample: sample, accentColor: accentColor, style: .twoTone)
            case .expandedDetail:
                Text("\(sample.title) \(sample.kind.title)")
                    .font(.caption.weight(.semibold))
                HStack {
                    Text(sample.usageText)
                    Spacer()
                    Text(sample.expectedText)
                    Spacer()
                    Text("\(sample.deltaText) pace")
                        .foregroundStyle(sample.severity.color)
                }
                .font(.caption2.monospacedDigit())
                PacingPrototypeBar(sample: sample, accentColor: accentColor, style: .expectedMarker)
                Text("\(sample.severity.neutralWord) · \(sample.resetText)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func inlineHeader(word: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("\(sample.title) \(sample.kind.title)")
                .font(.caption.weight(.semibold))
            Text(sample.usageText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            if !word.isEmpty {
                Text(word)
                    .font(.caption)
                    .foregroundStyle(sample.severity.color)
            }
            Spacer()
            Text(sample.resetText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private enum PacingPrototypeBarStyle {
    case expectedMarker
    case ghostExpected
    case paceBand
    case twoTone
}

private struct PacingPrototypeBar: View {
    let sample: PacingPrototypeSample
    let accentColor: Color
    let style: PacingPrototypeBarStyle

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let used = clamped(sample.usedPercent)
            let expected = clamped(sample.expectedPercent)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.14))

                if style == .paceBand, let expected {
                    Capsule()
                        .fill(Color.secondary.opacity(0.16))
                        .frame(width: width * CGFloat(min(1, (expected + 8) / 100)))
                }

                if style == .ghostExpected, let expected {
                    Capsule()
                        .fill(Color.secondary.opacity(0.24))
                        .frame(width: width * CGFloat(expected / 100))
                }

                if let used {
                    Capsule()
                        .fill(fillColor)
                        .frame(width: width * CGFloat(used / 100))
                }

                if style == .twoTone,
                   let used,
                   let expected,
                   used > expected {
                    Capsule()
                        .fill(sample.severity.color.opacity(0.75))
                        .frame(width: width * CGFloat((used - expected) / 100))
                        .offset(x: width * CGFloat(expected / 100))
                }

                if style == .expectedMarker, let expected {
                    Rectangle()
                        .fill(Color.primary.opacity(0.55))
                        .frame(width: 2, height: 9)
                        .offset(x: max(0, min(width - 2, width * CGFloat(expected / 100))))
                }
            }
        }
        .frame(height: 7)
        .opacity(sample.usedPercent == nil ? 0.55 : 1)
    }

    private var fillColor: Color {
        switch style {
        case .twoTone:
            return accentColor.opacity(0.8)
        default:
            return sample.severity == .severe ? .orange : accentColor
        }
    }

    private func clamped(_ value: Double?) -> Double? {
        value.map { min(max($0, 0), 100) }
    }
}
