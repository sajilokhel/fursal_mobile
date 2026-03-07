class AppConfig {
  // Backend base URL resolved at compile time via --dart-define.
  //
  // Usage examples:
  //   flutter run --dart-define=BACKEND_URL=http://10.0.2.2:3000   (Android emulator)
  //   flutter run --dart-define=BACKEND_URL=http://localhost:3000   (iOS simulator)
  //   flutter run --dart-define=BACKEND_URL=http://192.168.1.X:3000 (physical device)
  //   flutter run   (no define → defaults to production)
  //
  // For release builds the CI/CD pipeline should NOT pass BACKEND_URL so it
  // automatically falls back to the production URL.
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://www.sajilokhel.com',
  );

  // Helper to get the API endpoint base
  static String get apiUrl => '$backendBaseUrl/api';

  // Endpoints
  static String paymentInitiateUrl() => '$backendBaseUrl/api/payment/initiate';
}
