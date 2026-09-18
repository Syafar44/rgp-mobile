/// Outlet Panglima dari API (`POST /pos/app/v1/outlets/nearby`).
class Outlet {
  const Outlet({
    required this.id,
    required this.name,
    required this.address,
    this.lat,
    this.long,
    this.outletHubTypesId,
    this.distanceKm,
  });

  final int id;
  final String name;
  final String address;
  final double? lat;
  final double? long;
  final int? outletHubTypesId;

  /// Jarak dari lokasi pengguna dalam km (dari respons `nearby`).
  final double? distanceKm;

  factory Outlet.fromJson(Map<String, dynamic> json) => Outlet(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    address: json['address'] as String? ?? '',
    lat: (json['lat'] as num?)?.toDouble(),
    long: (json['long'] as num?)?.toDouble(),
    outletHubTypesId: (json['outlet_hub_types_id'] as num?)?.toInt(),
    distanceKm: (json['distance_km'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'lat': lat,
    'long': long,
    'outlet_hub_types_id': outletHubTypesId,
    'distance_km': distanceKm,
  };

  @override
  bool operator ==(Object other) =>
      other is Outlet && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}
