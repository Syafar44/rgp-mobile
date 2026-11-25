import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/dio_client.dart';
import '../core/utils/app_log.dart';
import 'models/auth_session.dart';
import 'models/customer_profile.dart';
import 'models/user_account.dart';
import 'models/user_profile.dart';

/// Penyimpanan status autentikasi.
///
/// [currentUser] = null berarti belum masuk. Semua akun berasal dari API dan
/// masuk lewat [applySession] (hasil `POST /auth`); kata sandi tidak pernah
/// disimpan di perangkat, jadi tidak ada pemeriksaan kredensial lokal.
///
/// [knownAccounts] hanyalah cache akun yang pernah masuk di perangkat ini —
/// dipakai agar pengguna lama cukup mengetik nomor HP, bukan untuk menentukan
/// boleh/tidaknya masuk. Cache & token dipertahankan ke lokal HP
/// ([SharedPreferences]) agar sesi tidak hilang saat aplikasi ditutup.
/// Operasi penyimpanan best-effort; kegagalan (mis. plugin belum siap di test)
/// diabaikan.
class AuthStore {
  AuthStore();

  final ValueNotifier<UserAccount?> currentUser =
      ValueNotifier<UserAccount?>(null);

  /// Sesi API aktif (token + klaim). Null bila belum login lewat API pada
  /// proses aplikasi ini — token yang dipulihkan dari lokal tetap terpasang
  /// di Dio walau nilai ini null.
  final ValueNotifier<AuthSession?> session = ValueNotifier<AuthSession?>(null);

  /// Akun yang pernah masuk di perangkat ini.
  final List<UserAccount> _users = [];

  /// Kapan token yang sedang dipakai diterbitkan.
  DateTime? _tokenAt;

  static const String _kUsers = 'auth_users_v2';
  static const String _kCurrent = 'auth_current_v2';
  static const String _kToken = 'auth_token_v2';
  static const String _kTokenAt = 'auth_token_at_v2';

  /// Masa berlaku token dari server (dikonfirmasi tim backend: 1 hari).
  ///
  /// Dipakai untuk memulangkan pembeli ke layar masuk **sebelum** ia menabrak
  /// 401 di tengah memesan. Interceptor di `dio_client` tetap ada sebagai
  /// jaring pengaman — kalau server memperpendek masa berlakunya, atau token
  /// dicabut lebih awal, yang menangkap adalah interceptor itu.
  static const Duration tokenLifetime = Duration(days: 1);

  bool get isLoggedIn => currentUser.value != null;

  List<UserAccount> get knownAccounts => List.unmodifiable(_users);

  /// True bila email akun aktif sudah terverifikasi.
  ///
  /// Catatan: ini murni sinyal UI. Server BELUM menegakkan `email_verified`
  /// di endpoint transaksi (lihat API_REGISTER_FLUTTER.md), jadi jangan
  /// dianggap sebagai pengaman.
  bool get isEmailVerified => currentUser.value?.emailVerified ?? false;

  /// Cari akun yang pernah masuk di perangkat ini berdasarkan nomor HP atau
  /// email. Null berarti "tidak dikenal di perangkat ini" — BUKAN berarti
  /// belum terdaftar di server (API tidak menyediakan cara mengecek itu).
  UserAccount? findAccount(String phoneOrEmail) {
    final q = phoneOrEmail.trim();
    if (q.isEmpty) return null;
    final qLower = q.toLowerCase();
    for (final u in _users) {
      if (u.phone == q || u.email.toLowerCase() == qLower) return u;
    }
    return null;
  }

  /// Simpan sesi hasil `/auth`: pasang token ke Dio, catat akun, dan masuk.
  ///
  /// [phone] hanya identitas lokal (server menyebutnya `contact`) dan boleh
  /// kosong bila pengguna masuk memakai email — identitas sebenarnya adalah
  /// email dari respons `/auth`.
  Future<void> applySession(
    AuthSession newSession, {
    String phone = '',
    String? address,
  }) async {
    final account = UserAccount(
      phone: phone.trim(),
      name: newSession.name,
      email: newSession.email,
      id: newSession.id,
      address: address ?? newSession.address,
      emailVerified: newSession.emailVerified,
    );
    setAuthToken(newSession.token);
    // Token baru → masa berlakunya dihitung dari sekarang.
    _tokenAt = DateTime.now();
    _upsert(account);
    session.value = newSession;
    currentUser.value = account;
    await _save();
  }

  /// Selaraskan akun aktif dengan hasil `GET /me`.
  ///
  /// Dipanggil setelah profil dimuat agar nama/email/status verifikasi yang
  /// ditampilkan berasal dari token yang benar-benar dipakai server.
  Future<void> applyProfile(UserProfile profile) async {
    final cur = currentUser.value;
    if (cur == null) return;
    final updated = UserAccount(
      phone: cur.phone,
      name: profile.name.isEmpty ? cur.name : profile.name,
      email: profile.email.isEmpty ? cur.email : profile.email,
      id: profile.userId.isEmpty ? cur.id : profile.userId,
      address: cur.address,
      emailVerified: profile.emailVerified,
    );
    _upsert(updated);
    currentUser.value = updated;
    await _save();
  }

