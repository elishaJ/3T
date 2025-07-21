import Foundation
import AppKit

class SimpleAuth: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private var textField: NSTextField?
    private var completion: ((String?) -> Void)?
    
    func authenticate(completion: @escaping (String?) -> Void) {
        self.completion = completion
        
        // First, open Asana in the default browser
        if let url = URL(string: "https://app.asana.com") {
            NSWorkspace.shared.open(url)
        }
        
        // Show dialog with instructions after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showCookieEntryWindow()
        }
    }
    
    private func showCookieEntryWindow() {
        // Create a proper window with standard controls
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Asana Authentication"
        window.center()
        window.delegate = self
        
        // Create the content view
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 300))
        
        // Add instructions label
        let instructionsLabel = NSTextField(frame: NSRect(x: 20, y: 100, width: 460, height: 180))
        instructionsLabel.stringValue = "Please follow these steps:\n\n" +
            "1. Log in to Asana in your browser\n" +
            "2. Once logged in, press F12 to open Developer Tools\n" +
            "3. Go to the Network tab and refresh the page\n" +
            "4. Click on any request to app.asana.com\n" +
            "5. In the Headers tab, find 'Cookie' under Request Headers\n" +
            "6. Copy the cookie value and paste it below"
        instructionsLabel.isEditable = false
        instructionsLabel.isSelectable = true
        instructionsLabel.drawsBackground = false
        instructionsLabel.isBezeled = false
        instructionsLabel.textColor = NSColor.labelColor
        instructionsLabel.font = NSFont.systemFont(ofSize: 12)
        contentView.addSubview(instructionsLabel)
        
        // Add text field for cookie input
        let textField = NSTextField(frame: NSRect(x: 20, y: 70, width: 460, height: 24))
        textField.placeholderString = "Paste cookie value here"
        contentView.addSubview(textField)
        self.textField = textField
        
        // Add buttons
        let okButton = NSButton(frame: NSRect(x: 380, y: 20, width: 100, height: 32))
        okButton.title = "OK"
        okButton.bezelStyle = .rounded
        okButton.target = self
        okButton.action = #selector(okButtonClicked)
        contentView.addSubview(okButton)
        
        let cancelButton = NSButton(frame: NSRect(x: 280, y: 20, width: 100, height: 32))
        cancelButton.title = "Cancel"
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelButtonClicked)
        contentView.addSubview(cancelButton)
        
        window.contentView = contentView
        
        // Store the window reference
        self.window = window
        
        // Show the window and make it stay on top initially
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        
        // After a short delay, change the window level back to normal
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            window.level = .normal
        }
    }
    
    @objc func okButtonClicked() {
        guard let textField = self.textField else { return }
        
        let cookie = textField.stringValue
        
        if cookie.isEmpty {
            // Show error for empty cookie
            let alert = NSAlert()
            alert.messageText = "Empty Cookie"
            alert.informativeText = "Please enter a cookie value."
            alert.alertStyle = .warning
            alert.beginSheetModal(for: window!) { _ in }
            return
        }
        
        if cookie.count < 20 {
            // Show error for short cookie
            let alert = NSAlert()
            alert.messageText = "Cookie Too Short"
            alert.informativeText = "The cookie you entered appears to be too short. Please make sure you've copied the entire cookie value from the Request Headers."
            alert.alertStyle = .warning
            alert.beginSheetModal(for: window!) { _ in }
            return
        }
        
        // Store the completion and cookie locally
        guard let completion = self.completion else { return }
        let localCookie = cookie
        
        // Clear the completion to prevent double-calling
        self.completion = nil
        
        // Hide the window
        window?.orderOut(nil)
        
        // Call completion with the cookie
        DispatchQueue.main.async {
            completion(localCookie)
        }
    }
    
    @objc func cancelButtonClicked() {
        // Store the completion locally
        guard let completion = self.completion else { return }
        
        // Clear the completion to prevent double-calling
        self.completion = nil
        
        // Hide the window
        window?.orderOut(nil)
        
        // Call completion with nil
        DispatchQueue.main.async {
            completion(nil)
        }
    }
    
    func windowWillClose(_ notification: Notification) {
        // Only call completion if it hasn't been called from a button click
        if let completion = self.completion {
            // Store the completion locally to avoid race conditions
            let localCompletion = completion
            self.completion = nil
            
            // Call completion with nil after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                localCompletion(nil)
            }
        }
    }
}