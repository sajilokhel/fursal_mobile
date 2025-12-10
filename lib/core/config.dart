class AppConfig {
  // Backend base URL
  // NOTE: Change this depending on your environment:
  // - Android Emulator: 'http://10.0.2.2:3000'
  // - iOS Simulator: 'http://localhost:3000'
  // - Physical Device: 'http://<YOUR_PC_IP>:3000' (e.g. 192.168.1.X)
  // - Production: 'https://www.sajilokhel.com'
  static const String backendBaseUrl = 'http://192.168.1.90:3000';

  // Helper to get the API endpoint base
  static String get apiUrl => '$backendBaseUrl/api';

  // Endpoints
  static String paymentInitiateUrl() => '$backendBaseUrl/api/payment/initiate';
}
