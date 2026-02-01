class Vehicle {
  final String id;
  final String ownerId;
  final String registrationNumber;
  final String make;
  final String model;
  final String color;
  final DateTime createdAt;

  Vehicle({
    required this.id,
    required this.ownerId,
    required this.registrationNumber,
    required this.make,
    required this.model,
    required this.color,
    required this.createdAt,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] ?? '',
      ownerId: json['owner_id'] ?? '',
      registrationNumber: json['registration_number'] ?? '',
      make: json['make'] ?? '',
      model: json['model'] ?? '',
      color: json['color'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'registration_number': registrationNumber,
      'make': make,
      'model': model,
      'color': color,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get displayName => '$make $model ($registrationNumber)';
}
