import CoreGraphics
import Foundation
import MacSnapCore
import XCTest

final class MacSnapCoreTests: XCTestCase {
    func testCellAtPointUsesRowsFromTopAndColumnsFromLeft() {
        let model = GridModel(rows: 2, columns: 4)
        let frame = CGRect(x: 100, y: 200, width: 800, height: 400)

        XCTAssertEqual(model.cell(at: CGPoint(x: 101, y: 599), in: frame), GridCell(row: 0, column: 0))
        XCTAssertEqual(model.cell(at: CGPoint(x: 899, y: 201), in: frame), GridCell(row: 1, column: 3))
        XCTAssertEqual(model.cell(at: CGPoint(x: 500, y: 400), in: frame), GridCell(row: 1, column: 2))
    }

    func testCellAtPointRejectsPointsOutsideScreenFrame() {
        let model = GridModel(rows: 2, columns: 4)
        let frame = CGRect(x: 100, y: 200, width: 800, height: 400)

        XCTAssertNil(model.cell(at: CGPoint(x: 99, y: 300), in: frame))
        XCTAssertNil(model.cell(at: CGPoint(x: 901, y: 300), in: frame))
        XCTAssertNil(model.cell(at: CGPoint(x: 300, y: 199), in: frame))
        XCTAssertNil(model.cell(at: CGPoint(x: 300, y: 601), in: frame))
    }

    func testRectForSingleCell() {
        let model = GridModel(rows: 2, columns: 4)
        let frame = CGRect(x: 100, y: 200, width: 800, height: 400)

        XCTAssertEqual(
            model.rect(for: GridCell(row: 0, column: 0), in: frame),
            CGRect(x: 100, y: 400, width: 200, height: 200)
        )
        XCTAssertEqual(
            model.rect(for: GridCell(row: 1, column: 3), in: frame),
            CGRect(x: 700, y: 200, width: 200, height: 200)
        )
    }

    func testRectForSpanIsDirectionIndependent() {
        let model = GridModel(rows: 3, columns: 3)
        let frame = CGRect(x: 0, y: 0, width: 900, height: 600)
        let forward = GridSelection(start: GridCell(row: 0, column: 0), end: GridCell(row: 1, column: 1))
        let backward = GridSelection(start: GridCell(row: 1, column: 1), end: GridCell(row: 0, column: 0))

        let expected = CGRect(x: 0, y: 200, width: 600, height: 400)
        XCTAssertEqual(model.rect(for: forward, in: frame), expected)
        XCTAssertEqual(model.rect(for: backward, in: frame), expected)
    }

    func testGridSupportsCommonSizes() {
        let frame = CGRect(x: -500, y: 50, width: 1200, height: 900)

        XCTAssertEqual(
            GridModel(rows: 1, columns: 2).rect(for: GridCell(row: 0, column: 1), in: frame),
            CGRect(x: 100, y: 50, width: 600, height: 900)
        )
        XCTAssertEqual(
            GridModel(rows: 3, columns: 3).rect(for: GridCell(row: 2, column: 2), in: frame),
            CGRect(x: 300, y: 50, width: 400, height: 300)
        )
        XCTAssertEqual(
            GridModel(rows: 4, columns: 4).rect(for: GridCell(row: 3, column: 0), in: frame),
            CGRect(x: -500, y: 50, width: 300, height: 225)
        )
    }

    func testGapInsetsTargetRect() {
        let model = GridModel(rows: 2, columns: 2, gap: 20)
        let frame = CGRect(x: 0, y: 0, width: 400, height: 400)

        XCTAssertEqual(
            model.rect(for: GridCell(row: 0, column: 0), in: frame),
            CGRect(x: 10, y: 210, width: 180, height: 180)
        )
    }

    func testSettingsGapFeedsModel() {
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

        XCTAssertEqual(
            model.rect(for: GridCell(row: 0, column: 0), in: frame),
            CGRect(x: 5, y: 205, width: 190, height: 190)
        )
    }

    func testModelClampsInvalidSettingsAndCells() {
        let model = GridModel(rows: 0, columns: -2)
        let frame = CGRect(x: 0, y: 0, width: 400, height: 400)

        XCTAssertEqual(model.rows, 1)
        XCTAssertEqual(model.columns, 1)
        XCTAssertEqual(model.rect(for: GridCell(row: 50, column: 50), in: frame), frame)
    }

    func testProfileStorageAndSwitching() throws {
        let suiteName = "MacSnapCoreTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.profiles.count, 1)
        XCTAssertEqual(store.activeProfile.name, "Default")
        XCTAssertNil(store.activeProfile.shortcut)

        store.rows = 3
        store.columns = 5
        store.gap = 12
        store.renameActiveProfile("Work")
        let shortcut = KeyboardShortcut(keyCode: 11, modifiers: 768, displayName: "Command+Shift+B")
        store.setActiveProfileShortcut(shortcut)

        let workProfile = store.activeProfile
        XCTAssertEqual(workProfile.name, "Work")
        XCTAssertEqual(workProfile.rows, 3)
        XCTAssertEqual(workProfile.columns, 5)
        XCTAssertEqual(workProfile.gap, 12)
        XCTAssertEqual(workProfile.shortcut, shortcut.normalized())

        let secondProfile = store.addProfile()
        XCTAssertEqual(store.activeProfileID, secondProfile.id)
        XCTAssertEqual(store.profiles.count, 2)
        XCTAssertEqual(store.activeProfile.rows, 3)

        store.rows = 1
        store.activeProfileID = workProfile.id
        XCTAssertEqual(store.rows, 3)
        store.activeProfileID = secondProfile.id
        XCTAssertEqual(store.rows, 1)
    }

    func testOptionalModifierStorage() throws {
        let suiteName = "MacSnapCoreTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = SettingsStore(defaults: defaults)
        XCTAssertNil(store.alternateSnapModifier)
        XCTAssertNil(store.alternateSpanModifier)

        store.alternateSnapModifier = .control
        store.alternateSpanModifier = .option
        XCTAssertEqual(store.settings.alternateSnapModifier, .control)
        XCTAssertEqual(store.settings.alternateSpanModifier, .option)

        store.alternateSnapModifier = .shift
        XCTAssertNil(store.alternateSnapModifier)

        store.alternateSpanModifier = .middleClick
        XCTAssertNil(store.alternateSpanModifier)

        store.alternateSnapModifier = .rightClick
        store.alternateSpanModifier = .rightClick
        XCTAssertNil(store.alternateSnapModifier)
        XCTAssertEqual(store.alternateSpanModifier, .rightClick)
    }

    func testLaunchAtLoginDefaultsOnAndResetsOn() throws {
        let suiteName = "MacSnapCoreTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = SettingsStore(defaults: defaults)
        XCTAssertTrue(store.launchAtLogin)

        store.launchAtLogin = false
        XCTAssertFalse(store.launchAtLogin)

        store.reset()
        XCTAssertTrue(store.launchAtLogin)
    }
}
