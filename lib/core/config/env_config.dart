import 'dart:io';
import 'package:flutter/widgets.dart';

enum Environment { dev, staging, prod }
enum StorageProvider { cloudinary, r2 }

abstract final class EnvConfig {
  static bool? _isTestOverride;
  static bool get isTest {
    if (_isTestOverride != null) return _isTestOverride!;
    if (Platform.environment.containsKey('FLUTTER_TEST')) return true;
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('TestWidgets');
    } catch (_) {
      return false;
    }
  }
  static set isTest(bool value) => _isTestOverride = value;
  static late Environment environment;
  static late String firebaseProjectId;
  static late bool enableDetailedLogging;
  static late bool enableAnalytics;
  static late String r2WorkerBaseUrl;
  static late String r2CdnBaseUrl;
  static late String cloudinaryApiBaseUrl;

  // Cloudinary Settings from Compile-Time Environment
  static String? _cloudinaryCloudNameOverride;
  static String? _cloudinaryUploadPresetOverride;

  static String get cloudinaryCloudName => _cloudinaryCloudNameOverride ?? const String.fromEnvironment('CLOUDINARY_CLOUD_NAME');
  static String get cloudinaryUploadPreset => _cloudinaryUploadPresetOverride ?? const String.fromEnvironment('CLOUDINARY_UPLOAD_PRESET');

  @visibleForTesting
  static set cloudinaryCloudNameOverride(String value) => _cloudinaryCloudNameOverride = value;

  @visibleForTesting
  static set cloudinaryUploadPresetOverride(String value) => _cloudinaryUploadPresetOverride = value;
  static StorageProvider? _storageProvider;
  static StorageProvider get storageProvider {
    if (_storageProvider != null) return _storageProvider!;
    if (isTest) return StorageProvider.cloudinary;
    throw StateError('EnvConfig.storageProvider has not been initialized.');
  }
  static set storageProvider(StorageProvider value) => _storageProvider = value;

  static void initialize(Environment env) {
    environment = env;
    switch (env) {
      case Environment.dev:
        firebaseProjectId = 'memovault-dev';
        enableDetailedLogging = true;
        enableAnalytics = false;
        r2WorkerBaseUrl = 'http://localhost:8787';
        r2CdnBaseUrl = 'mock-r2://';
        cloudinaryApiBaseUrl = 'https://api.cloudinary.com';
        storageProvider = StorageProvider.cloudinary;
      case Environment.staging:
        firebaseProjectId = 'memovault-staging';
        enableDetailedLogging = true;
        enableAnalytics = true;
        r2WorkerBaseUrl = 'https://staging-media-api.memovault.com';
        r2CdnBaseUrl = 'https://staging-media.memovault.com';
        cloudinaryApiBaseUrl = 'https://api.cloudinary.com';
        storageProvider = StorageProvider.cloudinary;
      case Environment.prod:
        firebaseProjectId = 'memovault-prod';
        enableDetailedLogging = false;
        enableAnalytics = true;
        r2WorkerBaseUrl = 'https://media-api.memovault.com';
        r2CdnBaseUrl = 'https://media.memovault.com';
        cloudinaryApiBaseUrl = 'https://api.cloudinary.com';
        storageProvider = StorageProvider.cloudinary; // Temporary Cloudinary override
    }
  }

  static bool get isProduction => environment == Environment.prod;
  static bool get isDevelopment => environment == Environment.dev;
  static bool get isStaging => environment == Environment.staging;

  /// True only for the dev flavor. Used to conditionally skip Firebase
  /// initialization (eliminates DNS errors and startup network calls in dev).
  static bool get isDevFlavor => environment == Environment.dev;
}
