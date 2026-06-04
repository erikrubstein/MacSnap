import AppKit
import GridSnapCore

@MainActor
final class GridOverlayController {
    private var window: NSWindow?
    private var overlayView: GridOverlayView?

    var isVisible: Bool {
        window?.isVisible == true
    }

    func show(
        on screen: NSScreen,
        model: GridModel,
        selection: GridSelection?,
        appearance: GridAppearance,
        in screenFrame: CGRect? = nil
    ) {
        if window == nil || overlayView == nil {
            makeWindow()
        }

        guard let window, let overlayView else {
            return
        }

        let frame = screenFrame ?? screen.visibleFrame
        if window.frame != frame {
            window.setFrame(frame, display: true)
        }

        overlayView.configure(screenFrame: frame, model: model, selection: selection, appearance: appearance)

        if !window.isVisible {
            window.alphaValue = 0
            window.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.10
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().alphaValue = 1
            }
        }
    }

    func update(
        on screen: NSScreen,
        model: GridModel,
        selection: GridSelection?,
        appearance: GridAppearance,
        in screenFrame: CGRect? = nil
    ) {
        guard isVisible else {
            show(on: screen, model: model, selection: selection, appearance: appearance, in: screenFrame)
            return
        }

        show(on: screen, model: model, selection: selection, appearance: appearance, in: screenFrame)
    }

    func hide() {
        guard let window, window.isVisible else {
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.10
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 0
        } completionHandler: {
            Task { @MainActor in
                window.orderOut(nil)
                window.alphaValue = 1
            }
        }
    }

    private func makeWindow() {
        let view = GridOverlayView()
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.contentView = view
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.level = .statusBar
        panel.animationBehavior = .none

        window = panel
        overlayView = view
    }
}

private final class GridOverlayView: NSView {
    private var screenFrame: CGRect = .zero
    private var model = GridModel(rows: 2, columns: 4)
    private var selection: GridSelection?
    private var gridAppearance = GridAppearance(
        backgroundColor: GridColor(red: 0, green: 0, blue: 0, alpha: 0.10),
        gridLineColor: GridColor(red: 1, green: 1, blue: 1, alpha: 0.64),
        selectionColor: GridColor(red: 0.86, green: 0.86, blue: 0.86, alpha: 0.34)
    )

    override var isFlipped: Bool {
        false
    }

    func configure(
        screenFrame: CGRect,
        model: GridModel,
        selection: GridSelection?,
        appearance: GridAppearance
    ) {
        self.screenFrame = screenFrame
        self.model = model
        self.selection = selection
        self.gridAppearance = appearance
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard bounds.width > 0, bounds.height > 0 else {
            return
        }

        drawBackground()

        if let selection {
            drawSelection(selection)
        }

        drawGridLines()
        drawOuterBorder()
    }

    private func drawBackground() {
        NSColor(gridColor: gridAppearance.backgroundColor).setFill()
        bounds.fill()
    }

    private func drawSelection(_ selection: GridSelection) {
        let rect = localRect(for: model.rect(for: selection, in: screenFrame))
        let selectionColor = NSColor(gridColor: gridAppearance.selectionColor)
        selectionColor.setFill()
        rect.fill()

        let outline = NSBezierPath(rect: rect.insetBy(dx: 1, dy: 1))
        outline.lineWidth = 2
        selectionColor.withAlphaComponent(min(selectionColor.alphaComponent + 0.45, 1)).setStroke()
        outline.stroke()
    }

    private func drawGridLines() {
        let path = NSBezierPath()
        path.lineWidth = 1

        let cellWidth = bounds.width / CGFloat(model.columns)
        for column in 1..<model.columns {
            let x = CGFloat(column) * cellWidth
            path.move(to: CGPoint(x: x, y: bounds.minY))
            path.line(to: CGPoint(x: x, y: bounds.maxY))
        }

        let cellHeight = bounds.height / CGFloat(model.rows)
        for row in 1..<model.rows {
            let y = CGFloat(row) * cellHeight
            path.move(to: CGPoint(x: bounds.minX, y: y))
            path.line(to: CGPoint(x: bounds.maxX, y: y))
        }

        NSColor(gridColor: gridAppearance.gridLineColor).setStroke()
        path.stroke()
    }

    private func drawOuterBorder() {
        let border = NSBezierPath(rect: bounds.insetBy(dx: 1, dy: 1))
        border.lineWidth = 2
        NSColor(gridColor: gridAppearance.gridLineColor)
            .withAlphaComponent(min(gridAppearance.gridLineColor.alpha + 0.20, 1))
            .setStroke()
        border.stroke()
    }

    private func localRect(for screenRect: CGRect) -> CGRect {
        CGRect(
            x: screenRect.minX - screenFrame.minX,
            y: screenRect.minY - screenFrame.minY,
            width: screenRect.width,
            height: screenRect.height
        )
    }
}

private extension NSColor {
    convenience init(gridColor: GridColor) {
        self.init(
            calibratedRed: CGFloat(gridColor.red),
            green: CGFloat(gridColor.green),
            blue: CGFloat(gridColor.blue),
            alpha: CGFloat(gridColor.alpha)
        )
    }
}
