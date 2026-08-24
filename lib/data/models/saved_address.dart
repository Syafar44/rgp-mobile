/// Alamat pengiriman yang disimpan pengguna (tab Delivery).
class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.label,
    required this.fullAddress,
    required this.recipient,
    required this.phone,
    this.note = '',
    this.isPrimary = false,
    this.lat,
    this.lon,
  });

  final String id;

  /// Nama alamat, mis. "Rumah", "Gerai panglima".
  final String label;

  /// Alamat lengkap (hasil geolokasi).
  final String fullAddress;

  /// Nama penerima.
  final String recipient;
  final String phone;

  /// Catatan spesial (patokan, nomor rumah).
  final String note;

  /// Jadikan alamat utama untuk delivery.
  final bool isPrimary;

  /// Koordinat hasil pilih di peta (OpenStreetMap).
  final double? lat;
  final double? lon;

  SavedAddress copyWith({
    String? label,
    String? fullAddress,
    String? recipient,
    String? phone,
    String? note,
    bool? isPrimary,
    double? lat,
    double? lon,
  }) {
    return SavedAddress(
      id: id,
      label: label ?? this.label,
      fullAddress: fullAddress ?? this.fullAddress,
      recipient: recipient ?? this.recipient,
      phone: phone ?? this.phone,
      note: note ?? this.note,
      isPrimary: isPrimary ?? this.isPrimary,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
    );
  }
}
