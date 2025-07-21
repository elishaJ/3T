import Foundation
import SwiftUI
import AppKit

class TicketViewModel: ObservableObject {
    @Published var tickets: [Ticket] = []
    @Published var completedTickets: [Ticket] = []
    @Published var isLoading = false
    @Published var isAuthenticated = false
    @Published var showingCompleted = false
    @Published var projectId: String = ""
    @Published var projectName: String = "Tickets"
    @Published var showingSettings = false
    
    // Function to show settings in a floating window
    func showSettings() {
        settingsWindowController = SettingsWindowController(viewModel: self)
        settingsWindowController?.showWindow()
    }
    
    private var timer: Timer?
    private let asanaService = AsanaService()
    private let storage = TicketStorage.shared
    
    init() {
        loadSavedTickets()
        loadProjectId()
        startTimer()
    }
    
    private func loadProjectId() {
        projectId = storage.loadProjectId() ?? ""
    }
    
    func saveProjectId() {
        // Save the project ID to storage
        storage.saveProjectId(projectId)
        
        // Clear any cached data related to the old project ID
        tickets = []
        completedTickets = []
        projectName = "Tickets"
        
        // Fetch the project name for the new project ID
        fetchProjectName()
    }
    
    func validateProjectId(_ projectId: String, completion: @escaping (Bool) -> Void) {
        asanaService.validateProjectId(projectId, completion: completion)
    }
    
    func fetchProjectName() {
        guard !projectId.isEmpty, isAuthenticated else { return }
        
        asanaService.fetchProjectName(projectId: projectId) { [weak self] name in
            DispatchQueue.main.async {
                if let name = name {
                    self?.projectName = name
                    // Post notification for project name change
                    NotificationCenter.default.post(name: NSNotification.Name("ProjectNameChanged"), object: name)
                }
            }
        }
    }
    
    private func loadSavedTickets() {
        let savedTickets = storage.loadTickets()
        
        // Separate active and completed tickets
        tickets = savedTickets.filter { $0.status != .completed }
        completedTickets = savedTickets.filter { $0.status == .completed }
    }
    
    private func saveTickets() {
        // Save both active and completed tickets
        let allTickets = tickets + completedTickets
        storage.saveTickets(allTickets)
    }
    
    func checkAuthenticationStatus() {
        isAuthenticated = asanaService.isAuthenticated
        if isAuthenticated && !projectId.isEmpty {
            // Fetch the project name
            fetchProjectName()
            // Validate the cookie by trying to fetch tickets
            refreshTickets(silent: true)
        }
    }
    
    func refreshAuthenticationIfNeeded() {
        // If we get an authentication error when fetching tickets,
        // try to refresh the cookie automatically
        asanaService.authenticate { [weak self] success in
            if success {
                self?.isAuthenticated = true
                self?.refreshTickets()
            }
        }
    }
    
    // Keep a strong reference to the auth object
    private var authService: SimpleAuth?
    
