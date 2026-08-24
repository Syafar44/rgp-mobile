/// Profil pengguna aplikasi.
class UserProfile {
  const UserProfile({
    required this.name,
    required this.role,
    required this.phone,
    required this.email,
    this.avatarEmoji = '👤',
  });

  final String name;
  final String role;
  final String phone;
  final String email;
  final String avatarEmoji;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      avatarEmoji: json['avatarEmoji'] as String? ?? '👤',
    );
  }
}
