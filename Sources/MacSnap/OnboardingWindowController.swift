import AppKit
import MacSnapCore

@MainActor
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    private enum Step: Int, CaseIterable {
        case welcome
        case permissions
        case modifiers
        case profile
        case usage
    }

    private let store: SettingsStore
    private let overlayController: GridOverlayController
    private let onFinished: () -> Void
    private let titleLabel = NSTextField(labelWithString: "")
    private let bodyLabel = NSTextField(wrappingLabelWithString: "")
    private let contentStack = NSStackView()
    private let stepLabel = NSTextField(labelWithString: "")
    private let backButton = NSButton(title: "Back", target: nil, action: nil)
    private let skipButton = NSButton(title: "Skip Setup", target: nil, action: nil)
    private let nextButton = NSButton(title: "Continue", target: nil, action: nil)
    private let permissionStatusLabel = NSTextField(labelWithString: "")
    private let snapModifierPopup = NSPopUpButton()
    private let spanModifierPopup = NSPopUpButton()
    private let rowsSlider = NSSlider()
    private let columnsSlider = NSSlider()
    private let gapSlider = NSSlider()
    private let rowsValueLabel = NSTextField(labelWithString: "")
    private let columnsValueLabel = NSTextField(labelWithString: "")
    private let gapValueLabel = NSTextField(labelWithString: "")

    private var currentStep: Step = .welcome
    private var draftSnapModifier: SnapModifier
    private var draftSpanModifier: SnapModifier

    init(
        store: SettingsStore,
        overlayController: GridOverlayController,
        onFinished: @escaping () -> Void
    ) {
        self.store = store
        self.overlayController = overlayController
        self.onFinished = onFinished
        draftSnapModifier = store.snapModifier
        draftSpanModifier = store.spanModifier

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Set Up MacSnap"
        window.center()
        window.isReleasedWhenClosed = false
        window.collectionBehavior.insert(.moveToActiveSpace)
        window.level = GridOverlayController.appWindowLevel

        super.init(window: window)

        window.delegate = self
        window.contentView = makeContentView()
        configureControls()
        render()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        overlayController.hide()
    }

    private func makeContentView() -> NSView {
        let container = NSView()

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 26, weight: .bold)
        bodyLabel.font = .systemFont(ofSize: 14)
        bodyLabel.textColor = .secondaryLabelColor
        bodyLabel.maximumNumberOfLines = 0
        bodyLabel.widthAnchor.constraint(equalToConstant: 540).isActive = true

        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 14
        contentStack.widthAnchor.constraint(equalToConstant: 540).isActive = true

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(bodyLabel)
        stack.addArrangedSubview(contentStack)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        stack.addArrangedSubview(spacer)
        stack.addArrangedSubview(makeFooterRow())

        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -32),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -24)
        ])

        return container
    }

    private func makeFooterRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.widthAnchor.constraint(equalToConstant: 540).isActive = true

        stepLabel.textColor = .secondaryLabelColor

        backButton.target = self
        backButton.action = #selector(backClicked)
        skipButton.target = self
        skipButton.action = #selector(skipClicked)
        nextButton.target = self
        nextButton.action = #selector(nextClicked)
        nextButton.keyEquivalent = "\r"

        let spacer = NSView()
        row.addArrangedSubview(stepLabel)
        row.addArrangedSubview(spacer)
        row.addArrangedSubview(backButton)
        row.addArrangedSubview(skipButton)
        row.addArrangedSubview(nextButton)

        return row
    }

    private func configureControls() {
        snapModifierPopup.addItems(withTitles: SnapModifier.allCases.map(\.menuDisplayName))
        snapModifierPopup.target = self
        snapModifierPopup.action = #selector(snapModifierChanged)
        snapModifierPopup.widthAnchor.constraint(equalToConstant: 170).isActive = true

        spanModifierPopup.addItems(withTitles: SnapModifier.allCases.map(\.menuDisplayName))
        spanModifierPopup.target = self
        spanModifierPopup.action = #selector(spanModifierChanged)
        spanModifierPopup.widthAnchor.constraint(equalToConstant: 170).isActive = true

        configureSlider(rowsSlider, min: 1, max: 12)
        configureSlider(columnsSlider, min: 1, max: 12)
        configureSlider(gapSlider, min: 0, max: 80, showsTickMarks: false)
        rowsValueLabel.widthAnchor.constraint(equalToConstant: 32).isActive = true
        columnsValueLabel.widthAnchor.constraint(equalToConstant: 32).isActive = true
        gapValueLabel.widthAnchor.constraint(equalToConstant: 32).isActive = true

        rowsSlider.integerValue = store.rows
        columnsSlider.integerValue = store.columns
        gapSlider.integerValue = store.gap
    }

    private func configureSlider(_ slider: NSSlider, min: Int, max: Int, showsTickMarks: Bool = true) {
        slider.minValue = Double(min)
        slider.maxValue = Double(max)
        if showsTickMarks {
            slider.numberOfTickMarks = max - min + 1
            slider.allowsTickMarkValuesOnly = true
        }
        slider.widthAnchor.constraint(equalToConstant: 260).isActive = true
        slider.target = self
        slider.action = #selector(profileSliderChanged)
    }

    private func render() {
        removeContentViews()
        if currentStep != .profile {
            overlayController.hide()
        }
        stepLabel.stringValue = "Step \(currentStep.rawValue + 1) of \(Step.allCases.count)"
        backButton.isEnabled = currentStep != .welcome
        skipButton.isHidden = currentStep == .usage
        nextButton.title = currentStep == .usage ? "Finish" : "Continue"

        switch currentStep {
        case .welcome:
            renderWelcome()
        case .permissions:
            renderPermissions()
        case .modifiers:
            renderModifiers()
        case .profile:
            renderProfile()
        case .usage:
            renderUsage()
        }
    }

    private func removeContentViews() {
        for view in contentStack.arrangedSubviews {
            contentStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }

    private func renderWelcome() {
        titleLabel.stringValue = "Welcome to MacSnap"
        bodyLabel.stringValue = "MacSnap gives macOS a FancyZones-style grid for quickly placing windows."

        contentStack.addArrangedSubview(makeCallout(
            title: "What you will set up",
            text: "Pick the keys or mouse buttons that trigger snapping, choose your first default grid, and learn the basic drag gesture."
        ))
    }

    private func renderPermissions() {
        titleLabel.stringValue = "Allow Window Control"
        bodyLabel.stringValue = "MacSnap needs Accessibility permission before it can detect and move windows."

        _ = PermissionManager.requestAccessibilityPermissionIfNeeded()
        contentStack.addArrangedSubview(permissionStatusLabel)
        refreshPermissionStatus()
        if !PermissionManager.isAccessibilityTrusted {
            contentStack.addArrangedSubview(makeButtonRow([
                NSButton(title: "Open Settings", target: self, action: #selector(openAccessibilitySettings)),
                NSButton(title: "Refresh", target: self, action: #selector(refreshPermissions))
            ]))
        }
    }

    private func renderModifiers() {
        titleLabel.stringValue = "Choose Modifiers"
        bodyLabel.stringValue = "These controls decide when the grid appears and when span mode toggles."

        refreshModifierPopups()
        contentStack.addArrangedSubview(makePopupRow(
            label: "Snap modifier",
            detail: "Hold this while dragging a window to show the grid.",
            popup: snapModifierPopup
        ))
        contentStack.addArrangedSubview(makePopupRow(
            label: "Span modifier",
            detail: "Press this while snapping to toggle selecting multiple cells.",
            popup: spanModifierPopup
        ))
    }

    private func renderProfile() {
        titleLabel.stringValue = "Choose Your First Grid"
        bodyLabel.stringValue = "This becomes your default profile. You can add more profiles later from Settings."

        contentStack.addArrangedSubview(makeSliderRow(label: "Rows", slider: rowsSlider, valueLabel: rowsValueLabel))
        contentStack.addArrangedSubview(makeSliderRow(label: "Columns", slider: columnsSlider, valueLabel: columnsValueLabel))
        contentStack.addArrangedSubview(makeSliderRow(label: "Gap", slider: gapSlider, valueLabel: gapValueLabel))
        refreshProfileLabels()
        showProfileGridOverlay()
    }

    private func renderUsage() {
        titleLabel.stringValue = "How to Snap"
        bodyLabel.stringValue = "You are ready to use MacSnap."

        contentStack.addArrangedSubview(makeInstruction("1", "Hold \(draftSnapModifier.displayName) and drag a window."))
        contentStack.addArrangedSubview(makeInstruction("2", "Move over the grid cell you want, then release the window."))
        let spanInstruction = makeInstruction("3", "Press \(draftSpanModifier.displayName) while snapping to toggle span mode for multi-cell layouts.")
        contentStack.addArrangedSubview(spanInstruction)
        contentStack.setCustomSpacing(20, after: spanInstruction)
        contentStack.addArrangedSubview(makeCallout(
            title: "You can change this anytime",
            text: "Use the MacSnap menu bar icon to reopen Setup or change everything in Settings."
        ))
    }

    private func makeCallout(title: String, text: String) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        stack.wantsLayer = true
        stack.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.55).cgColor
        stack.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.35).cgColor
        stack.layer?.borderWidth = 1
        stack.layer?.cornerRadius = 6
        stack.setContentHuggingPriority(.required, for: .vertical)
        stack.setContentCompressionResistancePriority(.required, for: .vertical)
        stack.widthAnchor.constraint(equalToConstant: 540).isActive = true

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        let textLabel = NSTextField(wrappingLabelWithString: text)
        textLabel.textColor = .secondaryLabelColor
        textLabel.widthAnchor.constraint(equalToConstant: 500).isActive = true
        textLabel.maximumNumberOfLines = 0
        textLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(textLabel)
        return stack
    }

    private func makeButtonRow(_ buttons: [NSButton]) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        for button in buttons {
            row.addArrangedSubview(button)
        }
        return row
    }

    private func makePopupRow(label: String, detail: String, popup: NSPopUpButton) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 14

        let labelStack = NSStackView()
        labelStack.orientation = .vertical
        labelStack.alignment = .leading
        labelStack.spacing = 3
        labelStack.widthAnchor.constraint(equalToConstant: 230).isActive = true

        let titleLabel = NSTextField(labelWithString: label)
        let detailLabel = NSTextField(wrappingLabelWithString: detail)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.font = .systemFont(ofSize: 12)
        detailLabel.widthAnchor.constraint(equalToConstant: 230).isActive = true

        labelStack.addArrangedSubview(titleLabel)
        labelStack.addArrangedSubview(detailLabel)

        row.addArrangedSubview(labelStack)
        row.addArrangedSubview(popup)
        return row
    }

    private func makeSliderRow(label: String, slider: NSSlider, valueLabel: NSTextField) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        let titleLabel = NSTextField(labelWithString: label)
        titleLabel.widthAnchor.constraint(equalToConstant: 92).isActive = true
        valueLabel.alignment = .right

        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(slider)
        row.addArrangedSubview(valueLabel)
        return row
    }

    private func makeInstruction(_ number: String, _ text: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 12
        row.setContentHuggingPriority(.required, for: .vertical)
        row.setContentCompressionResistancePriority(.required, for: .vertical)

        let badge = NSTextField(labelWithString: number)
        badge.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        badge.alignment = .center
        badge.widthAnchor.constraint(equalToConstant: 22).isActive = true
        badge.setContentCompressionResistancePriority(.required, for: .vertical)

        let label = NSTextField(wrappingLabelWithString: text)
        label.maximumNumberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.widthAnchor.constraint(equalToConstant: 490).isActive = true
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)

        row.addArrangedSubview(badge)
        row.addArrangedSubview(label)
        return row
    }

    private func refreshPermissionStatus() {
        if PermissionManager.isAccessibilityTrusted {
            permissionStatusLabel.stringValue = "Accessibility permission is enabled. You are all set."
            permissionStatusLabel.textColor = .systemGreen
        } else {
            permissionStatusLabel.stringValue = "Accessibility permission is not enabled yet."
            permissionStatusLabel.textColor = .systemOrange
        }
    }

    private func refreshModifierPopups() {
        snapModifierPopup.selectItem(withTitle: draftSnapModifier.menuDisplayName)
        spanModifierPopup.selectItem(withTitle: draftSpanModifier.menuDisplayName)
    }

    private func refreshProfileLabels() {
        rowsValueLabel.stringValue = "\(rowsSlider.integerValue)"
        columnsValueLabel.stringValue = "\(columnsSlider.integerValue)"
        gapValueLabel.stringValue = "\(gapSlider.integerValue)"
    }

    private func showProfileGridOverlay() {
        guard let screen = window?.screen ?? NSScreen.main else {
            return
        }

        let settings = GridSettings(
            rows: rowsSlider.integerValue,
            columns: columnsSlider.integerValue,
            gap: gapSlider.integerValue,
            snapModifier: draftSnapModifier,
            alternateSnapModifier: store.alternateSnapModifier,
            spanModifier: draftSpanModifier,
            alternateSpanModifier: store.alternateSpanModifier,
            useVisibleFrame: store.useVisibleFrame,
            restoreSizeOnUnsnap: store.restoreSizeOnUnsnap,
            appearance: store.appearance
        )
        let frame = settings.useVisibleFrame ? screen.visibleFrame : screen.frame

        overlayController.update(
            on: screen,
            model: GridModel(settings: settings),
            selection: nil,
            appearance: settings.appearance,
            in: frame
        )
    }

    private func fallbackSpanModifier(for snapModifier: SnapModifier) -> SnapModifier {
        snapModifier == .middleClick ? .option : .middleClick
    }

    private func finish(applySettings: Bool) {
        overlayController.hide()

        if applySettings {
            store.snapModifier = draftSnapModifier
            store.spanModifier = draftSpanModifier
            store.rows = rowsSlider.integerValue
            store.columns = columnsSlider.integerValue
            store.gap = gapSlider.integerValue
        }

        store.hasCompletedOnboarding = true
        onFinished()
        close()
    }

    @objc private func openAccessibilitySettings() {
        PermissionManager.openAccessibilitySettings()
    }

    @objc private func refreshPermissions() {
        refreshPermissionStatus()
    }

    @objc private func snapModifierChanged() {
        let selectedIndex = snapModifierPopup.indexOfSelectedItem
        guard SnapModifier.allCases.indices.contains(selectedIndex) else {
            return
        }

        draftSnapModifier = SnapModifier.allCases[selectedIndex]
        if draftSpanModifier == draftSnapModifier {
            draftSpanModifier = fallbackSpanModifier(for: draftSnapModifier)
        }
        refreshModifierPopups()
    }

    @objc private func spanModifierChanged() {
        let selectedIndex = spanModifierPopup.indexOfSelectedItem
        guard SnapModifier.allCases.indices.contains(selectedIndex) else {
            return
        }

        let selectedModifier = SnapModifier.allCases[selectedIndex]
        draftSpanModifier = selectedModifier == draftSnapModifier
            ? fallbackSpanModifier(for: draftSnapModifier)
            : selectedModifier
        refreshModifierPopups()
    }

    @objc private func profileSliderChanged() {
        refreshProfileLabels()
        if currentStep == .profile {
            showProfileGridOverlay()
        }
    }

    @objc private func backClicked() {
        guard let previousStep = Step(rawValue: currentStep.rawValue - 1) else {
            return
        }

        currentStep = previousStep
        render()
    }

    @objc private func skipClicked() {
        finish(applySettings: false)
    }

    @objc private func nextClicked() {
        if currentStep == .usage {
            finish(applySettings: true)
            return
        }

        guard let nextStep = Step(rawValue: currentStep.rawValue + 1) else {
            return
        }

        currentStep = nextStep
        render()
    }
}
