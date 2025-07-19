import Foundation
import AppKit

class AsanaService: NSObject {
    private let baseURL = "https://app.asana.com/api/1.0"
    
    private let storage = TicketStorage.shared
    
    // Store the cookie value
    private var cookieValue: String {
        get { storage.loadCookie() ?? "" }
        set { storage.saveCookie(newValue) }
    }
    
    var isAuthenticated: Bool {
        return !cookieValue.isEmpty
    }
    
    func clearAuthentication() {
        storage.clearCookie()
        // Force reload the cookie value
        cookieValue = ""
    }
    
    func authenticate(completion: @escaping (Bool) -> Void) {
        // Use simple authentication
        let auth = SimpleAuth()
        auth.authenticate { [weak self] cookie in
            if let cookie = cookie, !cookie.isEmpty {
                self?.cookieValue = cookie
                completion(true)
            } else {
                completion(false)
            }
        }
    }
    
    func fetchTickets(completion: @escaping (Result<[Ticket], Error>) -> Void) {
        guard isAuthenticated else {
            completion(.failure(NSError(domain: "AsanaService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])))
            return
        }
        
        // You'll need to replace this with your actual project ID
        let projectId = "1210715168742653"
        
        // Add query parameters to filter for in-progress tasks
        // We'll use the section name to filter and ensure we're only getting tasks from this project
        let endpoint = "\(baseURL)/projects/\(projectId)/tasks?opt_fields=name,gid,completed,memberships.section.name,memberships.project.gid"
        
        guard let url = URL(string: endpoint) else {
            completion(.failure(NSError(domain: "AsanaService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        print("Fetching tickets from Asana: \(endpoint)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(cookieValue, forHTTPHeaderField: "Cookie")
        
        // Add common headers that might help with authentication
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        
        // Disable cache to ensure fresh results
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "AsanaService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                // Parse the JSON response
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let data = json["data"] as? [[String: Any]] {
                    
                    print("Received \(data.count) tasks from Asana API")
                    
                    let tickets = data.compactMap { taskData -> Ticket? in
                        guard let id = taskData["gid"] as? String,
                              let name = taskData["name"] as? String,
                              let completed = taskData["completed"] as? Bool,
                              !completed else {
                            return nil
                        }
                        
                        // Check if the task is in the "In Progress" section of THIS project
                        var isInProgress = false
                        if let memberships = taskData["memberships"] as? [[String: Any]] {
                            for membership in memberships {
                                // First check if this membership is for the current project
                                if let project = membership["project"] as? [String: Any],
                                   let projectGid = project["gid"] as? String,
                                   projectGid == projectId,
                                   let section = membership["section"] as? [String: Any],
                                   let sectionName = section["name"] as? String {
                                    print("Task \(name) (\(id)) is in section: \(sectionName) of project \(projectId)")
                                    if sectionName.lowercased().contains("in progress") {
                                        isInProgress = true
                                        break
                                    }
                                }
                            }
                        }
                        
                        // Only return tasks that are in the "In Progress" section
                        guard isInProgress else {
                            print("Skipping task \(name) (\(id)) - not in 'In Progress' section")
                            return nil
                        }
                        
                        print("Adding task \(name) (\(id)) - in 'In Progress' section")
                        return Ticket(id: id, name: name)
                    }
                    
                    print("Filtered to \(tickets.count) 'In Progress' tickets")
                    completion(.success(tickets))
                } else {
                    completion(.failure(NSError(domain: "AsanaService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}