import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TicketViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 4) {
                    Text("⏱️")
                    Text("Ticket Tracker")
                        .font(.headline)
                }
                    .contextMenu {
                        Button("Quit") {
                            confirmQuit()
                        }
                    }
                Spacer()
                
                // Settings button is always visible
                Button(action: {
                    viewModel.showingSettings = true
                }) {
                    Image(systemName: "gear")
                }
                .buttonStyle(BorderlessButtonStyle())
                .help("Settings")
                
                // Only show these buttons when authenticated
                if viewModel.isAuthenticated {
                    Button(action: {
                        confirmClearAuthentication()
                    }) {
                        Image(systemName: "person.crop.circle.badge.xmark")
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help("Clear authentication")
                    
                    Button(action: {
                        viewModel.toggleCompletedVisibility()
                    }) {
                        Image(systemName: viewModel.showingCompleted ? "eye.slash" : "eye")
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help(viewModel.showingCompleted ? "Hide completed tickets" : "Show completed tickets")
                    
                    Button(action: {
                        // Option-click to force reset
                        let forceReset = NSEvent.modifierFlags.contains(.option)
                        viewModel.refreshTickets(forceReset: forceReset)
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help("Refresh tickets (Option-click to force reset)")
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            .contextMenu {
                Button("Quit") {
                    confirmQuit()
                }
            }
            
            Divider()
            
            if viewModel.isLoading {
                ProgressView("Loading tickets...")
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !viewModel.isAuthenticated {
                VStack(spacing: 16) {
                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("Connect to Asana")
                        .font(.headline)
                    
                    Text("Sign in to track time on your Asana tickets")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Sign In") {
                        viewModel.authenticate()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 8)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.tickets.isEmpty {
                VStack {
                    if viewModel.projectId.isEmpty {
                        Text("No project ID configured")
                            .foregroundColor(.secondary)
                        Button("Configure Project ID") {
                            viewModel.showingSettings = true
                        }
                        .padding(.top)
                    } else {
                        VStack(spacing: 8) {
                            Text("No tickets found")
                                .foregroundColor(.secondary)
                            Text("Make sure you have tickets in the 'In Progress' section of your Asana project")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Refresh Tickets") {
                                viewModel.refreshTickets()
                            }
                            .padding(.top)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section(header: VStack(alignment: .leading, spacing: 6) {
                        if !viewModel.projectName.isEmpty && viewModel.projectName != "Tickets" {
                            Text(viewModel.projectName)
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                        
                        HStack {
                            Text("Active Tickets")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(getCurrentDateString())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }) {
                        if viewModel.tickets.isEmpty {
                            Text("No active tickets")
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            ForEach(viewModel.tickets) { ticket in
                                TicketRow(ticket: ticket, viewModel: viewModel)
                            }
                        }
                    }
                    
                    if viewModel.showingCompleted && !viewModel.completedTickets.isEmpty {
                        Section(header: Text("Completed Tickets")
                            .font(.subheadline)
                            .foregroundColor(.secondary)) {
                            ForEach(viewModel.completedTickets) { ticket in
                                CompletedTicketRow(ticket: ticket, viewModel: viewModel)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 320, height: 400)
        .sheet(isPresented: $viewModel.showingSettings) {
            SettingsView(viewModel: viewModel)
        }
        .onAppear {
            viewModel.checkAuthenticationStatus()
        }
    }
    
    // Helper function to get current date string
    private func getCurrentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }
    
    // Show confirmation dialog before clearing authentication
    private func confirmClearAuthentication() {
        let alert = NSAlert()
        alert.messageText = "Clear Cookie?"
        alert.informativeText = "This will log you out of Asana. You'll need to log in again to see your tickets."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            viewModel.clearAuthentication()
        }
    }
    
    // Show confirmation dialog before quitting
    private func confirmQuit() {
        let alert = NSAlert()
        alert.messageText = "Quit Ticket Tracker?"
        alert.informativeText = "Are you sure you want to quit? Any active time tracking will be saved."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSApplication.shared.terminate(nil)
        }
    }
    

}

struct TicketRow: View {
    let ticket: Ticket
    @ObservedObject var viewModel: TicketViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(ticket.name)
                .fontWeight(.medium)
                .lineLimit(1)
            
            HStack {
                // Always show time spent if it's not zero
                if ticket.timeSpent > 0 || ticket.status != .notStarted {
                    Text("Time: \(ticket.formattedTime)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Not started")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Show different buttons based on status
                switch ticket.status {
                case .notStarted:
                    Button(action: {
                        viewModel.toggleTracking(for: ticket)
                    }) {
                        Text("Start")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help("Start tracking this ticket")
                    
                case .active:
                    HStack(spacing: 4) {
                        Button(action: {
                            viewModel.toggleTracking(for: ticket)
                        }) {
                            Text("Pause")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .help("Pause tracking this ticket")
                        
                        Button(action: {
                            viewModel.completeTicket(for: ticket)
                        }) {
                            Text("Complete")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .help("Mark this ticket as completed")
                    }
                    
                case .paused:
                    HStack(spacing: 4) {
                        Button(action: {
                            viewModel.toggleTracking(for: ticket)
                        }) {
                            Text("Resume")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .help("Resume tracking this ticket")
                        
                        Button(action: {
                            viewModel.completeTicket(for: ticket)
                        }) {
                            Text("Complete")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .help("Mark this ticket as completed")
                    }
                    
                case .completed:
                    Text("Completed")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}