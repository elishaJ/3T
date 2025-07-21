import AppKit

extension NSAlert {
    func runModalAsFloating() -> NSApplication.ModalResponse {
        // Save the current key window
        let keyWindow = NSApplication.shared.keyWindow
        
        // Run the alert modally
        let response = self.runModal()
        
        // Restore the key window
        keyWindow?.makeKeyAndOrderFront(nil)
        
        return response
    }
}