import Foundation
import AppKit

class CookieExtractor {
    enum BrowserType: String {
        case chrome = "com.google.chrome"
        case firefox = "org.mozilla.firefox"
        
        var bundleId: String {
            return self.rawValue
        }
        
        var name: String {
            switch self {
            case .chrome: return "Google Chrome"
            case .firefox: return "Firefox"
            }
        }
    }
    
    static func getDefaultBrowser() -> BrowserType? {
        // Get the default web browser bundle ID
        let urlString = "https://www.example.com"
        guard let url = URL(string: urlString),
              let appURL = NSWorkspace.shared.urlForApplication(toOpen: url) else {
            return nil
        }
        
        // Get the bundle identifier using Bundle
        let bundle = Bundle(url: appURL)
        let bundleId = bundle?.bundleIdentifier ?? ""
        
        if bundleId.contains(BrowserType.chrome.bundleId) {
            return .chrome
        } else if bundleId.contains(BrowserType.firefox.bundleId) {
            return .firefox
        }
        
        // Fallback: check the app name
        let appName = appURL.lastPathComponent.lowercased()
        if appName.contains("chrome") {
            return .chrome
        } else if appName.contains("firefox") {
            return .firefox
        }
        
        return nil
    }
    
    static func extractAsanaCookie(completion: @escaping (String?) -> Void) {
        // Try to extract from browser automatically
        DispatchQueue.global(qos: .userInitiated).async {
            // First check the default browser
            if let defaultBrowser = getDefaultBrowser() {
                var cookie: String? = nil
                
                switch defaultBrowser {
                case .chrome:
                    cookie = extractFromChrome()
                case .firefox:
                    cookie = extractFromFirefox()
                }
                
                if let cookie = cookie, !cookie.isEmpty {
                    DispatchQueue.main.async {
                        completion(cookie)
                    }
                    return
                }
            }
            
            // If default browser failed, try the other browsers
            let defaultBrowser = getDefaultBrowser()
            
            // Try Chrome if it's not the default or if default browser check failed
            if defaultBrowser != .chrome {
                if let cookie = extractFromChrome(), !cookie.isEmpty {
                    DispatchQueue.main.async {
                        completion(cookie)
                    }
                    return
                }
            }
            
            // Try Firefox if it's not the default or if default browser check failed
            if defaultBrowser != .firefox {
                if let cookie = extractFromFirefox(), !cookie.isEmpty {
                    DispatchQueue.main.async {
                        completion(cookie)
                    }
                    return
                }
            }
            
            // If all automatic methods fail, return nil
            DispatchQueue.main.async {
                completion(nil)
            }
        }
    }
    
    private static func extractFromChrome() -> String? {
        // First check if Chrome is running
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = runningApps.contains { $0.bundleIdentifier?.contains("com.google.Chrome") ?? false }
        
        if !isRunning {
            print("Chrome is not running")
            return nil
        }
        
        // Use AppleScript to get cookies from Chrome
        let script = """
        tell application "Google Chrome"
            set cookieValue to ""
            set foundAsana to false
            
            -- Check if Asana is open in any tab
            repeat with w in windows
                repeat with t in tabs of w
                    if (URL of t contains "asana.com") then
                        set foundAsana to true
                        set active tab of w to t
                        exit repeat
                    end if
                end repeat
                if foundAsana then exit repeat
            end repeat
            
            -- If Asana is open, try to get cookies
            if foundAsana then
                -- Execute JavaScript to get cookies via the Network panel
                set cookieScript to "
                    (function() {\n
                        // Create a test request to Asana API\n
                        var xhr = new XMLHttpRequest();\n
                        xhr.open('GET', 'https://app.asana.com/api/1.0/users/me', false);\n
                        xhr.send(null);\n
                        // Return the cookie header that was sent\n
                        return document.cookie;\n
                    })();"
                
                set cookieValue to execute active tab of front window javascript cookieScript
            end if
            
            return cookieValue
        end tell
        """
        
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        if let result = appleScript?.executeAndReturnError(&error).stringValue, !result.isEmpty {
            print("Successfully extracted cookie from Chrome")
            return result
        } else if let error = error {
            print("Chrome AppleScript error: \(error)")
        }
        
        return nil
    }
    
    private static func extractFromFirefox() -> String? {
        // Use AppleScript to get cookies from Firefox
        let script = """
        tell application "Firefox"
            set cookieValue to ""
            activate
            delay 0.5
            tell application "System Events"
                keystroke "l" using {command down}
                delay 0.2
                keystroke "c" using {command down}
            end tell
            delay 0.2
            set currentURL to (the clipboard)
            
            if currentURL contains "asana.com" then
                tell application "System Events"
                    keystroke "i" using {command down, option down}
                    delay 1
                    keystroke "k"
                    delay 0.5
                    keystroke "c" using {command down}
                end tell
                delay 0.2
                set cookieValue to (the clipboard)
            end if
            
            return cookieValue
        end tell
        """
        
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        if let result = appleScript?.executeAndReturnError(&error).stringValue, !result.isEmpty {
            return result
        }
        
        return nil
    }
}