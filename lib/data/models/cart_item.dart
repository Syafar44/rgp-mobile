import 'product.dart';

/// Satu baris di keranjang: produk, jumlah, dan catatan tambahan opsional.
class CartItem {
  const CartItem({
    required this.product,
    required this.qty,
    this.note = '',
  });

  final Product product;
  final int qty;
  final String note;

  /// Subtotal baris ini (harga efektif × jumlah).
  int get subtotal => product.effectivePrice * qty;

  CartItem copyWith({int? qty, String? note}) => CartItem(
        product: product,
        qty: qty ?? this.qty,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => {
        'product': product.toJson(),
        'qty': qty,
        'note': note,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        product: Product.fromJson(json['product'] as Map<String, dynamic>),
        qty: (json['qty'] as num?)?.toInt() ?? 1,
        note: json['note'] as String? ?? '',
      );
}
