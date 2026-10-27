import AppKit

// ============================================================
// Agent traffic light — native macOS version (Swift + AppKit)
//   red    = needs human input (waiting for confirmation / tool error)
//   yellow = working
//   blue   = idle
// Status source: ~/.agent-status, content is status or status:agent
//          (written by Claude Code / Qoder / OpenCode hooks via set_status.sh,
//           merged across agents by priority attention > working > idle)
// Interaction: drag with left button to move (position is remembered),
//              drag edge/corner to resize (aspect-locked, 0.5x–2x, size remembered),
//              right-click for menu (Reset Size / Quit).
// Build: run ./build.sh on a Mac
// ============================================================

let homeDir = NSHomeDirectory()
let stateFile = (homeDir as NSString).appendingPathComponent(".agent-status")

// (status key, lamp center y, bright color, dim color, display name)
let lampDefs: [(key: String, y: CGFloat, bright: NSColor, dim: NSColor, name: String)] = [
    ("attention", 50,
     NSColor(red: 1.00, green: 0.27, blue: 0.23, alpha: 1),
     NSColor(red: 0.29, green: 0.13, blue: 0.12, alpha: 1), "Attention"),
    ("working", 136,
     NSColor(red: 1.00, green: 0.84, blue: 0.04, alpha: 1),
     NSColor(red: 0.29, green: 0.24, blue: 0.08, alpha: 1), "Working"),
    ("idle", 222,
     NSColor(red: 0.04, green: 0.52, blue: 1.00, alpha: 1),
     NSColor(red: 0.10, green: 0.17, blue: 0.28, alpha: 1), "Idle"),
]

// ---------------- theme ----------------
enum Theme: String, CaseIterable {
    case dark
    case light

    var housingColor: NSColor {
        switch self {
        case .dark: return NSColor(white: 0.11, alpha: 1)
        case .light: return NSColor(white: 0.95, alpha: 1)
        }
    }

    var bezelColor: NSColor {
        switch self {
        case .dark: return NSColor(white: 0.17, alpha: 1)
        case .light: return NSColor(white: 0.85, alpha: 1)
        }
    }

    var labelColor: NSColor {
        switch self {
        case .dark: return NSColor(white: 0.68, alpha: 1)
        case .light: return NSColor(white: 0.20, alpha: 1)
        }
    }

    var displayName: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        }
    }
}

let themeDefaultsKey = "AgentLightsTheme"

func loadTheme() -> Theme {
    guard let raw = UserDefaults.standard.string(forKey: themeDefaultsKey),
          let theme = Theme(rawValue: raw) else {
        return .dark
    }
    return theme
}

func saveTheme(_ theme: Theme) {
    UserDefaults.standard.set(theme.rawValue, forKey: themeDefaultsKey)
}

func readStatus() -> (String, String) {
    guard let raw = try? String(contentsOfFile: stateFile, encoding: .utf8) else {
        return ("idle", "")
    }
    let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = t.split(separator: ":", maxSplits: 1).map(String.init)
    var s = parts.first ?? "idle"
    if !["idle", "working", "attention"].contains(s) { s = "idle" }
    let agent = parts.count > 1 ? String(parts[1].prefix(14)) : ""
    return (s, agent)
}

