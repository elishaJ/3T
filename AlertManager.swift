import SwiftUI
import AppKit

class AlertManager {
    static let shared = AlertManager()
    
    // Keep strong references to prevent deallocation
    private var activeAlerts: [NSAlert] = []
    private var activeWindows: [NSWindow] = []
    
    private init() {}
    
    func showAlert(title: String, message: String, buttonTitle: String = "OK", style: NSAlert.Style = .informational, completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            // Use a simpler approach - just run the alert modally
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = style
            alert.addButton(withTitle: buttonTitle)
            
            // Keep a reference to the alert
            self.activeAlerts.append(alert)
            
            // Run the alert modally
            let response = alert.runModal()
            
            // Remove the reference
            if let index = self.activeAlerts.firstIndex(where: { $0 === alert }) {
                self.activeAlerts.remove(at: index)
            }
            
            // Call completion handler
            if response == .alertFirstButtonReturn {
                completion?()
            }
        }
    }
    
    func showConfirmAlert(title: String, message: String, confirmButton: String = "OK", cancelButton: String = "Cancel", style: NSAlert.Style = .warning, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            // Use a simpler approach - just run the alert modally
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = style
            alert.addButton(withTitle: confirmButton)
            alert.addButton(withTitle: cancelButton)
            
            // Keep a reference to the alert
            self.activeAlerts.append(alert)
            
            // Run the alert modally
            let response = alert.runModal()
            
            // Remove the reference
            if let index = self.activeAlerts.firstIndex(where: { $0 === alert }) {
                self.activeAlerts.remove(at: index)
            }
            
            // Call completion handler with result
            completion(response == .alertFirstButtonReturn)
        }
    }
}