import SwiftUI

/// 시안의 선 아이콘: 즐겨찾기 폴더 = 주황 폴더, 실제 폴더 = 회색 폴더, 앱 = 둥근 사각형, 웹 주소 = 지구본, 파일 = 접힌 문서
struct FavoriteIcon: View {
    let kind: FavoriteKind
    let size: CGFloat
    let dark: Bool

    var body: some View {
        let line = max(size / 11, 1)
        Group {
            switch kind {
            case .group:
                FolderShape().fill(dark ? Color(red: 245 / 255, green: 166 / 255, blue: 35 / 255)
                                        : Color(red: 224 / 255, green: 142 / 255, blue: 18 / 255))
            case .folder:
                FolderShape().fill(Color(red: 124 / 255, green: 128 / 255, blue: 144 / 255))   // #7C8090
            case .app:
                RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                    .stroke(.secondary, lineWidth: line)
                    .padding(line / 2 + size * 0.06)
            case .url:
                GlobeShape().stroke(.secondary, lineWidth: line).padding(line / 2 + size * 0.04)
            case .separator:
                Rectangle().fill(.secondary).frame(height: line)
            case .file:
                DocumentShape().stroke(.secondary, style: StrokeStyle(lineWidth: line, lineJoin: .round))
                    .padding(.horizontal, size * 0.14).padding(.vertical, line / 2 + size * 0.04)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct FolderShape: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        let top = r.minY + h * 0.16, tabTop = r.minY + h * 0.06, bottom = r.minY + h * 0.88
        let rad = w * 0.08
        var p = Path()
        p.move(to: CGPoint(x: r.minX + rad, y: tabTop))
        p.addLine(to: CGPoint(x: r.minX + w * 0.38, y: tabTop))
        p.addLine(to: CGPoint(x: r.minX + w * 0.48, y: top))
        p.addLine(to: CGPoint(x: r.maxX - rad, y: top))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: top + rad), control: CGPoint(x: r.maxX, y: top))
        p.addLine(to: CGPoint(x: r.maxX, y: bottom - rad))
        p.addQuadCurve(to: CGPoint(x: r.maxX - rad, y: bottom), control: CGPoint(x: r.maxX, y: bottom))
        p.addLine(to: CGPoint(x: r.minX + rad, y: bottom))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: bottom - rad), control: CGPoint(x: r.minX, y: bottom))
        p.addLine(to: CGPoint(x: r.minX, y: tabTop + rad))
        p.addQuadCurve(to: CGPoint(x: r.minX + rad, y: tabTop), control: CGPoint(x: r.minX, y: tabTop))
        p.closeSubpath()
        return p
    }
}

private struct GlobeShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.addEllipse(in: r)
        p.addEllipse(in: r.insetBy(dx: r.width * 0.28, dy: 0))
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        return p
    }
}

private struct DocumentShape: Shape {
    func path(in r: CGRect) -> Path {
        let fold = r.width * 0.38
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - fold, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + fold))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        p.move(to: CGPoint(x: r.maxX - fold, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - fold, y: r.minY + fold))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + fold))
        return p
    }
}
