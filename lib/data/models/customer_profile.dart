/// Profil customer end user (`GET /customer/me`).
///
/// Berbeda dari [UserProfile] yang berasal dari `GET /me`: `/me` hanya membaca
/// klaim token (identitas & hak akses), sedangkan data customer — **nomor
/// kontak, alamat, dan kode customer** — hanya ada di sini.
library;

class CustomerProfile {
  const CustomerProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.contact,
    required this.address,
    this.code = '',
    this.customerGroupsId = 0,
    this.isActive = true,
  });

  /// Id baris customer — bukan id user.
  final int id;

  final String name;

  /// Terikat proses verifikasi; tidak bisa diubah lewat API profil.
  final String email;

  /// Nomor HP.
  final String contact;

  final String address;

  /// Kode customer, dibuat saat registrasi (mis. `CUS1788585593655`).
  final String code;

  final int customerGroupsId;

  /// Status aktif dari sisi admin.
  final bool isActive;

  factory CustomerProfile.fromJson(Map<String, dynamic> json) =>
      CustomerProfile(
        id: _int(json['id']) ?? 0,
        name: (json['name'] ?? '').toString(),
        email: (json['email'] ?? '').toString(),
        contact: (json['contact'] ?? '').toString(),
        address: (json['address'] ?? '').toString(),
        code: (json['code'] ?? '').toString(),
        customerGroupsId: _int(json['customer_groups_id']) ?? 0,
        isActive: json['is_active'] != false,
      );
}

int? _int(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}
