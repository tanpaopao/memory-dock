import AppKit

let application = NSApplication.shared

MainActor.assumeIsolated {
    let appDelegate = AppDelegate()
    application.delegate = appDelegate
    application.setActivationPolicy(.accessory)
    application.run()
}