// ---------------- diagonal resize cursors ----------------
// AppKit has no public diagonal resize cursor, so draw one:
// 24x24, white outline + black core (visible on light and dark backgrounds),
// hotspot at the center. northEast=false draws ↖↘, true draws ↗↙.
func makeCornerCursor(northEast: Bool) -> NSCursor {
    let side: CGFloat = 24
    let img = NSImage(size: NSSize(width: side, height: side), flipped: true) { _ in
        let a = northEast ? NSPoint(x: side - 5, y: 5) : NSPoint(x: 5, y: 5)
        let b = northEast ? NSPoint(x: 5, y: side - 5) : NSPoint(x: side - 5, y: side - 5)
        let shaft = NSBezierPath()
        shaft.move(to: a)
        shaft.line(to: b)
        func head(at tip: NSPoint, toward o: NSPoint) -> NSBezierPath {
            let ux: CGFloat = (o.x > tip.x) ? 1 : -1
            let uy: CGFloat = (o.y > tip.y) ? 1 : -1
            let p = NSBezierPath()
            p.move(to: tip)
            p.line(to: NSPoint(x: tip.x + 9 * ux, y: tip.y))
            p.line(to: NSPoint(x: tip.x, y: tip.y + 9 * uy))
            p.close()
            return p
        }
        let h1 = head(at: a, toward: b)
        let h2 = head(at: b, toward: a)
        NSColor.white.setFill(); NSColor.white.setStroke()   // outline
        shaft.lineWidth = 5.5; shaft.stroke()
        h1.fill(); h2.fill()
        NSColor.black.setFill(); NSColor.black.setStroke()   // core
        shaft.lineWidth = 1.8; shaft.stroke()
        h1.fill(); h2.fill()
        return true
    }
    return NSCursor(image: img, hotSpot: NSPoint(x: side / 2, y: side / 2))
}

// ---------------- light view ----------------
class LightView: NSView {
    var status = "idle"
    var agent = ""
    var theme = Theme.dark

    static let nwseCursor = makeCornerCursor(northEast: false)
    static let neswCursor = makeCornerCursor(northEast: true)
    static let edgeZone: CGFloat = 6      // edge hover band (points)
    static let cornerZone: CGFloat = 14   // corner hover square (points)
    var trackingArea: NSTrackingArea?

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let b = bounds
        // scale factor from the 84x296 design space (aspect ratio is locked,
        // so width/84 == height/296; min() just guards against rounding)
        let s = min(b.width / 84, b.height / 296)
        // housing (rounded)
        theme.housingColor.setFill()
        NSBezierPath(roundedRect: b, xRadius: 18 * s, yRadius: 18 * s).fill()
        // the three lamps
        let cx = b.width / 2
        for def in lampDefs {
            let active = (def.key == status)
            let c = NSPoint(x: cx, y: def.y * s)
            theme.bezelColor.setFill()  // bezel
            NSBezierPath(ovalIn: NSRect(x: c.x - 26 * s, y: c.y - 26 * s, width: 52 * s, height: 52 * s)).fill()
            (active ? def.bright : def.dim).setFill()  // lamp
            NSBezierPath(ovalIn: NSRect(x: c.x - 21 * s, y: c.y - 21 * s, width: 42 * s, height: 42 * s)).fill()
            if active {  // highlight dot
                NSColor.white.withAlphaComponent(0.85).setFill()
                NSBezierPath(ovalIn: NSRect(x: c.x - 9 * s, y: c.y - 13 * s, width: 10 * s, height: 8 * s)).fill()
            }
        }
        // status label (two-line layout: status name + agent name)
        let name = lampDefs.first(where: { $0.key == status })?.name ?? ""
        let text = agent.isEmpty ? name : "\(name)\n\(agent)"
        let fontSize = min(14, max(9, 11 * s))
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byTruncatingTail
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize),
            .foregroundColor: theme.labelColor,
            .paragraphStyle: paragraphStyle,
        ]
        let maxTextWidth = b.width - 16 * s
        let labelAreaHeight: CGFloat = 74 * s
        let size = (text as NSString).boundingRect(
            with: NSSize(width: maxTextWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: attrs).size
        let textRect = NSRect(
            x: 8 * s,
            y: 222 * s + (labelAreaHeight - size.height) / 2,
            width: maxTextWidth,
            height: size.height)
        (text as NSString).draw(in: textRect, withAttributes: attrs)
    }

    // ---------------- resize-cursor feedback ----------------
    // A borderless window shows no resize cursor on its own, so track the
    // mouse and swap the cursor per zone: corners -> diagonal (custom image),
    // edges -> system left/right or up/down arrows, interior -> normal arrow.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = trackingArea { removeTrackingArea(t) }
        let t = NSTrackingArea(rect: bounds,
                               options: [.mouseMoved, .mouseEnteredAndExited,
                                         .cursorUpdate, .activeAlways, .inVisibleRect],
                               owner: self, userInfo: nil)
        addTrackingArea(t)
        trackingArea = t
    }

    func resizeCursor(at pointInWindow: NSPoint) -> NSCursor? {
        let p = convert(pointInWindow, from: nil)
        let b = bounds
        let c = Self.cornerZone
        let left = p.x <= c, right = p.x >= b.width - c
        let top = p.y <= c, bottom = p.y >= b.height - c   // flipped: y=0 is top
        if (left && top) || (right && bottom) { return Self.nwseCursor }
        if (right && top) || (left && bottom) { return Self.neswCursor }
        let e = Self.edgeZone
        if p.x <= e || p.x >= b.width - e { return NSCursor.resizeLeftRight }
        if p.y <= e || p.y >= b.height - e { return NSCursor.resizeUpDown }
        return nil
    }

    func applyCursor(at pointInWindow: NSPoint) {
        (resizeCursor(at: pointInWindow) ?? NSCursor.arrow).set()
    }

    override func mouseMoved(with event: NSEvent) { applyCursor(at: event.locationInWindow) }
    override func cursorUpdate(with event: NSEvent) { applyCursor(at: event.locationInWindow) }
    override func mouseExited(with event: NSEvent) { NSCursor.arrow.set() }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        let reset = NSMenuItem(title: "Reset Size",
                               action: #selector(resetSize),
                               keyEquivalent: "")
        reset.target = self
        menu.addItem(reset)
        menu.addItem(.separator())

        let themeMenu = NSMenu(title: "Theme")
        for t in Theme.allCases {
            let item = NSMenuItem(title: t.displayName,
                                  action: #selector(themeItemSelected(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = t
            item.state = (t == theme) ? .on : .off
            themeMenu.addItem(item)
        }
        let themeItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        themeItem.submenu = themeMenu
        menu.addItem(themeItem)

        menu.addItem(.separator())
        let item = NSMenuItem(title: "Quit",
                              action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "")
        item.target = NSApp
        menu.addItem(item)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc func themeItemSelected(_ sender: NSMenuItem) {
        guard let newTheme = sender.representedObject as? Theme else { return }
        theme = newTheme
        saveTheme(theme)
        needsDisplay = true
    }

    @objc func resetSize() {
        guard let w = window else { return }
        var f = w.frame
        f.size = NSSize(width: 84, height: 296)
        w.setFrame(f, display: true)
    }
}

