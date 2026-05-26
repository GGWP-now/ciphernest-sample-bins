import Cocoa
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private let input = NSTextField(string: "matrix-safe")
    private let output = NSTextField(labelWithString: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let frame = NSRect(x: 0, y: 0, width: 460, height: 190)
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "macOS UI Victim"
        window.center()

        let content = NSView(frame: frame)
        let title = NSTextField(labelWithString: "macOS UI Victim")
        title.font = .boldSystemFont(ofSize: 18)
        title.frame = NSRect(x: 20, y: 135, width: 300, height: 24)

        input.frame = NSRect(x: 20, y: 92, width: 300, height: 24)
        let button = NSButton(title: "Hash", target: self, action: #selector(updateOutput))
        button.frame = NSRect(x: 335, y: 89, width: 90, height: 30)

        output.frame = NSRect(x: 20, y: 50, width: 405, height: 24)

        content.addSubview(title)
        content.addSubview(input)
        content.addSubview(button)
        content.addSubview(output)
        window.contentView = content
        window.makeKeyAndOrderFront(nil)
        self.window = window
        updateOutput()
    }

    @objc private func updateOutput() {
        let hash = input.stringValue.unicodeScalars.reduce(UInt64(0xcbf29ce484222325)) { partial, scalar in
            (partial ^ UInt64(scalar.value)) &* UInt64(0x100000001b3)
        }
        output.stringValue = String(format: "%@ -> 0x%016llX", input.stringValue, hash)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
