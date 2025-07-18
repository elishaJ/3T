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
    
    func refreshTickets() {
        guard isAuthenticated else { return }
        
        isLoading = true
        asanaService.fetchTickets { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let fetchedTickets):
                    // Preserve tracking state for existing tickets
                    var updatedTickets = fetchedTickets
                    
                    // Check both active and completed tickets for existing data
                    for i in 0..<updatedTickets.count {
                        // Check active tickets
                        if let existingTicket = self?.tickets.first(where: { $0.id == updatedTickets[i].id }) {
                            updatedTickets[i].status = existingTicket.status
                            updatedTickets[i].timeSpent = existingTicket.timeSpent
                        } 
                        // Check completed tickets
                        else if let completedTicket = self?.completedTickets.first(where: { $0.id == updatedTickets[i].id }) {
                            // If it's in completed list, don't add it to active tickets
                            updatedTickets[i].status = .completed
                            updatedTickets[i].timeSpent = completedTicket.timeSpent
                        }
                    }
                    
                    // Filter out tickets that are already in completed section
                    let activeTickets = updatedTickets.filter { ticket in
                        !self!.completedTickets.contains(where: { $0.id == ticket.id })
                    }
                    
                    self?.tickets = activeTickets
                    self?.saveTickets()
                case .failure(let error):
                    print("Error fetching tickets: \(error.localizedDescription)")
                    
                    // Check if it's an authentication error
                    if (error as NSError).domain == "AsanaService" && (error as NSError).code == 401 {
                        // Try to refresh authentication
                        self?.isAuthenticated = false
                        self?.refreshAuthenticationIfNeeded()
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