// ---------------- launch ----------------
let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // no Dock icon, floating only

let currentTheme = loadTheme()
let view = LightView(frame: NSRect(x: 0, y: 0, width: 84, height: 296))
view.theme = currentTheme

let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 84, height: 296),
                    styleMask: [.borderless, .nonactivatingPanel, .resizable],
                    backing: .buffered, defer: false)
panel.contentView = view
panel.level = .floating                       // always on top
panel.isOpaque = false
panel.backgroundColor = .clear                 // transparent rounded corners
panel.hasShadow = true
panel.isMovableByWindowBackground = true       // drag from anywhere
panel.acceptsMouseMovedEvents = true           // hover tracking for resize cursors
panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
panel.contentAspectRatio = NSSize(width: 84, height: 296)  // keep 84:296 while resizing
panel.minSize = NSSize(width: 42, height: 148)             // 0.5x
panel.maxSize = NSSize(width: 168, height: 592)            // 2x
panel.setFrameAutosaveName("AgentTrafficLight") // position + size are remembered

if !panel.setFrameUsingName("AgentTrafficLight") {
    // first launch: bottom-right corner
    if let screen = NSScreen.main {
        let vf = screen.visibleFrame
        let f = panel.frame
        panel.setFrameOrigin(NSPoint(x: vf.maxX - f.width - 26, y: vf.maxY - f.height - 90))
    }
}
panel.orderFrontRegardless()

// poll the status file every 0.5s, redraw only on change
_ = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
    let (s, a) = readStatus()
    if s != view.status || a != view.agent {
        view.status = s
        view.agent = a
        view.needsDisplay = true
    }
}

app.run()
