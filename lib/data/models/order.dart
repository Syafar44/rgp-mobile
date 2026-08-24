import 'product.dart';

/// Status sebuah pesanan.
enum OrderStatus {
  pending('Menunggu'),
  diproses('Diproses'),
  selesai('Selesai'),
  dibatalkan('Dibatalkan');

  const OrderStatus(this.label);

  /// Label untuk ditampilkan ke pengguna.
  final String label;

  /// Pesanan yang masih aktif (tampil di tab Pesanan).
  bool get isActive => this == pending || this == diproses;

  /// Pesanan yang sudah tuntas (tampil di tab History).
  bool get isDone => this == selesai || this == dibatalkan;
}

/// Satu baris item di dalam pesanan (produk + jumlah).
class OrderItem {
  const OrderItem({required this.product, required this.qty});

  final Product product;
  final int qty;

  int get subtotal => product.price * qty;
}

/// Sebuah pesanan pelanggan.
class Order {
  const Order({
    required this.id,
    required this.customer,
    required this.items,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String customer;
  final List<OrderItem> items;
  final OrderStatus status;
  final DateTime createdAt;

  /// Total harga seluruh item.
  int get total => items.fold(0, (sum, item) => sum + item.subtotal);

  /// Total jumlah unit produk.
  int get totalQty => items.fold(0, (sum, item) => sum + item.qty);

  Order copyWith({OrderStatus? status}) => Order(
        id: id,
        customer: customer,
        items: items,
        status: status ?? this.status,
        createdAt: createdAt,
      );
}
