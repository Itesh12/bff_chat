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
      expect(EnvConfig.isDevelopment, true);
      expect(EnvConfig.isProduction, false);
    });

    test('Staging environment parameters initialize correctly', () {
      EnvConfig.initialize(Environment.staging);

      expect(EnvConfig.environment, Environment.staging);
      expect(EnvConfig.firebaseProjectId, 'memovault-staging');
      expect(EnvConfig.enableDetailedLogging, true);
      expect(EnvConfig.enableAnalytics, true);
      expect(EnvConfig.isDevelopment, false);
      expect(EnvConfig.isProduction, false);
    });

    test('Prod environment parameters initialize correctly', () {
      EnvConfig.initialize(Environment.prod);

      expect(EnvConfig.environment, Environment.prod);
      expect(EnvConfig.firebaseProjectId, 'memovault-prod');
      expect(EnvConfig.enableDetailedLogging, false);
      expect(EnvConfig.enableAnalytics, true);
      expect(EnvConfig.isDevelopment, false);
      expect(EnvConfig.isProduction, true);
    });
  });
}
