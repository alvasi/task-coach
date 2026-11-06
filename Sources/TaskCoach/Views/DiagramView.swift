import SwiftUI

/// Draws the small grid diagrams Claude returns: boxes on a 4x4 grid, arrows between them.
struct DiagramView: View {
    let diagram: Diagram

    private let nodeHeight: CGFloat = 34
    private let rowSpacing: CGFloat = 62

    private var cols: Int { max(1, (diagram.nodes.map(\.col).max() ?? 0) + 1) }
    private var rows: Int { max(1, (diagram.nodes.map(\.row).max() ?? 0) + 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                let layout = Layout(width: geo.size.width, cols: cols, nodeHeight: nodeHeight, rowSpacing: rowSpacing)
                ZStack(alignment: .topLeading) {
                    Canvas { ctx, _ in
                        for edge in diagram.edges { draw(edge, in: &ctx, layout: layout) }
                    }
                    ForEach(diagram.nodes, id: \.id) { node in
                        let r = layout.rect(for: node)
                        Text(node.label)
                            .font(.serif(12, node.highlight == true ? .bold : .regular))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 4)
                            .frame(width: r.width, height: r.height)
                            .foregroundStyle(node.highlight == true ? Theme.pencil : Theme.ink)
                            .background(Rectangle().fill(Theme.paperRaised))
                            .overlay(
                                Rectangle().strokeBorder(node.highlight == true ? Theme.pencil : Theme.ink.opacity(0.7),
                                                         lineWidth: node.highlight == true ? 1.6 : 1)
                            )
                            .position(x: r.midX, y: r.midY)
                    }
                }
            }
            .frame(height: CGFloat(rows) * rowSpacing - (rowSpacing - nodeHeight) + 20)

            if let caption = diagram.caption, !caption.isEmpty {
                Text(caption).font(.serif(12)).italic().foregroundStyle(Theme.inkMuted)
            }
        }
        .padding(12)
        .overlay(Rectangle().strokeBorder(Theme.cardStroke, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
    }

    private struct Layout {
        let width: CGFloat
        let cols: Int
        let nodeHeight: CGFloat
        let rowSpacing: CGFloat

        func rect(for node: DiagramNode) -> CGRect {
            let cell = width / CGFloat(cols)
            let w = min(cell * (cols >= 3 ? 0.76 : 0.8), 150)
            let cx = cell * (CGFloat(node.col) + 0.5)
            let cy = CGFloat(node.row) * rowSpacing + nodeHeight / 2 + 16
            return CGRect(x: cx - w / 2, y: cy - nodeHeight / 2, width: w, height: nodeHeight)
        }
    }

    private func draw(_ edge: DiagramEdge, in ctx: inout GraphicsContext, layout: Layout) {
        guard let a = diagram.nodes.first(where: { $0.id == edge.from }),
              let b = diagram.nodes.first(where: { $0.id == edge.to }) else { return }
        let ra = layout.rect(for: a), rb = layout.rect(for: b)
        let start = Self.exitPoint(from: ra, toward: CGPoint(x: rb.midX, y: rb.midY))
        let end = Self.exitPoint(from: rb, toward: CGPoint(x: ra.midX, y: ra.midY))

        let missing = edge.style == "missing"
        let dashed = missing || edge.style == "dashed"
        let color: Color = missing ? Theme.pencil : Theme.inkMuted
        let style = StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: dashed ? [4, 3] : [])

        var line = Path()
        line.move(to: start)
        line.addLine(to: end)
        ctx.stroke(line, with: .color(color), style: style)

        // Filled arrowhead
        let angle = atan2(end.y - start.y, end.x - start.x)
        var head = Path()
        head.move(to: end)
        head.addLine(to: CGPoint(x: end.x - 7 * cos(angle - .pi / 7), y: end.y - 7 * sin(angle - .pi / 7)))
        head.addLine(to: CGPoint(x: end.x - 7 * cos(angle + .pi / 7), y: end.y - 7 * sin(angle + .pi / 7)))
        head.closeSubpath()
        ctx.fill(head, with: .color(color))

        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        if missing {
            let badge = CGRect(x: mid.x - 8, y: mid.y - 8, width: 16, height: 16)
            ctx.fill(Path(ellipseIn: badge), with: .color(Theme.pencil))
            ctx.draw(Text("?").font(.system(size: 10.5, weight: .heavy)).foregroundColor(.white), at: mid)
            return
        }
        if let label = edge.label, !label.isEmpty {
            let text = Text(label).font(.serif(10.5)).italic().foregroundColor(Theme.inkMuted)
            if abs(ra.midY - rb.midY) < 1 {
                // Same row: above the boxes, where there's room.
                ctx.draw(text, at: CGPoint(x: mid.x, y: ra.minY - 7))
            } else if abs(end.y - start.y) > abs(end.x - start.x) {
                ctx.draw(text, at: CGPoint(x: mid.x + 6, y: mid.y), anchor: .leading)
            } else {
                // Diagonal: just above the line's middle, on the side away from the other branch.
                let goingDown = end.y > start.y
                ctx.draw(text, at: CGPoint(x: mid.x, y: mid.y + (goingDown ? 9 : -9)),
                         anchor: goingDown ? .topTrailing : .bottomTrailing)
            }
        }
    }

    /// Where a line from the rect's centre toward `target` crosses the rect's edge.
    private static func exitPoint(from rect: CGRect, toward target: CGPoint) -> CGPoint {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let dx = target.x - c.x, dy = target.y - c.y
        guard dx != 0 || dy != 0 else { return c }
        let sx = dx == 0 ? CGFloat.infinity : (rect.width / 2) / abs(dx)
        let sy = dy == 0 ? CGFloat.infinity : (rect.height / 2) / abs(dy)
        let s = min(sx, sy)
        return CGPoint(x: c.x + dx * s, y: c.y + dy * s)
    }
}
