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

// ---------------- light view ----------------
class LightView: NSView {
    var status = "idle"
    var agent = ""

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let b = bounds
        // scale factor from the 84x296 design space (aspect ratio is locked,
        // so width/84 == height/296; min() just guards against rounding)
        let s = min(b.width / 84, b.height / 296)
        // housing (rounded)
        NSColor(white: 0.11, alpha: 1).setFill()
        NSBezierPath(roundedRect: b, xRadius: 18 * s, yRadius: 18 * s).fill()
        // the three lamps
        let cx = b.width / 2
        for def in lampDefs {
            let active = (def.key == status)
            let c = NSPoint(x: cx, y: def.y * s)
            NSColor(white: 0.17, alpha: 1).setFill()  // bezel
            NSBezierPath(ovalIn: NSRect(x: c.x - 26 * s, y: c.y - 26 * s, width: 52 * s, height: 52 * s)).fill()
            (active ? def.bright : def.dim).setFill()  // lamp
            NSBezierPath(ovalIn: NSRect(x: c.x - 21 * s, y: c.y - 21 * s, width: 42 * s, height: 42 * s)).fill()
            if active {  // highlight dot
                NSColor.white.withAlphaComponent(0.85).setFill()
                NSBezierPath(ovalIn: NSRect(x: c.x - 9 * s, y: c.y - 13 * s, width: 10 * s, height: 8 * s)).fill()
            }
        }
        // status label
        let name = lampDefs.first(where: { $0.key == status })?.name ?? ""
        let text = agent.isEmpty ? name : "\(name) · \(agent)"
        let fontSize = min(14, max(9, 11 * s))
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize),
            .foregroundColor: NSColor(white: 0.68, alpha: 1),
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        (text as NSString).draw(
            at: NSPoint(x: (b.width - size.width) / 2, y: 264 * s),
            withAttributes: attrs)
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        let reset = NSMenuItem(title: "Reset Size",
                               action: #selector(resetSize),
                               keyEquivalent: "")
        reset.target = self
        menu.addItem(reset)
        menu.addItem(.separator())
        let item = NSMenuItem(title: "Quit",
                              action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "")
        item.target = NSApp
        menu.addItem(item)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
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

let view = LightView(frame: NSRect(x: 0, y: 0, width: 84, height: 296))

let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 84, height: 296),
                    styleMask: [.borderless, .nonactivatingPanel, .resizable],
                    backing: .buffered, defer: false)
panel.contentView = view
panel.level = .floating                       // always on top
panel.isOpaque = false
panel.backgroundColor = .clear                 // transparent rounded corners
panel.hasShadow = true
panel.isMovableByWindowBackground = true       // drag from anywhere
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
