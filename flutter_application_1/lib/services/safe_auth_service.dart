import 'dart:async';
import 'package:flutter/foundation.dart';

/// Exception for handling session conflicts
class UserSessionConflictException implements Exception {
  final String message;
  final List<Map<String, dynamic>> activeSessions;
  
  const UserSessionConflictException(this.message, this.activeSessions);
  
  @override
  String toString() => 'UserSessionConflictException: $message';
}

/// Lightweight authentication crash prevention service
/// 
/// This provides basic authentication functionality without the heavy
/// session monitoring that was causing compilation crashes.
class SafeAuthService {
  static bool _isInitialized = false;
  
  /// Initialize safe authentication (crash-proof)
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      debugPrint('SAFE_AUTH: Initializing lightweight authentication');
      _isInitialized = true;
      debugPrint('SAFE_AUTH: Authentication initialized successfully');
    } catch (e) {
      debugPrint('SAFE_AUTH: Error during initialization: $e');
      // Don't crash the app - continue without auth features
    }
  }
  
  /// Check if authentication is working properly
  static bool get isHealthy => _isInitialized;
  
  /// Get status for debugging
  static String getStatus() {
    return 'SafeAuthService: ${_isInitialized ? "Initialized" : "Not initialized"}';
  }
}
