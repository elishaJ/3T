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
    
    // Store the project name
    private(set) var projectName: String = "Tickets"
    
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
                
                // Validate the cookie by making a test request
                self?.validateAuthentication { isValid in
                    if isValid {
                        completion(true)
                    } else {
                        // Cookie is invalid, clear it
                        self?.cookieValue = ""
                        
                        // Just return false, we'll handle the error in the ViewModel
                        completion(false)
                    }
                }
            } else {
                completion(false)
            }
        }
    }
    
    private func validateAuthentication(completion: @escaping (Bool) -> Void) {
        // Make a simple request to verify the cookie is valid
        let endpoint = "\(baseURL)/users/me"
        
        guard let url = URL(string: endpoint) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(cookieValue, forHTTPHeaderField: "Cookie")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            // Check if we got a successful response
            if let httpResponse = response as? HTTPURLResponse, 
               httpResponse.statusCode == 200,
               let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let userData = json["data"] as? [String: Any],
               userData["gid"] != nil {
                completion(true)
            } else {
                completion(false)
            }
        }.resume()
    }
    
    func saveCookie(_ cookie: String) {
        cookieValue = cookie
    }
    
    func fetchAccessibleProjects(completion: @escaping (Result<[String], Error>) -> Void) {
        guard isAuthenticated else {
            completion(.failure(NSError(domain: "AsanaService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])))
            return
        }
        
        let endpoint = "\(baseURL)/projects?limit=100&opt_fields=gid,name"
        
        guard let url = URL(string: endpoint) else {
            completion(.failure(NSError(domain: "AsanaService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(cookieValue, forHTTPHeaderField: "Cookie")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
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
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let projectsData = json["data"] as? [[String: Any]] else {
                    completion(.failure(NSError(domain: "AsanaService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse projects data"])))
                    return
                }
                
                // Extract project IDs
                let projectIds = projectsData.compactMap { projectData -> String? in
                    return projectData["gid"] as? String
                }
                
                print("Found \(projectIds.count) accessible projects")
                completion(.success(projectIds))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func validateProjectId(_ projectId: String, completion: @escaping (Bool) -> Void) {
        // Direct check for a specific project ID
        let endpoint = "\(baseURL)/projects/\(projectId)"
        
        guard let url = URL(string: endpoint) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(cookieValue, forHTTPHeaderField: "Cookie")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            // Check HTTP status code
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    // Project exists and is accessible
                    print("Project ID \(projectId) is valid")
                    completion(true)
                    return
                } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    // Authentication error - cookie is invalid
                    print("Authentication error with status code: \(httpResponse.statusCode)")
                    // Clear the cookie as it's invalid
                    self.cookieValue = ""
                    // Show authentication error
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "Authentication Failed"
                        alert.informativeText = "Please make sure you've copied the correct cookie from Asana. Try logging in again and fetching a new cookie."
                        alert.alertStyle = .warning
                        
                        // Run the alert as a floating window
                        alert.runModalAsFloating()
                    }
                    completion(false)
                    return
                } else {
                    print("Project ID \(projectId) validation failed with status code: \(httpResponse.statusCode)")
                }
            }
            
            // Any other case is a failure
            completion(false)
        }.resume()
    }
    
    func fetchProjectName(projectId: String, completion: @escaping (String?) -> Void) {
        guard isAuthenticated else {
            completion(nil)
            return
        }
        
        let endpoint = "\(baseURL)/projects/\(projectId)"
        
        guard let url = URL(string: endpoint) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(cookieValue, forHTTPHeaderField: "Cookie")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let projectData = json["data"] as? [String: Any],
                   let name = projectData["name"] as? String {
                    
                    // Store the project name
                    self?.projectName = name
                    completion(name)
                } else {
                    completion(nil)
                }
            } catch {
                completion(nil)
            }
        }.resume()
    }
    
    func fetchTickets(completion: @escaping (Result<[Ticket], Error>) -> Void) {
        guard isAuthenticated else {
            completion(.failure(NSError(domain: "AsanaService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])))
            return
        }
        
        // Get the project ID from storage
        guard let projectId = storage.loadProjectId(), !projectId.isEmpty else {
            completion(.failure(NSError(domain: "AsanaService", code: 400, userInfo: [NSLocalizedDescriptionKey: "No project ID configured"])))
            return
        }
        
        // First check if the cookie is valid by making a simple request
        validateAuthentication { isValid in
            if !isValid {
                // Cookie is invalid
                completion(.failure(NSError(domain: "AsanaService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication failed. Please sign in again."])))
                return
            }
            
            // Now validate the project ID
            self.validateProjectId(projectId) { isValid in
                if !isValid {
                    // Project ID is invalid
                    completion(.failure(NSError(domain: "AsanaService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Project not found. Please check your project ID."])))
                    return
                }
                
                // Continue with fetching tickets if project ID is valid
                self.fetchTicketsForValidatedProject(projectId: projectId, completion: completion)
            }
        }
    }
    
    private func fetchTicketsForValidatedProject(projectId: String, completion: @escaping (Result<[Ticket], Error>) -> Void) {
        // Add query parameters to filter for in-progress tasks
        let endpoint = "\(baseURL)/projects/\(projectId)/tasks?opt_fields=name,gid,completed,memberships.section.name,memberships.project.gid"
        
        guard let url = URL(string: endpoint) else {
            completion(.failure(NSError(domain: "AsanaService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        print("Fetching tickets from Asana: \(endpoint)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(cookieValue, forHTTPHeaderField: "Cookie")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            // Check for network errors
            if let error = error {
                print("Network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            // Check for HTTP status code
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 401 {
                    completion(.failure(NSError(domain: "AsanaService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication failed or session expired"])))
                    return
                } else if httpResponse.statusCode == 404 {
                    completion(.failure(NSError(domain: "AsanaService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Project not found. Please check your project ID."])))
                    return
                }
            }
            
            // Check for data
            guard let data = data else {
                completion(.failure(NSError(domain: "AsanaService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                // Parse JSON
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(.failure(NSError(domain: "AsanaService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON"])))
                    return
                }
                
                // Check for error response
                if let errors = json["errors"] as? [[String: Any]], !errors.isEmpty {
                    if let firstError = errors.first,
                       let status = firstError["status"] as? Int, status == 401 {
                        completion(.failure(NSError(domain: "AsanaService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication failed or session expired"])))
                        return
                    }
                }
                
                // Parse tasks
                guard let tasksData = json["data"] as? [[String: Any]] else {
                    completion(.failure(NSError(domain: "AsanaService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse tasks data"])))
                    return
                }
                
                print("Received \(tasksData.count) tasks from Asana API")
                
                // Process tasks
                let tickets = tasksData.compactMap { taskData -> Ticket? in
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
                
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}