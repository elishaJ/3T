import Foundation
import SwiftUI

class TicketViewModel: ObservableObject {
    @Published var tickets: [Ticket] = []
    @Published var completedTickets: [Ticket] = []
    @Published var isLoading = false
    @Published var isAuthenticated = false
    @Published var showingCompleted = false
    
    private var timer: Timer?
    private let asanaService = AsanaService()
    private let storage = TicketStorage.shared
    
    init() {
        loadSavedTickets()
        startTimer()
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
        if isAuthenticated {
            // Validate the cookie by trying to fetch tickets
            refreshTickets()
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
    
    func authenticate() {
        asanaService.authenticate { [weak self] success in
            DispatchQueue.main.async {
                self?.isAuthenticated = success
                if success {
                    self?.refreshTickets()
                    // Post notification that authentication succeeded
                    AppNotificationCenter.shared.postAuthenticationSuccess()
                }
            }
        }
    }
    
    func refreshTickets(forceReset: Bool = false) {
        guard isAuthenticated else { return }
        
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
                    
                    // Check if it's an authentication error
                    if (error as NSError).domain == "AsanaService" && (error as NSError).code == 401 {
                        // Try to refresh authentication
                        self.isAuthenticated = false
                        self.refreshAuthenticationIfNeeded()
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