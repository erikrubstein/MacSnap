import AppKit
import MacSnapCore

@MainActor
final class SettingsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    enum PreviewIntent {
        case none
        case sampleCell
        case affectedDisplays(Set<String>)
    }

    private enum Column {
        static let name = NSUserInterfaceItemIdentifier("name")
        static let grid = NSUserInterfaceItemIdentifier("grid")
        static let gap = NSUserInterfaceItemIdentifier("gap")
        static let defaultShortcut = NSUserInterfaceItemIdentifier("defaultShortcut")
        static let displayShortcut = NSUserInterfaceItemIdentifier("displayShortcut")
    }

    private let store: SettingsStore
    private let overlayController: GridOverlayController
    private let onSettingsChanged: (GridSettings, PreviewIntent) -> Void
    private let onLaunchAtLoginChanged: (Bool) -> Void
    private let onShortcutRecordingChanged: (Bool) -> Void
    private let profilePasteboardType = NSPasteboard.PasteboardType("com.erik.macsnap.profile")

    private let profilesTableView = NSTableView()
    private let editProfileButton = NSButton(title: "Edit", target: nil, action: nil)
    private let deleteProfileButton = NSButton(title: "Delete", target: nil, action: nil)
    private let snapModifierPopup = NSPopUpButton()
    private let alternateSnapModifierPopup = NSPopUpButton()
    private let spanModifierPopup = NSPopUpButton()
    private let alternateSpanModifierPopup = NSPopUpButton()
    private let currentDisplayDefaultShortcutField = ShortcutRecorderField()
    private let launchAtLoginSwitch = NSSwitch()
    private let visibleFrameSwitch = NSSwitch()
    private let restoreSizeSwitch = NSSwitch()
    private let displayAssignmentsStack = NSStackView()
    private let backgroundColorWell = NSColorWell()
    private let gridLineColorWell = NSColorWell()
    private let selectionColorWell = NSColorWell()
    private var permissionSection: NSView?
    private let rowLabelWidth: CGFloat = 230

    private var isRefreshing = false
    private var displayAssignmentPopups: [NSPopUpButton: DisplayIdentity] = [:]
    private var helpPopover: NSPopover?
    private var profileEditorWindowController: ProfileEditorWindowController?

    init(
        store: SettingsStore,
        overlayController: GridOverlayController,
        onSettingsChanged: @escaping (GridSettings, PreviewIntent) -> Void,
        onLaunchAtLoginChanged: @escaping (Bool) -> Void,
        onShortcutRecordingChanged: @escaping (Bool) -> Void
    ) {
        self.store = store
        self.overlayController = overlayController
        self.onSettingsChanged = onSettingsChanged
        self.onLaunchAtLoginChanged = onLaunchAtLoginChanged
        self.onShortcutRecordingChanged = onShortcutRecordingChanged

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 750),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MacSnap Settings"
        window.center()
        window.isReleasedWhenClosed = false
        window.collectionBehavior.insert(.moveToActiveSpace)
        window.level = GridOverlayController.appWindowLevel
        window.minSize = NSSize(width: 760, height: 520)
        window.maxSize = NSSize(width: 760, height: CGFloat.greatestFiniteMagnitude)

        super.init(window: window)

        window.contentView = makeContentView()
        refresh()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func showWindow(_ sender: Any?) {
        refresh()
        if window?.isVisible == false {
            moveWindowToCurrentScreen()
        }
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    func reload() {
        refresh()
    }

    private func moveWindowToCurrentScreen() {
        guard let window else {
            return
        }

        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { screen in
            screen.visibleFrame.contains(mouseLocation) || screen.frame.contains(mouseLocation)
        } ?? NSScreen.main

        guard let screen else {
            window.center()
            return
        }

        let visibleFrame = screen.visibleFrame
        var frame = window.frame
        frame.origin.x = visibleFrame.midX - frame.width / 2
        frame.origin.y = visibleFrame.midY - frame.height / 2
        window.setFrame(frame, display: false)
    }

    private func makeContentView() -> NSView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 22
        stack.translatesAutoresizingMaskIntoConstraints = false

        let permissionSection = makeSection(
            title: "Permissions",
            help: "MacSnap needs Accessibility permission so it can read and move windows.",
            rows: [makePermissionRow()]
        )
        self.permissionSection = permissionSection
        stack.addArrangedSubview(permissionSection)
        stack.addArrangedSubview(makeSection(
            title: "Profiles",
            help: """
            Profiles are reusable grid layouts. Rows and columns define the grid, and gap adds spacing around snapped windows.

            Optional shortcuts can be set for each profile. "Make Default" makes that profile the new default profile, while "Apply" applies that profile to the current display.

            "Apply Default Profile" removes the manual assignment from the display under your mouse, so that display goes back to using the default profile.
            """,
            rows: [
                makeProfilesTable(),
                makeCurrentDisplayDefaultShortcutRow(),
                makeProfileButtonRow()
            ]
        ))
        stack.addArrangedSubview(makeSection(
            title: "Displays",
            help: """
            The default profile is used by any display that is set to "Use default".

            You can assign a specific profile to a display when that display needs its own grid. That assignment stays remembered for the display, even if you unplug it and reconnect it later.
            """,
            rows: [
                makeDisplayAssignmentsView()
            ]
        ))
        stack.addArrangedSubview(makeSection(
            title: "Global",
            help: """
            Snap modifiers show the grid while you drag a window. You can set a primary modifier and, optionally, an alternate modifier that does the same thing.

            Span modifiers toggle span mode while snapping, letting you select multiple grid cells instead of only one.

            The switches control startup behavior, whether snapping avoids the menu bar and Dock, and whether windows restore their previous size when dragged away.
            """,
            rows: [
                makeModifierRow(),
                makeAlternateSnapModifierRow(),
                makeSpanModifierRow(),
                makeAlternateSpanModifierRow(),
                makeLaunchAtLoginRow(),
                makeVisibleFrameRow(),
                makeRestoreSizeRow()
            ]
        ))
        stack.addArrangedSubview(makeSection(
            title: "Appearance",
            help: "Customize the colors used by the grid overlay while snapping.",
            rows: [
                makeColorRow(label: "Background", colorWell: backgroundColorWell),
                makeColorRow(label: "Grid lines", colorWell: gridLineColorWell),
                makeColorRow(label: "Selection", colorWell: selectionColorWell)
            ]
        ))
        stack.addArrangedSubview(makeFooterRow())

        container.addSubview(stack)
        scrollView.documentView = container

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            container.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            container.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -24)
        ])

        return scrollView
    }

    private func makeSection(title: String, help: String? = nil, rows: [NSView]) -> NSView {
        let wrapper = NSStackView()
        wrapper.orientation = .vertical
        wrapper.alignment = .leading
        wrapper.spacing = 8

        let titleRow = NSStackView()
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 6

        let titleView = NSTextField(labelWithString: title)
        titleView.font = .systemFont(ofSize: 15, weight: .semibold)
        titleRow.addArrangedSubview(titleView)
        if let help {
            titleRow.addArrangedSubview(makeHelpButton(help))
        }

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

        wrapper.addArrangedSubview(titleRow)
        wrapper.addArrangedSubview(box)

        return wrapper
    }

    private func makeSettingLabel(_ title: String, tooltip: String? = nil) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.lineBreakMode = .byTruncatingTail
        label.toolTip = tooltip
        label.widthAnchor.constraint(equalToConstant: rowLabelWidth).isActive = true
        return label
    }

    private func makeHelpButton(_ help: String) -> NSButton {
        let image = NSImage(systemSymbolName: "questionmark.circle", accessibilityDescription: help)
        image?.isTemplate = true

        let button = HelpButton(helpText: help)
        button.image = image
        button.target = self
        button.action = #selector(showHelp(_:))
        return button
    }

    @objc private func showHelp(_ sender: NSButton) {
        guard let sender = sender as? HelpButton else {
            return
        }

        helpPopover?.close()

        let label = NSTextField(wrappingLabelWithString: sender.helpText)
        label.font = .systemFont(ofSize: 13)
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSView()
        contentView.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            label.widthAnchor.constraint(equalToConstant: 280)
        ])

        let viewController = NSViewController()
        viewController.view = contentView

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = viewController
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
        helpPopover = popover
    }

    private func makeProfilesTable() -> NSView {
        profilesTableView.dataSource = self
        profilesTableView.delegate = self
        profilesTableView.headerView = NSTableHeaderView()
        profilesTableView.rowHeight = 28
        profilesTableView.usesAlternatingRowBackgroundColors = true
        profilesTableView.allowsMultipleSelection = false
        profilesTableView.doubleAction = #selector(editProfileClicked)
        profilesTableView.target = self
        profilesTableView.registerForDraggedTypes([profilePasteboardType])
        profilesTableView.setDraggingSourceOperationMask(.move, forLocal: true)

        addColumn(id: Column.name, title: "Name", width: 190)
        addColumn(id: Column.grid, title: "Grid", width: 90)
        addColumn(id: Column.gap, title: "Gap", width: 60)
        addColumn(id: Column.defaultShortcut, title: "Make Default", width: 165)
        addColumn(id: Column.displayShortcut, title: "Apply", width: 165)

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

    private func makeCurrentDisplayDefaultShortcutRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        let labelView = makeSettingLabel("Apply Default Profile")

        currentDisplayDefaultShortcutField.widthAnchor.constraint(equalToConstant: 170).isActive = true
        currentDisplayDefaultShortcutField.onShortcutRecorded = { [weak self] shortcut in
            self?.currentDisplayDefaultShortcutRecorded(shortcut)
        }
        currentDisplayDefaultShortcutField.onRecordingChanged = { [weak self] isRecording in
            self?.onShortcutRecordingChanged(isRecording)
        }

        let clearButton = NSButton(
            title: "Clear",
            target: self,
            action: #selector(clearCurrentDisplayDefaultShortcutClicked)
        )

        row.addArrangedSubview(labelView)
        row.addArrangedSubview(currentDisplayDefaultShortcutField)
        row.addArrangedSubview(clearButton)

        return row
    }

    private func makeDisplayAssignmentsView() -> NSView {
        displayAssignmentsStack.orientation = .vertical
        displayAssignmentsStack.alignment = .leading
        displayAssignmentsStack.spacing = 10
        return displayAssignmentsStack
    }

    private func makeDefaultProfileRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        let labelView = makeSettingLabel("Default profile")

        let popup = NSPopUpButton()
        for profile in store.profiles {
            popup.addItem(withTitle: profile.name)
            popup.lastItem?.representedObject = profile.id.uuidString
        }

        if let index = store.profiles.firstIndex(where: { $0.id == store.activeProfileID }) {
            popup.selectItem(at: index)
        }

        popup.target = self
        popup.action = #selector(defaultProfileChanged(_:))
        popup.widthAnchor.constraint(equalToConstant: 240).isActive = true

        row.addArrangedSubview(labelView)
        row.addArrangedSubview(popup)

        return row
    }

    private func makeDisplayAssignmentRow(for display: DisplayIdentity) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        let labelView = makeSettingLabel(display.name, tooltip: display.id)

        let popup = NSPopUpButton()
        popup.addItem(withTitle: "Use default (\(store.activeProfile.name))")
        popup.lastItem?.representedObject = nil

        for profile in store.profiles {
            popup.addItem(withTitle: profile.name)
            popup.lastItem?.representedObject = profile.id.uuidString
        }

        let assignedProfileID = store.profileID(forDisplayID: display.id)
        if let assignedProfileID,
           let index = store.profiles.firstIndex(where: { $0.id == assignedProfileID }) {
            popup.selectItem(at: index + 1)
        } else {
            popup.selectItem(at: 0)
        }

        popup.target = self
        popup.action = #selector(displayAssignmentChanged(_:))
        popup.widthAnchor.constraint(equalToConstant: 240).isActive = true
        displayAssignmentPopups[popup] = display

        row.addArrangedSubview(labelView)
        row.addArrangedSubview(popup)

        return row
    }

    private func makeColorRow(label: String, colorWell: NSColorWell) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        let labelView = makeSettingLabel(label)

        colorWell.target = self
        colorWell.action = #selector(colorWellChanged(_:))
        colorWell.widthAnchor.constraint(equalToConstant: 48).isActive = true
        colorWell.heightAnchor.constraint(equalToConstant: 24).isActive = true

        row.addArrangedSubview(labelView)
        row.addArrangedSubview(colorWell)

        return row
    }

    private var optionalModifierTitles: [String] {
        ["None"] + SnapModifier.allCases.map(\.menuDisplayName)
    }

    private func makeModifierRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        let labelView = makeSettingLabel("Snap modifier")

        snapModifierPopup.removeAllItems()
        snapModifierPopup.addItems(withTitles: SnapModifier.allCases.map(\.menuDisplayName))
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

        let labelView = makeSettingLabel("Alternate snap modifier")

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

        let labelView = makeSettingLabel("Span modifier")

        spanModifierPopup.removeAllItems()
        spanModifierPopup.addItems(withTitles: SnapModifier.allCases.map(\.menuDisplayName))
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

        let labelView = makeSettingLabel("Alternate span modifier")

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

        let labelView = makeSettingLabel("Avoid menu bar and Dock")

        visibleFrameSwitch.target = self
        visibleFrameSwitch.action = #selector(visibleFrameSwitchChanged(_:))

        row.addArrangedSubview(labelView)
        row.addArrangedSubview(visibleFrameSwitch)

        return row
    }

    private func makeLaunchAtLoginRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        let labelView = makeSettingLabel("Launch at login")

        launchAtLoginSwitch.target = self
        launchAtLoginSwitch.action = #selector(launchAtLoginSwitchChanged(_:))

        row.addArrangedSubview(labelView)
        row.addArrangedSubview(launchAtLoginSwitch)

        return row
    }

    private func makeRestoreSizeRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        let labelView = makeSettingLabel("Restore size when unsnapped")

        restoreSizeSwitch.target = self
        restoreSizeSwitch.action = #selector(restoreSizeSwitchChanged(_:))

        row.addArrangedSubview(labelView)
        row.addArrangedSubview(restoreSizeSwitch)

        return row
    }

    private func makePermissionRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 12
        row.widthAnchor.constraint(equalToConstant: 680).isActive = true

        let labelView = NSTextField(labelWithString: "MacSnap needs Accessibility permission before snapping can work.")
        labelView.lineBreakMode = .byWordWrapping
        labelView.maximumNumberOfLines = 0
        labelView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        labelView.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let openButton = NSButton(title: "Open Settings", target: self, action: #selector(openAccessibilitySettings))
        let refreshButton = NSButton(title: "Refresh", target: self, action: #selector(refreshButtonClicked))

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 8
        buttonRow.setContentCompressionResistancePriority(.required, for: .horizontal)
        buttonRow.addArrangedSubview(openButton)
        buttonRow.addArrangedSubview(refreshButton)

        row.addArrangedSubview(labelView)
        row.addArrangedSubview(buttonRow)

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
        let previouslySelectedProfileID = selectedProfile?.id

        profilesTableView.reloadData()
        if let previouslySelectedProfileID,
           let row = store.profiles.firstIndex(where: { $0.id == previouslySelectedProfileID }) {
            profilesTableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        } else if profilesTableView.selectedRow >= store.profiles.count {
            profilesTableView.deselectAll(nil)
        }

        editProfileButton.isEnabled = selectedProfile != nil
        deleteProfileButton.isEnabled = store.profiles.count > 1 && selectedProfile != nil
        snapModifierPopup.selectItem(withTitle: settings.snapModifier.menuDisplayName)
        alternateSnapModifierPopup.selectItem(withTitle: settings.alternateSnapModifier?.menuDisplayName ?? "None")
        spanModifierPopup.selectItem(withTitle: settings.spanModifier.menuDisplayName)
        alternateSpanModifierPopup.selectItem(withTitle: settings.alternateSpanModifier?.menuDisplayName ?? "None")
        currentDisplayDefaultShortcutField.setShortcut(store.currentDisplayDefaultShortcut)
        launchAtLoginSwitch.state = store.launchAtLogin ? .on : .off
        visibleFrameSwitch.state = settings.useVisibleFrame ? .on : .off
        restoreSizeSwitch.state = settings.restoreSizeOnUnsnap ? .on : .off
        backgroundColorWell.color = NSColor(gridColor: settings.appearance.backgroundColor)
        gridLineColorWell.color = NSColor(gridColor: settings.appearance.gridLineColor)
        selectionColorWell.color = NSColor(gridColor: settings.appearance.selectionColor)
        refreshDisplayAssignments()

        permissionSection?.isHidden = PermissionManager.isAccessibilityTrusted
    }

    private var selectedProfile: GridProfile? {
        let row = profilesTableView.selectedRow
        guard row >= 0, store.profiles.indices.contains(row) else {
            return nil
        }
        return store.profiles[row]
    }

    private func selectProfile(id: UUID?) {
        guard let id,
              let row = store.profiles.firstIndex(where: { $0.id == id })
        else {
            profilesTableView.deselectAll(nil)
            return
        }

        profilesTableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    }

    private func refreshDisplayAssignments() {
        for view in displayAssignmentsStack.arrangedSubviews {
            displayAssignmentsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        displayAssignmentPopups.removeAll()
        displayAssignmentsStack.addArrangedSubview(makeDefaultProfileRow())

        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            let label = NSTextField(labelWithString: "No active displays")
            label.textColor = .secondaryLabelColor
            displayAssignmentsStack.addArrangedSubview(label)
            return
        }

        for screen in screens {
            displayAssignmentsStack.addArrangedSubview(makeDisplayAssignmentRow(for: DisplayIdentity(screen: screen)))
        }
    }

    private func displayIDsUsingDefaultProfile() -> Set<String> {
        Set(NSScreen.screens.compactMap { screen in
            let display = DisplayIdentity(screen: screen)
            return store.profileID(forDisplayID: display.id) == nil ? display.id : nil
        })
    }

    private func displayIDs(usingProfileID profileID: UUID) -> Set<String> {
        Set(NSScreen.screens.compactMap { screen in
            let display = DisplayIdentity(screen: screen)
            let effectiveProfileID = store.profileID(forDisplayID: display.id) ?? store.activeProfileID
            return effectiveProfileID == profileID ? display.id : nil
        })
    }

    private func screens(usingProfileID profileID: UUID) -> [NSScreen] {
        NSScreen.screens.filter { screen in
            let display = DisplayIdentity(screen: screen)
            let effectiveProfileID = store.profileID(forDisplayID: display.id) ?? store.activeProfileID
            return effectiveProfileID == profileID
        }
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
        case Column.name:
            text = profile.name
        case Column.grid:
            text = "\(profile.rows) x \(profile.columns)"
        case Column.gap:
            text = "\(profile.gap)"
        case Column.defaultShortcut:
            text = profile.defaultShortcut?.menuDisplayName ?? "None"
        case Column.displayShortcut:
            text = profile.displayShortcut?.menuDisplayName ?? "None"
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

    @objc private func addProfileClicked() {
        let profile = store.addProfile()
        refresh()
        selectProfile(id: profile.id)
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

        let affectedDisplayIDs = displayIDs(usingProfileID: selectedProfile.id)
        store.deleteProfile(id: selectedProfile.id)
        refresh()
        onSettingsChanged(store.settings, .affectedDisplays(affectedDisplayIDs))
    }

    private func showEditor(for profile: GridProfile) {
        let editor = ProfileEditorWindowController(
            profile: profile,
            profilesProvider: { [weak self] in
                self?.store.profiles ?? []
            },
            overlayController: overlayController,
            settingsProvider: { [weak self] in
                self?.store.settings ?? SettingsStore.defaultSettings
            },
            affectedScreensProvider: { [weak self] profileID in
                self?.screens(usingProfileID: profileID) ?? []
            },
            onShortcutRecordingChanged: onShortcutRecordingChanged
        ) { [weak self] updatedProfile in
            guard let self else {
                return
            }

            store.updateProfile(updatedProfile)
            refresh()
            onSettingsChanged(store.settings, .none)
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

    private func currentDisplayDefaultShortcutRecorded(_ shortcut: KeyboardShortcut) {
        store.currentDisplayDefaultShortcut = shortcut.normalized()
        refresh()
        onSettingsChanged(store.settings, .none)
    }

    @objc private func clearCurrentDisplayDefaultShortcutClicked() {
        store.currentDisplayDefaultShortcut = nil
        currentDisplayDefaultShortcutField.setShortcut(nil)
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

    @objc private func launchAtLoginSwitchChanged(_ sender: NSSwitch) {
        let enabled = sender.state == .on
        store.launchAtLogin = enabled
        onLaunchAtLoginChanged(enabled)
        refresh()
    }

    @objc private func restoreSizeSwitchChanged(_ sender: NSSwitch) {
        saveGlobal(restoreSizeOnUnsnap: sender.state == .on)
    }

    @objc private func defaultProfileChanged(_ sender: NSPopUpButton) {
        guard !isRefreshing,
              let rawID = sender.selectedItem?.representedObject as? String,
              let profileID = UUID(uuidString: rawID),
              profileID != store.activeProfileID
        else {
            return
        }

        store.activeProfileID = profileID
        let affectedDisplayIDs = displayIDsUsingDefaultProfile()
        refresh()
        onSettingsChanged(store.settings, .affectedDisplays(affectedDisplayIDs))
    }

    @objc private func displayAssignmentChanged(_ sender: NSPopUpButton) {
        guard !isRefreshing,
              let display = displayAssignmentPopups[sender]
        else {
            return
        }

        let profileID = (sender.selectedItem?.representedObject as? String).flatMap(UUID.init(uuidString:))
        let previousProfileID = store.profileID(forDisplayID: display.id)
        store.setProfile(profileID, forDisplayID: display.id, displayName: display.name)
        refresh()
        let previewIntent: PreviewIntent = previousProfileID == profileID
            ? .none
            : .affectedDisplays([display.id])
        onSettingsChanged(store.settings, previewIntent)
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
        onLaunchAtLoginChanged(store.launchAtLogin)
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

private final class HelpButton: NSButton {
    let helpText: String

    init(helpText: String) {
        self.helpText = helpText
        super.init(frame: .zero)

        bezelStyle = .inline
        isBordered = false
        imagePosition = .imageOnly
        contentTintColor = .secondaryLabelColor
        toolTip = helpText
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 16).isActive = true
        heightAnchor.constraint(equalToConstant: 16).isActive = true
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    required init?(coder: NSCoder) {
        nil
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
