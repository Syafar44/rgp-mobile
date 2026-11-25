import '../core/config/env.dart';
import '../core/utils/app_log.dart';
import 'auth_store.dart';
import 'cart_store.dart';
import 'location_service.dart';
import 'models/outlet.dart';
import 'outlet_repository.dart';
import 'outlet_store.dart';

/// Pilihkan outlet terdekat secara otomatis saat aplikasi dibuka.
///
/// Memilih outlet adalah syarat sebelum pembeli bisa melihat menu sama sekali,
/// dan hampir selalu jawabannya "yang paling dekat". Jadi aplikasi selalu
/// menyesuaikannya dengan posisi pembeli tiap sesi dimulai; pembeli tetap bisa
/// menggantinya sendiri lewat kartu lokasi di Beranda.
///
/// **Menimpa pilihan sebelumnya.** Outlet dari sesi lama sengaja tidak
/// dipertahankan — keputusan produk, supaya orang yang berpindah kota tidak
/// diam-diam memesan ke outlet yang ia tinggalkan. Konsekuensinya: keranjang
/// yang masih berisi menu dari outlet lama **ditinggalkan tanpa konfirmasi**
/// (aturan server: satu pembeli satu keranjang aktif).
///
/// **Hanya dipanggil saat sesi dimulai**, bukan tiap aplikasi kembali dari
/// latar belakang — lihat `WidgetTree.initState`. Outlet yang berganti sendiri
/// di tengah pembeli memilih menu lebih membingungkan daripada berguna.
///
/// **Sepenuhnya best-effort.** GPS mati, izin ditolak, atau jaringan bermasalah
/// tidak menghasilkan galat apa pun — outlet sebelumnya (bila ada) dibiarkan
/// apa adanya dan pembeli bisa memilih manual. Mengembalikan outlet yang baru
/// dipilih, atau null bila tidak ada perubahan.
Future<Outlet?> autoSelectNearestOutlet() async {
  const tag = 'OUTLET';

  // `POST /outlets/nearby` butuh token Bearer, dan tanpa BASE_URL daftar
  // outletnya tidak mungkin diambil — percuma meminta izin lokasi.
  if (!authStore.isLoggedIn || !Env.isConfigured) return null;

  final sebelum = outletStore.outlet;

  try {
    AppLog.info(
      tag,
      'mencari outlet terdekat…',
      detail: sebelum == null ? 'belum ada outlet' : 'sekarang: ${sebelum.name}',
    );
    final posisi = await locationService.getCurrentPosition();

    // Server sudah mengurutkan dari yang terdekat; ambil yang teratas.
    final outlets = await outletRepository.nearby(
      lat: posisi.latitude,
      long: posisi.longitude,
      limit: 5,
    );
    if (outlets.isEmpty) {
      AppLog.warn(tag, 'tidak ada outlet di sekitar — pilihan lama dibiarkan');
      return null;
    }

    // Pembeli bisa saja memilih sendiri selagi GPS & permintaan jaringan di
    // atas berjalan (beberapa detik). Menimpa pilihan yang baru saja ia
    // ketuk akan terlihat seperti kerusakan, jadi yang ditimpa hanya outlet
    // yang memang belum ia sentuh pada sesi ini.
    if (outletStore.outlet?.id != sebelum?.id) {
      AppLog.info(tag, 'pembeli memilih sendiri saat pencarian — GPS diabaikan');
      return null;
    }

    final terdekat = outlets.first;
    if (terdekat.id == sebelum?.id) {
      AppLog.info(tag, 'outlet terdekat sama dengan yang aktif: ${terdekat.name}');
      return null;
    }

    outletStore.select(terdekat);
    // Keranjang dimuat ulang untuk outlet baru. Tanpa ini, bilah keranjang
    // masih memperlihatkan isi milik outlet lama.
    await cartStore.syncWithSelectedOutlet();

    AppLog.info(
      tag,
      'outlet berpindah ke ${terdekat.name}',
      detail: 'dari ${sebelum?.name ?? '(belum ada)'} · '
          'jarak ${terdekat.distanceKm} km · '
          'dari ${outlets.length} outlet di sekitar',
    );
    return terdekat;
  } on LocationException catch (e) {
    // Lumrah: GPS mati atau izin ditolak. Bukan kerusakan.
    AppLog.info(tag, 'lokasi tidak tersedia', detail: e.message);
  } catch (e) {
    AppLog.warn(tag, 'gagal memilih outlet otomatis', detail: e.toString());
  }
  return null;
}
