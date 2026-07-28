class UserModel {
  final String id;
  final String username;
  final String name;
  final String role; // Admin, Pharmacist, Cashier

  UserModel({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      username: json['username'] as String,
      name: json['name'] as String,
      role: json['role'] as String? ?? 'Pharmacist',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'name': name,
      'role': role,
    };
  }
}
