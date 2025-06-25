# LAN Networking and Session Management Implementation

## Overview
This implementation provides comprehensive LAN networking capabilities for the J-Gem Medical Application, allowing multiple devices to connect, sync data, and manage user sessions with token-based authentication.

## Key Features

### 1. Session Management
- **Token-based Authentication**: Prevents multiple logins from the same user account
- **Device Tracking**: Monitors which devices are connected and active
- **Session Timeout**: Automatically expires inactive sessions
- **Real-time Updates**: Live notifications when users login/logout

### 2. Database Synchronization
- **Real-time Sync**: Automatic synchronization of database changes between devices
- **Bidirectional**: Both upload and download changes between server and client
- **Conflict Resolution**: Handles concurrent modifications gracefully

### 3. User Role Management
- **Role-based Access**: Different functionality based on user roles (admin, doctor, medtech)
- **Permission Enforcement**: Ensures users can only access authorized features
- **Current User Context**: Maintains logged-in user information across the application

## Components

### Core Services

#### AuthService (`lib/services/auth_service.dart`)
- Enhanced login with session management
- Token validation and refresh
- User role caching and management
- Device ID generation for session tracking

#### LanSessionService (`lib/services/lan_session_service.dart`)
- User session registration and management
- Session validation and timeout handling
- Real-time session updates via WebSocket
- Multi-device session monitoring

#### LanSyncService (`lib/services/lan_sync_service.dart`)
- Database server hosting
- File change monitoring
- Automatic synchronization
- Network access control

#### LanClientService (`lib/services/lan_client_service.dart`)
- Client connection to LAN servers
- Session registration with remote servers
- Heartbeat maintenance
- Active session monitoring

### User Interface

#### Enhanced LAN Connection Screen (`lib/screens/enhanced_lan_connection_screen.dart`)
- Server management controls
- Active users viewer with real-time updates
- Session management (force logout users)
- Database synchronization controls

#### LAN Client Connection Screen (`lib/screens/lan_client_connection_screen.dart`)
- Connect to remote LAN servers
- View active users on remote servers
- Download and sync databases
- Real-time session monitoring

## Usage Instructions

### Setting up LAN Server (Main Device)

1. **Enable LAN Server**
   - Navigate to LAN Connection screen
   - Toggle the LAN Server switch ON
   - Note the generated access code
   - Share IP addresses and access code with client devices

2. **Session Management**
   - Enable Session Server for user management
   - Monitor active users in real-time
   - Force logout users if needed
   - View session duration and activity status

3. **Database Sharing**
   - Database is automatically shared when LAN server is enabled
   - Monitor pending changes and sync status
   - Use provided URLs for external database tools

### Connecting Client Device

1. **Connect to Server**
   - Get IP address and access code from main device
   - Enter connection details in LAN Client Connection screen
   - Click Connect to establish connection

2. **View Active Users**
   - See all logged-in users across devices
   - Monitor session activity and duration
   - Real-time updates when users login/logout

3. **Sync Database**
   - Download latest database from server
   - Upload local changes to server
   - Automatic synchronization ensures data consistency

## Security Features

### Network Security
- **LAN-only Access**: Server only accepts connections from local network
- **Access Code Protection**: Requires shared access code for database access
- **IP Range Filtering**: Configurable allowed network ranges

### Session Security
- **Single Login Enforcement**: Prevents same user from logging in on multiple devices
- **Session Tokens**: Unique tokens for each session
- **Automatic Timeout**: Sessions expire after period of inactivity
- **Device Tracking**: Monitor and control device access

### Data Protection
- **Encrypted Storage**: Sensitive data stored using secure storage
- **Password Hashing**: BCrypt hashing with salt for passwords
- **Audit Logging**: All user activities are logged for accountability

## Role-based Functionality

### Admin Users
- Full access to all features
- User management capabilities
- System maintenance and configuration
- Access to all reports and analytics

### Doctor Users
- Patient consultation and management
- Medical record creation and editing
- Prescription and treatment planning
- Access to patient history and reports

### Medical Technician (Medtech) Users
- Laboratory test management
- Sample collection and processing
- Result entry and reporting
- Basic patient queue management

## Technical Implementation

### Database Schema
The system uses SQLite database with tables for:
- Users (with roles and authentication)
- Patients and medical records
- Appointments and scheduling
- Laboratory results and reports
- Session tracking and audit logs

### Real-time Communication
- WebSocket connections for live updates
- HTTP API for data synchronization
- Heartbeat mechanism for session monitoring
- Event-driven architecture for notifications

### Error Handling
- Comprehensive error handling and recovery
- User-friendly error messages
- Automatic reconnection attempts
- Graceful degradation when services unavailable

## Configuration

### Network Settings
- Default ports: 8080 (data), 8081 (sessions)
- Configurable IP ranges for security
- Automatic network discovery
- Manual IP configuration support

### Session Settings
- Session timeout: 8 hours (configurable)
- Heartbeat interval: 1 minute
- Refresh rate: 10 seconds for UI updates
- Maximum concurrent sessions per user: 1

## Troubleshooting

### Connection Issues
1. Verify devices are on same network
2. Check firewall settings
3. Confirm access code is correct
4. Ensure server is running and accessible

### Session Problems
1. Check if user is already logged in elsewhere
2. Verify session server is running
3. Clear application data and retry
4. Check system clock synchronization

### Sync Issues
1. Verify network connectivity
2. Check database permissions
3. Monitor for conflicting changes
4. Restart synchronization services

## Future Enhancements

### Planned Features
- Encrypted data transmission
- Cloud backup integration
- Mobile device support
- Advanced conflict resolution
- Role-based dashboard customization

### Performance Optimizations
- Delta synchronization (only changed data)
- Compression for data transfer
- Caching mechanisms
- Background sync scheduling

This implementation provides a robust foundation for multi-device clinic management with secure session handling and real-time data synchronization.
