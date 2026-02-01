class ApiConfig {
  // Change this to your backend URL
  // For Android emulator use: 10.0.2.2:8080
  // For iOS simulator use: localhost:8080
  // For physical device use your computer's IP: 192.168.x.x:8080
  static const String baseUrl = 'http://192.168.29.47:8080/api';

  // Endpoints
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String vehicles = '/vehicles';
  static const String vehicleSearch = '/vehicles/search';
  static const String sessions = '/sessions';
  static const String activeSession = '/sessions/active';
  static const String pendingPickups = '/sessions/pending-pickups';
  static const String allActiveSessions = '/sessions/active-all';

  static String sessionById(String id) => '/sessions/$id';
  static String requestPickup(String id) => '/sessions/$id/request-pickup';
  static String verifyDelivery(String id) => '/sessions/$id/verify-delivery';
  static String updateStatus(String id) => '/sessions/$id/status';
  static String acceptParking(String id) => '/sessions/$id/accept';
  static String rejectParking(String id) => '/sessions/$id/reject';
  static String cancelPickup(String id) => '/sessions/$id/cancel-pickup';
  static const String history = '/sessions/history';
}
