# Real-Time Patient Sync Verification Guide

## Overview
This guide will help you verify that patient registration is properly syncing in real-time across devices.

## Prerequisites
1. **LAN Server Running**: Ensure the LAN server is active on the main device
2. **Same Network**: Both devices must be connected to the same WiFi/LAN network
3. **Client Connected**: Client device must be connected to the LAN server
4. **Access Code**: Both devices using the same current access code

## Step-by-Step Verification

### Phase 1: Setup Verification

#### On Server Device (Main Device):
1. **Start LAN Server**:
   - Go to `Settings → LAN Connection`
   - Toggle `LAN Server Status` to **ON**
   - Note the **Access Code** (e.g., "w3wiaToG")
   - Note the **IP Address** (e.g., "192.168.68.115")

2. **Verify Server is Running**:
   - You should see green status indicators
   - Multiple IP addresses should be listed
   - Port should show as 8080

#### On Client Device:
1. **Connect to Server**:
   - Go to `Settings → LAN Connection`
   - Click on `LAN Client Connection`
   - Enter **Server IP**: (from server device)
   - Enter **Port**: 8080
   - Enter **Access Code**: (from server device)
   - Click **Connect**

2. **Verify Connection**:
   - Status should show "Connected successfully"
   - You should see server information displayed
   - Active sessions list should show your connection

### Phase 2: Real-Time Sync Test

#### Test 1: Patient Registration from Server Device
1. **On Server Device**:
   - Go to `Registration → Patient Registration`
   - Fill in patient details:
     - First Name: "TestSync"
     - Last Name: "Patient1"
     - Date of Birth: Select any date
     - Gender: Select any
     - Contact: "09123456789"
     - Blood Type: Select any
   - Click **REGISTER PATIENT**
   - Note the generated Patient ID

2. **On Client Device (within 10 seconds)**:
   - Go to `Search → Patient Search`
   - Search for "TestSync" or "Patient1"
   - **Expected Result**: Patient should appear in search results
   - Check that all details match what was entered

#### Test 2: Patient Registration from Client Device
1. **On Client Device**:
   - Go to `Registration → Patient Registration`
   - Fill in patient details:
     - First Name: "SyncTest"
     - Last Name: "Patient2"
     - Date of Birth: Select any date
     - Gender: Select any
     - Contact: "09987654321"
     - Blood Type: Select any
   - Click **REGISTER PATIENT**
   - Note the generated Patient ID

2. **On Server Device (within 10 seconds)**:
   - Go to `Search → Patient Search`
   - Search for "SyncTest" or "Patient2"
   - **Expected Result**: Patient should appear in search results
   - Check that all details match what was entered

#### Test 3: Patient Update Sync
1. **On Server Device**:
   - Go to `Search → Patient Search`
   - Search for "TestSync Patient1"
   - Click the **Edit** button (pencil icon)
   - Change contact number to "09111111111"
   - Click **SAVE CHANGES**

2. **On Client Device (within 10 seconds)**:
   - Go to `Search → Patient Search`
   - Search for "TestSync Patient1"
   - **Expected Result**: Contact number should show "09111111111"

### Phase 3: Troubleshooting Failed Sync

If patients are not syncing in real-time, follow these steps:

#### Check 1: Connection Status
- **On both devices**: Verify connection status in LAN Client/Server screens
- **Expected**: Green indicators and "Connected" status

#### Check 2: WebSocket Connection
- **On client device**: Check if you see WebSocket connection messages in app logs
- **Expected**: Should see "Real-time sync connected to [IP]:[PORT]" in debug logs

#### Check 3: Access Code Verification
- **Compare access codes**: Ensure both devices are using the same access code
- **If different**: Update client with current server access code

#### Check 4: Network Connectivity
- **Test basic connectivity**: 
  - Run the debug script: `dart run debug_lan_connection.dart`
  - Should find working configuration
- **Check WiFi**: Ensure both devices are on the same network

#### Check 5: Manual Database Sync
1. **On client device**:
   - Go to LAN Client Connection screen
   - Click **Download DB** button
   - Click **Sync Changes** button
   - Check if patient now appears

### Phase 4: Advanced Debugging

#### Run Test Scripts
1. **Connection Test**:
   ```bash
   dart run debug_lan_connection.dart
   ```
   - Should find working server configuration

2. **Real-Time Sync Test**:
   ```bash
   dart run test_real_time_patient_sync.dart
   ```
   - Should show successful WebSocket connection and message sending

#### Check Debug Logs
Look for these messages in the app debug output:

**Successful Sync Messages**:
- "Real-time sync connected to [IP]:[PORT]"
- "Sent patient info update"
- "Received WebSocket message type: patient_info_update"
- "Patient info updated: [PATIENT_ID]"

**Error Messages to Watch For**:
- "Failed to connect to real-time sync"
- "WebSocket error"
- "Failed to send real-time sync"

### Expected Results Summary

✅ **Working Real-Time Sync**:
- Patient registered on Device A appears on Device B within 10 seconds
- Patient updates on Device A reflect on Device B within 10 seconds
- No manual sync required
- Both devices show "Connected" status

❌ **Non-Working Sync** (needs investigation):
- Patient registration only appears after manual "Download DB"
- Changes not visible until app restart or manual sync
- Connection shows as disconnected
- WebSocket connection errors in logs

### Common Issues and Solutions

| Issue | Likely Cause | Solution |
|-------|--------------|----------|
| "Connection failed" | Wrong IP/Port/Access Code | Verify server connection details |
| "HTTP 403 Forbidden" | Wrong access code | Get current access code from server |
| "Network unreachable" | Different WiFi networks | Connect to same network |
| "WebSocket connection failed" | Firewall blocking | Check firewall settings |
| Patients sync manually only | Real-time service not initialized | Restart both apps |
| Old access code | Server regenerated code | Get new code from server screen |

### Final Verification

After following this guide, real-time patient sync should work as follows:

1. **Immediate Sync**: Patient registration appears on other devices within 10 seconds
2. **Bi-directional**: Works from any connected device to all others
3. **Automatic**: No manual sync buttons needed
4. **Consistent**: All patient data fields sync correctly

If sync is still not working after following this guide, the issue may require technical investigation of the WebSocket message handling or network configuration.
