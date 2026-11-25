/// Pembaruan aplikasi lewat **Google Play In-App Updates**.
///
/// Hanya berfungsi pada aplikasi yang dipasang dari Google Play (termasuk
/// jalur uji internal/tertutup). Build debug atau APK pasang-manual akan
/// ditolak Play — galatnya ditelan, aplikasi tetap jalan seperti biasa.
library;

import 'package:in_app_update/in_app_update.dart';

/// Prioritas mulai angka ini = update wajib (modal tidak bisa ditutup).
///
/// Prioritas 0–5 diisi saat merilis lewat **Google Play Developer API**
/// (`inAppUpdatePriority` pada track) — tidak ada isiannya di tampilan Play
/// Console. Tanpa diisi nilainya 0, jadi update selalu opsional.
const int kPrioritasWajib = 4;

/// Apa yang harus dilakukan aplikasi terhadap hasil pemeriksaan.
enum UpdatePlan {
  /// Tidak ada versi baru (atau Play tidak mengizinkan update langsung).
  tidakAda,

  /// Ada versi baru — pembeli boleh menundanya.
  opsional,

  /// Ada versi baru yang wajib dipasang sebelum aplikasi dipakai.
  wajib,

  /// Update langsung sudah dimulai sebelumnya lalu aplikasi ditutup di
  /// tengahnya. Aturan Play: lanjutkan, tanpa bertanya lagi.
  lanjutkan,
}

/// Terjemahkan hasil `checkForUpdate` menjadi [UpdatePlan].
UpdatePlan rencanaUpdate(AppUpdateInfo info) {
  switch (info.updateAvailability) {
    case UpdateAvailability.developerTriggeredUpdateInProgress:
      return UpdatePlan.lanjutkan;
    case UpdateAvailability.updateAvailable:
      // Layar update Play (immediate) bisa saja tidak diizinkan, mis. ruang
      // penyimpanan kurang — jangan menawarkan sesuatu yang pasti gagal.
      if (!info.immediateUpdateAllowed) return UpdatePlan.tidakAda;
      return info.updatePriority >= kPrioritasWajib
          ? UpdatePlan.wajib
          : UpdatePlan.opsional;
    case UpdateAvailability.updateNotAvailable:
    case UpdateAvailability.unknown:
      return UpdatePlan.tidakAda;
  }
}

/// Sumber pemeriksaan — diganti di test.
typedef UpdateChecker = Future<AppUpdateInfo> Function();

/// Pemasang update (layar penuh Google Play) — diganti di test.
typedef UpdatePerformer = Future<AppUpdateResult> Function();
