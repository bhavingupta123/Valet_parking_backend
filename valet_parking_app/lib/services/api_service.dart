import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiService {
  String? _token;

  void setToken(String token) {
    _token = token;
  }

  void clearToken() {
    _token = null;
  }

  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  dynamic _handleResponse(http.Response response) {
    final body = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    if (body is Map) {
      throw ApiException(
        body['error'] ?? 'Unknown error occurred',
        statusCode: response.statusCode,
      );
    }
    throw ApiException('Unknown error occurred', statusCode: response.statusCode);
  }

  // Auth
  Future<Map<String, dynamic>> sendOtp(String phone, String role) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.sendOtp}'),
      headers: _headers,
      body: jsonEncode({'phone': phone, 'role': role}),
    );
    return _handleResponse(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String otp, String name) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.verifyOtp}'),
      headers: _headers,
      body: jsonEncode({'phone': phone, 'otp': otp, 'name': name}),
    );
    return _handleResponse(response) as Map<String, dynamic>;
  }

  // Vehicles
  Future<List<dynamic>> getVehicles() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.vehicles}'),
      headers: _headers,
    );
    final data = _handleResponse(response);
    if (data is List) {
      return data;
    }
    return [];
  }

  Future<Map<String, dynamic>> addVehicle({
    required String registrationNumber,
    required String make,
    required String model,
    required String color,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.vehicles}'),
      headers: _headers,
      body: jsonEncode({
        'registration_number': registrationNumber,
        'make': make,
        'model': model,
        'color': color,
      }),
    );
    return _handleResponse(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> searchVehicle(String registrationNumber) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.vehicleSearch}?registration_number=$registrationNumber'),
      headers: _headers,
    );
    return _handleResponse(response) as Map<String, dynamic>;
  }

  // Sessions
  Future<Map<String, dynamic>> createSession({
    required String vehicleId,
    required String customerId,
    required String venueName,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.sessions}'),
      headers: _headers,
      body: jsonEncode({
        'vehicle_id': vehicleId,
        'customer_id': customerId,
        'venue_name': venueName,
      }),
    );
    return _handleResponse(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getActiveSession() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.activeSession}'),
      headers: _headers,
    );
    return _handleResponse(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSession(String id) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.sessionById(id)}'),
      headers: _headers,
    );
    return _handleResponse(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> requestPickup(String sessionId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.requestPickup(sessionId)}'),
      headers: _headers,
    );
    return _handleResponse(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyDelivery(String sessionId, String otp) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.verifyDelivery(sessionId)}'),
      headers: _headers,
      body: jsonEncode({'otp': otp}),
    );
    return _handleResponse(response) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getPendingPickups() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.pendingPickups}'),
      headers: _headers,
    );
    final data = _handleResponse(response);
    if (data is List) {
      return data;
    }
    return [];
  }

  Future<List<dynamic>> getAllActiveSessions() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.allActiveSessions}'),
      headers: _headers,
    );
    final data = _handleResponse(response);
    if (data is List) {
      return data;
    }
    return [];
  }

  Future<Map<String, dynamic>> updateSessionStatus(String sessionId, String status) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.updateStatus(sessionId)}'),
      headers: _headers,
      body: jsonEncode({'status': status}),
    );
    return _handleResponse(response) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getHistory() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.history}'),
      headers: _headers,
    );
    final data = _handleResponse(response);
    if (data is List) {
      return data;
    }
    return [];
  }

  Future<Map<String, dynamic>> acceptParking(String sessionId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.acceptParking(sessionId)}'),
      headers: _headers,
    );
    return _handleResponse(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> rejectParking(String sessionId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.rejectParking(sessionId)}'),
      headers: _headers,
    );
    return _handleResponse(response) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cancelPickup(String sessionId) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.cancelPickup(sessionId)}'),
      headers: _headers,
    );
    return _handleResponse(response) as Map<String, dynamic>;
  }
}
