import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import 'email_login_page.dart';

/// Gerbang saat BELUM masuk — onboarding gambar full layar (3 slide) dengan
/// tombol "Gabung Sekarang". (Tanpa tombol "Lewati" karena login wajib.)
class LoginLandingPage extends StatefulWidget {
  const LoginLandingPage({super.key});

  @override
  State<LoginLandingPage> createState() => _LoginLandingPageState();
}

class _LoginLandingPageState extends State<LoginLandingPage> {
  final PageController _controller = PageController();
  int _page = 0;

  static const List<({String image, String title, String subtitle})> _slides = [
    (
      image:
          'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=900&q=70&auto=format&fit=crop',
      title: 'Selamat datang di Roti Gembung Panglima!',
      subtitle:
          'Nikmati roti gembung & kopi fresh berkualitas tinggi lewat satu '
          'aplikasi.',
    ),
    (
      image:
          'https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=900&q=70&auto=format&fit=crop',
      title: 'Selalu Fresh Setiap Hari',
      subtitle:
          'Dibuat dari bahan pilihan, Roti Gembung Panglima selalu fresh dan '
          'menggugah selera.',
    ),
    (
      image:
          'https://images.unsplash.com/photo-1521017432531-fbd92d768814?w=900&q=70&auto=format&fit=crop',
      title: 'Siap Melayani Panglima People',
      subtitle:
          'Antar ke alamatmu atau ambil di outlet terdekat, kami siap '
          'melayani di mana saja.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _join() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const EmailLoginPage()),
  );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light, // ikon status bar putih di atas gambar
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _controller,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, i) => _Slide(slide: _slides[i]),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 20,
                    child: _Dots(count: _slides.length, active: _page),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _join,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.maroon700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Gabung Sekarang',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Satu slide onboarding: gambar full layar + gradasi + teks judul/subjudul.
class _Slide extends StatelessWidget {
  const _Slide({required this.slide});

  final ({String image, String title, String subtitle}) slide;

  @override
  Widget build(BuildContext context) {
    const shadow = [Shadow(color: Colors.black54, blurRadius: 10)];
    return Stack(
      fit: StackFit.expand,
      children: [
        // Gambar full layar (fallback maroon bila jaringan gagal).
        Image.network(
          slide.image,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : Container(color: AppColors.maroon700),
          errorBuilder: (context, error, stack) =>
              Container(color: AppColors.maroon700),
        ),
        // Gradasi gelap di atas (agar teks terbaca) & sedikit di bawah (dots).
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black54,
                Colors.transparent,
                Colors.transparent,
                Colors.black38,
              ],
              stops: [0.0, 0.35, 0.75, 1.0],
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
            child: Column(
              children: [
                Text(
                  slide.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                    shadows: shadow,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  slide.subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.4,
                    shadows: shadow,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == active ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == active
                  ? AppColors.white
                  : Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
