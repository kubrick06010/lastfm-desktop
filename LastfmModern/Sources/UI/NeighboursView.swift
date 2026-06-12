import SwiftUI

struct NeighboursView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @Environment(\.openURL) private var openURL
    @Binding var query: String
    let onOpenGraph: (LastfmNeighbour) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Neighbours")
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                    Spacer()
                    Button("Refresh") {
                        Task { await scrobbleService.refreshNeighbours() }
                    }
                    .buttonStyle(.borderedProminent)
                }

                TextField("Filter neighbours", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .appPanelStyle()

                Text(scrobbleService.neighboursStatus)
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)

                Text("Separation: \(scrobbleService.separationStatus)")
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)

                if filteredNeighbours.isEmpty {
                    Text("No neighbours available.")
                        .font(.custom("Avenir Next Regular", size: 13))
                        .foregroundStyle(.secondary)
                        .appPanelStyle()
                } else {
                    Text("Showing \(filteredNeighbours.count) of \(scrobbleService.neighbours.count) neighbours")
                        .font(.custom("Avenir Next Medium", size: 12))
                        .foregroundStyle(.secondary)

                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(filteredNeighbours) { neighbour in
                            neighbourRow(neighbour)
                        }
                    }
                    .appPanelStyle()
                }
            }
            .padding(24)
        }
    }

    private var filteredNeighbours: [LastfmNeighbour] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return scrobbleService.neighbours }
        return scrobbleService.neighbours.filter { item in
            item.user.localizedCaseInsensitiveContains(trimmed) ||
            (item.realname?.localizedCaseInsensitiveContains(trimmed) ?? false) ||
            (item.country?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    private func neighbourRow(_ neighbour: LastfmNeighbour) -> some View {
        HStack(spacing: 10) {
            Button {
                onOpenGraph(neighbour)
            } label: {
                avatar(neighbour.avatarURL)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(neighbour.user)
                        .font(.custom("Avenir Next Medium", size: 13))
                    if let badge = badgeType(neighbour) {
                        badgeView(badge)
                    }
                }
                if let realname = neighbour.realname, !realname.isEmpty {
                    Text(realname)
                        .font(.custom("Avenir Next Regular", size: 11))
                        .foregroundStyle(.secondary)
                } else if let country = neighbour.country, !country.isEmpty {
                    Text(country)
                        .font(.custom("Avenir Next Regular", size: 11))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Text("Compatibility")
                        .font(.custom("Avenir Next Medium", size: 11))
                        .foregroundStyle(.secondary)
                    Text(matchLabel(neighbour.matchScore))
                        .font(.custom("Avenir Next Medium", size: 11))
                }
                matchBar(neighbour.matchScore)
            }
            Spacer()
            Button {
                onOpenGraph(neighbour)
            } label: {
                separationChip(for: neighbour.user)
            }
            .buttonStyle(.plain)
            Button {
                if let raw = neighbour.profileURL, let url = URL(string: raw) {
                    openURL(url)
                } else if let url = URL(string: "https://www.last.fm/user/\(neighbour.user)") {
                    openURL(url)
                }
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func avatar(_ urlString: String?) -> some View {
        if let urlString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image.resizable().scaledToFill()
                default:
                    fallbackAvatar()
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            fallbackAvatar()
        }
    }

    private func fallbackAvatar() -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.06))
            Image(systemName: "person.crop.circle.fill")
                .foregroundStyle(.secondary)
        }
        .frame(width: 40, height: 40)
    }

    private func matchLabel(_ score: Double?) -> String {
        guard let score else { return "-" }
        return "\(Int((score * 100).rounded()))%"
    }

    private func matchBar(_ score: Double?) -> some View {
        let ratio = min(1, max(0, score ?? 0))
        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.cyan.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .mask(
                        GeometryReader { geo in
                            Rectangle().frame(width: geo.size.width * ratio)
                        }
                    )
            }
            .frame(height: 8)
            .frame(width: 180)
    }

    private func badgeType(_ neighbour: LastfmNeighbour) -> String? {
        if let raw = neighbour.accountType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !raw.isEmpty, raw != "user" {
            return raw
        }
        return neighbour.isSubscriber ? "subscriber" : nil
    }

    private func badgeView(_ type: String) -> some View {
        let normalized = type.lowercased()
        let label = accountBadgeLabel(for: normalized)
        let fill: AnyShapeStyle = normalized == "alum"
            ? AnyShapeStyle(LinearGradient(colors: [Color(red: 0.55, green: 0.14, blue: 1.0), Color(red: 0.70, green: 0.26, blue: 1.0)], startPoint: .leading, endPoint: .trailing))
            : AnyShapeStyle(Color.black)
        return Text(label)
            .font(.custom("Avenir Next Demi Bold", size: 9))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(fill, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func separationChip(for user: String) -> some View {
        let lower = user.lowercased()
        let degree = scrobbleService.separationByUser[lower]
        let isComputing = scrobbleService.separationStatus.localizedCaseInsensitiveContains("Calculating")
        let label: String
        if let degree {
            label = "\(degree)°"
        } else if isComputing {
            label = "..."
        } else {
            label = "?"
        }

        return Text(label)
            .font(.custom("Avenir Next Demi Bold", size: 10))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

struct InteractiveSeparationGraphView: View {
    let graph: SocialGraphSnapshot
    let onOpenUser: (String) -> Void
    private let accent = Color(red: 1.0, green: 0.30, blue: 0.35)

    @State private var zoom: CGFloat = 1
    @State private var accumulatedZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var accumulatedOffset: CGSize = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Separation Network")
                    .font(.custom("Avenir Next Demi Bold", size: 18))
                Spacer()
                Text("Pinch to zoom, drag to pan")
                    .font(.custom("Avenir Next Medium", size: 11))
                    .foregroundStyle(.secondary)
                Button("Reset") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        zoom = 1
                        accumulatedZoom = 1
                        offset = .zero
                        accumulatedOffset = .zero
                    }
                }
                .buttonStyle(.plain)
                .font(.custom("Avenir Next Medium", size: 11))
            }

            GeometryReader { geo in
                let positions = layoutPositions(in: geo.size)
                ZStack {
                    ForEach(graph.edges) { edge in
                        if let from = positions[edge.from], let to = positions[edge.to] {
                            Path { path in
                                path.move(to: from)
                                path.addLine(to: to)
                            }
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        }
                    }

                    ForEach(graph.nodes) { node in
                        if let point = positions[node.id] {
                            Button {
                                onOpenUser(node.displayName)
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(nodeColor(node))
                                    Circle()
                                        .stroke(Color.white.opacity(0.24), lineWidth: node.isSource ? 2 : 1)
                                }
                                .frame(width: nodeSize(node), height: nodeSize(node))
                            }
                            .buttonStyle(.plain)
                            .position(point)

                            if node.isSource || node.isTarget || node.degree <= 1 {
                                Text(node.displayName)
                                    .font(.custom("Avenir Next Medium", size: 10))
                                    .lineLimit(1)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                                    .position(x: point.x, y: point.y + 14)
                            }
                        }
                    }
                }
                .scaleEffect(zoom)
                .offset(offset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: accumulatedOffset.width + value.translation.width,
                                height: accumulatedOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            accumulatedOffset = offset
                        }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            zoom = min(4.0, max(0.55, accumulatedZoom * value))
                        }
                        .onEnded { _ in
                            accumulatedZoom = zoom
                        }
                )
            }

            HStack(spacing: 14) {
                legendDot(accent, "You")
                legendDot(.cyan, "Target")
                legendDot(.white.opacity(0.6), "Intermediate")
            }
        }
    }

    private func layoutPositions(in size: CGSize) -> [String: CGPoint] {
        guard !graph.nodes.isEmpty else { return [:] }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxDegree = max(1, graph.nodes.map(\.degree).max() ?? 1)
        let baseRadius = min(size.width, size.height) * 0.44
        let ringStep = baseRadius / CGFloat(maxDegree)
        let groups = Dictionary(grouping: graph.nodes, by: \.degree)
        var positions: [String: CGPoint] = [:]
        positions.reserveCapacity(graph.nodes.count)

        for degree in groups.keys.sorted() {
            guard let nodesAtDegree = groups[degree] else { continue }
            if degree == 0 {
                if let source = nodesAtDegree.first {
                    positions[source.id] = center
                }
                continue
            }
            let radius = ringStep * CGFloat(degree)
            let count = nodesAtDegree.count
            for (idx, node) in nodesAtDegree.enumerated() {
                let angle = (2 * Double.pi * (Double(idx) / Double(max(1, count)))) - Double.pi / 2
                let x = center.x + CGFloat(cos(angle)) * radius
                let y = center.y + CGFloat(sin(angle)) * radius
                positions[node.id] = CGPoint(x: x, y: y)
            }
        }
        return positions
    }

    private func nodeColor(_ node: SocialGraphNode) -> Color {
        if node.isSource { return accent }
        if node.isTarget { return .cyan }
        return .white.opacity(0.72)
    }

    private func nodeSize(_ node: SocialGraphNode) -> CGFloat {
        if node.isSource { return 12 }
        if node.isTarget { return 10 }
        return 8
    }

    private func legendDot(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(.secondary)
        }
    }
}
