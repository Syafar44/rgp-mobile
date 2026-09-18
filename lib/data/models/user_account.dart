/// Akun pengguna yang sedang/pernah masuk di perangkat ini.
///
/// Seluruh data berasal dari respons `/auth`; kata sandi TIDAK pernah disimpan
/// di perangkat — pemeriksaan kredensial sepenuhnya di server. Nomor HP
/// ([phone], `contact` di sisi server) dipakai sebagai identitas lokal.
class UserAccount {
  const UserAccount({
    required this.phone,
    required this.name,
    required this.email,
    required this.id,
    this.address = '',
    this.emailVerified = false,
  });

  final String phone;
  final String name;
  final String email;

  /// Id user dari server.
  final String id;

  final String address;

  /// Status verifikasi email terakhir yang diketahui (dari token `/auth`).
  final bool emailVerified;

  UserAccount copyWith({bool? emailVerified, String? address}) => UserAccount(
    phone: phone,
    name: name,
    email: email,
    id: id,
    address: address ?? this.address,
    emailVerified: emailVerified ?? this.emailVerified,
  );

  Map<String, dynamic> toJson() => {
    'phone': phone,
    'name': name,
    'email': email,
    'id': id,
    'address': address,
    'emailVerified': emailVerified,
  };

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
    phone: json['phone'] as String? ?? '',
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    id: json['id']?.toString() ?? '',
    address: json['address'] as String? ?? '',
    emailVerified: json['emailVerified'] == true,
  );
}
