class User {
  final String id;
  final String phone;
  final String name;
  final String role;
  final DateTime createdAt;

  User({
    required this.id,
    required this.phone,
    required this.name,
    required this.role,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      phone: json['phone'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'name': name,
      'role': role,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isCustomer => role == 'customer';
  bool get isValet => role == 'valet';
}
