import SwiftUI
import TrashFlushCore

/// Canvas symbol tags. Files use their index (0 and up).
enum Symbol {
    static let trashFull = -1
    static let trashEmpty = -2
    static let recycle = -3
}

/// Files leaving the Trash, the same in every animation: they climb out of the
/// Dock's own Trash (masked below its rim, since the real one can't be hidden),
/// or out of a stand-in that peeks up when the Dock is hidden.
struct TrashThrow {
    let scene: NotchScene
    let iconCount: Int

    /// Where files leave the Trash: the top of the can. Dock icons stay upright
    /// on every edge, so that is always straight up from the center.
    func rim(of trash: CGPoint) -> CGPoint {
        CGPoint(x: trash.x, y: trash.y - scene.trashIconSize * 0.35)
    }

    /// Hides anything still inside the Dock's Trash.
    func maskInside(_ context: inout GraphicsContext, trash: CGPoint) {
        guard !scene.peeksTrash else { return }
        let width = scene.trashIconSize + NotchScene.fileSize * 2
        let rim = rim(of: trash)
        var outside = Path(CGRect(origin: .zero, size: scene.size))
        outside.addRect(CGRect(x: trash.x - width / 2, y: rim.y, width: width, height: scene.size.height - rim.y))
        context.clip(to: outside, style: FillStyle(eoFill: true))
    }

    /// Small files rising up to the rim, from the middle of the stand-in, or
    /// from just out of sight inside the Dock's Trash.
    func drawEmerging(_ flights: [NotchTimeline.Flight], in context: inout GraphicsContext,
                      trash: CGPoint, time t: Double) {
        guard iconCount > 0 else { return }
        for flight in flights where flight.emergence(at: t) > 0 && t < flight.start {
            guard let icon = context.resolveSymbol(id: flight.index % iconCount) else { continue }
            let rise = 1 - pow(1 - flight.emergence(at: t), 2)
            let scale = FlightPath.scale(progress: 0, isMini: flight.isMini)
            let top = rim(of: trash)
            let bottom = scene.peeksTrash ? trash : CGPoint(x: top.x, y: top.y + NotchScene.fileSize * scale / 2)
            var file = context
            file.translateBy(x: bottom.x + (top.x - bottom.x) * rise, y: bottom.y + (top.y - bottom.y) * rise)
            file.scaleBy(x: scale, y: scale)
            file.draw(icon, at: .zero, anchor: .center)
        }
    }

    /// A one-icon Dock sliding out from the screen edge, like the real Dock does
    /// when you hover there, with the Trash in it. Full until the last file
    /// leaves, it puffs up from its base each time it throws one.
    func drawStandIn(in context: inout GraphicsContext, at center: CGPoint, emptied: Bool, puff: Double) {
        let icon = scene.trashIconSize
        let tile = CGRect(x: center.x - icon / 2 - 6, y: center.y - icon / 2 - 6, width: icon + 12, height: icon + 12)
        let shape = Path(roundedRect: tile, cornerRadius: 16, style: .continuous)
        context.fill(shape, with: .color(.white.opacity(0.2)))
        context.stroke(shape, with: .color(.white.opacity(0.3)), lineWidth: 1)

        guard let trash = context.resolveSymbol(id: emptied ? Symbol.trashEmpty : Symbol.trashFull) else { return }
        var puffed = context
        puffed.translateBy(x: center.x, y: center.y + icon / 2)
        puffed.scaleBy(x: 1 + puff * 0.5, y: 1 + puff)
        puffed.draw(trash, at: CGPoint(x: 0, y: -icon / 2), anchor: .center)
    }
}
