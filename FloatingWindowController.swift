import SwiftUI
import AppKit

class FloatingWindowController<Content: View>: NSWindowController {
    convenience init(rootView: Content, title: String, width: CGFloat, height: CGFloat) {
        // Create a hosting view for the SwiftUI content
        let hostingController = NSHostingController(rootView: rootView)
        
        // Create a window with standard controls
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        // Configure the window
        window.title = title
        window.contentViewController = hostingController
        window.center()
        window.level = .floating // Make it stay on top
        
        // Initialize with the window
        self.init(window: window)
    }
    
    func showWindow() {
        self.showWindow(nil)
        self.window?.makeKeyAndOrderFront(nil)
    }
}