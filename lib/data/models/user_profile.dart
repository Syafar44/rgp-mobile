/// Profil pengguna dari `GET /me`.
///
/// PENTING: `/me` membaca **klaim token JWT**, bukan query database baru. Jadi
/// [emailVerified] membawa nilai yang sama persis dengan saat token itu dibuat
/// — bila token belum diperbarui setelah verifikasi, `/me` tetap melaporkan
/// `false`. `/me` bukan cara mendapatkan status verifikasi terkini; untuk itu
/// harus login ulang (`POST /auth`).
class UserProfile {
  const UserProfile({
    required this.userId,
    required this.name,
    required this.email,
    required this.emailVerified,
    this.department = '',
    this.roles = '',
    this.customer = const [],
  });

  final String userId;
  final String name;
  final String email;
  final bool emailVerified;
  final String department;
  final String roles;

  /// Id customer yang boleh diakses. Untuk akun karyawan berisi `["*"]` —
  /// penanda "tanpa batas", bukan id sungguhan.
  final List<String> customer;

  /// Id customer milik akun ini, mengabaikan penanda `"*"`.
  String? get customerId {
    for (final id in customer) {
      if (id != '*' && id.isNotEmpty) return id;
    }
    return null;
  }

  /// Bentuk respons: `{"message": "success", "data": { ... }}`.
  factory UserProfile.fromResponse(Map<String, dynamic> body) {
    final data = (body['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    return UserProfile(
      userId: data['userid']?.toString() ?? '',
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      emailVerified: data['email_verified'] == true,
      department: data['department'] as String? ?? '',
      roles: data['roles'] as String? ?? '',
      customer:
          (data['customer'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const [],
    );
  }
}
