import 'user.dart';
import 'vehicle.dart';

enum SessionStatus { pending, parked, requested, moving, available, delivered, cancelled, inTransit }

class ParkingSession {
  final String id;
  final String ticketNumber;
  final String vehicleId;
  final String customerId;
  final String valetId;
  final String venueName;
  final SessionStatus status;
  final DateTime parkedAt;
  final DateTime? requestedAt;
  final DateTime? deliveredAt;
  final String? pickupOtp;
  final DateTime? otpExpiresAt;

  // Related data
  Vehicle? vehicle;
  User? customer;
  User? valet;

  ParkingSession({
    required this.id,
    required this.ticketNumber,
    required this.vehicleId,
    required this.customerId,
    required this.valetId,
    required this.venueName,
    required this.status,
    required this.parkedAt,
    this.requestedAt,
    this.deliveredAt,
    this.pickupOtp,
    this.otpExpiresAt,
    this.vehicle,
    this.customer,
    this.valet,
  });

  factory ParkingSession.fromJson(Map<String, dynamic> json) {
    final sessionData = json['session'] ?? json;

    SessionStatus parseStatus(String? s) {
      switch (s) {
        case 'pending': return SessionStatus.pending;
        case 'parked': return SessionStatus.parked;
        case 'requested': return SessionStatus.requested;
        case 'moving': return SessionStatus.moving;
        case 'available': return SessionStatus.available;
        case 'delivered': return SessionStatus.delivered;
        case 'cancelled': return SessionStatus.cancelled;
        case 'in_transit': return SessionStatus.inTransit;
        default: return SessionStatus.parked;
      }
    }

    return ParkingSession(
      id: sessionData['id'] ?? '',
      ticketNumber: sessionData['ticket_number'] ?? '',
      vehicleId: sessionData['vehicle_id'] ?? '',
      customerId: sessionData['customer_id'] ?? '',
      valetId: sessionData['valet_id'] ?? '',
      venueName: sessionData['venue_name'] ?? '',
      status: parseStatus(sessionData['status']),
      parkedAt: sessionData['parked_at'] != null
          ? DateTime.parse(sessionData['parked_at'])
          : DateTime.now(),
      requestedAt: sessionData['requested_at'] != null
          ? DateTime.parse(sessionData['requested_at'])
          : null,
      deliveredAt: sessionData['delivered_at'] != null
          ? DateTime.parse(sessionData['delivered_at'])
          : null,
      pickupOtp: sessionData['pickup_otp'],
      otpExpiresAt: sessionData['otp_expires_at'] != null
          ? DateTime.parse(sessionData['otp_expires_at'])
          : null,
      vehicle: json['vehicle'] != null ? Vehicle.fromJson(json['vehicle']) : null,
      customer: json['customer'] != null ? User.fromJson(json['customer']) : null,
      valet: json['valet'] != null ? User.fromJson(json['valet']) : null,
    );
  }

  String get statusText {
    switch (status) {
      case SessionStatus.pending: return 'Waiting for Approval';
      case SessionStatus.parked: return 'Parked';
      case SessionStatus.requested: return 'Pickup Requested';
      case SessionStatus.moving: return 'Valet on the way';
      case SessionStatus.available: return 'Ready for Pickup';
      case SessionStatus.delivered: return 'Delivered';
      case SessionStatus.cancelled: return 'Cancelled';
      case SessionStatus.inTransit: return 'In Transit';
    }
  }
}
