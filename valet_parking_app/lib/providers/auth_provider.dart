import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService;

  User? _user;
  String? _token;
  bool _isLoading = false;
  String? _error;
  String? _pendingOtp; // Store OTP for display in MVP

  AuthProvider(this._apiService);

  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get pendingOtp => _pendingOtp;
  bool get isAuthenticated => _token != null && _user != null;
  bool get isCustomer => _user?.isCustomer ?? false;
  bool get isValet => _user?.isValet ?? false;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');

    if (_token != null) {
      _apiService.setToken(_token!);

      // Load user from storage
      final userData = prefs.getString('user');
      if (userData != null) {
        try {
          _user = User.fromJson(
            Map<String, dynamic>.from(
              Uri.splitQueryString(userData).map(
                (k, v) => MapEntry(k, v),
              ),
            ),
          );
        } catch (e) {
          await logout();
        }
      }
    }

    notifyListeners();
  }

  Future<bool> sendOtp(String phone, String role) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.sendOtp(phone, role);
      _pendingOtp = response['otp']; // Store OTP for MVP display
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyOtp(String phone, String otp, String name) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.verifyOtp(phone, otp, name);

      _token = response['token'];
      _user = User.fromJson(response['user']);
      _pendingOtp = null;

      _apiService.setToken(_token!);

      // Save to storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token!);
      await prefs.setString('user_id', _user!.id);
      await prefs.setString('user_role', _user!.role);
      await prefs.setString('user_phone', _user!.phone);
      await prefs.setString('user_name', _user!.name);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _user = null;
    _token = null;
    _pendingOtp = null;
    _apiService.clearToken();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
