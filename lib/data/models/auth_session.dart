/// Hasil `POST /auth` — identitas pengguna + token JWT.
///
/// PENTING: [emailVerified] adalah status verifikasi **pada saat token ini
/// dibuat** dan ikut disematkan di dalam JWT. Nilainya TIDAK berubah otomatis
/// selama token masih berlaku (24 jam). Setelah `POST /verify_email` sukses,
/// aplikasi WAJIB memanggil `/auth` lagi untuk mendapat token baru — lihat
/// `AuthRepository.verifyEmailAndRefresh`.
class AuthSession {
  const AuthSession({
    required this.id,
    required this.name,
    required this.email,
    required this.emailVerified,
    required this.roles,
    required this.token,
    this.department = '',
    this.customer = const [],
    this.customerInfo = const [],
  });

  final String id;
  final String name;
  final String email;
  final bool emailVerified;
  final String roles;
  final String token;
  final String department;

  /// Id customer yang boleh diakses akun ini. Untuk customer end user berisi
  /// satu id miliknya sendiri; untuk akun karyawan berisi `["*"]`.
  final List<String> customer;

  final List<CustomerInfo> customerInfo;

  /// True bila akun ini punya akses "seluruh customer" (penanda `*`).
  bool get isAllCustomer => customer.contains('*');

  /// Id customer milik akun ini. Null untuk akun ber-penanda `*` — `"*"`
  /// BUKAN id sungguhan dan tidak boleh dikirim sebagai `customer_id`.
  String? get customerId {
    for (final id in customer) {
      if (id != '*' && id.isNotEmpty) return id;
    }
    return null;
  }

  /// Alamat customer dari `customer_info` (kosong bila tidak ada).
  String get address => customerInfo.isEmpty ? '' : customerInfo.first.address;

  /// Bentuk respons: `{"message": "Success", "data": { ... }}`.
  factory AuthSession.fromResponse(Map<String, dynamic> body) {
    final data = (body['data'] as Map?)?.cast<String, dynamic>() ?? const {};
    return AuthSession(
      id: data['id']?.toString() ?? '',
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      emailVerified: data['email_verified'] == true,
      roles: data['roles'] as String? ?? '',
      token: data['token'] as String? ?? '',
      department: data['department'] as String? ?? '',
      customer: (data['customer'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const [],
      customerInfo: (data['customer_info'] as List?)
              ?.whereType<Map>()
              .map((e) => CustomerInfo.fromJson(e.cast<String, dynamic>()))
              .toList(growable: false) ??
          const [],
    );
  }

  AuthSession copyWith({bool? emailVerified, String? token}) => AuthSession(
    id: id,
    name: name,
    email: email,
    emailVerified: emailVerified ?? this.emailVerified,
    roles: roles,
    token: token ?? this.token,
    department: department,
    customer: customer,
    customerInfo: customerInfo,
  );
}

/// Satu entri `customer_info` pada respons `/auth`.
class CustomerInfo {
  const CustomerInfo({
    required this.id,
    required this.address,
    this.lat = '',
    this.long = '',
  });

  final String id;
  final String address;
  final String lat;
  final String long;

  factory CustomerInfo.fromJson(Map<String, dynamic> json) => CustomerInfo(
    id: json['id']?.toString() ?? '',
    address: json['address'] as String? ?? '',
    lat: json['lat']?.toString() ?? '',
    long: json['long']?.toString() ?? '',
  );
}
