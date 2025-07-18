import Foundation
import AppKit

class SimpleAuth {
    func authenticate(completion: @escaping (String?) -> Void) {
        // First, open Asana in the default browser
        if let url = URL(string: "https://app.asana.com") {
            NSWorkspace.shared.open(url)
        }
        
        // Show dialog with instructions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showCookieEntryDialog(completion: completion)
        }
    }
    
    private func showCookieEntryDialog(completion: @escaping (String?) -> Void) {
        let alert = NSAlert()
        
        alert.messageText = "Asana Authentication"
        alert.informativeText = "Please follow these steps:\n\n" +
            "1. Log in to Asana in your browser\n" +
            "2. Once logged in, press F12 to open Developer Tools\n" +
            "3. Go to the Network tab\n" +
            "4. Refresh the page (F5)\n" +
            "5. Click on any request to app.asana.com\n" +
            "6. In the Headers tab, find 'Cookie' under Request Headers\n" +
            "7. Right-click on the cookie value and select 'Copy Value'\n" +
            "8. Paste it below"
        
        // Create text field for cookie input
        let inputTextField = NSTextField(frame: NSRect(x: 0, y: 0, width: 400, height: 24))
        inputTextField.placeholderString = "Paste cookie value here"
        
        alert.accessoryView = inputTextField
        
        // Add buttons
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Open Browser Again")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn && !inputTextField.stringValue.isEmpty {
            // User clicked OK and provided a cookie
            completion(inputTextField.stringValue)
        } else if response == .alertThirdButtonReturn {
            // User clicked "Open Browser Again"
            if let url = URL(string: "https://app.asana.com") {
                NSWorkspace.shared.open(url)
            }
            // Show the dialog again after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showCookieEntryDialog(completion: completion)
            }
        } else {
            // User clicked Cancel or closed the dialog
            completion(nil)
        }
    }
}