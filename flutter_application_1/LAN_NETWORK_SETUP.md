# LAN Network Setup and Session Management

This document explains how to set up and use the LAN networking features for multi-device synchronization and session management in the J-Gem Medical and Diagnostic Clinic application.

## Features Overview

### 🔐 Enhanced Session Management
- **Single Sign-On (SSO)**: Prevents multiple logins from the same user account across different devices
- **Real-time Session Monitoring**: View active user sessions across the network
- **Session Tokens**: Secure token-based authentication for LAN connections
- **Automatic Session Cleanup**: Sessions expire after inactivity and are cleaned up automatically

### 🌐 LAN Database Synchronization
- **Real-time Data Sync**: Automatic synchronization of database changes across devices
- **Conflict Resolution**: Handles concurrent data modifications gracefully
- **Offline Support**: Works when devices are temporarily disconnected

### 👥 User Activity Monitoring
- **Active Users Viewer**: See who is currently logged in and their activity status
- **Device Information**: View device names and IP addresses of connected users
- **Session Duration**: Track how long users have been logged in
- **Remote Session Management**: Administrators can end user sessions remotely

## Setup Instructions

### Step 1: Start the LAN Server (Main Device)

1. **Launch the Application** on your main device (usually the primary computer)

2. **Navigate to LAN Connection** screen:
   - From the dashboard, click the WiFi icon in the top-right corner
   - Or go to Settings → LAN Connection

3. **Enable LAN Server**:
   - Toggle the "LAN Server Status" switch to ON
   - The server will start on port 8080 by default
   - Note down the **Access Code** displayed (e.g., "Ab3Cd9Xz")
   - Note down the **IP Address** of the server

4. **Enable Session Management**:
   - Toggle the "Session Management" switch to ON
   - This will start the session server on port 8081
   - This enables user login monitoring and prevents duplicate logins

### Step 2: Connect Client Devices

1. **Launch the Application** on your secondary device

2. **Navigate to LAN Client Connection**:
   - From the dashboard, click the WiFi icon in the top-right corner
   - This opens the LAN Client Connection screen

3. **Enter Connection Details**:
   - **Server IP Address**: Enter the IP address from Step 1 (e.g., "192.168.1.100")
   - **Port**: Enter "8080" (default LAN server port)
   - **Access Code**: Enter the access code from Step 1

4. **Connect to Server**:
   - Click "Connect" button
   - Wait for "Connected successfully" message

5. **Sync Database**:
   - Click "Download DB" to get the latest database
   - Click "Sync Changes" to synchronize any local changes

## Using the System

### Login with Session Management

When you log in to the application:

1. **Enhanced Login Process**:
   - The system checks if your username is already logged in on another device
   - If already logged in elsewhere, you'll see: *"User is already logged in on another device. Please logout from the other device first."*
   - If available, login proceeds normally and a session is registered

2. **Session Registration**:
   - Your device is registered with the session server
   - Your session appears in the "Active Users" list on all connected devices
   - Session includes: username, device name, IP address, login time, and activity status

### Monitoring Active Users

On the **LAN Connection Screen** (main device):

1. **View Active Sessions**:
   - Scroll down to the "Session Management" section
   - See all currently logged-in users in real-time
   - Information displayed:
     - Username and access level (Admin, Doctor, MedTech)
     - Device name and IP address
     - Login time and session duration
     - Last activity status (Active, or "X minutes ago")

2. **Manage Sessions**:
   - Click "End Session" next to any user to force logout
   - Sessions refresh automatically every 5 seconds
   - Inactive sessions (no activity for 8 hours) are automatically removed

On the **LAN Client Connection Screen** (secondary devices):

1. **View Network Users**:
   - After connecting, scroll down to "Active Users" section
   - See who else is currently using the system
   - Useful for coordinating data entry and avoiding conflicts

### Database Synchronization

**Automatic Sync**:
- Changes are automatically synchronized every 5 minutes
- Real-time updates for critical operations
- Conflict resolution handles simultaneous edits

**Manual Sync**:
- Use "Sync Changes" button for immediate synchronization
- Use "Download DB" for complete database refresh
- Monitor pending changes count on the server status

### Security Features

1. **Network Security**:
   - LAN server only accepts connections from local network IP addresses
   - Access codes are required for all database operations
   - Sessions use secure tokens for authentication

2. **Session Security**:
   - Sessions automatically expire after 8 hours of inactivity
   - Heartbeat mechanism keeps active sessions alive
   - Secure cleanup when users logout or close the application

## Troubleshooting

### Connection Issues

**Problem**: "Failed to connect to server"
- **Solution**: Check IP address, port, and access code are correct
- Ensure both devices are on the same network
- Verify the LAN server is running on the main device

**Problem**: "User already logged in" error
- **Solution**: Go to the main device and end the existing session
- Or logout from the other device manually

### Session Management Issues

**Problem**: Users not appearing in active list
- **Solution**: Ensure Session Management is enabled on the main device
- Check that session server is running on port 8081
- Verify network connectivity between devices

**Problem**: Sessions not cleaning up automatically
- **Solution**: Restart the session management service
- Check for network interruptions
- Sessions will be cleaned up on next heartbeat

### Performance Optimization

1. **Network Performance**:
   - Use wired connections for better stability
   - Ensure good WiFi signal strength for wireless devices
   - Consider dedicated network for clinic operations

2. **Database Performance**:
   - Regular database maintenance and cleanup
   - Monitor pending changes and sync frequently
   - Use manual sync during high-activity periods

## Best Practices

### Multi-Device Workflow

1. **Primary Device Setup**:
   - Use the most powerful computer as the main device
   - Keep it running during clinic hours
   - Regular backups of the database

2. **Secondary Device Usage**:
   - Connect at start of shift
   - Sync at regular intervals during the day
   - Proper logout at end of shift

3. **User Management**:
   - Assign unique usernames for each staff member
   - Use appropriate access levels (Admin, Doctor, MedTech)
   - Monitor session activity for security

### Data Management

1. **Synchronization Schedule**:
   - Sync before entering critical patient data
   - Manual sync after bulk data entry
   - End-of-day complete synchronization

2. **Conflict Resolution**:
   - Coordinate data entry between devices
   - Use the active users list to see who's working
   - Resolve conflicts through communication

3. **Backup Strategy**:
   - Main device maintains primary database
   - Secondary devices for redundancy
   - Regular database exports

## Technical Details

### Network Ports
- **Port 8080**: LAN database server
- **Port 8081**: Session management server
- **Port Range**: 8080-8090 should be available

### Database Technology
- **SQLite**: Local database on each device
- **HTTP/WebSocket**: Communication protocol
- **JSON**: Data exchange format

### Session Management
- **Token-based**: Secure session authentication
- **Heartbeat**: 1-minute intervals for activity monitoring
- **Timeout**: 8 hours of inactivity before auto-logout

## Support

For technical support or issues:
1. Check this documentation first
2. Verify network and connection settings
3. Restart services if needed
4. Contact system administrator for advanced troubleshooting

---

*This documentation covers the LAN networking and session management features of the J-Gem Medical and Diagnostic Clinic application. Keep this document accessible for reference during setup and daily operations.*
