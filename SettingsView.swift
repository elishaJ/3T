import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: TicketViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var tempProjectId: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Asana Project ID")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("Enter Asana Project ID", text: $tempProjectId)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text("You can find your project ID in the URL when viewing the project in Asana (e.g., https://app.asana.com/0/123456789/list - where 123456789 is the project ID)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Save") {
                    // Validate project ID format (should be numeric)
                    if !tempProjectId.trimmingCharacters(in: .whitespaces).isEmpty && tempProjectId.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil {
                        // Validate project ID against accessible projects
                        if viewModel.isAuthenticated {
                            viewModel.validateProjectId(tempProjectId) { isValid in
                                if isValid {
                                    DispatchQueue.main.async {
                                        viewModel.projectId = tempProjectId
                                        viewModel.saveProjectId()
                                        presentationMode.wrappedValue.dismiss()
                                        
                                        // Refresh tickets after a short delay
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            viewModel.refreshTickets()
                                            // Show the popover
                                            AppNotificationCenter.shared.postAuthenticationSuccess()
                                        }
                                    }
                                } else {
                                    DispatchQueue.main.async {
                                        // Show error for invalid project ID
                                        let alert = NSAlert()
                                        alert.messageText = "Project Not Found"
                                        alert.informativeText = "The project ID you entered was not found in your accessible projects. Please check the ID and try again."
                                        alert.alertStyle = .warning
                                        alert.runModal()
                                    }
                                }
                            }
                        } else {
                            // Not authenticated, just save the ID without validation
                            viewModel.projectId = tempProjectId
                            viewModel.saveProjectId()
                            presentationMode.wrappedValue.dismiss()
                        }
                    } else {
                        // Show error for invalid project ID format
                        let alert = NSAlert()
                        alert.messageText = "Invalid Project ID Format"
                        alert.informativeText = "Project ID should contain only numbers. Please check the ID and try again."
                        alert.alertStyle = .warning
                        alert.runModal()
                    }
                }
                .keyboardShortcut(.return)
                .disabled(tempProjectId.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 250)
        .onAppear {
            tempProjectId = viewModel.projectId
        }
    }
}