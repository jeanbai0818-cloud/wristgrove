import SwiftUI

enum GroveStyle {
    static let sage = Color(red: 0.52, green: 0.65, blue: 0.54)
    static let forest = Color(red: 0.18, green: 0.34, blue: 0.26)
    static let cream = Color(red: 0.97, green: 0.96, blue: 0.91)
    static let night = Color(red: 0.055, green: 0.11, blue: 0.085)

    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? night : cream
    }

    static func card(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.065) : Color.white.opacity(0.8)
    }

    static func ink(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? cream : forest
    }
}

/// An original pair of leaves; the mark does not encode a health score.
struct GroveMark: View {
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            Circle().fill(GroveStyle.sage.opacity(0.16))
            GroveLeaf()
                .fill(GroveStyle.sage)
                .frame(width: size * 0.4, height: size * 0.57)
                .rotationEffect(.degrees(-24))
                .offset(x: -size * 0.11, y: -size * 0.02)
            GroveLeaf()
                .fill(GroveStyle.forest)
                .frame(width: size * 0.31, height: size * 0.45)
                .rotationEffect(.degrees(37))
                .offset(x: size * 0.15, y: size * 0.07)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct GroveLeaf: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                      control1: CGPoint(x: rect.minX - rect.width * 0.1, y: rect.height * 0.67),
                      control2: CGPoint(x: rect.minX, y: rect.height * 0.16))
        path.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                      control1: CGPoint(x: rect.maxX, y: rect.height * 0.1),
                      control2: CGPoint(x: rect.maxX + rect.width * 0.12, y: rect.height * 0.64))
        return path
    }
}

struct GroveCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    private let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GroveStyle.card(scheme), in: RoundedRectangle(cornerRadius: 24))
    }
}

struct DemoBadge: View {
    var body: some View {
        Label(GroveCopy.text("演示数据", "Demo data"), systemImage: "leaf")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(GroveStyle.sage.opacity(0.2), in: Capsule())
            .accessibilityLabel(GroveCopy.text("演示数据，不是你的健康数据", "Demo data, not your health data"))
    }
}
