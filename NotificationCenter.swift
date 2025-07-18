import Foundation

// Define notification names
extension Notification.Name {
    static let authenticationSucceeded = Notification.Name("authenticationSucceeded")
}

// Notification center wrapper for easier use
class AppNotificationCenter {
    static let shared = AppNotificationCenter()
    
    private init() {}
    
    func postAuthenticationSuccess() {
        NotificationCenter.default.post(name: .authenticationSucceeded, object: nil)
    }
    
    func addAuthenticationSuccessObserver(_ observer: Any, selector: Selector) {
        NotificationCenter.default.addObserver(observer, selector: selector, name: .authenticationSucceeded, object: nil)
    }
}