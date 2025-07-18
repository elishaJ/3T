import Foundation

struct TicketData: Codable {
    let id: String
    let name: String
    let status: String
    let timeSpent: TimeInterval
    
    init(from ticket: Ticket) {
        self.id = ticket.id
        self.name = ticket.name
        self.status = ticket.status.rawValue
        self.timeSpent = ticket.timeSpent
    }
    
    func toTicket() -> Ticket {
        var ticket = Ticket(id: id, name: name)
        ticket.timeSpent = timeSpent
        if let status = Ticket.TrackingStatus(rawValue: status) {
            ticket.status = status
        }
        return ticket
    }
}

class TicketStorage {
    static let shared = TicketStorage()
    
    private let userDefaults = UserDefaults.standard
    private let ticketsKey = "savedTickets"
    private let cookieKey = "asanaCookie"
    
    func saveTickets(_ tickets: [Ticket]) {
        let ticketData = tickets.map { TicketData(from: $0) }
        if let encoded = try? JSONEncoder().encode(ticketData) {
            userDefaults.set(encoded, forKey: ticketsKey)
        }
    }
    
    func loadTickets() -> [Ticket] {
        guard let data = userDefaults.data(forKey: ticketsKey),
              let ticketData = try? JSONDecoder().decode([TicketData].self, from: data) else {
            return []
        }
        
        return ticketData.map { $0.toTicket() }
    }
    
    func saveCookie(_ cookie: String) {
        userDefaults.set(cookie, forKey: cookieKey)
    }
    
    func loadCookie() -> String? {
        return userDefaults.string(forKey: cookieKey)
    }
    
    func clearCookie() {
        userDefaults.removeObject(forKey: cookieKey)
    }
}