  /// Selaraskan akun aktif dengan `GET /customer/me`.
  ///
  /// Inilah sumber nomor HP & alamat: `/auth` maupun `/me` tidak
  /// mengirimkannya, hanya grup `/customer` yang punya.
  Future<void> applyCustomer(CustomerProfile profile) async {
    final cur = currentUser.value;
    if (cur == null) return;
    final updated = UserAccount(
      phone: profile.contact.trim().isEmpty ? cur.phone : profile.contact.trim(),
      name: profile.name.trim().isEmpty ? cur.name : profile.name.trim(),
      email: profile.email.trim().isEmpty ? cur.email : profile.email.trim(),
      id: cur.id,
      address: profile.address.trim().isEmpty ? cur.address : profile.address,
      emailVerified: cur.emailVerified,
    );
    _upsert(updated);
    currentUser.value = updated;
    await _save();
  }

  /// Simpan nomor HP akun aktif.
  ///
  /// Perlu ada karena `/auth` maupun `/me` tidak mengirim `contact` — nomor
  /// hanya diketahui saat mendaftar, atau saat pembeli mengetikkannya sendiri
  /// (mis. ketika gateway pembayaran memintanya). Menyimpannya membuat
  /// pertanyaan itu cukup sekali per perangkat.
  Future<void> setPhone(String phone) async {
    final cur = currentUser.value;
    final trimmed = phone.trim();
    if (cur == null || trimmed.isEmpty || cur.phone == trimmed) return;

    final updated = UserAccount(
      phone: trimmed,
      name: cur.name,
      email: cur.email,
      id: cur.id,
      address: cur.address,
      emailVerified: cur.emailVerified,
    );
    _upsert(updated);
    currentUser.value = updated;
    await _save();
  }

  void logout() {
    setAuthToken(null);
    _tokenAt = null;
    session.value = null;
    currentUser.value = null;
    _save();
  }

  /// Muat akun, sesi & token dari lokal. Panggil sekali saat aplikasi start.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawUsers = prefs.getString(_kUsers);
      if (rawUsers != null) {
        final decoded = jsonDecode(rawUsers) as List<dynamic>;
        for (final e in decoded) {
          _upsert(UserAccount.fromJson(e as Map<String, dynamic>));
        }
      }
      final token = prefs.getString(_kToken);
      final tokenAt = prefs.getInt(_kTokenAt);

      // Token lewat masa berlaku → jangan dipulihkan sama sekali. Memulihkan
      // sesi yang sudah mati membuat pembeli menyangka masih masuk, lalu
      // setiap permintaan ditolak satu per satu.
      final kedaluwarsa =
          tokenAt != null &&
          DateTime.now().millisecondsSinceEpoch - tokenAt >
              tokenLifetime.inMilliseconds;
      if (kedaluwarsa) {
        AppLog.info('AUTH', 'sesi tersimpan sudah lewat 1 hari — dibersihkan');
        await prefs.remove(_kCurrent);
        await prefs.remove(_kToken);
        await prefs.remove(_kTokenAt);
        return;
      }

      if (token != null && token.isNotEmpty) {
        setAuthToken(token);
        _tokenAt = tokenAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(tokenAt);
      }

      final cur = prefs.getString(_kCurrent);
      if (cur != null) currentUser.value = findAccount(cur);
    } catch (_) {
      // Abaikan: plugin belum siap atau data tidak valid.
    }
  }

  /// Tambah/ganti akun di cache (kunci: nomor HP atau email yang sama).
  void _upsert(UserAccount account) {
    final email = account.email.toLowerCase();
    _users.removeWhere(
      (u) =>
          u.phone == account.phone ||
          (email.isNotEmpty && u.email.toLowerCase() == email),
    );
    _users.add(account);
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kUsers,
        jsonEncode(_users.map((e) => e.toJson()).toList()),
      );
      final cur = currentUser.value;
      if (cur == null) {
        await prefs.remove(_kCurrent);
        await prefs.remove(_kToken);
        await prefs.remove(_kTokenAt);
      } else {
        // Email adalah identitas di server; nomor HP hanya pelengkap lokal.
        await prefs.setString(
          _kCurrent,
          cur.email.isNotEmpty ? cur.email : cur.phone,
        );
        final token = authToken;
        if (token == null || token.isEmpty) {
          await prefs.remove(_kToken);
          await prefs.remove(_kTokenAt);
        } else {
          await prefs.setString(_kToken, token);
          final at = _tokenAt;
          if (at != null) {
            await prefs.setInt(_kTokenAt, at.millisecondsSinceEpoch);
          }
        }
      }
    } catch (_) {
      // Abaikan kegagalan penyimpanan (best-effort).
    }
  }
}

/// Instance global. Dimuat dari lokal saat `main()`.
final AuthStore authStore = AuthStore();
