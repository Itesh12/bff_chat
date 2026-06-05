import 'dart:async';

/// Abstract service managing registration, token updates, and message payload hooks
/// for Firebase Cloud Messaging (FCM) on Android and Apple Push Notification service (APNs) on iOS.
abstract class PushNotificationService {
  /// Stream of incoming push message payloads (decrypted/processed if necessary).
  Stream<Map<String, dynamic>> get messageStream;

  /// Initializes push notification handlers, asks for permissions, and registers listeners.
  Future<void> initialize();

  /// Retrieves the active FCM (Android) or APNs (iOS) registration token for the device.
  Future<String?> getDeviceToken();

  /// Clears registration tokens and stops push listeners (e.g., during panic lock or sign-out).
  Future<void> clearToken();

  /// Decrypts an incoming E2EE push notification payload in the background.
  /// Typically called from background handlers when a push payload contains ciphertext.
  Future<Map<String, dynamic>> decryptPushPayload(Map<String, dynamic> encryptedPayload);
}
