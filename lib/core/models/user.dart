enum UserRole {
  admin,
  cashier,
  warehouse,
}

class AppUser {
  final int? id;
  final String username;
  final String password; // In a real app, this would be a hash
  final String name;
  final UserRole role;
  final DateTime createdAt;

  AppUser({
    this.id,
    required this.username,
    required this.password,
    required this.name,
    required this.role,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'name': name,
      'role': role.name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'],
      username: map['username'],
      password: map['password'],
      name: map['name'],
      role: UserRole.values.firstWhere((e) => e.name == map['role']),
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
