import AppKit

extension NSAlert {
    // Run the alert as a floating window that stays on top
    func runModalAsFloating() -> NSApplication.ModalResponse {
        // Make sure the alert window is on top
        self.window.level = .floating
        
        // Run the alert modally
        return self.runModal()
    }
}