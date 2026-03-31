import Cocoa
import Carbon

// MARK: - Input Source

struct InputSource {
    let id: String
    let name: String
    let source: TISInputSource
}

func getInputSources() -> [InputSource] {
    let conditions = [
        kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource!,
        kTISPropertyInputSourceIsEnabled: true as CFBoolean
    ] as CFDictionary

    guard let sourceList = TISCreateInputSourceList(conditions, false)?.takeRetainedValue() as? [TISInputSource] else {
        return []
    }

    return sourceList.compactMap { source in
        guard let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
              let namePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName),
              let typePtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceType) else {
            return nil
        }
        let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
        let name = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String
        let type = Unmanaged<CFString>.fromOpaque(typePtr).takeUnretainedValue() as String

        let keyboardLayout = kTISTypeKeyboardLayout as String
        let keyboardInputMode = kTISTypeKeyboardInputMode as String
        guard type == keyboardLayout || type == keyboardInputMode else { return nil }

        return InputSource(id: id, name: name, source: source)
    }
}

func getCurrentSourceID() -> String {
    let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
    guard let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return "" }
    return Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
}

func switchTo(_ source: InputSource) {
    TISSelectInputSource(source.source)
}

// MARK: - Floating Window

class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel], backing: backingStoreType, defer: flag)
        level = .floating
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isFloatingPanel = true
        collectionBehavior = [.canJoinAllSpaces, .stationary]
    }
}

// MARK: - Tool Button (reusable)

class ToolButton: NSView {
    var label: NSTextField!
    var isActive = false
    var onClick: (() -> Void)?
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private let activeColor: NSColor
    private let minWidth: CGFloat

