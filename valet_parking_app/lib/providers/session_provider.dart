import 'package:flutter/material.dart';
import '../models/session.dart';
import '../models/vehicle.dart';
import '../services/api_service.dart';

class SessionProvider with ChangeNotifier {
  final ApiService _apiService;

  ParkingSession? _activeSession;
  List<Vehicle> _vehicles = [];
  List<ParkingSession> _pendingPickups = [];
  List<ParkingSession> _allActiveSessions = [];
  List<ParkingSession> _history = [];
  bool _isLoading = false;
  String? _error;
  String? _pickupOtp;

  SessionProvider(this._apiService);

  ParkingSession? get activeSession => _activeSession;
  List<Vehicle> get vehicles => _vehicles;
  List<ParkingSession> get pendingPickups => _pendingPickups;
  List<ParkingSession> get allActiveSessions => _allActiveSessions;
  List<ParkingSession> get history => _history;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get pickupOtp => _pickupOtp;

  // Silent refresh - doesn't set loading state (for polling)
  Future<void> refreshActiveSession() async {
    try {
      final data = await _apiService.getActiveSession();
      _activeSession = ParkingSession.fromJson(data);
      notifyListeners();
    } catch (e) {
      _activeSession = null;
      notifyListeners();
    }
  }

  Future<void> loadActiveSession() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _apiService.getActiveSession();
      _activeSession = ParkingSession.fromJson(data);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _activeSession = null;
      _error = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadVehicles() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _apiService.getVehicles();
      _vehicles = data.map((v) => Vehicle.fromJson(v)).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addVehicle({
    required String registrationNumber,
    required String make,
    required String model,
    required String color,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _apiService.addVehicle(
        registrationNumber: registrationNumber,
        make: make,
        model: model,
        color: color,
      );
      _vehicles.add(Vehicle.fromJson(data));
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

  Future<Map<String, dynamic>?> searchVehicle(String registrationNumber) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _apiService.searchVehicle(registrationNumber);
      _isLoading = false;
      notifyListeners();
      return data;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> createSession({
    required String vehicleId,
    required String customerId,
    required String venueName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.createSession(
        vehicleId: vehicleId,
        customerId: customerId,
        venueName: venueName,
      );
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

  Future<bool> requestPickup() async {
    if (_activeSession == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _apiService.requestPickup(_activeSession!.id);
      _pickupOtp = data['pickup_otp'];
      await loadActiveSession();
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

  // Silent refresh for polling
  Future<void> refreshPendingPickups() async {
    try {
      final data = await _apiService.getPendingPickups();
      _pendingPickups = data.map((s) => ParkingSession.fromJson(s)).toList();
      notifyListeners();
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> loadPendingPickups() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _apiService.getPendingPickups();
      _pendingPickups = data.map((s) => ParkingSession.fromJson(s)).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Silent refresh for polling
  Future<void> refreshAllActiveSessions() async {
    try {
      final data = await _apiService.getAllActiveSessions();
      _allActiveSessions = data.map((s) => ParkingSession.fromJson(s)).toList();
      notifyListeners();
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> loadAllActiveSessions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _apiService.getAllActiveSessions();
      _allActiveSessions = data.map((s) => ParkingSession.fromJson(s)).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadHistory() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _apiService.getHistory();
      _history = data.map((s) => ParkingSession.fromJson(s)).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyDelivery(String sessionId, String otp) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.verifyDelivery(sessionId, otp);
      await loadPendingPickups();
      _pickupOtp = null; // Clear OTP after delivery
      _activeSession = null; // Clear active session
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

  void clearPickupOtp() {
    _pickupOtp = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<bool> updateSessionStatus(String sessionId, String status) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.updateSessionStatus(sessionId, status);
      await refreshPendingPickups();
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

  Future<bool> acceptParking() async {
    if (_activeSession == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.acceptParking(_activeSession!.id);
      await loadActiveSession();
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

  Future<bool> rejectParking() async {
    if (_activeSession == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.rejectParking(_activeSession!.id);
      _activeSession = null;
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

  Future<bool> cancelPickup() async {
    if (_activeSession == null) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.cancelPickup(_activeSession!.id);
      _pickupOtp = null;
      await loadActiveSession();
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
}
