import SwiftUI
import AppKit
import Combine

// MARK: - State

enum LightState: String {
    case red, yellow, green
}

class TrafficLightStateManager: ObservableObject {
    @Published var currentState: LightState = .green

    private let stateFilePath = "/tmp/claude-traffic-light/state.json"
    private let stateDirPath = "/tmp/claude-traffic-light"
    private var fileDescriptor: Int32 = -1
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var dirDispatchSource: DispatchSourceFileSystemObject?

    init() {
        ensureStateDirectory()
        readCurrentState()
        startMonitoring()
    }

    private func ensureStateDirectory() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: stateDirPath) {
            try? fm.createDirectory(atPath: stateDirPath, withIntermediateDirectories: true)
        }
    }

    private func readCurrentState() {
        guard let data = FileManager.default.contents(atPath: stateFilePath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let stateStr = json["state"] as? String,
              let state = LightState(rawValue: stateStr) else {
            return
        }
        DispatchQueue.main.async {
            self.currentState = state
        }
    }

    private func startMonitoring() {
        startFileMonitoring()
        startDirectoryMonitoring()
    }

    private func startFileMonitoring() {
        stopFileMonitoring()

        fileDescriptor = open(stateFilePath, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue.global(qos: .userInitiated)
        )

        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            let flags = source.data
            if flags.contains(.delete) || flags.contains(.rename) {
                self.stopFileMonitoring()
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                    self.startFileMonitoring()
                    self.readCurrentState()
                }
            } else {
                self.readCurrentState()
            }
        }

        source.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }

        source.resume()
        dispatchSource = source
    }

    private func startDirectoryMonitoring() {
        let dirFd = open(stateDirPath, O_EVTONLY)
        guard dirFd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: dirFd,
            eventMask: [.write],
            queue: DispatchQueue.global(qos: .userInitiated)
        )

        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            if FileManager.default.fileExists(atPath: self.stateFilePath) && self.fileDescriptor < 0 {
                self.startFileMonitoring()
                self.readCurrentState()
            }
        }

        source.setCancelHandler {
            close(dirFd)
        }

        source.resume()
        dirDispatchSource = source
    }

    private func stopFileMonitoring() {
        dispatchSource?.cancel()
        dispatchSource = nil
    }
}

// MARK: - View

struct TrafficLightView: View {
    @ObservedObject var stateManager: TrafficLightStateManager
    @State private var yellowOpacity: Double = 1.0

    var body: some View {
        VStack(spacing: 8) {
            lightCircle(
                isActive: stateManager.currentState == .red,
                activeColor: Color(red: 1.0, green: 0.231, blue: 0.188),
                glowColor: Color.red
            )
            lightCircle(
                isActive: stateManager.currentState == .yellow,
                activeColor: Color(red: 1.0, green: 0.8, blue: 0.0),
                glowColor: Color.yellow
            )
            .opacity(stateManager.currentState == .yellow ? yellowOpacity : 1.0)
            lightCircle(
                isActive: stateManager.currentState == .green,
                activeColor: Color(red: 0.204, green: 0.78, blue: 0.349),
                glowColor: Color.green
            )
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.176, green: 0.176, blue: 0.176))
        )
        .onChange(of: stateManager.currentState) {
            updateYellowAnimation()
        }
        .onAppear {
            updateYellowAnimation()
        }
    }

    private func updateYellowAnimation() {
        if stateManager.currentState == .yellow {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                yellowOpacity = 0.2
            }
        } else {
            withAnimation(.default) {
                yellowOpacity = 1.0
            }
        }
    }

    private func lightCircle(isActive: Bool, activeColor: Color, glowColor: Color) -> some View {
        Circle()
            .fill(isActive ? activeColor : Color(red: 0.227, green: 0.227, blue: 0.227))
            .frame(width: 30, height: 30)
            .shadow(color: isActive ? glowColor.opacity(0.8) : Color.clear, radius: isActive ? 8 : 0)
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NSPanel!
    private var statusItem: NSStatusItem!
    private var stateManager: TrafficLightStateManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        stateManager = TrafficLightStateManager()
        setupPanel()
        setupMenuBar()
    }

    private func setupPanel() {
        let contentView = TrafficLightView(stateManager: stateManager)

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 50, height: 140),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.contentView = NSHostingView(rootView: contentView)
        panel.contentView?.wantsLayer = true

        restoreWindowPosition()
        panel.orderFront(nil)
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Claude Traffic Light")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit Claude Traffic Light", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func quitApp() {
        saveWindowPosition()
        NSApp.terminate(nil)
    }

    private func saveWindowPosition() {
        guard let frame = panel?.frame else { return }
        UserDefaults.standard.set(frame.origin.x, forKey: "windowX")
        UserDefaults.standard.set(frame.origin.y, forKey: "windowY")
    }

    private func restoreWindowPosition() {
        let x = UserDefaults.standard.double(forKey: "windowX")
        let y = UserDefaults.standard.double(forKey: "windowY")
        if x != 0 || y != 0 {
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            panel.center()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        saveWindowPosition()
    }
}

// MARK: - Main

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
