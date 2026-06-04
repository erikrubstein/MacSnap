import CoreGraphics
import Foundation

public struct GridCell: Equatable, Hashable, Sendable {
    public let row: Int
    public let column: Int

    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }
}

public struct GridSelection: Equatable, Sendable {
    public let start: GridCell
    public let end: GridCell

    public var minRow: Int { min(start.row, end.row) }
    public var maxRow: Int { max(start.row, end.row) }
    public var minColumn: Int { min(start.column, end.column) }
    public var maxColumn: Int { max(start.column, end.column) }

    public init(cell: GridCell) {
        self.start = cell
        self.end = cell
    }

    public init(start: GridCell, end: GridCell) {
        self.start = start
        self.end = end
    }
}

public struct GridModel: Equatable, Sendable {
    public let rows: Int
    public let columns: Int
    public let gap: CGFloat

    public init(rows: Int, columns: Int, gap: CGFloat = 0) {
        self.rows = max(1, rows)
        self.columns = max(1, columns)
        self.gap = max(0, gap)
    }

    public init(settings: GridSettings, gap: CGFloat? = nil) {
        self.init(rows: settings.rows, columns: settings.columns, gap: gap ?? CGFloat(settings.gap))
    }

    public func cell(at point: CGPoint, in screenFrame: CGRect) -> GridCell? {
        guard screenFrame.width > 0, screenFrame.height > 0 else {
            return nil
        }

        guard point.x >= screenFrame.minX,
              point.x <= screenFrame.maxX,
              point.y >= screenFrame.minY,
              point.y <= screenFrame.maxY
        else {
            return nil
        }

        let localX = min(max(point.x - screenFrame.minX, 0), screenFrame.width.nextDown)
        let distanceFromTop = min(max(screenFrame.maxY - point.y, 0), screenFrame.height.nextDown)
        let column = Int(floor(localX / cellWidth(in: screenFrame)))
        let row = Int(floor(distanceFromTop / cellHeight(in: screenFrame)))

        return GridCell(
            row: min(max(row, 0), rows - 1),
            column: min(max(column, 0), columns - 1)
        )
    }

    public func rect(for cell: GridCell, in screenFrame: CGRect) -> CGRect {
        rect(for: GridSelection(cell: normalized(cell)), in: screenFrame)
    }

    public func rect(for selection: GridSelection, in screenFrame: CGRect) -> CGRect {
        guard screenFrame.width > 0, screenFrame.height > 0 else {
            return .zero
        }

        let start = normalized(selection.start)
        let end = normalized(selection.end)
        let normalizedSelection = GridSelection(start: start, end: end)
        let cellWidth = cellWidth(in: screenFrame)
        let cellHeight = cellHeight(in: screenFrame)

        let x = screenFrame.minX + CGFloat(normalizedSelection.minColumn) * cellWidth
        let maxY = screenFrame.maxY - CGFloat(normalizedSelection.minRow) * cellHeight
        let width = CGFloat(normalizedSelection.maxColumn - normalizedSelection.minColumn + 1) * cellWidth
        let height = CGFloat(normalizedSelection.maxRow - normalizedSelection.minRow + 1) * cellHeight
        let y = maxY - height
        let rawRect = CGRect(x: x, y: y, width: width, height: height)

        return inset(rawRect, by: gap)
    }

    public func selection(from anchor: GridCell, to current: GridCell) -> GridSelection {
        GridSelection(start: normalized(anchor), end: normalized(current))
    }

    private func cellWidth(in screenFrame: CGRect) -> CGFloat {
        screenFrame.width / CGFloat(columns)
    }

    private func cellHeight(in screenFrame: CGRect) -> CGFloat {
        screenFrame.height / CGFloat(rows)
    }

    private func normalized(_ cell: GridCell) -> GridCell {
        GridCell(
            row: min(max(cell.row, 0), rows - 1),
            column: min(max(cell.column, 0), columns - 1)
        )
    }

    private func inset(_ rect: CGRect, by gap: CGFloat) -> CGRect {
        guard gap > 0 else {
            return rect
        }

        let inset = gap / 2
        guard rect.width > gap, rect.height > gap else {
            return rect
        }

        return rect.insetBy(dx: inset, dy: inset)
    }
}
