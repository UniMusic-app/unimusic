import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate, NSMenuItemValidation {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  @IBAction func toggleFloatOnTop(_ sender: Any?) {
      guard let window = NSApp.windows.first else { return }
      window.level = window.level == .floating ? .normal : .floating
  }

  func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
      // If this is the Float on Top menu item, update its state to reflect current window level
      if menuItem.action == #selector(toggleFloatOnTop(_:)) {
          if let window = NSApp.windows.first {
              menuItem.state = (window.level == .floating) ? .on : .off
          } else {
              return false
          }
      }
      return true
  }
}
