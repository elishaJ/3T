import Foundation
import WebKit
import AppKit

class WebViewAuth: NSObject, WKNavigationDelegate, NSWindowDelegate {
    private var webView: WKWebView!
    private var window: NSWindow!
    private var completion: ((String?) -> Void)?
    
    func authenticate(completion: @escaping (String?) -> Void) {
        self.completion = completion
        
        // Create a configuration that allows JavaScript and cookies
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        configuration.preferences.javaScriptEnabled = true
        
        // Create the web view
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), configuration: configuration)
        webView.navigationDelegate = self
        
        // Create a window to show the web view
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 650),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Sign in to Asana"
        
        // Create a container view with the web view and a button
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 650))
        
        // Add web view to container
        webView.frame = NSRect(x: 0, y: 50, width: 800, height: 600)
        containerView.addSubview(webView)
        
        // Add a button at the bottom
        let button = NSButton(frame: NSRect(x: 300, y: 10, width: 200, height: 30))
        button.title = "I'm logged in, continue"
        button.bezelStyle = .rounded
        button.target = self
        button.action = #selector(extractCookiesManually)
        containerView.addSubview(button)
        
        window.contentView = containerView
        window.level = .floating  // Make window appear above other windows
        window.delegate = self
        self.window = window
        
        // Load Asana
        if let url = URL(string: "https://app.asana.com") {
            webView.load(URLRequest(url: url))
        }
        
        // Show the window and bring to front
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("Page loaded: \(webView.url?.absoluteString ?? "unknown")")
        
        // Check if we're on the Asana app page (after login)
        if webView.url?.absoluteString.contains("/0/") ?? false {
            print("Detected Asana app page, extracting cookies...")
            // Wait a moment to ensure all cookies are set
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.extractCookies()
            }
        } else {
            // Check if we can access the API with current cookies
            checkAuthentication(webView)
        }
    }
    
    private func checkAuthentication(_ webView: WKWebView) {
        print("Checking authentication status...")
        webView.evaluateJavaScript("""
            var checkAuth = async function() {
                try {
                    let response = await fetch('https://app.asana.com/api/1.0/users/me', {
                        method: 'GET',
                        credentials: 'include'
                    });
                    return response.status === 200;
                } catch (e) {
                    console.error(e);
                    return false;
                }
            };
            checkAuth();
        """) { [weak self] result, error in
            if let error = error {
                print("JavaScript error: \(error)")
            }
            
            if let success = result as? Bool, success {
                print("Authentication successful, extracting cookies...")
                // We have valid cookies, extract them
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.extractCookies()
                }
            } else {
                print("Not authenticated yet: \(result ?? "nil")")
                // Check again after a delay if we're still on an Asana page
                if self?.webView.url?.host?.contains("asana.com") ?? false {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        if let webView = self?.webView {
                            self?.checkAuthentication(webView)
                        }
                    }
                }
            }
        }
    }
    
    private func extractCookies() {
        print("Extracting cookies...")
        // Get all cookies from the Asana domain
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
            // Filter for Asana cookies
            let asanaCookies = cookies.filter { $0.domain.contains("asana.com") }
            print("Found \(asanaCookies.count) Asana cookies")
            
            // Format cookies as a header string
            let cookieHeader = asanaCookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            
            if !cookieHeader.isEmpty {
                print("Successfully extracted cookie header")
                // Close the window
                DispatchQueue.main.async {
                    self?.window.close()
                    self?.completion?(cookieHeader)
                }
            } else {
                print("No cookies found, waiting longer...")
                // Try again after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.extractCookies()
                }
            }
        }
    }
    
    @objc private func extractCookiesManually() {
        print("Manual cookie extraction triggered")
        
        // Use JavaScript to make a fetch request and capture the cookies
        let script = """
        (async function() {
            try {
                // Make a request to the API
                const response = await fetch('https://app.asana.com/api/1.0/users/me', {
                    method: 'GET',
                    credentials: 'include'
                });
                
                // Check if the request was successful
                if (response.status === 200) {
                    // Return success
                    return true;
                } else {
                    console.error('API request failed with status:', response.status);
                    return false;
                }
            } catch (error) {
                console.error('Error making API request:', error);
                return false;
            }
        })();
        """
        
        webView.evaluateJavaScript(script) { [weak self] (result, error) in
            if let success = result as? Bool, success {
                print("API request successful, extracting cookies")
                // If the API request was successful, extract cookies from WKWebsiteDataStore
                self?.extractCookies()
            } else {
                print("API request failed, trying direct cookie extraction")
                // Try to get cookies directly from JavaScript
                self?.webView.evaluateJavaScript("document.cookie") { [weak self] (result, error) in
                    if let cookieString = result as? String, !cookieString.isEmpty {
                        print("Got cookies from JavaScript: \(cookieString)")
                        DispatchQueue.main.async {
                            self?.window.close()
                            self?.completion?(cookieString)
                        }
                    } else {
                        // If all else fails, try the WKWebsiteDataStore approach
                        self?.extractCookies()
                    }
                }
            }
        }
    }
    
    // Handle window close button
    func windowWillClose(_ notification: Notification) {
        print("Window closed by user")
        // If the window is closed manually, call completion with nil
        completion?(nil)
    }
}