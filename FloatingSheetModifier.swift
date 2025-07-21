import SwiftUI
import AppKit

// A view modifier that makes a sheet appear as a floating window
struct FloatingSheetModifier: ViewModifier {
    @Binding var isPresented: Bool
    let content: () -> AnyView
    
    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { show in
                if show {
                    DispatchQueue.main.async {
                        // Find the sheet window and make it float
                        if let window = NSApplication.shared.windows.first(where: { $0.title == "Settings" }) {
                            window.level = .floating
                        }
                    }
                }
            }
    }
}

extension View {
    func floatingSheet<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        self.modifier(FloatingSheetModifier(isPresented: isPresented, content: { AnyView(content()) }))
            .sheet(isPresented: isPresented) {
                content()
            }
    }
}