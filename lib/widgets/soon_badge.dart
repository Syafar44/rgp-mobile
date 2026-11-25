import 'package:flutter/material.dart';

import '../core/config/app_features.dart';
import '../core/theme/app_colors.dart';

/// Label "Segera hadir" untuk fitur yang sengaja dikunci.
///
/// Satu bentuk untuk seluruh aplikasi supaya pembeli mengenalinya sebagai
/// keadaan yang sama di mana pun ditemui — bukan sekadar tombol yang kebetulan
/// mati. Teksnya diambil dari [AppFeatures.segeraHadir].
class SoonBadge extends StatelessWidget {
  const SoonBadge({super.key, this.icon = true});

  /// Sertakan ikon gembok. Dimatikan pada tempat yang sudah sempit.
  final bool icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon) ...[
            Icon(Icons.lock_outline, size: 11, color: AppColors.grey600),
            const SizedBox(width: 4),
          ],
          Text(
            AppFeatures.segeraHadir,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.grey600,
            ),
          ),
        ],
      ),
    );
  }
}
