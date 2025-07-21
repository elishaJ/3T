#!/bin/bash
set -e 
# Create app bundle structure
mkdir -p TicketTracker.app/Contents/MacOS
mkdir -p TicketTracker.app/Contents/Resources

# Create Info.plist
cat > TicketTracker.app/Contents/Info.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>TicketTracker</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.TicketTracker</string>
    <key>CFBundleName</key>
    <string>TicketTracker</string>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>CFBundleURLName</key>
            <string>com.example.tickettracker</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>tickettracker</string>
            </array>
        </dict>
    </array>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

# Compile Swift files
swiftc -o TicketTracker.app/Contents/MacOS/TicketTracker \
    -target x86_64-apple-macosx14.0 \
    -sdk $(xcrun --show-sdk-path) \
    -framework AppKit \
    -framework SwiftUI \
    -framework Foundation \
    TicketTrackerApp.swift \
    ContentView.swift \
    TicketViewModel.swift \
    Ticket.swift \
    AsanaService.swift \
    TicketStorage.swift \
    CompletedTicketRow.swift \
    CookieExtractor.swift \
    SimpleAuth.swift \
    NotificationCenter.swift \
    SettingsView.swift \
    NSAlertExtension.swift \
    SettingsWindowController.swift

# Make executable
chmod +x TicketTracker.app/Contents/MacOS/TicketTracker

echo "Build complete. Run with: open TicketTracker.app"