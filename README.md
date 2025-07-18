# Ticket Tracker

A macOS menu bar app that connects to Asana to track time spent on tickets.

## Features

- Connects to Asana and fetches tickets from a project
- Displays tickets in a dropdown menu from the menu bar
- Start/stop time tracking for individual tickets
- Tracks time spent on each ticket

## Setup Instructions

1. Update the `AsanaService.swift` file:
   - Replace `YOUR_ASANA_PROJECT_ID` with the ID of the project you want to track
   - You can find your project ID in the URL when viewing the project in Asana
     (e.g., https://app.asana.com/0/123456789/list - where 123456789 is the project ID)

2. Build and run the app

3. When prompted, you'll need to provide your Asana cookie:
   - Open Asana in your browser and login
   - Open browser developer tools (F12 or right-click > Inspect)
   - Go to Network tab
   - Refresh the page
   - Click on any request to app.asana.com
   - Find 'Cookie' in the request headers
   - Copy the entire cookie value
   - Paste it in the app's authentication dialog

3. Build and run the app in Xcode

## Usage

1. Click the ticket icon in the menu bar to open the app
2. If not connected, click "Connect to Asana" and follow the instructions to enter your cookie
3. Once connected, your tickets will appear in the list
4. Click "Start" to begin tracking time on a ticket
5. Click "Stop" to stop tracking time
6. Click the refresh button to update the ticket list

Note: The cookie authentication may expire after some time. If this happens, you'll need to reconnect using a fresh cookie.

## Requirements

- macOS 11.0 or later
- Xcode 13.0 or later
- Swift 5.5 or later
- Asana account with API access