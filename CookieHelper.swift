import Foundation
import AppKit

class CookieHelper {
    static func showCookieExtractionGuide() {
        let browserName = CookieExtractor.getDefaultBrowser()?.name ?? "your browser"
        
        let alert = NSAlert()
        alert.messageText = "How to Extract Asana Cookies"
        alert.informativeText = "Follow these steps to extract cookies from \(browserName):"
        
        // Create a text view for detailed instructions with images
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 500, height: 300))
        textView.isEditable = false
        
        // Add instructions with formatting
        let instructions = """
        1. Open Asana in \(browserName) and make sure you're logged in
        
        2. Open Developer Tools:
           - Chrome: Press F12 or Cmd+Option+I
           - Firefox: Press F12 or Cmd+Option+I
        
        3. Go to the Network tab in Developer Tools
        
        4. Refresh the page (F5 or Cmd+R)
        
        5. Look for any request to app.asana.com in the list
        
        6. Click on one of the requests to see details
        
        7. In the Headers tab, scroll down to find the "Cookie:" header
        
        8. Right-click on the cookie value and select "Copy Value"
        
        9. Paste the copied cookie into the authentication dialog
        """
        
        textView.string = instructions
        
        // Add scrolling if needed
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 500, height: 300))
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        
        alert.accessoryView = scrollView
        
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    static func openAsanaAndShowGuide() {
        // Open Asana in the default browser
        if let url = URL(string: "https://app.asana.com") {
            NSWorkspace.shared.open(url)
        }
        
        // Show the guide after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showCookieExtractionGuide()
        }
    }
}