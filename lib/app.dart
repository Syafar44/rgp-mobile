import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'widget_tree.dart';

class RotiGembungApp extends StatelessWidget {
  const RotiGembungApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Roti Gembung Panglima',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const WidgetTree(),
    );
  }
}
