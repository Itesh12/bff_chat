enum Environment { dev, staging, prod }

abstract final class EnvConfig {
  static late Environment environment;
  static late String firebaseProjectId;
  static late bool enableDetailedLogging;
  static late bool enableAnalytics;

  static void initialize(Environment env) {
    environment = env;
    switch (env) {
      case Environment.dev:
        firebaseProjectId = 'memovault-dev';
        enableDetailedLogging = true;
        enableAnalytics = false;
      case Environment.staging:
        firebaseProjectId = 'memovault-staging';
        enableDetailedLogging = true;
        enableAnalytics = true;
      case Environment.prod:
        firebaseProjectId = 'memovault-prod';
        enableDetailedLogging = false;
        enableAnalytics = true;
    }
  }

  static bool get isProduction => environment == Environment.prod;
  static bool get isDevelopment => environment == Environment.dev;
}
