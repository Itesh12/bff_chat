import 'package:flutter_test/flutter_test.dart';
import 'package:memovault/core/config/env_config.dart';

void main() {
  group('EnvConfig Tests', () {
    test('Dev environment parameters initialize correctly', () {
      EnvConfig.initialize(Environment.dev);

      expect(EnvConfig.environment, Environment.dev);
      expect(EnvConfig.firebaseProjectId, 'memovault-dev');
      expect(EnvConfig.enableDetailedLogging, true);
      expect(EnvConfig.enableAnalytics, false);
      expect(EnvConfig.r2WorkerBaseUrl, 'http://localhost:8787');
      expect(EnvConfig.r2CdnBaseUrl, 'mock-r2://');
      expect(EnvConfig.isDevelopment, true);
      expect(EnvConfig.isProduction, false);
    });

    test('Staging environment parameters initialize correctly', () {
      EnvConfig.initialize(Environment.staging);

      expect(EnvConfig.environment, Environment.staging);
      expect(EnvConfig.firebaseProjectId, 'memovault-staging');
      expect(EnvConfig.enableDetailedLogging, true);
      expect(EnvConfig.enableAnalytics, true);
      expect(EnvConfig.r2WorkerBaseUrl, 'https://staging-media-api.memovault.com');
      expect(EnvConfig.r2CdnBaseUrl, 'https://staging-media.memovault.com');
      expect(EnvConfig.isDevelopment, false);
      expect(EnvConfig.isProduction, false);
    });

    test('Prod environment parameters initialize correctly', () {
      EnvConfig.initialize(Environment.prod);

      expect(EnvConfig.environment, Environment.prod);
      expect(EnvConfig.firebaseProjectId, 'memovault-prod');
      expect(EnvConfig.enableDetailedLogging, false);
      expect(EnvConfig.enableAnalytics, true);
      expect(EnvConfig.r2WorkerBaseUrl, 'https://media-api.memovault.com');
      expect(EnvConfig.r2CdnBaseUrl, 'https://media.memovault.com');
      expect(EnvConfig.isDevelopment, false);
      expect(EnvConfig.isProduction, true);
    });
  });
}