    init(title: String, activeColor: NSColor = .systemBlue, minWidth: CGFloat = 70) {
        self.activeColor = activeColor
        self.minWidth = minWidth
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8

        label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -6),
            widthAnchor.constraint(greaterThanOrEqualToConstant: minWidth),
            heightAnchor.constraint(equalToConstant: 32)
        ])

        updateAppearance()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        updateAppearance()
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    func setActive(_ active: Bool) {
        isActive = active
        updateAppearance()
    }

    private func updateAppearance() {
        if isActive {
            layer?.backgroundColor = activeColor.cgColor
            label.textColor = .white
        } else if isHovered {
            layer?.backgroundColor = NSColor(white: 0.35, alpha: 1).cgColor
            label.textColor = .white
        } else {
            layer?.backgroundColor = NSColor(white: 0.25, alpha: 1).cgColor
            label.textColor = NSColor(white: 0.75, alpha: 1)
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: FloatingPanel!
    var langButtons: [ToolButton] = []
    var sources: [InputSource] = []
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        sources = getInputSources()
        setupMenuBar()

        let padding: CGFloat = 4
        let spacing: CGFloat = 4
        let buttonHeight: CGFloat = 32
        let langButtonWidth: CGFloat = 74
        let screenshotButtonWidth: CGFloat = 38
        let dividerWidth: CGFloat = 1 + spacing * 2

        let gripWidth: CGFloat = 20
        let langSectionWidth = CGFloat(max(sources.count, 1)) * (langButtonWidth + spacing) - spacing
        let width = padding + gripWidth + spacing + langSectionWidth + dividerWidth + screenshotButtonWidth + padding
        let height = buttonHeight + padding * 2

        let screen = NSScreen.main?.visibleFrame ?? .zero
        let x = screen.minX + 20
        let y = screen.minY + 20

        window = FloatingPanel(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(white: 0.15, alpha: 0.95).cgColor
        container.layer?.cornerRadius = 12
        window.contentView = container

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -padding),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: padding),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -padding)
        ])

        // Drag grip (6 dots)
        let grip = NSTextField(labelWithString: "\u{2807}")  // ⠇ braille 6-dot
        grip.font = NSFont.systemFont(ofSize: 16, weight: .bold)
        grip.textColor = NSColor(white: 0.45, alpha: 1)
        grip.alignment = .center
        grip.translatesAutoresizingMaskIntoConstraints = false
        let gripContainer = NSView()
        gripContainer.addSubview(grip)
        gripContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            gripContainer.widthAnchor.constraint(equalToConstant: gripWidth),
            grip.centerXAnchor.constraint(equalTo: gripContainer.centerXAnchor),
            grip.centerYAnchor.constraint(equalTo: gripContainer.centerYAnchor)
        ])
        stack.addArrangedSubview(gripContainer)

        // Language buttons
        for source in sources {
            let btn = ToolButton(title: source.name, minWidth: langButtonWidth)
            btn.onClick = { [weak self] in
                switchTo(source)
                self?.updateHighlight()
            }
            langButtons.append(btn)
            stack.addArrangedSubview(btn)
        }

        // Divider
        let divider = NSView()
        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor(white: 0.35, alpha: 1).cgColor
        divider.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(divider)
        NSLayoutConstraint.activate([
            divider.widthAnchor.constraint(equalToConstant: 1),
            divider.heightAnchor.constraint(equalToConstant: 20)
        ])

        // Screenshot button
        let ssBtn = ToolButton(title: "\u{2702}", activeColor: .systemOrange, minWidth: screenshotButtonWidth)
        ssBtn.onClick = { [weak self] in
            self?.takeScreenshot()
        }
        stack.addArrangedSubview(ssBtn)

        updateHighlight()

        // Listen for input source changes (event-driven, no polling)
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(inputSourceChanged),
            name: NSNotification.Name("AppleSelectedInputSourcesChangedNotification"),
            object: nil
        )

        // Right-click menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "종료", action: #selector(quit), keyEquivalent: "q"))
        window.contentView?.menu = menu

        window.orderFrontRegardless()
    }

    // MARK: - Menu Bar

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateMenuBarTitle()
        buildStatusMenu()
    }

    func shortLabel(for source: InputSource) -> String {
        let id = source.id.lowercased()
        let name = source.name

        // 한국어 키보드 (2벌식, 3벌식 등)
        if id.contains("korean") || name.contains("벌식") || name.contains("한국") || name.contains("한글") {
            return "한"
        }
        // 중국어 병음
        if id.contains("pinyin") || name.contains("拼") || name.contains("拼音") {
            return "拼"
        }
        // 일본어
        if id.contains("japanese") || name.contains("日本") {
            return "あ"
        }
        // ABC / 영어
        if id.contains("abc") || id.contains("us") || name == "ABC" || name == "U.S." {
            return "A"
        }
        // 그 외: 첫 글자
        return String(name.prefix(1))
    }

    func updateMenuBarTitle() {
        let currentID = getCurrentSourceID()
        let current = sources.first { $0.id == currentID }
        let short = current.map { shortLabel(for: $0) } ?? "?"
        statusItem.button?.title = short
        statusItem.button?.font = NSFont.systemFont(ofSize: 14, weight: .medium)
    }

    func buildStatusMenu() {
        let menu = NSMenu()

        // 헤더
        let header = NSMenuItem(title: "입력 소스", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(NSMenuItem.separator())

        // 입력 소스 목록
        let currentID = getCurrentSourceID()
        for (i, source) in sources.enumerated() {
            let item = NSMenuItem(title: source.name, action: #selector(menuSwitchSource(_:)), keyEquivalent: "")
            item.tag = i
            item.target = self
            if source.id == currentID {
                item.state = .on
            }
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        // 스크린샷
        let ssItem = NSMenuItem(title: "스크린샷 (클립보드)", action: #selector(menuScreenshot), keyEquivalent: "s")
        ssItem.target = self
        menu.addItem(ssItem)

        menu.addItem(NSMenuItem.separator())

        // 종료
        let quitItem = NSMenuItem(title: "종료", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc func menuSwitchSource(_ sender: NSMenuItem) {
        let idx = sender.tag
        guard idx >= 0 && idx < sources.count else { return }
        switchTo(sources[idx])
        updateHighlight()
        updateMenuBarTitle()
        buildStatusMenu()
    }

    @objc func menuScreenshot() {
        takeScreenshot()
    }

    // MARK: - Highlight

    func updateHighlight() {
        let currentID = getCurrentSourceID()
        for (i, btn) in langButtons.enumerated() {
            btn.setActive(sources[i].id == currentID)
        }
    }

    @objc func inputSourceChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.updateHighlight()
            self?.updateMenuBarTitle()
            self?.buildStatusMenu()
        }
    }

    func takeScreenshot() {
        window.orderOut(nil)
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.3) { [weak self] in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            task.arguments = ["-ic"]
            try? task.run()
            task.waitUntilExit()
            DispatchQueue.main.async {
                self?.window.makeKeyAndOrderFront(nil)
            }
        }
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

// MARK: - Main

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
