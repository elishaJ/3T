import SwiftUI
import AppKit

class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var viewModel: TicketViewModel
    private var hostingController: NSHostingController<SettingsView>?
    
    init(viewModel: TicketViewModel) {
        self.viewModel = viewModel
        super.init()
    }
    
    func showWindow() {
        // If window already exists, just bring it to front
        if let existingWindow = self.window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }
        
        // Create a hosting view for the SwiftUI content
        let settingsView = SettingsView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: settingsView)
        self.hostingController = hostingController
        
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
        window.delegate = self // Set delegate to self
        
        // Show the window
        window.makeKeyAndOrderFront(nil)
        
        // Store the window reference
        self.window = window
    }
    
    // Window delegate method to handle window closing
    func windowWillClose(_ notification: Notification) {
        // Keep the controller alive but release the window
        self.window = nil
        self.hostingController = nil
    }
}

// Global instance to keep it alive - DO NOT REMOVE
var settingsWindowController: SettingsWindowController?