    func authenticate() {
        // Create a new auth service and keep a strong reference to it
        let auth = SimpleAuth()
        self.authService = auth
        
        auth.authenticate { [weak self] cookie in
            // Make sure we're on the main thread
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Clear the reference to the auth service
                self.authService = nil
                
                let success = cookie != nil
                self.isAuthenticated = success
                
                if success {
                    // Save the cookie
                    if let cookie = cookie {
                        self.asanaService.saveCookie(cookie)
                    }
                    
                    // Add a delay before refreshing tickets
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        if self.projectId.isEmpty {
                            // If no project ID is set, show settings
                            self.showSettings()
                        } else {
                            // Otherwise refresh tickets
                            self.refreshTickets()
                        }
                        
                        // Post notification that authentication succeeded
                        // This will also make the app window appear
                        AppNotificationCenter.shared.postAuthenticationSuccess()
                    }
                } else {
                    // Show a consistent error message for all authentication issues
                    let alert = NSAlert()
                    alert.messageText = "Authentication Failed"
                    alert.informativeText = "Please make sure you've copied the correct cookie from Asana. Try logging in again and fetching a new cookie."
                    alert.alertStyle = .warning
                    
                    // Run the alert as a floating window
                    alert.runModalAsFloating()
                }
            }
        }
    }
    
    func refreshTickets(forceReset: Bool = false, silent: Bool = false) {
        guard isAuthenticated else { return }
        guard !projectId.isEmpty else { return }
        
        // If forceReset is true, clear all stored tickets
        if forceReset {
            storage.clearAllTickets()
            tickets = []
            completedTickets = []
        }
        
        // Always start with an empty tickets array
        tickets = []
        
        isLoading = true
        asanaService.fetchTickets { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                switch result {
                case .success(let fetchedTickets):
                    print("Fetched \(fetchedTickets.count) tickets from Asana")
                    
                    // If we're doing a force reset, don't load saved tickets
                    let savedTickets = forceReset ? [] : self.storage.loadTickets()
                    
                    // Create new tickets array with only tickets from Asana
                    var newTickets: [Ticket] = []
                    
                    // Process each fetched ticket from Asana
                    for var fetchedTicket in fetchedTickets {
                        // Check if this ticket exists in saved tickets (active or completed)
                        if let existingTicket = savedTickets.first(where: { $0.id == fetchedTicket.id }) {
                            // Preserve time spent and status
                            fetchedTicket.timeSpent = existingTicket.timeSpent
                            
                            // Only apply status if it's not completed
                            if existingTicket.status != .completed {
                                fetchedTicket.status = existingTicket.status
                            } else {
                                // Skip this ticket if it's completed
                                continue
                            }
                        }
                        
                        // Add to new tickets list
                        newTickets.append(fetchedTicket)
                    }
                    
                    // Update active tickets with only those from Asana
                    self.tickets = newTickets
                    
                    // Keep completed tickets as they were (unless we're doing a force reset)
                    if !forceReset {
                        self.completedTickets = savedTickets.filter { $0.status == .completed }
                    }
                    
                    print("Active tickets: \(self.tickets.count), Completed tickets: \(self.completedTickets.count)")
                    
                    // Save the updated tickets
                    self.saveTickets()
                    
                case .failure(let error):
                    print("Error fetching tickets: \(error.localizedDescription)")
                    
                    // Check error type
                    let nsError = error as NSError
                    if nsError.domain == "AsanaService" {
                        if nsError.code == 401 {
                            // Authentication error
                            self.isAuthenticated = false
                            
                            // Only show alert if not in silent mode
                            if !silent {
                                // Show session expired alert with custom buttons
                                let alert = NSAlert()
                                alert.messageText = "Authentication Failed"
                                alert.informativeText = "Please make sure you've copied the correct cookie from Asana. Try logging in again and fetching a new cookie."
                                alert.alertStyle = .warning
                                alert.addButton(withTitle: "Sign In")
                                alert.addButton(withTitle: "Cancel")
                                
                                // Run the alert as a floating window
                                let response = alert.runModalAsFloating()
                                if response == .alertFirstButtonReturn {
                                    self.authenticate()
                                }
                            }
                        } else if nsError.code == 404 {
                            // Project not found error
                            if !silent {
                                let alert = NSAlert()
                                alert.messageText = "Project Not Found"
                                alert.informativeText = "The project ID you entered was not found. Please check your project ID in the settings."
                                alert.alertStyle = .warning
                                alert.addButton(withTitle: "Open Settings")
                                alert.addButton(withTitle: "Cancel")
                                
                                // Run the alert as a floating window
                                let response = alert.runModalAsFloating()
                                if response == .alertFirstButtonReturn {
                                    self.showSettings()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func toggleTracking(for ticket: Ticket) {
        // Check if the ticket is in the completed section
        if let index = completedTickets.firstIndex(where: { $0.id == ticket.id }) {
            // Move back to active tickets
            var updatedTicket = completedTickets[index]
            updatedTicket.status = .active
            tickets.append(updatedTicket)
            completedTickets.remove(at: index)
            saveTickets()
            return
        }
        
        guard let index = tickets.firstIndex(where: { $0.id == ticket.id }) else { return }
        
        // Toggle between active and paused
        if tickets[index].status == .active {
            tickets[index].status = .paused
            print("Paused tracking ticket \(ticket.id) with time spent: \(ticket.formattedTime)")
        } else {
            tickets[index].status = .active
            print("Started tracking ticket \(ticket.id)")
        }
        
        saveTickets()
    }
    
    func completeTicket(for ticket: Ticket) {
        guard let index = tickets.firstIndex(where: { $0.id == ticket.id }) else { return }
        
        var completedTicket = tickets[index]
        completedTicket.status = .completed
        
        // Move to completed section
        completedTickets.append(completedTicket)
        tickets.remove(at: index)
        
        print("Completed ticket \(ticket.id) with time spent: \(ticket.formattedTime)")
        saveTickets()
    }
    
    func toggleCompletedVisibility() {
        showingCompleted.toggle()
    }
    
    func clearAuthentication() {
        asanaService.clearAuthentication()
        isAuthenticated = false
        tickets = []
        completedTickets = []
    }
    
    // For debugging purposes only
    func clearLocalCache() {
        // Clear local ticket cache but keep authentication
        tickets = []
        completedTickets = []
        storage.clearAllTickets()
        print("Local ticket cache cleared")
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            for i in 0..<self.tickets.count {
                if self.tickets[i].status == .active {
                    self.tickets[i].timeSpent += 1
                }
            }
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}