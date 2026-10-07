import Charts
import SwiftUI

// MARK: - Explanations

/// A process name that explains itself: click the name or the glyph beside it
/// to open the wiki. Deliberately always visible rather than hover-revealed,
/// because the person who needs it is the one who has no idea what they are
/// looking at.
struct ProcessNameCell: View {
    let name: String
    var bundleIdentifier: String? = nil
    var detail: String? = nil
    var font: Font = Typeface.label(12.5)

    @Environment(AppRouter.self) private var router
    @State private var isHovering = false

    var body: some View {
        Button {
            router.openWiki(forName: name, bundleIdentifier: bundleIdentifier)
        } label: {
            HStack(spacing: 5) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(font)
                        .foregroundStyle(isHovering ? Palette.accent : Palette.ink)
                        .lineLimit(1)
                    if let detail {
                        Text(detail)
                            .font(Typeface.label(10.5))
                            .foregroundStyle(Palette.inkSoft)
                            .lineLimit(1)
                    }
                }
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Palette.inkSoft.opacity(isHovering ? 0.9 : 0.45))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("What is \(name)?")
        .accessibilityLabel(name)
        .accessibilityHint("Opens the wiki to explain what this is")
        .onHover { hovering in
            withAnimation(Motion.reveal) { isHovering = hovering }
        }
    }
}

/// A metric name that explains itself: hover for a one-line answer, click for
/// the fuller one. Every technical term in the app wears one of these.
struct GlossaryLabel: View {
    let entry: GlossaryEntry
    var title: String? = nil
    var font: Font = Typeface.label(11.5)
    var tint: Color = Palette.inkSoft
    var showsGlyph: Bool = true

    @State private var showsDetail = false

    var body: some View {
        Button {
            showsDetail.toggle()
        } label: {
            HStack(spacing: 4) {
                Text(title ?? entry.term)
                    .font(font)
                if showsGlyph {
                    Image(systemName: "info.circle")
                        .font(.system(size: 8.5, weight: .semibold))
                        .opacity(0.55)
                }
            }
            .foregroundStyle(tint)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(entry.summary)
        .popover(isPresented: $showsDetail, arrowEdge: .bottom) {
            GlossaryPopover(entry: entry)
        }
        .accessibilityLabel(entry.term)
        .accessibilityHint(entry.summary)
    }
}

struct GlossaryPopover: View {
    let entry: GlossaryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(entry.term)
                .font(Typeface.heading(13))
                .foregroundStyle(Palette.ink)
            Text(entry.summary)
                .font(Typeface.proseEmphasis(15))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Rectangle()
                .fill(Palette.rule)
                .frame(height: 1)
            Text(entry.detail)
                .font(Typeface.prose(13.5))
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: 300, alignment: .leading)
        .background(Palette.paperCard)
    }
}

// MARK: - Values

/// Numeric readout whose digits roll over instead of snapping.
struct MetricValue: View {
    let text: String
    var font: Font = Typeface.data(13)
    var color: Color = Palette.ink

    var body: some View {
        Text(text)
            .font(font)
            .monospacedDigit()
            .foregroundStyle(color)
            .contentTransition(.numericText())
            .animation(Motion.drift, value: text)
    }
}

/// Thin meter that eases to its new fill instead of jumping.
struct GaugeBar: View {
    var fraction: Double
    var tint: Color = Palette.accent
    var height: CGFloat = 4

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(tint.opacity(0.18))
                Capsule()
                    .fill(tint)
                    .frame(width: max(height, proxy.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: height)
        .animation(Motion.respecting(Motion.settle, reduceMotion: reduceMotion), value: fraction)
    }
}

struct HealthDot: View {
    let level: HealthLevel
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(Palette.health(level))
            .frame(width: size, height: size)
            .shadow(color: Palette.health(level).opacity(0.5), radius: level == .normal ? 0 : 4)
    }
}

// MARK: - Panel surfaces

/// A value on the dark instrument surface: tracked label above, mono value below.
struct ReadoutTile: View {
    var label: GlossaryEntry?
    var title: String
    var value: String
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let label {
                GlossaryLabel(entry: label, tint: Palette.readoutSoft)
            } else {
                Text(title)
                    .font(Typeface.label(11.5))
                    .foregroundStyle(Palette.readoutSoft)
            }
            MetricValue(text: value, font: Typeface.data(15), color: Palette.readoutInk)
            if let caption {
                Text(caption)
                    .font(Typeface.label(10.5))
                    .foregroundStyle(Palette.readoutSoft.opacity(0.85))
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous)
                .fill(Palette.readoutCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous)
                .strokeBorder(Palette.readoutRule, lineWidth: 1)
        )
    }
}

// MARK: - Ledger

/// A paper list: hairline rows that warm up under the pointer instead of
/// taking a hard selection highlight.
struct LedgerRow<Content: View>: View {
    var isFirst: Bool = false
    @ViewBuilder var content: Content

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            content
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isHovering ? Palette.ink.opacity(0.045) : Color.clear)
        .overlay(alignment: .top) {
            if isFirst {
                Rectangle().fill(Palette.rule).frame(height: 1)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.rule).frame(height: 1)
        }
        .onHover { hovering in
            withAnimation(Motion.reveal) { isHovering = hovering }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Column headings for a ledger.
struct LedgerHeader<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 12) {
            content
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Sortable column heading, with the explanation as a separate small control
/// so the sort button and the info button never compete for the same click.
struct SortableHeader: View {
    let title: String
    var entry: GlossaryEntry? = nil
    var isActive: Bool = false
    var isAscending: Bool = false
    var width: CGFloat? = nil
    let action: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button(action: action) {
                HStack(spacing: 3) {
                    Text(title)
                        .font(Typeface.label(11))
                        .foregroundStyle(isActive ? Palette.ink : Palette.inkSoft)
                    Image(systemName: isAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Palette.accent)
                        .opacity(isActive ? 1 : 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if let entry {
                GlossaryGlyphButton(entry: entry)
            }
        }
        .frame(width: width, alignment: .trailing)
        .animation(Motion.reveal, value: isActive)
    }
}

/// Just the question mark, for places where the term is already on screen.
struct GlossaryGlyphButton: View {
    let entry: GlossaryEntry

    @State private var showsDetail = false

    var body: some View {
        Button {
            showsDetail.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(Palette.inkSoft.opacity(0.6))
                .frame(width: 12, height: 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(entry.summary)
        .popover(isPresented: $showsDetail, arrowEdge: .bottom) {
            GlossaryPopover(entry: entry)
        }
        .accessibilityLabel("What is \(entry.term)?")
        .accessibilityHint(entry.summary)
    }
}

/// The live trace that runs through the readout band.
struct PulseTrace: View {
    let points: [HistoryPoint]
    var keyPath: KeyPath<HistoryPoint, Double>
    var tint: Color = Palette.accent

    var body: some View {
        Chart(points.decimatedForDrawing()) { point in
            AreaMark(x: .value("Time", point.timestamp), y: .value("Value", point[keyPath: keyPath]))
                .foregroundStyle(
                    LinearGradient(
                        colors: [tint.opacity(0.32), tint.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)
            LineMark(x: .value("Time", point.timestamp), y: .value("Value", point[keyPath: keyPath]))
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .interpolationMethod(.monotone)
            if point == points.last {
                PointMark(x: .value("Time", point.timestamp), y: .value("Value", point[keyPath: keyPath]))
                    .foregroundStyle(tint)
                    .symbolSize(38)
                    .shadow(color: tint.opacity(0.85), radius: 5)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...100)
        .chartPlotStyle { plot in
            plot.background(.clear)
        }
    }
}
