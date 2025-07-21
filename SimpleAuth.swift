import Foundation
import AppKit

class SimpleAuth: NSObject, NSWindowDelegate {
    // Flag to track if validation is in progress
    private var isValidating = false
    private var window: NSWindow?
    private var textField: NSTextField?
    private var errorLabel: NSTextField?
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
        
        // Add error label (hidden by default)
        let errorLabel = NSTextField(frame: NSRect(x: 20, y: 40, width: 460, height: 30))
        errorLabel.isEditable = false
        errorLabel.isSelectable = false
        errorLabel.drawsBackground = false
        errorLabel.isBezeled = false
        errorLabel.textColor = NSColor.systemRed
        errorLabel.font = NSFont.systemFont(ofSize: 11)
        errorLabel.cell?.wraps = true
        errorLabel.cell?.lineBreakMode = .byWordWrapping
        errorLabel.stringValue = ""
        errorLabel.isHidden = true
        contentView.addSubview(errorLabel)
        self.errorLabel = errorLabel
        
        // Add buttons
        let okButton = NSButton(frame: NSRect(x: 380, y: 10, width: 100, height: 32))
        okButton.title = "OK"
        okButton.bezelStyle = .rounded
        okButton.target = self
        okButton.action = #selector(okButtonClicked)
        contentView.addSubview(okButton)
        
        let cancelButton = NSButton(frame: NSRect(x: 280, y: 10, width: 100, height: 32))
        cancelButton.title = "Cancel"
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelButtonClicked)
        contentView.addSubview(cancelButton)
        
        window.contentView = contentView
        
        // Store the window reference
        self.window = window
        
        // Show the window and make it stay on top
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
    }
    
    @objc func okButtonClicked() {
        guard let textField = self.textField else { return }
        
        let cookie = textField.stringValue
        
        if cookie.isEmpty {
            // Show error for empty cookie
            showError("Please enter a cookie value.")
            return
        }
        
        if cookie.count < 20 {
            // Show error for short cookie
            showError("The cookie you entered appears to be too short. Please make sure you've copied the entire cookie value from the Request Headers.")
            return
        }
        
        // Show validating message
        showError("Validating cookie...", isError: false)
        
        // Store the completion and cookie locally
        guard let completion = self.completion else { return }
        let localCookie = cookie
        
        // Validate the cookie
        validateCookie(cookie) { [weak self] isValid in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if isValid {
                    // Cookie is valid
                    // Clear the completion to prevent double-calling
                    self.completion = nil
                    
                    // Hide the window
                    self.window?.orderOut(nil)
                    
                    // Call completion with the cookie
                    completion(localCookie)
                } else {
                    // Cookie is invalid, show error
                    self.showError("The cookie appears to be invalid. Please review the instructions above and try again.")
                }
            }
        }
    }
    
    private func showError(_ message: String, isError: Bool = true) {
        guard let errorLabel = self.errorLabel else { return }
        
        // Show the error message
        errorLabel.stringValue = isError ? "🚫 " + message : message
        errorLabel.isHidden = false
        errorLabel.textColor = isError ? NSColor.systemRed : NSColor.systemBlue
        
        // Add a text field action to clear the error when typing
        textField?.action = #selector(textFieldChanged)
        textField?.target = self
    }
    
    @objc func textFieldChanged() {
        // Clear the error when the user types (but not during validation)
        if !isValidating {
            errorLabel?.isHidden = true
        }
    }
    
    private func validateCookie(_ cookie: String, completion: @escaping (Bool) -> Void) {
        // Set validation flag
        isValidating = true
        
        // Create a simple request to validate the cookie
        let endpoint = "https://app.asana.com/api/1.0/users/me"
        
        guard let url = URL(string: endpoint) else {
            isValidating = false
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(cookie, forHTTPHeaderField: "Cookie")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            // Reset validation flag
            self?.isValidating = false
            
            // Check if we got a successful response
            if let httpResponse = response as? HTTPURLResponse, 
               httpResponse.statusCode == 200,
               let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let userData = json["data"] as? [String: Any],
               userData["gid"] != nil {
                completion(true)
            } else {
                completion(false)
            }
        }.resume()
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