import SwiftUI
import AppKit

class SettingsWindowController {
    private var window: NSWindow?
    private var viewModel: TicketViewModel
    
    init(viewModel: TicketViewModel) {
        self.viewModel = viewModel
    }
    
    func showWindow() {
        // Create a hosting view for the SwiftUI content
        let settingsView = SettingsView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: settingsView)
        
        // Create a window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 250),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        // Configure the window
        window.title = "Settings"
        window.contentViewController = hostingController
        window.center()
        window.level = .floating // Make it stay on top
        
        // Show the window
        window.makeKeyAndOrderFront(nil)
        
        // Store the window reference
        self.window = window
    }
}

// Global instance to keep it alive
var settingsWindowController: SettingsWindowController?