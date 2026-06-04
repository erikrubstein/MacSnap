import CoreGraphics
import Foundation
import GridSnapCore

@main
struct GridSnapGeometryCheck {
    static func main() {
        checkCellAtPointUsesRowsFromTopAndColumnsFromLeft()
        checkCellAtPointRejectsPointsOutsideScreenFrame()
        checkRectForSingleCell()
        checkRectForSpanIsDirectionIndependent()
        checkGridSupportsCommonSizes()
        checkGapInsetsTargetRect()
        checkSettingsGapFeedsModel()
        checkModelClampsInvalidSettingsAndCells()
        checkProfileStorageAndSwitching()

        print("GridSnapGeometryCheck: all checks passed.")
    }

    private static func checkCellAtPointUsesRowsFromTopAndColumnsFromLeft() {
        let model = GridModel(rows: 2, columns: 4)
        let frame = CGRect(x: 100, y: 200, width: 800, height: 400)

        expect(model.cell(at: CGPoint(x: 101, y: 599), in: frame) == GridCell(row: 0, column: 0))
        expect(model.cell(at: CGPoint(x: 899, y: 201), in: frame) == GridCell(row: 1, column: 3))
        expect(model.cell(at: CGPoint(x: 500, y: 400), in: frame) == GridCell(row: 1, column: 2))
    }

    private static func checkCellAtPointRejectsPointsOutsideScreenFrame() {
        let model = GridModel(rows: 2, columns: 4)
        let frame = CGRect(x: 100, y: 200, width: 800, height: 400)

        expect(model.cell(at: CGPoint(x: 99, y: 300), in: frame) == nil)
        expect(model.cell(at: CGPoint(x: 901, y: 300), in: frame) == nil)
        expect(model.cell(at: CGPoint(x: 300, y: 199), in: frame) == nil)
        expect(model.cell(at: CGPoint(x: 300, y: 601), in: frame) == nil)
    }

    private static func checkRectForSingleCell() {
        let model = GridModel(rows: 2, columns: 4)
        let frame = CGRect(x: 100, y: 200, width: 800, height: 400)

        expect(
            model.rect(for: GridCell(row: 0, column: 0), in: frame) ==
            CGRect(x: 100, y: 400, width: 200, height: 200)
        )
        expect(
            model.rect(for: GridCell(row: 1, column: 3), in: frame) ==
            CGRect(x: 700, y: 200, width: 200, height: 200)
        )
    }

    private static func checkRectForSpanIsDirectionIndependent() {
        let model = GridModel(rows: 3, columns: 3)
        let frame = CGRect(x: 0, y: 0, width: 900, height: 600)
        let forward = GridSelection(start: GridCell(row: 0, column: 0), end: GridCell(row: 1, column: 1))
        let backward = GridSelection(start: GridCell(row: 1, column: 1), end: GridCell(row: 0, column: 0))

        let expected = CGRect(x: 0, y: 200, width: 600, height: 400)
        expect(model.rect(for: forward, in: frame) == expected)
        expect(model.rect(for: backward, in: frame) == expected)
    }

    private static func checkGridSupportsCommonSizes() {
        let frame = CGRect(x: -500, y: 50, width: 1200, height: 900)

        expect(
            GridModel(rows: 1, columns: 2).rect(for: GridCell(row: 0, column: 1), in: frame) ==
            CGRect(x: 100, y: 50, width: 600, height: 900)
        )
        expect(
            GridModel(rows: 3, columns: 3).rect(for: GridCell(row: 2, column: 2), in: frame) ==
            CGRect(x: 300, y: 50, width: 400, height: 300)
        )
        expect(
            GridModel(rows: 4, columns: 4).rect(for: GridCell(row: 3, column: 0), in: frame) ==
            CGRect(x: -500, y: 50, width: 300, height: 225)
        )
    }

    private static func checkGapInsetsTargetRect() {
        let model = GridModel(rows: 2, columns: 2, gap: 20)
        let frame = CGRect(x: 0, y: 0, width: 400, height: 400)

        expect(
            model.rect(for: GridCell(row: 0, column: 0), in: frame) ==
            CGRect(x: 10, y: 210, width: 180, height: 180)
        )
    }

    private static func checkSettingsGapFeedsModel() {
        let settings = GridSettings(
            rows: 2,
            columns: 2,
            gap: 10,
            snapModifier: .shift,
            spanModifier: .middleClick,
            useVisibleFrame: true,
            restoreSizeOnUnsnap: false,
            appearance: SettingsStore.defaultSettings.appearance
        )
        let model = GridModel(settings: settings)
        let frame = CGRect(x: 0, y: 0, width: 400, height: 400)

        expect(
            model.rect(for: GridCell(row: 0, column: 0), in: frame) ==
            CGRect(x: 5, y: 205, width: 190, height: 190)
        )
    }

    private static func checkModelClampsInvalidSettingsAndCells() {
        let model = GridModel(rows: 0, columns: -2)
        let frame = CGRect(x: 0, y: 0, width: 400, height: 400)

        expect(model.rows == 1)
        expect(model.columns == 1)
        expect(model.rect(for: GridCell(row: 50, column: 50), in: frame) == frame)
    }

    private static func checkProfileStorageAndSwitching() {
        let suiteName = "GridSnapGeometryCheck-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Could not create isolated UserDefaults suite")
        }
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = SettingsStore(defaults: defaults)
        expect(store.profiles.count == 1)
        expect(store.activeProfile.name == "Default")
        expect(store.activeProfile.shortcut == nil)

        store.rows = 3
        store.columns = 5
        store.gap = 12
        store.renameActiveProfile("Work")
        let shortcut = KeyboardShortcut(keyCode: 11, modifiers: 768, displayName: "Command+Shift+B")
        store.setActiveProfileShortcut(shortcut)

        let workProfile = store.activeProfile
        expect(workProfile.name == "Work")
        expect(workProfile.rows == 3)
        expect(workProfile.columns == 5)
        expect(workProfile.gap == 12)
        expect(workProfile.shortcut == shortcut.normalized())

        let secondProfile = store.addProfile()
        expect(store.activeProfileID == secondProfile.id)
        expect(store.profiles.count == 2)
        expect(store.activeProfile.rows == 3)

        store.rows = 1
        store.activeProfileID = workProfile.id
        expect(store.rows == 3)
        store.activeProfileID = secondProfile.id
        expect(store.rows == 1)
    }

    private static func expect(_ condition: @autoclosure () -> Bool, file: StaticString = #file, line: UInt = #line) {
        guard condition() else {
            fatalError("GridSnapGeometryCheck failed at \(file):\(line)")
        }
    }
}
