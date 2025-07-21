import SwiftUI

@main
struct TicketTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!
    var popover: NSPopover!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        
        // Register for authentication success notification
        AppNotificationCenter.shared.addAuthenticationSuccessObserver(self, selector: #selector(showPopoverAfterAuth))
        
        // Register for project name changes
        NotificationCenter.default.addObserver(self, selector: #selector(updateWindowTitle), name: NSNotification.Name("ProjectNameChanged"), object: nil)
    }
    
    @objc func showPopoverAfterAuth() {
        // Show the popover after a short delay to ensure everything is loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            if let button = self?.statusBarItem.button, let popover = self?.popover, !popover.isShown {
                // Position the popover below the menu bar item
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                
                // Make the window key but don't center it
                if let window = popover.contentViewController?.view.window {
                    window.makeKey()
                }
            }
        }
    }
    
    func setupMenuBar() {
        // Create the popover for our content
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ContentView())
        popover.contentViewController?.title = "Ticket Tracker"
        self.popover = popover
        
        // Create the status bar item
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusBarItem.button {
            button.image = NSImage(systemSymbolName: "ticket", accessibilityDescription: "Ticket Tracker")
            button.action = #selector(togglePopover)
        }
    }
    
    @objc func togglePopover() {
        if let button = statusBarItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
    
    @objc func updateWindowTitle(notification: Notification) {
        if let projectName = notification.object as? String {
            popover.contentViewController?.title = projectName
        }
    }
}