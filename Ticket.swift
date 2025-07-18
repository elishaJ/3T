import Foundation

struct Ticket: Identifiable {
    let id: String
    let name: String
    var status: TrackingStatus = .notStarted
    var timeSpent: TimeInterval = 0
    
    enum TrackingStatus: String {
        case notStarted = "Not Started"
        case active = "Active"
        case paused = "Paused"
        case completed = "Completed"
    }
    
    var isTracking: Bool {
        return status == .active
    }
    
    var formattedTime: String {
        let hours = Int(timeSpent) / 3600
        let minutes = (Int(timeSpent) % 3600) / 60
        let seconds = Int(timeSpent) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}