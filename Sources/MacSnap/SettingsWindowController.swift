import AppKit
import MacSnapCore

@MainActor
final class SettingsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    enum PreviewIntent {
        case none
        case sampleCell
        case profileSwitch
    }

    private enum Column {
        static let active = NSUserInterfaceItemIdentifier("active")
        static let name = NSUserInterfaceItemIdentifier("name")
        static let grid = NSUserInterfaceItemIdentifier("grid")
        static let gap = NSUserInterfaceItemIdentifier("gap")
        static let shortcut = NSUserInterfaceItemIdentifier("shortcut")
    }

    private let store: SettingsStore
    private let onSettingsChanged: (GridSettings, PreviewIntent) -> Void
    private let onShortcutRecordingChanged: (Bool) -> Void
    private let profilePasteboardType = NSPasteboard.PasteboardType("com.erik.macsnap.profile")

    private let profilesTableView = NSTableView()
    private let editProfileButton = NSButton(title: "Edit", target: nil, action: nil)
    private let deleteProfileButton = NSButton(title: "Delete", target: nil, action: nil)
    private let snapModifierPopup = NSPopUpButton()
    private let alternateSnapModifierPopup = NSPopUpButton()
    private let spanModifierPopup = NSPopUpButton()
    private let alternateSpanModifierPopup = NSPopUpButton()
    private let visibleFrameSwitch = NSSwitch()
    private let restoreSizeSwitch = NSSwitch()
    private let backgroundColorWell = NSColorWell()
    private let gridLineColorWell = NSColorWell()
    private let selectionColorWell = NSColorWell()
    private var permissionSection: NSView?
    private let rowLabelWidth: CGFloat = 230

    private var isRefreshing = false
    private var profileEditorWindowController: ProfileEditorWindowController?

    init(
        store: SettingsStore,
        onSettingsChanged: @escaping (GridSettings, PreviewIntent) -> Void,
        onShortcutRecordingChanged: @escaping (Bool) -> Void
    ) {
        self.store = store
        self.onSettingsChanged = onSettingsChanged
        self.onShortcutRecordingChanged = onShortcutRecordingChanged

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 750),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MacSnap Settings"
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)

        window.contentView = makeContentView()
        refresh()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func showWindow(_ sender: Any?) {
        refresh()
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    func reload() {
        refresh()
    }

    private func makeContentView() -> NSView {
        let container = NSView()

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 22
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(makeSection(title: "Profiles", rows: [makeProfilesTable(), makeProfileButtonRow()]))
        stack.addArrangedSubview(makeSection(
            title: "Global",
            rows: [
                makeModifierRow(),
                makeAlternateSnapModifierRow(),
                makeSpanModifierRow(),
                makeAlternateSpanModifierRow(),
                makeVisibleFrameRow(),
                makeRestoreSizeRow()
            ]
        ))
        stack.addArrangedSubview(makeSection(
            title: "Appearance",
            rows: [
                makeColorRow(label: "Background", colorWell: backgroundColorWell),
                makeColorRow(label: "Grid lines", colorWell: gridLineColorWell),
                makeColorRow(label: "Selection", colorWell: selectionColorWell)
            ]
        ))
        let permissionSection = makeSection(title: "Permissions", rows: [makePermissionRow()])
        self.permissionSection = permissionSection
        stack.addArrangedSubview(permissionSection)
        stack.addArrangedSubview(makeFooterRow())

        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -24)
        ])

        return container
    }

    private func makeSection(title: String, rows: [NSView]) -> NSView {
        let wrapper = NSStackView()
        wrapper.orientation = .vertical
        wrapper.alignment = .leading
        wrapper.spacing = 8

        let titleView = NSTextField(labelWithString: title)
        titleView.font = .systemFont(ofSize: 15, weight: .semibold)

        let box = NSBox()
        box.title = ""
        box.boxType = .primary

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        for row in rows {
            stack.addArrangedSubview(row)
        }

        let contentView = NSView()
        contentView.addSubview(stack)
        box.contentView = contentView

        NSLayoutConstraint.activate([
            box.widthAnchor.constraint(equalToConstant: 712),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])

        wrapper.addArrangedSubview(titleView)
        wrapper.addArrangedSubview(box)

        return wrapper
    }

    private func makeProfilesTable() -> NSView {
        profilesTableView.dataSource = self
        profilesTableView.delegate = self
        profilesTableView.headerView = NSTableHeaderView()
        profilesTableView.rowHeight = 28
        profilesTableView.usesAlternatingRowBackgroundColors = true
        profilesTableView.allowsMultipleSelection = false
        profilesTableView.action = #selector(profileClicked)
        profilesTableView.doubleAction = #selector(editProfileClicked)
        profilesTableView.target = self
        profilesTableView.registerForDraggedTypes([profilePasteboardType])
        profilesTableView.setDraggingSourceOperationMask(.move, forLocal: true)

        addColumn(id: Column.active, title: "", width: 34)
        addColumn(id: Column.name, title: "Name", width: 210)
        addColumn(id: Column.grid, title: "Grid", width: 120)
        addColumn(id: Column.gap, title: "Gap", width: 70)
        addColumn(id: Column.shortcut, title: "Shortcut", width: 246)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.documentView = profilesTableView
        scrollView.borderType = .bezelBorder
        scrollView.widthAnchor.constraint(equalToConstant: 680).isActive = true
        scrollView.heightAnchor.constraint(equalToConstant: 170).isActive = true

        return scrollView
    }

    private func addColumn(id: NSUserInterfaceItemIdentifier, title: String, width: CGFloat) {
        let column = NSTableColumn(identifier: id)
        column.title = title
        column.width = width
        profilesTableView.addTableColumn(column)
    }

    private func makeProfileButtonRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        let addButton = NSButton(title: "Add", target: self, action: #selector(addProfileClicked))
        editProfileButton.target = self
        editProfileButton.action = #selector(editProfileClicked)
        deleteProfileButton.target = self
        deleteProfileButton.action = #selector(deleteProfileClicked)

        row.addArrangedSubview(addButton)
        row.addArrangedSubview(editProfileButton)
        row.addArrangedSubview(deleteProfileButton)

        return row
    }

    private func makeColorRow(label: String, colorWell: NSColorWell) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        let labelView = NSTextField(labelWithString: label)
        labelView.widthAnchor.constraint(equalToConstant: rowLabelWidth).isActive = true

        colorWell.target = self
        colorWell.action = #selector(colorWellChanged(_:))
        colorWell.widthAnchor.constraint(equalToConstant: 48).isActive = true
        colorWell.heightAnchor.constraint(equalToConstant: 24).isActive = true

        row.addArrangedSubview(labelView)
        row.addArrangedSubview(colorWell)

        return row
    }

    private var optionalModifierTitles: [String] {
        ["None"] + SnapModifier.allCases.map(\.displayName)
    }

    private func makeModifierRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        let labelView = NSTextField(labelWithString: "Snap modifier")
        labelView.widthAnchor.constraint(equalToConstant: rowLabelWidth).isActive = true

        snapModifierPopup.removeAllItems()
        snapModifierPopup.addItems(withTitles: SnapModifier.allCases.map(\.displayName))
        snapModifierPopup.target = self
        snapModifierPopup.action = #selector(snapModifierChanged)
        snapModifierPopup.widthAnchor.constraint(equalToConstant: 160).isActive = true

        row.addArrangedSubview(labelView)
        row.addArrangedSubview(snapModifierPopup)

        return row
    }

    private func makeAlternateSnapModifierRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        let labelView = NSTextField(labelWithString: "Alternate snap modifier")
        labelView.widthAnchor.constraint(equalToConstant: rowLabelWidth).isActive = true

        alternateSnapModifierPopup.removeAllItems()
        alternateSnapModifierPopup.addItems(withTitles: optionalModifierTitles)
        alternateSnapModifierPopup.target = self
        alternateSnapModifierPopup.action = #selector(alternateSnapModifierChanged)
        alternateSnapModifierPopup.widthAnchor.constraint(equalToConstant: 160).isActive = true

        row.addArrangedSubview(labelView)
        row.addArrangedSubview(alternateSnapModifierPopup)

        return row
    }

    private func makeSpanModifierRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        let labelView = NSTextField(labelWithString: "Span modifier")
        labelView.widthAnchor.constraint(equalToConstant: rowLabelWidth).isActive = true

        spanModifierPopup.removeAllItems()
        spanModifierPopup.addItems(withTitles: SnapModifier.allCases.map(\.displayName))
        spanModifierPopup.target = self
        spanModifierPopup.action = #selector(spanModifierChanged)
        spanModifierPopup.widthAnchor.constraint(equalToConstant: 160).isActive = true

        row.addArrangedSubview(labelView)
        row.addArrangedSubview(spanModifierPopup)

        return row
    }

    private func makeAlternateSpanModifierRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        let labelView = NSTextField(labelWithString: "Alternate span modifier")
        labelView.widthAnchor.constraint(equalToConstant: rowLabelWidth).isActive = true

        alternateSpanModifierPopup.removeAllItems()
        alternateSpanModifierPopup.addItems(withTitles: optionalModifierTitles)
        alternateSpanModifierPopup.target = self
        alternateSpanModifierPopup.action = #selector(alternateSpanModifierChanged)
        alternateSpanModifierPopup.widthAnchor.constraint(equalToConstant: 160).isActive = true

        row.addArrangedSubview(labelView)
        row.addArrangedSubview(alternateSpanModifierPopup)

        return row
    }

    private func makeVisibleFrameRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        let labelView = NSTextField(labelWithString: "Avoid menu bar and Dock")
        labelView.widthAnchor.constraint(equalToConstant: rowLabelWidth).isActive = true

        visibleFrameSwitch.target = self
        visibleFrameSwitch.action = #selector(visibleFrameSwitchChanged(_:))

        row.addArrangedSubview(labelView)
        row.addArrangedSubview(visibleFrameSwitch)

        return row
    }

    private func makeRestoreSizeRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        let labelView = NSTextField(labelWithString: "Restore size when unsnapped")
        labelView.widthAnchor.constraint(equalToConstant: rowLabelWidth).isActive = true

        restoreSizeSwitch.target = self
        restoreSizeSwitch.action = #selector(restoreSizeSwitchChanged(_:))

        row.addArrangedSubview(labelView)
        row.addArrangedSubview(restoreSizeSwitch)

        return row
    }

    private func makePermissionRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        let labelView = NSTextField(labelWithString: "MacSnap needs Accessibility permission before snapping can work.")
        labelView.widthAnchor.constraint(equalToConstant: 380).isActive = true

        let openButton = NSButton(title: "Open Settings", target: self, action: #selector(openAccessibilitySettings))
        let refreshButton = NSButton(title: "Refresh", target: self, action: #selector(refreshButtonClicked))

        row.addArrangedSubview(labelView)
        row.addArrangedSubview(openButton)
        row.addArrangedSubview(refreshButton)

        return row
    }

    private func makeFooterRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        let resetButton = NSButton(title: "Reset Defaults", target: self, action: #selector(resetClicked))
        row.addArrangedSubview(resetButton)

        return row
    }

    private func refresh() {
        isRefreshing = true
        defer {
            isRefreshing = false
        }

        let settings = store.settings
        let activeProfile = store.activeProfile

        profilesTableView.reloadData()
        if let row = store.profiles.firstIndex(where: { $0.id == activeProfile.id }) {
            profilesTableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }

        editProfileButton.isEnabled = selectedProfile != nil
        deleteProfileButton.isEnabled = store.profiles.count > 1 && selectedProfile != nil
        snapModifierPopup.selectItem(withTitle: settings.snapModifier.displayName)
        alternateSnapModifierPopup.selectItem(withTitle: settings.alternateSnapModifier?.displayName ?? "None")
        spanModifierPopup.selectItem(withTitle: settings.spanModifier.displayName)
        alternateSpanModifierPopup.selectItem(withTitle: settings.alternateSpanModifier?.displayName ?? "None")
        visibleFrameSwitch.state = settings.useVisibleFrame ? .on : .off
        restoreSizeSwitch.state = settings.restoreSizeOnUnsnap ? .on : .off
        backgroundColorWell.color = NSColor(gridColor: settings.appearance.backgroundColor)
        gridLineColorWell.color = NSColor(gridColor: settings.appearance.gridLineColor)
        selectionColorWell.color = NSColor(gridColor: settings.appearance.selectionColor)

        permissionSection?.isHidden = PermissionManager.isAccessibilityTrusted
    }

    private var selectedProfile: GridProfile? {
        let row = profilesTableView.selectedRow
        guard row >= 0, store.profiles.indices.contains(row) else {
            return nil
        }
        return store.profiles[row]
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        store.profiles.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn, store.profiles.indices.contains(row) else {
            return nil
        }

        let profile = store.profiles[row]
        let text: String

        switch tableColumn.identifier {
        case Column.active:
            text = profile.id == store.activeProfileID ? "✓" : ""
        case Column.name:
            text = profile.name
        case Column.grid:
            text = "\(profile.rows) x \(profile.columns)"
        case Column.gap:
            text = "\(profile.gap)"
        case Column.shortcut:
            text = profile.shortcut?.displayName ?? "None"
        default:
            text = ""
        }

        let cell = NSTableCellView()
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.lineBreakMode = .byTruncatingTail
        cell.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -10),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])

        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !isRefreshing else {
            return
        }

        guard selectedProfile != nil else {
            editProfileButton.isEnabled = false
            deleteProfileButton.isEnabled = false
            return
        }

        editProfileButton.isEnabled = true
        deleteProfileButton.isEnabled = store.profiles.count > 1
    }

    @objc private func profileClicked() {
        guard let selectedProfile,
              selectedProfile.id != store.activeProfileID
        else {
            return
        }

        store.activeProfileID = selectedProfile.id
        refresh()
        onSettingsChanged(store.settings, .profileSwitch)
    }

    @objc private func addProfileClicked() {
        let profile = store.addProfile()
        refresh()
        onSettingsChanged(store.settings, .none)
        showEditor(for: profile)
    }

    @objc private func editProfileClicked() {
        guard let selectedProfile else {
            return
        }

        showEditor(for: selectedProfile)
    }

    @objc private func deleteProfileClicked() {
        guard let selectedProfile else {
            return
        }

        store.deleteProfile(id: selectedProfile.id)
        refresh()
        onSettingsChanged(store.settings, .profileSwitch)
    }

    private func showEditor(for profile: GridProfile) {
        let editor = ProfileEditorWindowController(
            profile: profile,
            profilesProvider: { [weak self] in
                self?.store.profiles ?? []
            },
            onShortcutRecordingChanged: onShortcutRecordingChanged
        ) { [weak self] updatedProfile in
            guard let self else {
                return
            }

            store.updateProfile(updatedProfile)
            store.activeProfileID = updatedProfile.id
            refresh()
            onSettingsChanged(store.settings, .profileSwitch)
        }

        profileEditorWindowController = editor
        window?.beginSheet(editor.window!) { [weak self] _ in
            self?.profileEditorWindowController = nil
        }
    }

    private func saveGlobal(
        snapModifier: SnapModifier? = nil,
        spanModifier: SnapModifier? = nil,
        useVisibleFrame: Bool? = nil,
        restoreSizeOnUnsnap: Bool? = nil
    ) {
        if let snapModifier {
            store.snapModifier = snapModifier
        }
        if let spanModifier {
            store.spanModifier = spanModifier
        }
        if let useVisibleFrame {
            store.useVisibleFrame = useVisibleFrame
        }
        if let restoreSizeOnUnsnap {
            store.restoreSizeOnUnsnap = restoreSizeOnUnsnap
        }

        refresh()
        onSettingsChanged(store.settings, .none)
    }

    private func optionalModifier(from popup: NSPopUpButton) -> SnapModifier? {
        let selectedIndex = popup.indexOfSelectedItem
        guard selectedIndex > 0 else {
            return nil
        }

        let modifierIndex = selectedIndex - 1
        guard SnapModifier.allCases.indices.contains(modifierIndex) else {
            return nil
        }

        return SnapModifier.allCases[modifierIndex]
    }

    @objc private func snapModifierChanged() {
        let selectedIndex = snapModifierPopup.indexOfSelectedItem
        guard SnapModifier.allCases.indices.contains(selectedIndex) else {
            return
        }

        saveGlobal(snapModifier: SnapModifier.allCases[selectedIndex])
    }

    @objc private func alternateSnapModifierChanged() {
        store.alternateSnapModifier = optionalModifier(from: alternateSnapModifierPopup)
        refresh()
        onSettingsChanged(store.settings, .none)
    }

    @objc private func spanModifierChanged() {
        let selectedIndex = spanModifierPopup.indexOfSelectedItem
        guard SnapModifier.allCases.indices.contains(selectedIndex) else {
            return
        }

        saveGlobal(spanModifier: SnapModifier.allCases[selectedIndex])
    }

    @objc private func alternateSpanModifierChanged() {
        store.alternateSpanModifier = optionalModifier(from: alternateSpanModifierPopup)
        refresh()
        onSettingsChanged(store.settings, .none)
    }

    @objc private func visibleFrameSwitchChanged(_ sender: NSSwitch) {
        saveGlobal(useVisibleFrame: sender.state == .on)
    }

    @objc private func restoreSizeSwitchChanged(_ sender: NSSwitch) {
        saveGlobal(restoreSizeOnUnsnap: sender.state == .on)
    }

    @objc private func colorWellChanged(_ sender: NSColorWell) {
        NSColorPanel.shared.showsAlpha = true
        store.appearance = GridAppearance(
            backgroundColor: backgroundColorWell.color.gridColor,
            gridLineColor: gridLineColorWell.color.gridColor,
            selectionColor: selectionColorWell.color.gridColor
        )
        refresh()
        onSettingsChanged(store.settings, .sampleCell)
    }

    @objc private func refreshButtonClicked() {
        refresh()
    }

    @objc private func openAccessibilitySettings() {
        PermissionManager.openAccessibilitySettings()
    }

    @objc private func resetClicked() {
        store.reset()
        refresh()
        onSettingsChanged(store.settings, .none)
    }

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard tableView == profilesTableView,
              store.profiles.indices.contains(row)
        else {
            return nil
        }

        let item = NSPasteboardItem()
        item.setString(store.profiles[row].id.uuidString, forType: profilePasteboardType)
        return item
    }

    func tableView(
        _ tableView: NSTableView,
        validateDrop info: NSDraggingInfo,
        proposedRow row: Int,
        proposedDropOperation dropOperation: NSTableView.DropOperation
    ) -> NSDragOperation {
        guard tableView == profilesTableView,
              info.draggingPasteboard.string(forType: profilePasteboardType) != nil
        else {
            return []
        }

        let dropRow = min(max(row, 0), store.profiles.count)
        tableView.setDropRow(dropRow, dropOperation: .above)
        return .move
    }

    func tableView(
        _ tableView: NSTableView,
        acceptDrop info: NSDraggingInfo,
        row: Int,
        dropOperation: NSTableView.DropOperation
    ) -> Bool {
        guard tableView == profilesTableView,
              let rawProfileID = info.draggingPasteboard.string(forType: profilePasteboardType),
              let profileID = UUID(uuidString: rawProfileID)
        else {
            return false
        }

        return moveProfile(id: profileID, toDropRow: row)
    }

    private func moveProfile(id: UUID, toDropRow row: Int) -> Bool {
        var profiles = store.profiles
        guard let sourceIndex = profiles.firstIndex(where: { $0.id == id }) else {
            return false
        }

        let profile = profiles.remove(at: sourceIndex)
        var destinationIndex = row
        if row > sourceIndex {
            destinationIndex -= 1
        }
        destinationIndex = min(max(destinationIndex, 0), profiles.count)

        guard destinationIndex != sourceIndex else {
            return false
        }

        profiles.insert(profile, at: destinationIndex)
        store.profiles = profiles
        refresh()

        isRefreshing = true
        profilesTableView.selectRowIndexes(IndexSet(integer: destinationIndex), byExtendingSelection: false)
        isRefreshing = false

        onSettingsChanged(store.settings, .none)
        return true
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

    var gridColor: GridColor {
        let color = usingColorSpace(.deviceRGB) ?? self
        return GridColor(
            red: Double(color.redComponent),
            green: Double(color.greenComponent),
            blue: Double(color.blueComponent),
            alpha: Double(color.alphaComponent)
        )
    }
}
