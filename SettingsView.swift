import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var viewModel: TicketViewModel
    @State private var tempProjectId: String = ""
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    
    @Environment(\.presentationMode) var presentationMode
    
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
                    .onChange(of: tempProjectId) { _ in
                        // Clear error when user types
                        showError = false
                    }
                
                if showError {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 4)
                }
                
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
                                        // Show error in the view
                                        errorMessage = "🚫 Project ID not found. Please review the instructions and try again."
                                        showError = true
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
                        // Show error in the view
                        errorMessage = "🚫 Project ID should contain only numbers. Please try again."
                        showError = true
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